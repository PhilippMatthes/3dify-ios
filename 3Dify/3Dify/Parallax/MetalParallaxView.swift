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
import Photos
import SpriteKit


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


internal extension View {
    func frame(rect: CGRect) -> some View {
        self
            .frame(width: rect.size.width, height: rect.size.height)
            .offset(x: rect.origin.x, y: rect.origin.y)
    }
}


struct MetalParallaxViewBestFitContainer: View {
    @Binding var shouldShowDepth: Bool
    @Binding var shouldShowWatermark: Bool
    @Binding var selectedAnimationInterval: TimeInterval
    @Binding var selectedAnimationIntensity: Float
    @Binding var selectedFocalPoint: Float
    @Binding var selectedBlurIntensity: Float
    @Binding var selectedAnimationTypeRawValue: Int
    @Binding var depthImage: DepthImage
    
    @Binding var isPaused: Bool
    @Binding var isSaving: Bool
    var onSaveVideoUpdate: (SaveState) -> ()
    
    func bestFitLayout(for frame: CGRect) -> CGRect {
        let viewAspectRatio = frame.size.height / frame.size.width
        let imageAspectRatio = depthImage.diffuse.size.height / depthImage.diffuse.size.width
        
        let bestFitHeight: CGFloat
        let bestFitWidth: CGFloat
        
        if imageAspectRatio > viewAspectRatio {
            bestFitWidth = frame.width
            bestFitHeight = frame.width * imageAspectRatio
        } else {
            bestFitWidth = frame.height / imageAspectRatio
            bestFitHeight = frame.height
        }
        
        let widthPadding = CGFloat(selectedAnimationIntensity) * (1 / 0.05) * 0.1
        let heightPadding = CGFloat(selectedAnimationIntensity) * (1 / 0.05) * 0.1
        
        return CGRect(
            x: -widthPadding,
            y: -heightPadding,
            width: bestFitWidth + 2 * widthPadding,
            height: bestFitHeight + 2 * heightPadding
        )
    }
    
    var body: some View {
        GeometryReader { outerGeometry in
            GeometryReader { innerGeometry in
                MetalParallaxViewRepresentable(
                    shouldShowDepth: self.$shouldShowDepth,
                    shouldShowWatermark: self.$shouldShowWatermark,
                    selectedAnimationInterval: self.$selectedAnimationInterval,
                    selectedAnimationIntensity: self.$selectedAnimationIntensity,
                    selectedFocalPoint: self.$selectedFocalPoint,
                    selectedBlurIntensity: self.$selectedBlurIntensity,
                    selectedAnimationTypeRawValue: self.$selectedAnimationTypeRawValue,
                    depthImage: self.$depthImage,
                    isPaused: self.$isPaused,
                    isSaving: self.$isSaving,
                    onSaveVideoUpdate: self.onSaveVideoUpdate
                )
                .frame(rect: self.bestFitLayout(for: innerGeometry.frame(in: .local)))
            }.frame(rect: outerGeometry.frame(in: .local))
        }
    }
}


struct MetalParallaxViewRepresentable: UIViewRepresentable {
    @Binding var shouldShowDepth: Bool
    @Binding var shouldShowWatermark: Bool
    @Binding var selectedAnimationInterval: TimeInterval
    @Binding var selectedAnimationIntensity: Float
    @Binding var selectedFocalPoint: Float
    @Binding var selectedBlurIntensity: Float
    @Binding var selectedAnimationTypeRawValue: Int
    @Binding var depthImage: DepthImage
    
    @Binding var isPaused: Bool
    @Binding var isSaving: Bool
    var onSaveVideoUpdate: (SaveState) -> ()
    
    func makeUIView(context: UIViewRepresentableContext<MetalParallaxViewRepresentable>) -> MetalParallaxView {
        let view = MetalParallaxView(frame: .zero, shouldShowWatermark: shouldShowWatermark)
        view.shouldShowDepth = shouldShowDepth
        view.depthImage = depthImage
        view.blurIntensity = selectedBlurIntensity
        view.focalPoint = selectedFocalPoint
        view.selectedAnimationType = ImageParallaxAnimationType(rawValue: selectedAnimationTypeRawValue)!
        view.selectedAnimationInterval = selectedAnimationInterval
        view.selectedAnimationIntensity = selectedAnimationIntensity
        view.isPaused = isPaused
        return view
    }
    
