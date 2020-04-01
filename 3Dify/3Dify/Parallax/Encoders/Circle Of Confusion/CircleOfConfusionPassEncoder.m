//
//  CircleOfConfusionPassEncoder.m
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#import "CircleOfConfusionPassEncoder.h"
#import "CoCUniforms.h"

@interface CircleOfConfusionPassEncoder ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> uniforms;
@property (nonatomic) float bokehRadius, focusDistance, focusRange;
@end

@implementation CircleOfConfusionPassEncoder

-(instancetype)initWithDevice:(id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        self.device = device;
        self.pipelineState = [self circleOfConfusionPipelineStateOnDevice:device];
        self.uniforms = [self makeUniforms];
    }
    return self;
}

-(id<MTLRenderPipelineState>)circleOfConfusionPipelineStateOnDevice:(id<MTLDevice>)device
{
    id<MTLLibrary> library = [device newDefaultLibrary];
    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.label = @"Circle Of Confusion Pipeline State";
    descriptor.vertexFunction = [library newFunctionWithName:@"project_texture"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"circle_of_confusion_pass"];
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatR32Float;
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    NSError *error = nil;
    id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (!pipelineState) {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    return pipelineState;
}

-(id<MTLBuffer>)makeUniforms
{
    id<MTLBuffer> buffer = [self.device newBufferWithLength:sizeof(CoCUniforms)
                                                    options:MTLResourceOptionCPUCacheModeDefault];
    buffer.label = @"Circle Of Confusion Pass Uniforms";
    return buffer;
}

#pragma mark - CircleOfConfusionPassEncoder

-(void)encodeIn:(id<MTLCommandBuffer>)commandBuffer
                   inputDepthTexture:(id<MTLTexture>)depthTexture
                       outputTexture:(id<MTLTexture>)outputTexture
                        drawableSize:(CGSize)drawableSize
                          clearColor:(MTLClearColor)clearColor
{
    MTLRenderPassDescriptor* descriptor = [self outputToColorTextureDescriptorOfSize:drawableSize
                                                                          clearColor:clearColor
                                                                           toTexture:outputTexture];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [encoder setLabel:@"Circle Of Confusion"];
    [encoder setRenderPipelineState:self.pipelineState];
    [encoder setFragmentTexture:depthTexture atIndex:0];
    [encoder setFragmentBuffer:self.uniforms offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [encoder endEncoding];
}

-(void)updateUniformsWithBokehRadius:(float)bokehRadius
{
    self.bokehRadius = bokehRadius;
    [self updateUniformBuffer];
}

-(void)updateUniformsWithFocusDistance:(float)focusDistance focusRange:(float)focusRange
{
    self.focusDistance = focusDistance;
    self.focusRange = focusRange;
    [self updateUniformBuffer];
}

-(void)updateUniformBuffer
{
    CoCUniforms uniforms = (CoCUniforms) {
        .focusDist = self.focusDistance,
        .focusRange = self.focusRange,
        .bokehRadius = self.bokehRadius
    };
    memcpy(self.uniforms.contents, &uniforms, sizeof(CoCUniforms));
}

- (MTLRenderPassDescriptor *)outputToColorTextureDescriptorOfSize:(CGSize)size
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
