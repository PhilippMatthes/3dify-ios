//
//  CircleOfConfusionPassEncoder.h
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

@import CoreGraphics;
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface CircleOfConfusionPassEncoder : NSObject
-(instancetype)initWithDevice:(id<MTLDevice>)device;
-(void)encodeIn:(id<MTLCommandBuffer>)commandBuffer
                   inputDepthTexture:(id<MTLTexture>)depthTexture
                       outputTexture:(id<MTLTexture>)outputTexture
                        drawableSize:(CGSize)drawableSize
                          clearColor:(MTLClearColor)clearColor;
-(void)updateUniformsWithBokehRadius:(float)bokehRadius;
-(void)updateUniformsWithFocusDistance:(float)focusDistance focusRange:(float)focusRange;
@end

NS_ASSUME_NONNULL_END
