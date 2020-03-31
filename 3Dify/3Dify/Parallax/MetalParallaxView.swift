//
//  MTKViewController.swift
//  MetalShaderCamera
//
//  Created by Alex Staravoitau on 26/04/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import UIKit
import MetalKit
import SwiftUI


enum ImageParallaxAnimationType: Int {
    case turnTable
    case horizontalSwitch
    case verticalSwitch
    
    static var all: [ImageParallaxAnimationType] {
        [turnTable, horizontalSwitch, verticalSwitch]
    }
    
    var description: String {
        switch self {
        case .turnTable: return "TurnTable"
        case .horizontalSwitch: return "HSwitch"
        case .verticalSwitch: return "VSwitch"
        }
    }
}


struct MetalParallaxViewRepresentable: UIViewRepresentable {
    @Binding var selectedAnimationInterval: TimeInterval
    @Binding var selectedAnimationIntensity: Float
    @Binding var selectedFocalPoint: Float
    @Binding var selectedAnimationTypeRawValue: Int
    @Binding var depthImage: DepthImage

    
    func makeUIView(context: UIViewRepresentableContext<MetalParallaxViewRepresentable>) -> MetalParallaxView {
        let view = MetalParallaxView(frame: .zero)
        view.depthImage = depthImage
        view.selectedFocalPoint = selectedFocalPoint
        view.selectedAnimationType = ImageParallaxAnimationType(rawValue: selectedAnimationTypeRawValue)!
        view.selectedAnimationInterval = selectedAnimationInterval
        view.selectedAnimationIntensity = selectedAnimationIntensity
        return view
    }
    
    func updateUIView(_ view: MetalParallaxView, context: Context) {
        if view.depthImage != depthImage {
            view.depthImage = depthImage
        }
        if view.selectedFocalPoint != selectedFocalPoint {
            view.selectedFocalPoint = selectedFocalPoint
        }
        let selectedAnimationType = ImageParallaxAnimationType(rawValue: selectedAnimationTypeRawValue)!
        if view.selectedAnimationType != selectedAnimationType {
            view.selectedAnimationType = selectedAnimationType
        }
        if view.selectedAnimationInterval != selectedAnimationInterval {
            view.selectedAnimationInterval = selectedAnimationInterval
        }
        if view.selectedAnimationIntensity != selectedAnimationIntensity {
            view.selectedAnimationIntensity = selectedAnimationIntensity
        }
    }
}


class MetalParallaxView: MTKView {
    var selectedAnimationInterval: TimeInterval?
    var selectedAnimationIntensity: Float?
    var selectedAnimationType: ImageParallaxAnimationType?
    var selectedFocalPoint: Float = 0.5
    
    var depthImage: DepthImage? {
        didSet {
            guard
                let depthImage = depthImage,
                let device = device
            else {return}
            let textureLoader = MTKTextureLoader(device: device)
            
            guard
                let diffuseData = depthImage.diffuse.pngData(),
                let depthData = depthImage.trueDepth?.pngData() ?? depthImage.predictedDepth?.pngData()
            else {return}
            
            diffuseTexture = try? textureLoader.newTexture(data: diffuseData)
            depthTexture = try? textureLoader.newTexture(data: depthData)
        }
    }
    var offsetX: Float = 0
    var offsetY: Float = 0
    
    var diffuseTexture: MTLTexture?
    var depthTexture: MTLTexture?
        
    lazy fileprivate var commandQueue: MTLCommandQueue? = {
        return device?.makeCommandQueue()
    }()

    let semaphore = DispatchSemaphore(value: 1)
    
    let startDate = Date()
    
    private var animatorShouldAnimate = true
    
    var parallaxPassDiffuseTexture: MTLTexture?
    var parallaxPassDepthTexture: MTLTexture?
    var parallaxPassDepthStencilState: MTLDepthStencilState?
    var parallaxPassRenderPassDescriptor: MTLRenderPassDescriptor?
    var parallaxPassRenderPipelineState: MTLRenderPipelineState?
    
