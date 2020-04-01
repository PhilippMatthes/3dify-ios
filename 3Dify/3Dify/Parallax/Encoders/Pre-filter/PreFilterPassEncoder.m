//
//  PreFilterPassEncoder.m
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#import "PreFilterPassEncoder.h"
#import <simd/simd.h>

@interface PreFilterPassEncoder ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> texelSizeUniformBuffer;
@end

@implementation PreFilterPassEncoder

-(instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        self.device = device;
        self.pipelineState = [self preFilterPipelineStateOnDevice:device];
        self.texelSizeUniformBuffer = [self makeTexelSizeUniformBuffer];
    }
    return self;
}

-(id<MTLBuffer>)makeTexelSizeUniformBuffer
{
    id<MTLBuffer> buffer = [self.device newBufferWithLength:sizeof(simd_float2)
                                                    options:MTLResourceOptionCPUCacheModeDefault];
    buffer.label = @"Texel Size Uniform";
    return buffer;
}

-(id<MTLRenderPipelineState>)preFilterPipelineStateOnDevice:(id<MTLDevice>)device
{
    id<MTLLibrary> library = [device newDefaultLibrary];
    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.label = @"Pre-filter Pipeline State";
    descriptor.vertexFunction = [library newFunctionWithName:@"project_texture"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"downsample_coc"];
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
    descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatR32Float;
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    NSError *error = nil;
    id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (!pipelineState) {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    return pipelineState;
}

-(void)   encodeIn:(id<MTLCommandBuffer>)commandBuffer
 inputColorTexture:(id<MTLTexture>)colorTexture
   inputCoCTexture:(id<MTLTexture>)cocTexture
outputColorTexture:(id<MTLTexture>)outputColorTexture
  outputCoCTexture:(id<MTLTexture>)outputCoCTexture
      drawableSize:(CGSize)drawableSize
        clearColor:(MTLClearColor)clearColor
{
    [self updateTexelSizeUniformWith:drawableSize];
    MTLRenderPassDescriptor* descriptor = [self outputToColorAndCocTextureDescriptorOfSize:drawableSize
                                                                                clearColor:clearColor
                                                                            toColorTexture:outputColorTexture
                                                                              toCoCTexture:outputCoCTexture];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [encoder setLabel:@"Pre-filter"];
    [encoder setRenderPipelineState:self.pipelineState];
    [encoder setFragmentTexture:colorTexture atIndex:0];
    [encoder setFragmentTexture:cocTexture atIndex:1];
    [encoder setFragmentBuffer:self.texelSizeUniformBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [encoder endEncoding];
}

-(void)updateTexelSizeUniformWith:(CGSize)drawableSize
{
    simd_float2 texelSize = { 1.0f / drawableSize.width, 1.0f / drawableSize.height };
    memcpy(self.texelSizeUniformBuffer.contents, &texelSize, sizeof(simd_float2));
}

-(MTLRenderPassDescriptor *)outputToColorAndCocTextureDescriptorOfSize:(CGSize)size
                                                            clearColor:(MTLClearColor)clearColor
                                                        toColorTexture:(id<MTLTexture>)colorTexture
                                                          toCoCTexture:(id<MTLTexture>)cocTexture
{
    MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    descriptor.colorAttachments[0].texture = colorTexture;
    descriptor.colorAttachments[0].clearColor = clearColor;
    descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    descriptor.colorAttachments[1].texture = cocTexture;
    descriptor.colorAttachments[1].clearColor = clearColor;
    descriptor.colorAttachments[1].loadAction = MTLLoadActionLoad;
    descriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
    descriptor.renderTargetWidth = size.width;
    descriptor.renderTargetHeight = size.height;
    return descriptor;
}

@end
