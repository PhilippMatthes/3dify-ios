//
//  ParallaxView.swift
//  3Dify
//
//  Created by It's free real estate on 30.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import SceneKit
import SpriteKit
import Photos
import MetalKit


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


enum SaveState {
    case failed
    case rendering(Double)
    case saving
    case finished
}


class ImageParallaxView: SCNView {
    private static let fov: CGFloat = 90
    private static let cameraPosition: SCNVector3 = .init(0, 0, 1)
    
    let gpuLock = DispatchSemaphore(value: 1)
    
    var depthImage: DepthImage? {
        didSet {
            guard
                let depthImage = depthImage,
                let device = MTLCreateSystemDefaultDevice()
            else {return}
            let textureLoader = MTKTextureLoader(device: device)
            
            guard
                let diffuseData = depthImage.diffuse.pngData(),
                let depthData = depthImage.trueDepth?.pngData() ?? depthImage.predictedDepth?.pngData(),
                let diffuseTexture = try? textureLoader.newTexture(data: diffuseData),
                let depthTexture = try? textureLoader.newTexture(data: depthData)
            else {return}
            
            let imageProperty = SCNMaterialProperty(contents: diffuseTexture)
            let imageDepthProperty = SCNMaterialProperty(contents: depthTexture)
            for property in [imageProperty, imageDepthProperty] {
                property.wrapT = .mirror
                property.wrapS = .mirror
            }
            technique?.setObject(imageProperty, forKeyedSubscript: "diffuseTextureSymbol" as NSCopying)
            technique?.setObject(imageDepthProperty, forKeyedSubscript: "depthTextureSymbol" as NSCopying)
        }
    }
    
    var selectedAnimationInterval: TimeInterval?
    
    var selectedAnimationIntensity: Float? {
        didSet {
            layoutPlane()
        }
    }
    
    var selectedAnimationType: ImageParallaxAnimationType?
    
    private var offset: CGPoint? {
        didSet {
            guard let offset = offset else {return}
            technique?.setObject(NSNumber(value: Float(offset.x)), forKeyedSubscript: "offsetXSymbol" as NSCopying)
            technique?.setObject(NSNumber(value: Float(offset.y)), forKeyedSubscript: "offsetYSymbol" as NSCopying)
        }
    }
       
    public var selectedFocalPoint: Float? {
        didSet {
            guard let selectedFocalPoint = selectedFocalPoint else {return}
            technique?.setObject(NSNumber(value: selectedFocalPoint), forKeyedSubscript: "selectedFocalPointSymbol" as NSCopying)
        }
    }
    
    private var plane: SCNPlane?
    private var planeNode: SCNNode?
    private var camera: SCNCamera?
    private var cameraNode: SCNNode?
    private var textNode: SKNode?
    
    private var animatorShouldAnimate = true
    
    init() {
        super.init(frame: .zero, options: nil)
    }
    
