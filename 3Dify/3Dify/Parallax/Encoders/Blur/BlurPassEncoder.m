//
//  BlurPassEncoder.m
//  3Dify
//
//  Created by It's free real estate on 02.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BlurPassEncoder.h"
#import <simd/simd.h>

typedef struct {
    simd_bool isVertical;
    simd_float1 blurIntensity;
    simd_float1 focalPoint;
} BlurUniforms;

@interface BlurPassEncoder ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> blurUniformsBuffer;
@property (nonatomic) simd_bool isVertical;
@property (nonatomic) simd_float1 blurIntensity;
@property (nonatomic) simd_float1 focalPoint;
@end

@implementation BlurPassEncoder

-(instancetype)initWithDevice:(id<MTLDevice>)device
                   isVertical:(simd_bool)isVertical
{
    self = [super init];
    if (self) {
        self.device = device;
        self.pipelineState = [self blurPipelineStateOnDevice:device];
        self.blurUniformsBuffer = [self makeBlurUniformsBuffer];
        self.isVertical = isVertical;
        self.blurIntensity = 5.0f;
        self.focalPoint = 0.0f;
    }
    return self;
}

-(id<MTLBuffer>)makeBlurUniformsBuffer
{
    id<MTLBuffer> buffer = [self.device newBufferWithLength:sizeof(BlurUniforms)
                                                    options:MTLResourceOptionCPUCacheModeDefault];
    buffer.label = @"Blur Uniforms";
    return buffer;
}

-(id<MTLRenderPipelineState>)blurPipelineStateOnDevice:(id<MTLDevice>)device
{
    id<MTLLibrary> library = [device newDefaultLibrary];
    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.label = @"Blur Pipeline State";
    descriptor.vertexFunction = [library newFunctionWithName:@"project_texture"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"blur"];
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
    descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    NSError *error = nil;
    id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (!pipelineState) {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    return pipelineState;
}

-(void)  encodeIn:(id<MTLCommandBuffer>)commandBuffer
inputColorTexture:(id<MTLTexture>)inputColorTexture
inputDepthTexture:(id<MTLTexture>)inputDepthTexture
   blurredTexture:(id<MTLTexture>)blurredTexture
     drawableSize:(CGSize)drawableSize
       clearColor:(MTLClearColor)clearColor
{
    MTLRenderPassDescriptor* descriptor = [
   self outputToColorTextureDescriptorOfSize:drawableSize
                                  clearColor:clearColor
                                  blurredTexture:blurredTexture];
    [self updateBlurUniforms];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [encoder setLabel:@"Blur"];
    [encoder setRenderPipelineState:self.pipelineState];
    [encoder setFragmentTexture:inputColorTexture atIndex:0];
    [encoder setFragmentTexture:inputDepthTexture atIndex:1];
    [encoder setFragmentBuffer:self.blurUniformsBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [encoder endEncoding];
}

-(void)updateBlurIntensity:(simd_float1)blurIntensity
{
    self.blurIntensity = blurIntensity;
}

-(void)updateFocalPoint:(simd_float1)focalPoint
{
    self.focalPoint = focalPoint;
}

-(void)updateBlurUniforms
{
    BlurUniforms uniforms = (BlurUniforms) {
        .isVertical = self.isVertical,
        .blurIntensity = self.blurIntensity,
        .focalPoint = self.focalPoint
    };
    memcpy(self.blurUniformsBuffer.contents, &uniforms, sizeof(BlurUniforms));
}

-(MTLRenderPassDescriptor *)outputToColorTextureDescriptorOfSize:(CGSize)size
                                                      clearColor:(MTLClearColor)clearColor
                                                  blurredTexture:(id<MTLTexture>)blurredTexture
{
    MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    descriptor.colorAttachments[0].texture = blurredTexture;
    descriptor.colorAttachments[0].clearColor = clearColor;
    descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    descriptor.renderTargetWidth = size.width;
    descriptor.renderTargetHeight = size.height;
    return descriptor;
}

@end
