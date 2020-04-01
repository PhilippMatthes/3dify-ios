
#import "ParallaxOcclusionPassEncoder.h"
#import <simd/simd.h>

typedef struct {
    simd_float1 offsetX;
    simd_float1 offsetY;
    simd_float1 focalPoint;
} ParallaxOcclusionUniforms;

@interface ParallaxOcclusionPassEncoder ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> parallaxOcclusionUniformsBuffer;
@property (nonatomic) simd_float1 offsetX;
@property (nonatomic) simd_float1 offsetY;
@property (nonatomic) simd_float1 focalPoint;
@end

@implementation ParallaxOcclusionPassEncoder

-(instancetype)initWithDevice:(id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        self.device = device;
        self.pipelineState = [self parallaxOcclusionPipelineStateOnDevice:device];
        self.parallaxOcclusionUniformsBuffer = [self makeParallaxOcclusionUniformsBuffer];
        self.offsetX = 0.0f;
        self.offsetY = 0.0f;
        self.focalPoint = 0.0f;
    }
    return self;
}

-(id<MTLBuffer>)makeParallaxOcclusionUniformsBuffer
{
    id<MTLBuffer> buffer = [self.device newBufferWithLength:sizeof(ParallaxOcclusionUniforms)
                                                    options:MTLResourceOptionCPUCacheModeDefault];
    buffer.label = @"Parallax Occlusion Uniforms";
    return buffer;
}

-(id<MTLRenderPipelineState>)parallaxOcclusionPipelineStateOnDevice:(id<MTLDevice>)device
{
    id<MTLLibrary> library = [device newDefaultLibrary];
    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.label = @"Parallax Occlusion Pipeline State";
    descriptor.vertexFunction = [library newFunctionWithName:@"project_texture"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"parallax_occlusion"];
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
outputColorTexture:(id<MTLTexture>)outputColorTexture
outputDepthTexture:(id<MTLTexture>)outputDepthTexture
     drawableSize:(CGSize)drawableSize
       clearColor:(MTLClearColor)clearColor
{
    MTLRenderPassDescriptor* descriptor = [self outputToColorTextureDescriptorOfSize:drawableSize
                                  clearColor:clearColor
                                  outputColorTexture:outputColorTexture
                                  outputDepthTexture:outputDepthTexture];
    [self updateParallaxOcclusionUniforms];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [encoder setLabel:@"Parallax Occlusion"];
    [encoder setRenderPipelineState:self.pipelineState];
    [encoder setFragmentTexture:inputColorTexture atIndex:0];
    [encoder setFragmentTexture:inputDepthTexture atIndex:1];
    [encoder setFragmentBuffer:self.parallaxOcclusionUniformsBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [encoder endEncoding];
}

-(void)updateOffsetX:(simd_float1)offsetX
          andOffsetY:(simd_float1)offsetY
{
    self.offsetX = offsetX;
    self.offsetY = offsetY;
}

-(void)updateFocalPoint:(simd_float1)focalPoint
{
    self.focalPoint = focalPoint;
}

-(void)updateParallaxOcclusionUniforms
{
    ParallaxOcclusionUniforms uniforms = (ParallaxOcclusionUniforms) {
        .offsetX = self.offsetX,
        .offsetY = self.offsetY,
        .focalPoint = self.focalPoint
    };
    memcpy(self.parallaxOcclusionUniformsBuffer.contents, &uniforms, sizeof(ParallaxOcclusionUniforms));
}

-(MTLRenderPassDescriptor *)outputToColorTextureDescriptorOfSize:(CGSize)size
                                                      clearColor:(MTLClearColor)clearColor
                                              outputColorTexture:(id<MTLTexture>)outputColorTexture
                                              outputDepthTexture:(id<MTLTexture>)outputDepthTexture
{
    MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    descriptor.colorAttachments[0].texture = outputColorTexture;
    descriptor.colorAttachments[0].clearColor = clearColor;
    descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    descriptor.colorAttachments[1].texture = outputDepthTexture;
    descriptor.colorAttachments[1].clearColor = clearColor;
    descriptor.colorAttachments[1].loadAction = MTLLoadActionLoad;
    descriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
    descriptor.renderTargetWidth = size.width;
    descriptor.renderTargetHeight = size.height;
    return descriptor;
}

@end
