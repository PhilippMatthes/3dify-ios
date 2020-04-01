//
//  PostFilterPassEncoder.m
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#import "PostFilterPassEncoder.h"
#import <simd/simd.h>

@interface PostFilterPassEncoder ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> texelSizeUniformBuffer;
@end

@implementation PostFilterPassEncoder

-(instancetype)initWithDevice:(id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        self.device = device;
        self.pipelineState = [self postFilterPipelineStateOnDevice:device];
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

-(id<MTLRenderPipelineState>)postFilterPipelineStateOnDevice:(id<MTLDevice>)device
{
    id<MTLLibrary> library = [device newDefaultLibrary];
    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.label = @"Post-filter Pipeline State";
    descriptor.vertexFunction = [library newFunctionWithName:@"project_texture"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"post_filter"];
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    NSError *error = nil;
    id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (!pipelineState) {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    return pipelineState;
}

-(void)  encodeIn:(id<MTLCommandBuffer>)commandBuffer
inputColorTexture:(id<MTLTexture>)colorTexture
    outputTexture:(id<MTLTexture>)outputTexture
     drawableSize:(CGSize)drawableSize
       clearColor:(MTLClearColor)clearColor
{
    [self updateTexelSizeUniformWith:drawableSize];
    MTLRenderPassDescriptor* descriptor = [self outputToColorTextureDescriptorOfSize:drawableSize
                                                                          clearColor:clearColor
                                                                           toTexture:outputTexture];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [encoder setLabel:@"Post-filter"];
    [encoder setRenderPipelineState:self.pipelineState];
    [encoder setFragmentTexture:colorTexture atIndex:0];
    [encoder setFragmentBuffer:self.texelSizeUniformBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [encoder endEncoding];
}

-(void)updateTexelSizeUniformWith:(CGSize)drawableSize
{
    simd_float2 texelSize = { 1.0f / drawableSize.width, 1.0f / drawableSize.height };
    memcpy(self.texelSizeUniformBuffer.contents, &texelSize, sizeof(simd_float2));
}

-(MTLRenderPassDescriptor *)outputToColorTextureDescriptorOfSize:(CGSize)size
                                                      clearColor:(MTLClearColor)clearColor
                                                       toTexture:(id<MTLTexture>)colorTexture
{
    MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    descriptor.colorAttachments[0].texture = colorTexture;
    descriptor.colorAttachments[0].clearColor = clearColor;
    descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    descriptor.renderTargetWidth = size.width;
    descriptor.renderTargetHeight = size.height;
    return descriptor;
}

@end
