//
//  ParallaxOcclusionEncoder.h
//  3Dify
//
//  Created by It's free real estate on 01.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

@import Foundation;
@import CoreGraphics;
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface ParallaxOcclusionPassEncoder : NSObject
-(instancetype)initWithDevice:(id<MTLDevice>)device;
-(void)  encodeIn:(id<MTLCommandBuffer>)commandBuffer
inputColorTexture:(id<MTLTexture>)inputColorTexture
inputDepthTexture:(id<MTLTexture>)inputDepthTexture
outputColorTexture:(id<MTLTexture>)outputColorTexture
outputDepthTexture:(id<MTLTexture>)outputDepthTexture
     drawableSize:(CGSize)drawableSize
       clearColor:(MTLClearColor)clearColor;
-(void)updateOffsetX:(float)offsetX
          andOffsetY:(float)offsetY;
-(void)updateFocalPoint:(float)focalPoint;
@end

NS_ASSUME_NONNULL_END