    var hBlurPassDiffuseTexture: MTLTexture?
    var hBlurPassDepthStencilState: MTLDepthStencilState?
    var hBlurPassRenderPassDescriptor: MTLRenderPassDescriptor?
    var hBlurPassRenderPipelineState: MTLRenderPipelineState?
    
    var vBlurPassDiffuseTexture: MTLTexture?
    var vBlurPassDepthStencilState: MTLDepthStencilState?
    var vBlurPassRenderPassDescriptor: MTLRenderPassDescriptor?
    var vBlurPassRenderPipelineState: MTLRenderPipelineState?
    
    init(frame: CGRect) {
        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            fatalError("Failed creating a default system Metal device / default library. Please, make sure Metal is available on your hardware.")
        }
        super.init(frame: frame, device: device)
        
        delegate = self
        framebufferOnly = false
        contentScaleFactor = UIScreen.main.scale
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        colorPixelFormat = .rgba16Float
        
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(userDidPanView(_:))))
    }
    
    @objc func userDidPanView(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            animatorShouldAnimate = false
        case .ended:
            animatorShouldAnimate = true
        default:
            break
        }
        
        let translation = gestureRecognizer.translation(in: self)
        offsetX = Float(max(min(translation.x / frame.width * 0.3, 0.06), -0.06))
        offsetY = Float(max(min(translation.y / frame.height * 0.3, 0.06), -0.06))
    }
    
    func reloadPasses(drawableSize: CGSize) {
        guard
            let device = device,
            let library = device.makeDefaultLibrary()
        else {
            fatalError("Failed creating a default system Metal device / default library. Please, make sure Metal is available on your hardware.")
        }
        
        guard drawableSize != .zero else {return}
        
        commandQueue = device.makeCommandQueue()
        commandQueue!.label = "Command Queue Master"
        
        // MARK: - Parallax Pass
        
        let parallaxPassDiffuseTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: true)
        parallaxPassDiffuseTextureDescriptor.sampleCount = 1
        parallaxPassDiffuseTextureDescriptor.storageMode = .private
        parallaxPassDiffuseTextureDescriptor.textureType = .type2D
        parallaxPassDiffuseTextureDescriptor.usage = [.renderTarget, .shaderRead]
        parallaxPassDiffuseTexture = device.makeTexture(descriptor: parallaxPassDiffuseTextureDescriptor)!
        
        let parallaxPassDepthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: true)
        parallaxPassDepthTextureDescriptor.sampleCount = 1
        parallaxPassDepthTextureDescriptor.storageMode = .private
        parallaxPassDepthTextureDescriptor.textureType = .type2D
        parallaxPassDepthTextureDescriptor.usage = [.renderTarget, .shaderRead]
        parallaxPassDepthTexture = device.makeTexture(descriptor: parallaxPassDepthTextureDescriptor)!
        
        let parallaxPassDepthStencilDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: true)
        parallaxPassDepthStencilDescriptor.sampleCount = 1
        parallaxPassDepthStencilDescriptor.storageMode = .private
        parallaxPassDepthStencilDescriptor.textureType = .type2D
        parallaxPassDepthStencilDescriptor.usage = [.renderTarget, .shaderRead]
        let parallaxPassDepthStencil = device.makeTexture(descriptor: parallaxPassDepthStencilDescriptor)!
        
        let parallaxPassDepthStencilStateDescriptor = MTLDepthStencilDescriptor()
        parallaxPassDepthStencilStateDescriptor.isDepthWriteEnabled = true
        parallaxPassDepthStencilStateDescriptor.depthCompareFunction = .lessEqual
        parallaxPassDepthStencilStateDescriptor.frontFaceStencil = nil
        parallaxPassDepthStencilStateDescriptor.backFaceStencil = nil
        parallaxPassDepthStencilState = device.makeDepthStencilState(descriptor: parallaxPassDepthStencilStateDescriptor)!
        
        parallaxPassRenderPassDescriptor = MTLRenderPassDescriptor()
        parallaxPassRenderPassDescriptor!.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        parallaxPassRenderPassDescriptor!.colorAttachments[0].texture = parallaxPassDiffuseTexture
        parallaxPassRenderPassDescriptor!.colorAttachments[0].loadAction = .clear
        parallaxPassRenderPassDescriptor!.colorAttachments[0].storeAction = .store
        parallaxPassRenderPassDescriptor!.colorAttachments[1].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        parallaxPassRenderPassDescriptor!.colorAttachments[1].texture = parallaxPassDepthTexture
        parallaxPassRenderPassDescriptor!.colorAttachments[1].loadAction = .clear
        parallaxPassRenderPassDescriptor!.colorAttachments[1].storeAction = .store
        parallaxPassRenderPassDescriptor!.depthAttachment.loadAction = .clear
        parallaxPassRenderPassDescriptor!.depthAttachment.storeAction = .store
        parallaxPassRenderPassDescriptor!.depthAttachment.texture = parallaxPassDepthStencil
        parallaxPassRenderPassDescriptor!.depthAttachment.clearDepth = 1.0
        
        let parallaxPassRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        parallaxPassRenderPipelineDescriptor.label = "Parallax Pass Renderer"
        parallaxPassRenderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        parallaxPassRenderPipelineDescriptor.colorAttachments[1].pixelFormat = .rgba16Float
        parallaxPassRenderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        parallaxPassRenderPipelineDescriptor.sampleCount = 1
        parallaxPassRenderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        parallaxPassRenderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "parallaxPassFragmentFunction")

        parallaxPassRenderPipelineState = try! device.makeRenderPipelineState(descriptor: parallaxPassRenderPipelineDescriptor)
        
        // MARK: - Horizontal Blur Pass
        
        let hBlurPassDiffuseTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: true)
        hBlurPassDiffuseTextureDescriptor.sampleCount = 1
        hBlurPassDiffuseTextureDescriptor.storageMode = .private
        hBlurPassDiffuseTextureDescriptor.textureType = .type2D
        hBlurPassDiffuseTextureDescriptor.usage = [.renderTarget, .shaderRead]
        hBlurPassDiffuseTexture = device.makeTexture(descriptor: hBlurPassDiffuseTextureDescriptor)!
        
        let hBlurPassDepthStencilDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: true)
        hBlurPassDepthStencilDescriptor.sampleCount = 1
        hBlurPassDepthStencilDescriptor.storageMode = .private
        hBlurPassDepthStencilDescriptor.textureType = .type2D
        hBlurPassDepthStencilDescriptor.usage = [.renderTarget, .shaderRead]
        let hBlurPassDepthStencil = device.makeTexture(descriptor: hBlurPassDepthStencilDescriptor)!
        
        let hBlurPassDepthStencilStateDescriptor = MTLDepthStencilDescriptor()
        hBlurPassDepthStencilStateDescriptor.isDepthWriteEnabled = true
        hBlurPassDepthStencilStateDescriptor.depthCompareFunction = .lessEqual
        hBlurPassDepthStencilStateDescriptor.frontFaceStencil = nil
        hBlurPassDepthStencilStateDescriptor.backFaceStencil = nil
        hBlurPassDepthStencilState = device.makeDepthStencilState(descriptor: hBlurPassDepthStencilStateDescriptor)!
        
        hBlurPassRenderPassDescriptor = MTLRenderPassDescriptor()
        hBlurPassRenderPassDescriptor!.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        hBlurPassRenderPassDescriptor!.colorAttachments[0].texture = hBlurPassDiffuseTexture
        hBlurPassRenderPassDescriptor!.colorAttachments[0].loadAction = .clear
        hBlurPassRenderPassDescriptor!.colorAttachments[0].storeAction = .store
        hBlurPassRenderPassDescriptor!.depthAttachment.loadAction = .clear
        hBlurPassRenderPassDescriptor!.depthAttachment.storeAction = .store
        hBlurPassRenderPassDescriptor!.depthAttachment.texture = hBlurPassDepthStencil
        hBlurPassRenderPassDescriptor!.depthAttachment.clearDepth = 1.0
        
        let hBlurPassRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        hBlurPassRenderPipelineDescriptor.label = "Horizontal Blur Pass Renderer"
        hBlurPassRenderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        hBlurPassRenderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        hBlurPassRenderPipelineDescriptor.sampleCount = 1
        hBlurPassRenderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        hBlurPassRenderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "hBlurPassFragmentFunction")

        hBlurPassRenderPipelineState = try! device.makeRenderPipelineState(descriptor: hBlurPassRenderPipelineDescriptor)
        
        
        // MARK: - Vertical Blur Pass
        
        let vBlurPassDiffuseTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: true)
        vBlurPassDiffuseTextureDescriptor.sampleCount = 1
        vBlurPassDiffuseTextureDescriptor.storageMode = .private
        vBlurPassDiffuseTextureDescriptor.textureType = .type2D
        vBlurPassDiffuseTextureDescriptor.usage = [.renderTarget, .shaderRead]
        vBlurPassDiffuseTexture = device.makeTexture(descriptor: vBlurPassDiffuseTextureDescriptor)!
        
        let vBlurPassDepthStencilDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: true)
        vBlurPassDepthStencilDescriptor.sampleCount = 1
        vBlurPassDepthStencilDescriptor.storageMode = .private
        vBlurPassDepthStencilDescriptor.textureType = .type2D
        vBlurPassDepthStencilDescriptor.usage = [.renderTarget, .shaderRead]
        let vBlurPassDepthStencil = device.makeTexture(descriptor: vBlurPassDepthStencilDescriptor)!
        
        let vBlurPassDepthStencilStateDescriptor = MTLDepthStencilDescriptor()
        vBlurPassDepthStencilStateDescriptor.isDepthWriteEnabled = true
        vBlurPassDepthStencilStateDescriptor.depthCompareFunction = .lessEqual
        vBlurPassDepthStencilStateDescriptor.frontFaceStencil = nil
        vBlurPassDepthStencilStateDescriptor.backFaceStencil = nil
        vBlurPassDepthStencilState = device.makeDepthStencilState(descriptor: vBlurPassDepthStencilStateDescriptor)!
        
        vBlurPassRenderPassDescriptor = MTLRenderPassDescriptor()
        vBlurPassRenderPassDescriptor!.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        vBlurPassRenderPassDescriptor!.colorAttachments[0].texture = vBlurPassDiffuseTexture
        vBlurPassRenderPassDescriptor!.colorAttachments[0].loadAction = .clear
        vBlurPassRenderPassDescriptor!.colorAttachments[0].storeAction = .store
        vBlurPassRenderPassDescriptor!.depthAttachment.loadAction = .clear
        vBlurPassRenderPassDescriptor!.depthAttachment.storeAction = .store
        vBlurPassRenderPassDescriptor!.depthAttachment.texture = vBlurPassDepthStencil
        vBlurPassRenderPassDescriptor!.depthAttachment.clearDepth = 1.0
        
        let vBlurPassRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        vBlurPassRenderPipelineDescriptor.label = "Vertical Blur Pass Renderer"
        vBlurPassRenderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        vBlurPassRenderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        vBlurPassRenderPipelineDescriptor.sampleCount = 1
        vBlurPassRenderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        vBlurPassRenderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "vBlurPassFragmentFunction")

        vBlurPassRenderPipelineState = try! device.makeRenderPipelineState(descriptor: vBlurPassRenderPipelineDescriptor)
    }
    
    required init(coder: NSCoder) {
        fatalError()
    }
}


