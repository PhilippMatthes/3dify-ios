//
//  PostFilterPassEncoder.h
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

@import CoreGraphics;
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface PostFilterPassEncoder : NSObject
-(instancetype)initWithDevice:(id<MTLDevice>)device;
-(void)  encodeIn:(id<MTLCommandBuffer>)commandBuffer
inputColorTexture:(id<MTLTexture>)colorTexture
    outputTexture:(id<MTLTexture>)outputTexture
     drawableSize:(CGSize)drawableSize
       clearColor:(MTLClearColor)clearColor;
@end

NS_ASSUME_NONNULL_END