    func updateUIView(_ view: MetalParallaxView, context: Context) {
        if view.shouldShowDepth != shouldShowDepth {
            view.shouldShowDepth = shouldShowDepth
        }
        if view.shouldShowWatermark != shouldShowWatermark {
            view.shouldShowWatermark = shouldShowWatermark
            
            if shouldShowWatermark {
                view.layoutAndShowWatermark()
            } else {
                view.removeWatermark()
            }
        }
        if view.depthImage != depthImage {
            view.depthImage = depthImage
        }
        if view.blurIntensity != selectedBlurIntensity {
            view.blurIntensity = selectedBlurIntensity
        }
        if view.focalPoint != selectedFocalPoint {
            view.focalPoint = selectedFocalPoint
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
        if view.isPaused != isPaused {
            view.isPaused = isPaused
        }
        if isSaving {
            view.renderVideo(update: self.onSaveVideoUpdate)
        }
    }
}


class MetalParallaxView: MTKView {
    var onBeforeRenderFrame: (() -> ())?
    var onAfterRenderFrame: ((MTLTexture) -> ())?
    
    var depthImage: DepthImage? {
        didSet {
            guard let depthImage = depthImage, let device = device else {return}
            let textureLoader = MTKTextureLoader(device: device)
            
            guard
                let diffuseData = depthImage.diffuse.pngData(),
                let depthData = depthImage.depth.pngData()
            else {return}
            
            inputDiffuseTexture = try? textureLoader.newTexture(data: diffuseData)
            inputDepthTexture = try? textureLoader.newTexture(data: depthData)
        }
    }
    
    var blurIntensity: Float? {
        didSet {
            guard let blurIntensity = blurIntensity else {return}
            vBlurPassEncoder.updateBlurIntensity(blurIntensity)
            hBlurPassEncoder.updateBlurIntensity(blurIntensity)
        }
    }
    
    var focalPoint: Float? {
        didSet {
            guard let focalPoint = focalPoint else {return}
            parallaxOcclusionPassEncoder.updateFocalPoint(focalPoint)
            vBlurPassEncoder.updateFocalPoint(focalPoint)
            hBlurPassEncoder.updateFocalPoint(focalPoint)
        }
    }
    
    var offset: CGPoint? {
        didSet {
            guard let offset = offset else {return}
            parallaxOcclusionPassEncoder.updateOffsetX(
                Float(offset.x),
                andOffsetY: Float(offset.y)
            )
        }
    }
        
    var shouldShowDepth: Bool?
    var shouldShowWatermark: Bool?
    
    var selectedAnimationInterval: TimeInterval?
    var selectedAnimationIntensity: Float?
    var selectedAnimationType: ImageParallaxAnimationType?
    
    var inputDiffuseTexture: MTLTexture?
    var inputDepthTexture: MTLTexture?
    
    var overlaySKView: SKView?
    var overlayTextNode: SKNode?
    
    let startDate = Date()
    
    var animatorShouldAnimate = true
    
    var commandQueue: MTLCommandQueue

    var parallaxOcclusionPassEncoder: ParallaxOcclusionPassEncoder
    var vBlurPassEncoder: BlurPassEncoder
    var hBlurPassEncoder: BlurPassEncoder
    
    var parallaxOcclusionPassOutputDiffuseTexture: MTLTexture!
    var parallaxOcclusionPassOutputDepthTexture: MTLTexture!
    var vBlurPassOutputTexture: MTLTexture!
    var hBlurPassOutputTexture: MTLTexture!

    
    let semaphore = DispatchSemaphore(value: 1)
    
    init(frame: CGRect, shouldShowWatermark: Bool) {
        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            fatalError("Failed creating a default system Metal device / default library. Please, make sure Metal is available on your hardware.")
        }
        
        self.shouldShowWatermark = shouldShowWatermark
        
        commandQueue = device.makeCommandQueue()!
        parallaxOcclusionPassEncoder = ParallaxOcclusionPassEncoder(device: device)
        vBlurPassEncoder = BlurPassEncoder(device: device, isVertical: true)
        hBlurPassEncoder = BlurPassEncoder(device: device, isVertical: false)
        
        super.init(frame: frame, device: device)
        
