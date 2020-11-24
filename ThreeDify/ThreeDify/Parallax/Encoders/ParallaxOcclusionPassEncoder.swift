import Foundation
import MetalKit
import simd

struct ParallaxOcclusionUniforms {
    var offsetX: simd_float1
    var offsetY: simd_float1
    var focalPoint: simd_float1
    
    static var initial: Self {
        .init(offsetX: 0, offsetY: 0, focalPoint: 0)
    }
}

struct ParallaxOcclusionPassEncoder {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let uniformsBuffer: MTLBuffer
    
    var uniforms: ParallaxOcclusionUniforms
    
    enum InitializationError: Error {
        case libraryInitFailed
        case pipelineInitFailed
        case bufferInitFailed
    }
    
    enum RenderingError: Error {
        case makeDescriptorFailed
    }
    
    init(device: MTLDevice, uniforms: ParallaxOcclusionUniforms = .initial) throws {
        self.device = device
        
        guard
            let library = device.makeDefaultLibrary()
        else { throw InitializationError.libraryInitFailed }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Parallax Occlusion Pipeline State"
        descriptor.vertexFunction = library.makeFunction(name: "project_texture")
        descriptor.fragmentFunction = library.makeFunction(name: "parallax_occlusion")
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
        buffer.label = "Parallax Occlusion Uniforms Buffer"
        self.uniformsBuffer = buffer
        
        self.uniforms = uniforms
    }
    
    mutating func encode(
        inCommandBuffer commandBuffer: MTLCommandBuffer,
        inputColorTexture: MTLTexture,
        inputDepthTexture: MTLTexture,
        outputColorTexture: MTLTexture,
        outputDepthTexture: MTLTexture,
        drawableSize: CGSize,
        clearColor: MTLClearColor
    ) throws {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = outputColorTexture
        descriptor.colorAttachments[0].clearColor = clearColor
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[1].texture = outputDepthTexture
        descriptor.colorAttachments[1].clearColor = clearColor
        descriptor.colorAttachments[1].loadAction = .load
        descriptor.colorAttachments[1].storeAction = .store
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
        encoder.label = "Parallax Occlusion"
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(inputColorTexture, index: 0)
        encoder.setFragmentTexture(inputDepthTexture, index: 1)
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }
}