    func prepareScene() {
        scene = SCNScene()
        
        guard
            let path = Bundle.main.path(forResource: "ImageParallaxTechnique", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
            let technique = SCNTechnique(dictionary: dict)
        else {fatalError()}
        
        self.technique = technique

        plane = SCNPlane()
        plane!.widthSegmentCount = 1
        plane!.heightSegmentCount = 1
        planeNode = SCNNode(geometry: plane)
        scene!.rootNode.addChildNode(planeNode!)
        
        camera = SCNCamera()
        camera!.fieldOfView = Self.fov
        camera!.projectionDirection = .vertical
        camera!.wantsHDR = true
        camera!.zNear = 0
        cameraNode = SCNNode()
        cameraNode!.camera = camera
        cameraNode!.position = Self.cameraPosition
        scene!.rootNode.addChildNode(cameraNode!)
        
        overlaySKScene = SKScene()
        textNode = SKNode()
        let madeWith = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        madeWith.text = "Made with"
        madeWith.fontSize = 24
        madeWith.horizontalAlignmentMode = .left
        madeWith.fontColor = SKColor.white
        madeWith.position = .zero
        textNode!.addChild(madeWith)
        let threeDeeIfy = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        threeDeeIfy.text = "3Dify"
        threeDeeIfy.fontSize = 24
        threeDeeIfy.horizontalAlignmentMode = .left
        threeDeeIfy.fontColor = SKColor.white
        threeDeeIfy.position = .init(x: 110, y: 0)
        textNode!.addChild(threeDeeIfy)
        overlaySKScene?.addChild(textNode!)
        overlaySKScene?.scaleMode = .resizeFill
        
        preferredFramesPerSecond = 60
                
        isPlaying = true
        delegate = self
    }
    
    func prepareGestureRecognizers() {
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(userDidPanView(_:))))
    }
    
    func layoutPlane() {
        guard
            let depthImage = depthImage,
            let selectedAnimationIntensity = selectedAnimationIntensity
        else {return}
        
        let viewAspectRatio = frame.size.height / frame.size.width
        let imageAspectRatio = depthImage.diffuse.size.height / depthImage.diffuse.size.width
        
        let frustumHeight = 2 * CGFloat(Self.cameraPosition.z) * tan(Self.fov * 0.5 * .pi / 180)
        let frustumWidth = frustumHeight / viewAspectRatio
        
        let bestFitHeight: CGFloat
        let bestFitWidth: CGFloat
        
        if imageAspectRatio > viewAspectRatio {
            bestFitWidth = frustumWidth
            bestFitHeight = frustumWidth * imageAspectRatio
        } else {
            bestFitWidth = frustumHeight / imageAspectRatio
            bestFitHeight = frustumHeight
        }
        
        plane?.height = bestFitHeight + CGFloat(selectedAnimationIntensity) * (1 / 0.05) * 0.2
        plane?.width = bestFitWidth + CGFloat(selectedAnimationIntensity) * (1 / 0.05) * 0.2
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        textNode?.position = .init(x: frame.midX - 86, y: 64)
        
        layoutPlane()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension ImageParallaxView {
    @objc func userDidPanView(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: self)
        switch gestureRecognizer.state {
        case .began:
            animatorShouldAnimate = false
        case .ended:
            animatorShouldAnimate = true
        default:
            break
        }
        offset = CGPoint(
            x: max(min(translation.x / frame.width * 0.3, 0.06), -0.06),
            y: max(min(translation.y / frame.height * 0.3, 0.06), -0.06)
        )
    }
    
    public func saveVideo(update: @escaping (SaveState) -> ()) {
        let renderQueue = DispatchQueue(label: "Render Queue", qos: .background)
        renderQueue.async {
            guard
                let selectedAnimationInterval = self.selectedAnimationInterval,
                let selectedAnimationType = self.selectedAnimationType,
                let selectedAnimationIntensity = self.selectedAnimationIntensity
            else {
                update(.failed)
                return
            }
                        
            print("Attempting to save video...")
        
            self.animatorShouldAnimate = false
            var screenShots = [UIImage]()
            let frames = Int(selectedAnimationInterval * 30)
            
            let dispatchGroup = DispatchGroup()
            for frameIndex in (0..<frames) {
                dispatchGroup.enter()
                renderQueue.async {
                    let progress = (Double(frameIndex) / Double(frames))
                    update(.rendering(100 * progress))
                    self.offset = self.computeOffset(at: progress, withAnimationType: selectedAnimationType)
                        .scaled(by: Double(selectedAnimationIntensity))
                    autoreleasepool {
                        screenShots.append(self.snapshot())
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: renderQueue) {
                self.animatorShouldAnimate = true
                
                update(.saving)
                let videoConverter = VideoConverter(width: Int(screenShots.first!.size.width), height: Int(screenShots.first!.size.height))
                videoConverter.createMovieFrom(images: screenShots) { url in
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

extension ImageParallaxView: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard
            let selectedAnimationInterval = self.selectedAnimationInterval,
            let selectedAnimationType = self.selectedAnimationType,
            let selectedAnimationIntensity = self.selectedAnimationIntensity,
            animatorShouldAnimate
        else {return}
        
        let progress = 0.5 + (time.remainder(dividingBy: selectedAnimationInterval)) / selectedAnimationInterval
        self.offset = self.computeOffset(at: progress, withAnimationType: selectedAnimationType)
            .scaled(by: Double(selectedAnimationIntensity))
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
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
}


struct ImageParallaxViewRepresentable: UIViewRepresentable {
    @Binding var isSaving: Bool
    @Binding var selectedAnimationInterval: TimeInterval
    @Binding var selectedAnimationIntensity: Float
    @Binding var selectedFocalPoint: Float
    @Binding var selectedAnimationTypeRawValue: Int
    @Binding var depthImage: DepthImage
    
    var onSaveVideoUpdate: (SaveState) -> ()
    
    func makeUIView(context: UIViewRepresentableContext<ImageParallaxViewRepresentable>) -> ImageParallaxView {
        let sceneView = ImageParallaxView()
        sceneView.prepareScene()
        sceneView.prepareGestureRecognizers()
        
        sceneView.depthImage = depthImage
        sceneView.selectedFocalPoint = selectedFocalPoint
        sceneView.selectedAnimationType = ImageParallaxAnimationType(rawValue: selectedAnimationTypeRawValue)!
        sceneView.selectedAnimationInterval = selectedAnimationInterval
        sceneView.selectedAnimationIntensity = selectedAnimationIntensity
        return sceneView
    }
    
    func updateUIView(_ sceneView: ImageParallaxView, context: UIViewRepresentableContext<ImageParallaxViewRepresentable>) {
        if sceneView.depthImage != depthImage {
            sceneView.depthImage = depthImage
        }
        if sceneView.selectedFocalPoint != selectedFocalPoint {
            sceneView.selectedFocalPoint = selectedFocalPoint
        }
        let selectedAnimationType = ImageParallaxAnimationType(rawValue: selectedAnimationTypeRawValue)!
        if sceneView.selectedAnimationType != selectedAnimationType {
            sceneView.selectedAnimationType = selectedAnimationType
        }
        if sceneView.selectedAnimationInterval != selectedAnimationInterval {
            sceneView.selectedAnimationInterval = selectedAnimationInterval
        }
        if sceneView.selectedAnimationIntensity != selectedAnimationIntensity {
            sceneView.selectedAnimationIntensity = selectedAnimationIntensity
        }
        
        if isSaving {
            sceneView.saveVideo(update: self.onSaveVideoUpdate)
        }
    }
}

struct ImageParallaxViewRepresentable_Previews: PreviewProvider {
    static var previews: some View {
        ImageParallaxViewRepresentable(
            isSaving: .constant(false),
            selectedAnimationInterval: .constant(3.0),
            selectedAnimationIntensity: .constant(0.02),
            selectedFocalPoint: .constant(0.0),
            selectedAnimationTypeRawValue: .constant(0),
            depthImage: .constant(
                DepthImage(
                    diffuse: UIImage(named: "mango-image")!,
                    trueDepth: UIImage(named: "mango-depth")!
                )
            )
        ) { _ in
            
        }
    }
}
