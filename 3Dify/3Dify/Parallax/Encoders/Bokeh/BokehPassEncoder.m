//
//  BokehPassEncoder.m
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#import "BokehPassEncoder.h"
#import <simd/simd.h>

typedef struct {
    simd_float2 texelSize;
    simd_float1 bokehRadius;
} BokehUniforms;

@interface BokehPassEncoder ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> bokehUniformsBuffer;
@property (nonatomic) float bokehSize;
@end

@implementation BokehPassEncoder

-(instancetype)initWithDevice:(id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        self.device = device;
        self.pipelineState = [self bokehPipelineStateOnDevice:device];
        self.bokehUniformsBuffer = [self makeBokehUniformsBuffer];
        self.bokehSize = 0.0f;
    }
    return self;
}

-(id<MTLBuffer>)makeBokehUniformsBuffer
{
    id<MTLBuffer> buffer = [self.device newBufferWithLength:sizeof(BokehUniforms)
                                                    options:MTLResourceOptionCPUCacheModeDefault];
    buffer.label = @"Bokeh Uniforms";
    return buffer;
}

-(id<MTLRenderPipelineState>)bokehPipelineStateOnDevice:(id<MTLDevice>)device
{
    id<MTLLibrary> library = [device newDefaultLibrary];
    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.label = @"Bokeh Pipeline State";
    descriptor.vertexFunction = [library newFunctionWithName:@"project_texture"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"bokeh"];
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
  inputCoCTexture:(id<MTLTexture>)cocTexture
    outputTexture:(id<MTLTexture>)outputTexture
     drawableSize:(CGSize)drawableSize
       clearColor:(MTLClearColor)clearColor
{
    [self updateBokehUniformsWith:drawableSize];
    MTLRenderPassDescriptor* descriptor = [self outputToColorTextureDescriptorOfSize:drawableSize
                                                                          clearColor:clearColor
                                                                           toTexture:outputTexture];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [encoder setLabel:@"Bokeh"];
    [encoder setRenderPipelineState:self.pipelineState];
    [encoder setFragmentTexture:colorTexture atIndex:0];
    [encoder setFragmentTexture:cocTexture atIndex:1];
    [encoder setFragmentBuffer:self.bokehUniformsBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [encoder endEncoding];
}

-(void)updateBokehRadius:(float)bokehSize
{
    self.bokehSize = bokehSize;
}

-(void)updateBokehUniformsWith:(CGSize)drawableSize
{
    BokehUniforms uniforms = (BokehUniforms) {
        .texelSize = { 1.0f / drawableSize.width, 1.0f / drawableSize.height },
        .bokehRadius = self.bokehSize
    };
    memcpy(self.bokehUniformsBuffer.contents, &uniforms, sizeof(BokehUniforms));
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
