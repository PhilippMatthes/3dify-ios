//
//  DepthToColorMapConverter.swift
//  AVCam
//
//  Created by Giulio Zaccaroni on 21/04/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import CoreMedia
import CoreVideo
import MetalKit

struct BGRAPixel {
    var blue: UInt8 = 0
    var green: UInt8 = 0
    var red: UInt8 = 0
    var alpha: UInt8 = 0
}

class DepthToColorMapConverter: FilterRenderer {
    
    var description: String = "Depth to Color Map Converter"
    
    var isPrepared = false
    
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    
    private var computePipelineState: MTLComputePipelineState?
    
    private lazy var commandQueue: MTLCommandQueue? = {
        return self.metalDevice.makeCommandQueue()
    }()
    private var colorBuf: MTLBuffer?

    private var textureCache: CVMetalTextureCache!
    private let bytesPerPixel = 8
    
    
    required init() {
        let defaultLibrary = metalDevice.makeDefaultLibrary()!
        let kernelFunction = defaultLibrary.makeFunction(name: "depthToColorMap")
        do {
            computePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction!)
        } catch {
            fatalError("Unable to create depth converter pipeline state. (\(error))")
        }
        
    }
    
    func prepare(outputRetainedBufferCountHint: Int) {
        reset()
        
        var metalTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache) != kCVReturnSuccess {
            assertionFailure("Unable to allocate depth converter texture cache")
        } else {
            textureCache = metalTextureCache
        }
        
        isPrepared = true
    }
    
    func reset() {
        textureCache = nil
        isPrepared = false
    }
    
    // MARK: - Depth to Grayscale Conversion
    func render(image: CGImage) -> CGImage? {
        if !isPrepared {
            assertionFailure("Invalid state: Not prepared")
            return nil
        }
        
        guard let outputTexture = texture(pixelFormat: .rgba16Float, width: image.width, height: image.height),
            let inputTexture = texture(from: image) else {
                return nil
        }

        // Set up command queue, buffer, and encoder
        guard let commandQueue = commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                print("Failed to create Metal command queue")
                CVMetalTextureCacheFlush(textureCache!, 0)
                return nil
        }
        
        commandEncoder.label = "Depth to JET"
        commandEncoder.setComputePipelineState(computePipelineState!)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        
        commandEncoder.setBuffer(colorBuf, offset: 0, index: 2)

        // Set up the thread groups.
        let width = computePipelineState!.threadExecutionWidth
        let height = computePipelineState!.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        let threadgroupsPerGrid = MTLSize(width: (inputTexture.width + width - 1) / width,
                                          height: (inputTexture.height + height - 1) / height,
                                          depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        
        return cgImage(from: outputTexture)
    }
    private func cgImage(from texture: MTLTexture) -> CGImage? {
        
        // The total number of bytes of the texture
        let imageByteCount = texture.width * texture.height * bytesPerPixel
        
        // The number of bytes for each image row
        let bytesPerRow = texture.width * bytesPerPixel
        
        // An empty buffer that will contain the image
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        // Gets the bytes from the texture
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        // Creates an image context
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &src, width: texture.width, height: texture.height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        // Creates the image from the graphics context
        let dstImage = context?.makeImage()
        
        // Creates the final UIImage
        return dstImage
    }
    private func texture(from image: CGImage) -> MTLTexture? {
        
        let textureLoader = MTKTextureLoader(device: self.metalDevice)
        do {
            let textureOut = try textureLoader.newTexture(cgImage: image)
            return textureOut
        }
        catch {
            return nil
        }
    }
    private func texture(pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture? {
        
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

            return self.metalDevice.makeTexture(descriptor: textureDescriptor)
    }
    func makeTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer, textureFormat: MTLPixelFormat) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Create a Metal texture from the image buffer
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, textureFormat, width, height, 0, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Depth converter failed to create preview texture")
            
            CVMetalTextureCacheFlush(textureCache, 0)
            
            return nil
        }
        
        return texture
    }
    

}

