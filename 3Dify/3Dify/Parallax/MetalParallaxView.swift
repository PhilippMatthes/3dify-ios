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
    @Binding var selectedAnimationInterval: TimeInterval
    @Binding var selectedAnimationIntensity: Float
    @Binding var selectedFocalPoint: Float
    @Binding var selectedFocalRange: Float
    @Binding var selectedBokehIntensity: Float
    @Binding var selectedAnimationTypeRawValue: Int
    @Binding var depthImage: DepthImage
    
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
                    selectedAnimationInterval: self.$selectedAnimationInterval,
                    selectedAnimationIntensity: self.$selectedAnimationIntensity,
                    selectedFocalPoint: self.$selectedFocalPoint,
                    selectedFocalRange: self.$selectedFocalRange,
                    selectedBokehIntensity: self.$selectedBokehIntensity,
                    selectedAnimationTypeRawValue: self.$selectedAnimationTypeRawValue,
                    depthImage: self.$depthImage,
                    isSaving: self.$isSaving,
                    onSaveVideoUpdate: self.onSaveVideoUpdate
                )
                .frame(rect: self.bestFitLayout(for: innerGeometry.frame(in: .local)))
            }.frame(rect: outerGeometry.frame(in: .local))
        }
    }
}


struct MetalParallaxViewRepresentable: UIViewRepresentable {
    @Binding var selectedAnimationInterval: TimeInterval
    @Binding var selectedAnimationIntensity: Float
    @Binding var selectedFocalPoint: Float
    @Binding var selectedFocalRange: Float
    @Binding var selectedBokehIntensity: Float
    @Binding var selectedAnimationTypeRawValue: Int
    @Binding var depthImage: DepthImage
    
    @Binding var isSaving: Bool
    var onSaveVideoUpdate: (SaveState) -> ()
    
    func makeUIView(context: UIViewRepresentableContext<MetalParallaxViewRepresentable>) -> MetalParallaxView {
        let view = MetalParallaxView(frame: .zero)
        view.depthImage = depthImage
        view.bokehRadius = selectedBokehIntensity
        view.focalDistance = selectedFocalPoint
        view.focalRange = selectedFocalRange
        view.selectedAnimationType = ImageParallaxAnimationType(rawValue: selectedAnimationTypeRawValue)!
        view.selectedAnimationInterval = selectedAnimationInterval
        view.selectedAnimationIntensity = selectedAnimationIntensity
        return view
    }
    
    func updateUIView(_ view: MetalParallaxView, context: Context) {
        if view.depthImage != depthImage {
            view.depthImage = depthImage
        }
        if view.bokehRadius != selectedBokehIntensity {
            view.bokehRadius = selectedBokehIntensity
        }
        if view.focalDistance != selectedFocalPoint {
            view.focalDistance = selectedFocalPoint
        }
        if view.focalRange != selectedFocalRange {
            view.focalRange = selectedFocalRange
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
                let depthData = depthImage.trueDepth?.pngData() ?? depthImage.predictedDepth?.pngData()
            else {return}
            
            inputDiffuseTexture = try? textureLoader.newTexture(data: diffuseData)
            inputDepthTexture = try? textureLoader.newTexture(data: depthData)
        }
    }
    
    var bokehRadius: Float? {
        didSet {
            guard let bokehRadius = bokehRadius else {return}
            bokehPassEncoder.updateBokehRadius(bokehRadius)
            circleOfConfusionPassEncoder.updateUniforms(withBokehRadius: bokehRadius)
        }
    }
    
    var focalDistance: Float? {
        didSet {
            guard let focalDistance = focalDistance, let focalRange = focalRange else {return}
            circleOfConfusionPassEncoder.updateUniforms(withFocusDistance: focalDistance, focusRange: focalRange)
        }
    }
    