extension MetalParallaxView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        NSLog("MetalParallaxViewController drawable size will change to \(size)")
        reloadPasses(drawableSize: size)
    }
    
    func computeOffset(
        at progress: Double,
        withAnimationType animationType: ImageParallaxAnimationType
    ) -> CGPoint {
        switch animationType {
        case .turnTable:
            return CGPoint(
                x: sin(CGFloat(progress) * 2 * CGFloat.pi),
                y: cos(CGFloat(progress) * 2 * CGFloat.pi)
            )
        case .horizontalSwitch:
            return CGPoint(
                x: progress < 0.5 ? (4 * progress - 1) : (-4 * progress + 3),
                y: 0
            )
        case .verticalSwitch:
            return CGPoint(
                x: 0,
                y: progress < 0.5 ? (4 * progress - 1) : (-4 * progress + 3)
            )
        }
    }
    
    public func draw(in: MTKView) {
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        let elapsedTime = Date().timeIntervalSince(self.startDate)
        
        if
            let selectedAnimationInterval = self.selectedAnimationInterval,
            let selectedAnimationType = self.selectedAnimationType,
            let selectedAnimationIntensity = self.selectedAnimationIntensity,
            animatorShouldAnimate
        {
            let progress = 0.5 + (elapsedTime.remainder(dividingBy: selectedAnimationInterval)) / selectedAnimationInterval
            let offset = self.computeOffset(at: progress, withAnimationType: selectedAnimationType)
                .scaled(by: Double(selectedAnimationIntensity))
            offsetX = Float(offset.x)
            offsetY = Float(offset.y)
        }

        autoreleasepool {
            guard
                let diffuseTexture = diffuseTexture,
                let depthTexture = depthTexture,
                let device = device,
                let commandBuffer = commandQueue?.makeCommandBuffer()
            else {
                _ = semaphore.signal()
                return
            }

            render(diffuseTexture: diffuseTexture, depthTexture: depthTexture, withCommandBuffer: commandBuffer, device: device, atTime: elapsedTime)
        }
    }
    
    private func render(
        diffuseTexture: MTLTexture,
        depthTexture: MTLTexture,
        withCommandBuffer commandBuffer: MTLCommandBuffer,
        device: MTLDevice,
        atTime time: TimeInterval
    ) {
        guard
            let commandQueue = commandQueue,
            let currentDrawable = currentDrawable,
            let parallaxPassDiffuseTexture = parallaxPassDiffuseTexture,
            let parallaxPassDepthTexture = parallaxPassDepthTexture,
            let parallaxPassDepthStencilState = parallaxPassDepthStencilState,
            let parallaxPassRenderPassDescriptor = parallaxPassRenderPassDescriptor,
            let parallaxPassRenderPipelineState = parallaxPassRenderPipelineState
        else {
            _ = semaphore.signal()
            return
        }
        
        let parallaxPassCommandBuffer = commandQueue.makeCommandBuffer()!
        
        let parallaxPassEncoder = parallaxPassCommandBuffer.makeRenderCommandEncoder(descriptor: parallaxPassRenderPassDescriptor)!
        parallaxPassEncoder.pushDebugGroup("Render Parallax Pass")
        parallaxPassEncoder.label = "Render Parallax Pass"
        parallaxPassEncoder.setDepthStencilState(parallaxPassDepthStencilState)
        parallaxPassEncoder.setRenderPipelineState(parallaxPassRenderPipelineState)
        parallaxPassEncoder.setFragmentTexture(diffuseTexture, index: 0)
        parallaxPassEncoder.setFragmentTexture(depthTexture, index: 1)
        parallaxPassEncoder.setFragmentBytes(&offsetX, length: MemoryLayout<Float>.stride, index: 0)
        parallaxPassEncoder.setFragmentBytes(&offsetY, length: MemoryLayout<Float>.stride, index: 1)
        parallaxPassEncoder.setFragmentBytes(&selectedFocalPoint, length: MemoryLayout<Float>.stride, index: 2)
        parallaxPassEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        parallaxPassEncoder.popDebugGroup()
        parallaxPassEncoder.endEncoding()
        
        parallaxPassCommandBuffer.commit()
        
        
        // MARK: - Horizontal Blur Pass
        
        guard
            let hBlurPassDiffuseTexture = hBlurPassDiffuseTexture,
            let hBlurPassDepthStencilState = hBlurPassDepthStencilState,
            let hBlurPassRenderPassDescriptor = hBlurPassRenderPassDescriptor,
            let hBlurPassRenderPipelineState = hBlurPassRenderPipelineState
        else {
            _ = semaphore.signal()
            return
        }
        
        let hBlurPassCommandBuffer = commandQueue.makeCommandBuffer()!
        
        let hBlurPassEncoder = hBlurPassCommandBuffer.makeRenderCommandEncoder(descriptor: hBlurPassRenderPassDescriptor)!
        hBlurPassEncoder.pushDebugGroup("Horizontal Blur Pass")
        hBlurPassEncoder.label = "Horizontal Blur Pass"
        hBlurPassEncoder.setDepthStencilState(hBlurPassDepthStencilState)
        hBlurPassEncoder.setRenderPipelineState(hBlurPassRenderPipelineState)
        hBlurPassEncoder.setFragmentTexture(parallaxPassDiffuseTexture, index: 0)
        hBlurPassEncoder.setFragmentTexture(parallaxPassDepthTexture, index: 1)
        hBlurPassEncoder.setFragmentBytes(&selectedFocalPoint, length: MemoryLayout<Float>.stride, index: 0)
        hBlurPassEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        hBlurPassEncoder.popDebugGroup()
        hBlurPassEncoder.endEncoding()
        
        hBlurPassCommandBuffer.commit()
        
        
        // MARK: - Vertical Blur Pass
                
        guard
            let vBlurPassDiffuseTexture = vBlurPassDiffuseTexture,
            let vBlurPassDepthStencilState = vBlurPassDepthStencilState,
            let vBlurPassRenderPassDescriptor = vBlurPassRenderPassDescriptor,
            let vBlurPassRenderPipelineState = vBlurPassRenderPipelineState
        else {
            _ = semaphore.signal()
            return
        }
        
        let vBlurPassCommandBuffer = commandQueue.makeCommandBuffer()!
        
        let vBlurPassEncoder = vBlurPassCommandBuffer.makeRenderCommandEncoder(descriptor: vBlurPassRenderPassDescriptor)!
        vBlurPassEncoder.pushDebugGroup("Vertical Blur Pass")
        vBlurPassEncoder.label = "Vertical Blur Pass"
        vBlurPassEncoder.setDepthStencilState(vBlurPassDepthStencilState)
        vBlurPassEncoder.setRenderPipelineState(vBlurPassRenderPipelineState)
        vBlurPassEncoder.setFragmentTexture(hBlurPassDiffuseTexture, index: 0)
        vBlurPassEncoder.setFragmentTexture(parallaxPassDepthTexture, index: 1)
        vBlurPassEncoder.setFragmentBytes(&selectedFocalPoint, length: MemoryLayout<Float>.stride, index: 0)
        vBlurPassEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        vBlurPassEncoder.popDebugGroup()
        vBlurPassEncoder.endEncoding()
        
        vBlurPassCommandBuffer.commit()
        
        
        // MARK: - Blit Encoder
        
        let blitCommandBuffer = commandQueue.makeCommandBuffer()!
        
        let blitEncoder = blitCommandBuffer.makeBlitCommandEncoder()!
        blitEncoder.pushDebugGroup("Blit")
        let origin: MTLOrigin = MTLOriginMake(0, 0, 0)
        let size: MTLSize = MTLSizeMake(Int(drawableSize.width), Int(drawableSize.height), 1)
        
        blitEncoder.copy(
            from: vBlurPassDiffuseTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: origin,
            sourceSize: size,
            to: currentDrawable.texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: origin
        )
        blitEncoder.endEncoding()
        blitEncoder.popDebugGroup()
        
        blitCommandBuffer.addScheduledHandler { [weak self] (buffer) in
            self?.semaphore.signal()
        }
        blitCommandBuffer.present(currentDrawable)
        blitCommandBuffer.commit()
    }
}
