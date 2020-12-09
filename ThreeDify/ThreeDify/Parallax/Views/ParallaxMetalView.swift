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

import MetalKit


class ParallaxMetalView: MTKView {
    var environment: ParallaxViewEnvironment {
        willSet {
            if environment.parallaxImage != newValue.parallaxImage {
                setDepthImage(newValue.parallaxImage)
            }
            if environment.selectedBlurIntensity != newValue.selectedBlurIntensity {
                setBlurIntensity(newValue.selectedBlurIntensity)
            }
            if environment.selectedFocalPoint != newValue.selectedFocalPoint {
                setFocalPoint(newValue.selectedFocalPoint)
            }
        }
    }
    
    /// A semaphore used to ensure that only one frame is rendered at a time.
    private let semaphore = DispatchSemaphore(value: 1)

    private var animationShouldAnimate: Bool = true
    
    private var inputDiffuseTexture: MTLTexture?
    private var inputDepthTexture: MTLTexture?
    
    private let commandQueue: MTLCommandQueue
    private var parallaxOcclusionPassEncoder: ParallaxOcclusionPassEncoder
    private var vBlurPassEncoder: BlurPassEncoder
    private var hBlurPassEncoder: BlurPassEncoder
    
    private var parallaxOcclusionPassOutputDiffuseTexture: MTLTexture!
    private var parallaxOcclusionPassOutputDepthTexture: MTLTexture!
    private var vBlurPassOutputTexture: MTLTexture!
    private var hBlurPassOutputTexture: MTLTexture!
    
    private func setDepthImage(_ parallaxImage: ParallaxImage) {
        releaseDrawables()
        guard let device = device else {return}
        let textureLoader = MTKTextureLoader(device: device)
        guard
            let diffuseData = parallaxImage.diffuseMap.pngData(),
            let depthData = parallaxImage.depthMap.pngData()
        else {return}
        inputDiffuseTexture = try? textureLoader.newTexture(data: diffuseData)
        inputDepthTexture = try? textureLoader.newTexture(data: depthData)
    }
    
    private func setBlurIntensity(_ blurIntensity: Float) {
        vBlurPassEncoder.uniforms.blurIntensity = blurIntensity
        hBlurPassEncoder.uniforms.blurIntensity = blurIntensity
    }

    private func setFocalPoint(_ focalPoint: Float) {
        parallaxOcclusionPassEncoder.uniforms.focalPoint = focalPoint
        vBlurPassEncoder.uniforms.focalPoint = focalPoint
        hBlurPassEncoder.uniforms.focalPoint = focalPoint
    }
    
    private func setOffset(_ offset: CGPoint) {
        parallaxOcclusionPassEncoder.uniforms.offsetX = Float(offset.x)
        parallaxOcclusionPassEncoder.uniforms.offsetY = Float(offset.y)
    }
    
    init(environment: ParallaxViewEnvironment) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue(),
            let parallaxEncoder = try? ParallaxOcclusionPassEncoder(device: device),
            let vBlurPassEncoder = try? BlurPassEncoder(
                device: device, isVertical: true
            ),
            let hBlurPassEncoder = try? BlurPassEncoder(
                device: device, isVertical: false
            )
        else { fatalError("Failed to create the Metal Parallax View.") }
                
        self.commandQueue = commandQueue
        self.environment = environment
        self.parallaxOcclusionPassEncoder = parallaxEncoder
        self.vBlurPassEncoder = vBlurPassEncoder
        self.hBlurPassEncoder = hBlurPassEncoder
        
        super.init(frame: .zero, device: device)
        
        delegate = self
        framebufferOnly = true
        clearColor = MTLClearColorMake(0, 0, 0, 1.0)
        contentScaleFactor = UIScreen.main.scale
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        colorPixelFormat = .rgba16Float
        preferredFramesPerSecond = 60
        
        setDepthImage(environment.parallaxImage)
        setBlurIntensity(environment.selectedBlurIntensity)
        setFocalPoint(environment.selectedFocalPoint)
        
        addGestureRecognizer(UIPanGestureRecognizer(
            target: self, action: #selector(userDidPanView(_:)))
        )
    }
    
    required init(coder: NSCoder) {
        fatalError()
    }
    
    @objc func userDidPanView(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            animationShouldAnimate = false
        case .ended:
            animationShouldAnimate = true
        default:
            break
        }
        
        let translation = gestureRecognizer.translation(in: self)
        setOffset(.init(
            x: max(min(translation.x / frame.width * 0.3, 0.06), -0.06),
            y: max(min(translation.y / frame.height * 0.3, 0.06), -0.06)
        ))
    }
}


extension ParallaxMetalView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        parallaxOcclusionPassOutputDiffuseTexture = readAndRender(
            targetTextureOfSize: size, andFormat: .rgba16Float
        )
        parallaxOcclusionPassOutputDepthTexture = readAndRender(
            targetTextureOfSize: size, andFormat: .rgba16Float
        )
        vBlurPassOutputTexture = readAndRender(
            targetTextureOfSize: size, andFormat: .rgba16Float
        )
    }
    
    private func readAndRender(targetTextureOfSize size: CGSize, andFormat format: MTLPixelFormat) -> MTLTexture {
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
        _ = semaphore.wait(timeout: .distantFuture)
        let elapsedTime = Date().timeIntervalSince1970
        
        if animationShouldAnimate {
            let progress = 0.5 + (elapsedTime.remainder(dividingBy: environment.selectedAnimationInterval)) / environment.selectedAnimationInterval
            let newOffset = environment.selectedAnimation.computeOffset(
                at: CGFloat(progress),
                selectedAnimationIntensity: CGFloat(environment.selectedAnimationIntensity)
            )
            setOffset(newOffset)
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
    
    private func scoped(device: MTLDevice, renderBlock: () -> Void) {
        let scope = MTLCaptureManager.shared().makeCaptureScope(device: device)
        scope.label = "Capture Scope"
        scope.begin()
        
        renderBlock()
        
        scope.end()
    }
    
    private func render(
        inputDiffuseTexture: MTLTexture,
        inputDepthTexture: MTLTexture,
        withCommandBuffer commandBuffer: MTLCommandBuffer,
        device: MTLDevice,
        atTime time: TimeInterval
    ) {
        guard let currentDrawable = currentDrawable else { return }
        
        scoped(device: device) {
            try? parallaxOcclusionPassEncoder.encode(
                inCommandBuffer: commandBuffer,
                inputColorTexture: inputDiffuseTexture,
                inputDepthTexture: inputDepthTexture,
                outputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
                outputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )

            try? vBlurPassEncoder.encode(
                inCommandBuffer: commandBuffer,
                inputColorTexture: parallaxOcclusionPassOutputDiffuseTexture,
                inputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                outputBlurredTexture: vBlurPassOutputTexture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
            
            try? hBlurPassEncoder.encode(
                inCommandBuffer: commandBuffer,
                inputColorTexture: vBlurPassOutputTexture,
                inputDepthTexture: parallaxOcclusionPassOutputDepthTexture,
                outputBlurredTexture: currentDrawable.texture,
                drawableSize: drawableSize,
                clearColor: clearColor
            )
        
            commandBuffer.addScheduledHandler { [weak self] (buffer) in
                self?.semaphore.signal()
            }
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }
}