    var focalRange: Float? {
        didSet {
            guard let focalDistance = focalDistance, let focalRange = focalRange else {return}
            circleOfConfusionPassEncoder.updateUniforms(withFocusDistance: focalDistance, focusRange: focalRange)
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
    var circleOfConfusionPassEncoder: CircleOfConfusionPassEncoder
    var preFilterPassEncoder: PreFilterPassEncoder
    var bokehPassEncoder: BokehPassEncoder
    var postFilterPassEncoder: PostFilterPassEncoder
    var composePassEncoder: ComposePassEncoder
    
    var parallaxOcclusionPassOutputDiffuseTexture: MTLTexture!
    var parallaxOcclusionPassOutputDepthTexture: MTLTexture!
    var circleOfConfusionTexture: MTLTexture!
    var preFilteredColorTexture: MTLTexture!
    var preFilteredCircleOfConfusionTexture: MTLTexture!
    var depthOfFieldTexture: MTLTexture!
    var postFilterTexture: MTLTexture!
    
    let semaphore = DispatchSemaphore(value: 1)
    
    init(frame: CGRect) {
        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            fatalError("Failed creating a default system Metal device / default library. Please, make sure Metal is available on your hardware.")
        }
        
        commandQueue = device.makeCommandQueue()!
        parallaxOcclusionPassEncoder = ParallaxOcclusionPassEncoder(device: device)
        circleOfConfusionPassEncoder = CircleOfConfusionPassEncoder(device: device)
        preFilterPassEncoder = PreFilterPassEncoder(device: device)
        bokehPassEncoder = BokehPassEncoder(device: device)
        postFilterPassEncoder = PostFilterPassEncoder(device: device)
        composePassEncoder = ComposePassEncoder(device: device)
        
        super.init(frame: frame, device: device)
        
        delegate = self
        framebufferOnly = true
        clearColor = MTLClearColorMake(0, 0, 0, 1.0)
        contentScaleFactor = UIScreen.main.scale
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        colorPixelFormat = .rgba16Float
        preferredFramesPerSecond = 60
        
        overlaySKView = SKView()
        let overlaySKScene = SKScene()
        overlaySKScene.backgroundColor = .clear
        overlayTextNode = SKNode()
        let madeWith = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        madeWith.text = "Made with"
        madeWith.fontSize = 24
        madeWith.horizontalAlignmentMode = .left
        madeWith.fontColor = SKColor.white
        madeWith.position = .zero
        overlayTextNode!.addChild(madeWith)
        let threeDeeIfy = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        threeDeeIfy.text = "3Dify"
        threeDeeIfy.fontSize = 24
        threeDeeIfy.horizontalAlignmentMode = .left
        threeDeeIfy.fontColor = SKColor.white
        threeDeeIfy.position = .init(x: 110, y: 0)
        overlayTextNode!.addChild(threeDeeIfy)
        overlaySKScene.addChild(overlayTextNode!)
        overlaySKScene.scaleMode = .resizeFill
        overlaySKView?.presentScene(overlaySKScene)
        overlaySKView?.allowsTransparency = true
        overlaySKView?.backgroundColor = .clear
        addSubview(overlaySKView!)
        overlaySKView!.frame = bounds
        
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(userDidPanView(_:))))
    }
    
    override func layoutSubviews() {
        overlaySKView?.frame = bounds
        overlayTextNode?.position = .init(x: frame.midX - 86, y: 64)
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
}


enum SaveState {
    case failed
    case rendering(Double)
    case saving
    case finished
}


