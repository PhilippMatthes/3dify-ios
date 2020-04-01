//
//  ComposePassEncoder.h
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 16/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

@import CoreGraphics;
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface ComposePassEncoder : NSObject
-(instancetype)initWithDevice:(id<MTLDevice>)device;
-(void)  encodeIn:(id<MTLCommandBuffer>)commandBuffer
inputColorTexture:(id<MTLTexture>)colorTexture
  inputDoFTexture:(id<MTLTexture>)dofTexture
  inputCoCTexture:(id<MTLTexture>)cocTexture
    outputTexture:(id<MTLTexture>)outputTexture
     drawableSize:(CGSize)drawableSize
       clearColor:(MTLClearColor)clearColor;
@end

NS_ASSUME_NONNULL_END
