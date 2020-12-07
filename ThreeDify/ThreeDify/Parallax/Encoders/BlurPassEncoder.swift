//
// 3Dify App
//
// Project website: https://github.com/3dify-app
//
// Authors:
// - Philipp Matthes 2020, Contact: mail@philippmatth.es
//
// Copyright notice: All rights reserved by the authors given above. Do not
// remove or change this copyright notice without confirmation of the authors.
//

import Foundation
import MetalKit
import simd

struct BlurPassUniforms {
    var isVertical: simd_bool
    var blurIntensity: simd_float1
    var focalPoint: simd_float1
    
    init(
        isVertical: simd_bool,
        blurIntensity: simd_float1 = 5,
        focalPoint: simd_float1 = 0
    ) {
        self.isVertical = isVertical
        self.blurIntensity = blurIntensity
        self.focalPoint = focalPoint
    }
}

struct BlurPassEncoder {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let uniformsBuffer: MTLBuffer
    
    var uniforms: BlurPassUniforms
    
    enum InitializationError: Error {
        case libraryInitFailed
        case pipelineInitFailed
        case bufferInitFailed
    }
    
    enum RenderingError: Error {
        case makeDescriptorFailed
    }
    
    init(device: MTLDevice, isVertical: Bool) throws {
        try self.init(device: device, uniforms: .init(isVertical: isVertical))
    }
    
    init(device: MTLDevice, uniforms: BlurPassUniforms) throws {
        self.device = device
        
        guard
            let library = device.makeDefaultLibrary()
        else { throw InitializationError.libraryInitFailed }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "\(uniforms.isVertical ? "Vertical" : "Horizontal") Blur Pipeline State"
        descriptor.vertexFunction = library.makeFunction(name: "project_texture")
        descriptor.fragmentFunction = library.makeFunction(name: "blur")
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.colorAttachments[1].pixelFormat = .rgba16Float
        descriptor.depthAttachmentPixelFormat = .invalid
        
        guard
            let pipelineState = try? device.makeRenderPipelineState(
                descriptor: descriptor
            )
        else { throw InitializationError.pipelineInitFailed }
        self.pipelineState = pipelineState
        guard
            let buffer = device.makeBuffer(
                length: MemoryLayout.size(ofValue: uniforms),
                options: .cpuCacheModeWriteCombined
            )
        else { throw InitializationError.bufferInitFailed }
        buffer.label = "\(uniforms.isVertical ? "Vertical" : "Horizontal") Blur Uniforms Buffer"
        self.uniformsBuffer = buffer
        
        self.uniforms = uniforms
    }
    
    mutating func encode(
        inCommandBuffer commandBuffer: MTLCommandBuffer,
        inputColorTexture: MTLTexture,
        inputDepthTexture: MTLTexture,
        outputBlurredTexture: MTLTexture,
        drawableSize: CGSize,
        clearColor: MTLClearColor
    ) throws {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = outputBlurredTexture
        descriptor.colorAttachments[0].clearColor = clearColor
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.renderTargetWidth = Int(drawableSize.width)
        descriptor.renderTargetHeight = Int(drawableSize.height)
        memcpy(
            uniformsBuffer.contents(),
            &uniforms,
            MemoryLayout.size(ofValue: uniforms)
        )
        guard
            let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            )
        else { throw RenderingError.makeDescriptorFailed }
        encoder.label = "\(uniforms.isVertical ? "Vertical" : "Horizontal") Blur"
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(inputColorTexture, index: 0)
        encoder.setFragmentTexture(inputDepthTexture, index: 1)
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }
}