        delegate = self
        framebufferOnly = true
        clearColor = MTLClearColorMake(0, 0, 0, 1.0)
        contentScaleFactor = UIScreen.main.scale
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        colorPixelFormat = .rgba16Float
        preferredFramesPerSecond = 60
        
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(userDidPanView(_:))))
        
        if shouldShowWatermark {
            layoutAndShowWatermark()
        }
    }
    
    public func layoutAndShowWatermark() {
        overlaySKView = SKView()
        let overlaySKScene = SKScene()
        overlaySKScene.backgroundColor = .clear
        overlayTextNode = SKNode()
        let backgroundNode = SKShapeNode(
            rect: .init(x: 0, y: 0, width: 183, height: 36),
            cornerRadius: 18
        )
        backgroundNode.fillColor = UIColor.black.withAlphaComponent(0.1)
        backgroundNode.strokeColor = .clear
        overlayTextNode?.addChild(backgroundNode)
        let madeWith = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        madeWith.text = "Made with"
        madeWith.fontSize = 24
        madeWith.horizontalAlignmentMode = .left
        madeWith.fontColor = SKColor.white
        madeWith.position = .init(x: 8, y: 8)
        overlayTextNode?.addChild(madeWith)
        let threeDeeIfy = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        threeDeeIfy.text = "3Dify"
        threeDeeIfy.fontSize = 24
        threeDeeIfy.horizontalAlignmentMode = .left
        threeDeeIfy.fontColor = SKColor.white
        threeDeeIfy.position = .init(x: 118, y: 8)
        overlayTextNode?.addChild(threeDeeIfy)
        overlaySKScene.addChild(overlayTextNode!)
        overlaySKScene.scaleMode = .resizeFill
        overlaySKView?.presentScene(overlaySKScene)
        overlaySKView?.allowsTransparency = true
        overlaySKView?.backgroundColor = .clear
        overlaySKView?.frame = bounds
        
        addSubview(overlaySKView!)
    }
    
    public func removeWatermark() {
        overlaySKView?.removeFromSuperview()
    }
    
    override func layoutSubviews() {
        overlaySKView?.frame = bounds
        overlayTextNode?.position = .init(x: frame.midX - 92, y: 64)
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
        offset = .init(
            x: max(min(translation.x / frame.width * 0.3, 0.06), -0.06),
            y: max(min(translation.y / frame.height * 0.3, 0.06), -0.06)
        )
    }
    
    required init(coder: NSCoder) {
        fatalError()
    }
}


extension MetalParallaxView {
    func computeOffset(
        at progress: CGFloat,
        withAnimationType animationType: ImageParallaxAnimationType,
        selectedAnimationIntensity: CGFloat
    ) -> CGPoint {
        switch animationType {
        case .turnTable:
            return CGPoint(
                x: sin(CGFloat(progress) * 2 * CGFloat.pi) * selectedAnimationIntensity,
                y: cos(CGFloat(progress) * 2 * CGFloat.pi) * selectedAnimationIntensity
            )
        case .horizontalSwitch:
            return CGPoint(
                x: sin(progress * 2 * .pi) * selectedAnimationIntensity,
                y: 0
            )
        case .verticalSwitch:
            return CGPoint(
                x: 0,
                y: sin(progress * 2 * .pi) * selectedAnimationIntensity
            )
        }
    }
}


enum SaveState {
    case failed
    case rendering(Double)
    case saving
    case finished
}