extension MetalParallaxView {
    public func renderVideo(update: @escaping (SaveState) -> ()) {
        guard
            let selectedAnimationInterval = self.selectedAnimationInterval,
            let selectedAnimationType = self.selectedAnimationType,
            let selectedAnimationIntensity = self.selectedAnimationIntensity,
            let video = CameraRollVideo(width: Int(drawableSize.width), height: Int(drawableSize.height), frameRate: 60)
        else {
            update(.failed)
            return
        }
        
        let renderQueue = DispatchQueue(label: "Render Queue", qos: .background)
        
        renderQueue.async {
            video.startWriting()
        
            let loops = 5
            let fps = 60
            let frames = Int(selectedAnimationInterval) * fps * loops
            var offsetsToRender = (0..<frames).reversed().map { frameIndex -> (Double, CGPoint) in
                let animationProgress = (Double(frameIndex) / Double(frames / loops))
                    .truncatingRemainder(dividingBy: 1)
                let progressToDisplay = Double(frameIndex) / Double(frames)
                return (progressToDisplay, self.computeOffset(at: animationProgress, withAnimationType: selectedAnimationType).scaled(by: Double(selectedAnimationIntensity)))
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
                                PHPhotoLibrary.shared().performChanges({
                                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                                }) { saved, error in
                                    if error != nil || !saved {
                                        update(.failed)
                                    } else {
                                        update(.finished)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            self.onAfterRenderFrame = { texture in
                let context = CIContext()
                autoreleasepool {
                    guard
                        let ciImage = CIImage(mtlTexture: texture, options: nil),
                        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
                    else {
                        // Rendering failed
                        update(.failed)
                        self.onBeforeRenderFrame = nil
                        self.onAfterRenderFrame = nil
                        return
                    }
                    renderQueue.async {
                        video.append(cgImage: cgImage)
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
        circleOfConfusionTexture = readAndRender(targetTextureOfSize: size, andFormat: .r32Float)
        preFilteredColorTexture = readAndRender(targetTextureOfSize: size, andFormat: .rgba16Float)
        preFilteredCircleOfConfusionTexture = readAndRender(targetTextureOfSize: size, andFormat: .r32Float)
        depthOfFieldTexture = readAndRender(targetTextureOfSize: size, andFormat: .rgba16Float)
        postFilterTexture = readAndRender(targetTextureOfSize: size, andFormat: .rgba16Float)
    }
    
    func readAndRender(targetTextureOfSize size: CGSize, andFormat format: MTLPixelFormat) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.sampleCount = 1
        descriptor.allowGPUOptimizedContents = true
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
            self.offset = self.computeOffset(at: progress, withAnimationType: selectedAnimationType)
                .scaled(by: Double(selectedAnimationIntensity))
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
        
        self.parallaxOcclusionPassEncoder.encode(
            in: commandBuffer,
            inputColorTexture: inputDiffuseTexture,
            inputDepthTexture: inputDepthTexture,
            outputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
            outputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
            drawableSize: drawableSize,
            clearColor: clearColor
        )
        self.circleOfConfusionPassEncoder.encode(
            in: commandBuffer,
            inputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
            outputTexture: circleOfConfusionTexture,
            drawableSize: drawableSize,
            clearColor: clearColor
        )
        self.preFilterPassEncoder.encode(
            in: commandBuffer,
            inputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
            inputCoCTexture: circleOfConfusionTexture,
            outputColorTexture: preFilteredColorTexture,
            outputCoCTexture: preFilteredCircleOfConfusionTexture,
            drawableSize: drawableSize,
            clearColor: clearColor
        )
        self.bokehPassEncoder.encode(
            in: commandBuffer,
            inputColorTexture: preFilteredColorTexture,
            inputCoCTexture: preFilteredCircleOfConfusionTexture,
            outputTexture: depthOfFieldTexture,
            drawableSize: drawableSize,
            clearColor: clearColor
        )
        self.postFilterPassEncoder.encode(
            in: commandBuffer,
            inputColorTexture: depthOfFieldTexture,
            outputTexture: postFilterTexture,
            drawableSize: drawableSize,
            clearColor: clearColor
        )
        self.composePassEncoder.encode(
            in: commandBuffer,
            inputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
            inputDoFTexture: postFilterTexture,
            inputCoCTexture: preFilteredCircleOfConfusionTexture,
            outputTexture: currentDrawable!.texture,
            drawableSize: drawableSize,
            clearColor: clearColor
        )
    
        commandBuffer.addScheduledHandler { [weak self] (buffer) in
            self?.semaphore.signal()
        }
        commandBuffer.present(currentDrawable!)
        
        scope.end()
        
        commandBuffer.commit()
        
        onAfterRenderFrame?(currentDrawable!.texture)
    }
}
