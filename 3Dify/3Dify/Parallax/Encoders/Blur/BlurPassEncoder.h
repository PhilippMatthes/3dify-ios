//
//  BlurPassEncoder.h
//  3Dify
//
//  Created by It's free real estate on 02.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

@import Foundation;
@import CoreGraphics;
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface BlurPassEncoder : NSObject
-(instancetype)initWithDevice:(id<MTLDevice>)device
                   isVertical:(bool)isVertical;
-(void)  encodeIn:(id<MTLCommandBuffer>)commandBuffer
inputColorTexture:(id<MTLTexture>)inputColorTexture
inputDepthTexture:(id<MTLTexture>)inputDepthTexture
   blurredTexture:(id<MTLTexture>)outputColorTexture
     drawableSize:(CGSize)drawableSize
       clearColor:(MTLClearColor)clearColor;
-(void)updateBlurIntensity:(float)blurIntensity;
-(void)updateFocalPoint:(float)focalPoint;
@end

NS_ASSUME_NONNULL_END