extension MetalParallaxView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, isOpaque, 0.0)
        if UIGraphicsGetCurrentContext() != nil {
            drawHierarchy(in: bounds, afterScreenUpdates: true)
            let screenshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return screenshot
        }
        return nil
    }
    
    public func renderVideo(update: @escaping (SaveState) -> ()) {
        guard
            let selectedAnimationInterval = self.selectedAnimationInterval,
            let selectedAnimationType = self.selectedAnimationType,
            let selectedAnimationIntensity = self.selectedAnimationIntensity,
            let video = CameraRollVideo(width: Int(drawableSize.width), height: Int(drawableSize.height), frameRate: 30)
        else {
            update(.failed)
            return
        }
        
        let renderQueue = DispatchQueue(label: "Render Queue", qos: .background)
        
        renderQueue.async {
            video.startWriting()
        
            let loops = 3
            let fps = 30
            let frames = Int(selectedAnimationInterval) * fps * loops
            var offsetsToRender = (0..<frames).reversed().map { frameIndex -> (Double, CGPoint) in
                let animationProgress = (Double(frameIndex) / Double(frames / loops))
                    .truncatingRemainder(dividingBy: 1)
                let progressToDisplay = Double(frameIndex) / Double(frames)
                return (
                    progressToDisplay,
                    self.computeOffset(
                        at: CGFloat(animationProgress),
                        withAnimationType: selectedAnimationType,
                        selectedAnimationIntensity: CGFloat(selectedAnimationIntensity)
                    )
                )
            }
            
            self.onBeforeRenderFrame = {
                if let (progress, offsetToRender) = offsetsToRender.popLast() {
                    // Render next offset
                    update(.rendering(progress * 100))
                    self.offset = offsetToRender
                } else {
                    // Rendering finished, save to video
                    update(.saving)
                    self.onBeforeRenderFrame = nil
                    self.onAfterRenderFrame = nil
                    
                    renderQueue.async {
                        video.finishWriting() { url in
                            DispatchQueue.main.async {
                                CustomPhotoAlbum.getOrCreate(albumWithName: "3Dify Videos") { album, error in
                                    guard
                                        error == nil,
                                        let album = album
                                    else {
                                        update(.failed)
                                        return
                                    }
                                    
                                    album.saveVideo(atUrl: url) {error in
                                        guard error == nil else {
                                            update(.failed)
                                            return
                                        }
                                        update(.finished)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            self.onAfterRenderFrame = { texture in
                autoreleasepool {
                    guard
                        let snapshot = self.snapshot()?.cgImage
                    else {
                        // Rendering failed
                        update(.failed)
                        self.onBeforeRenderFrame = nil
                        self.onAfterRenderFrame = nil
                        return
                    }
                    renderQueue.async {
                        video.append(cgImage: snapshot)
                    }
                }
            }
        }
    }
}


extension MetalParallaxView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        parallaxOcclusionPassOutputDiffuseTexture = readAndRender(targetTextureOfSize: size, andFormat: .rgba16Float)
        parallaxOcclusionPassOutputDepthTexture = readAndRender(targetTextureOfSize: size, andFormat: .rgba16Float)
        vBlurPassOutputTexture = readAndRender(targetTextureOfSize: size, andFormat: .rgba16Float)
    }
    
    func readAndRender(targetTextureOfSize size: CGSize, andFormat format: MTLPixelFormat) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: true
        )
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]
        return device!.makeTexture(descriptor: descriptor)!
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
            self.offset = self.computeOffset(
                at: CGFloat(progress),
                withAnimationType: selectedAnimationType,
                selectedAnimationIntensity: CGFloat(selectedAnimationIntensity)
            )
        }

        guard
            let inputDiffuseTexture = inputDiffuseTexture,
            let inputDepthTexture = inputDepthTexture,
            let device = device,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            _ = semaphore.signal()
            return
        }

        autoreleasepool {
            render(
                inputDiffuseTexture: inputDiffuseTexture,
                inputDepthTexture: inputDepthTexture,
                withCommandBuffer: commandBuffer,
                device: device,
                atTime: elapsedTime
            )
        }
    }
    
    private func render(
        inputDiffuseTexture: MTLTexture,
        inputDepthTexture: MTLTexture,
        withCommandBuffer commandBuffer: MTLCommandBuffer,
        device: MTLDevice,
        atTime time: TimeInterval
    ) {
        onBeforeRenderFrame?()
        
        let scope = MTLCaptureManager.shared().makeCaptureScope(device: device)
        scope.label = "Capture Scope"
        scope.begin()
        
        if self.shouldShowDepth == true && self.blurIntensity == 0 {
            self.parallaxOcclusionPassEncoder.encode(
                in: commandBuffer,
                inputColorTexture: inputDiffuseTexture,
                inputDepthTexture: inputDepthTexture,
                outputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
                outputDepthTexture: currentDrawable!.texture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
        } else if self.shouldShowDepth == true {
            self.parallaxOcclusionPassEncoder.encode(
                in: commandBuffer,
                inputColorTexture: inputDiffuseTexture,
                inputDepthTexture: inputDepthTexture,
                outputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
                outputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
            
            self.vBlurPassEncoder.encode(
                in: commandBuffer,
                inputColorTexture: parallaxOcclusionPassOutputDepthTexture,
                inputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                blurredTexture: vBlurPassOutputTexture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
            
            self.hBlurPassEncoder.encode(
                in: commandBuffer,
                inputColorTexture: vBlurPassOutputTexture,
                inputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                blurredTexture: currentDrawable!.texture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
        } else if self.blurIntensity == 0 {
            // Skip blur pass
            self.parallaxOcclusionPassEncoder.encode(
                in: commandBuffer,
                inputColorTexture: inputDiffuseTexture,
                inputDepthTexture: inputDepthTexture,
                outputColorTexture: currentDrawable!.texture,
                outputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
        } else {
            self.parallaxOcclusionPassEncoder.encode(
                in: commandBuffer,
                inputColorTexture: inputDiffuseTexture,
                inputDepthTexture: inputDepthTexture,
                outputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
                outputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
            
            self.vBlurPassEncoder.encode(
                in: commandBuffer,
                inputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
                inputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                blurredTexture: vBlurPassOutputTexture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
            
            self.hBlurPassEncoder.encode(
                in: commandBuffer,
                inputColorTexture: vBlurPassOutputTexture,
                inputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                blurredTexture: currentDrawable!.texture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
        }
    
        commandBuffer.addScheduledHandler { [weak self] (buffer) in
            self?.semaphore.signal()
        }
        commandBuffer.present(currentDrawable!)
        
        scope.end()
        
        commandBuffer.commit()
        
        onAfterRenderFrame?(currentDrawable!.texture)
    }
}
