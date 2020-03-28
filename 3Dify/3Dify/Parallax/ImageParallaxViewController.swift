//
//  ImageViewController.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import SceneKit
import SpriteKit
import Photos


enum ImageParallaxAnimationType: Int {
    case turnTable
    case horizontalSwitch
}


protocol ImageParallaxAnimationCoordinatorDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdateOffset offset: CGPoint)
}


class ImageParallaxAnimationCoordinator: NSObject, SCNSceneRendererDelegate {
    public var animationDuration: TimeInterval
    public var animationType: ImageParallaxAnimationType
    
    public var delegate: ImageParallaxAnimationCoordinatorDelegate?
    
    init(animationDuration: TimeInterval, animationType: ImageParallaxAnimationType) {
        self.animationDuration = animationDuration
        self.animationType = animationType
        super.init()
    }
    
    func offset(at progress: Double) -> CGPoint {
        switch animationType {
        case .turnTable:
            return CGPoint(
                x: sin(CGFloat(progress) * 2 * CGFloat.pi),
                y: cos(CGFloat(progress) * 2 * CGFloat.pi)
            ).scaled(by: 0.10)
        case .horizontalSwitch:
            return CGPoint(
                x: progress < 0.5 ? (4 * progress - 1) : (-4 * progress + 3),
                y: 0
            ).scaled(by: 0.10)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let progress = 0.5 + (time.remainder(dividingBy: animationDuration)) / animationDuration
        delegate?.renderer(renderer, didUpdateOffset: offset(at: progress))
    }
}


final class ImageParallaxViewController: UIViewController {
    struct Uniforms {
        var offset: SIMD2<Float>
    }
    
    public var depthImage: DepthImage? {
        didSet {
            guard
                let depthImage = depthImage,
                let imageDepth = depthImage.trueDepth ?? depthImage.predictedDepth
            else {return}
            let imageProperty = SCNMaterialProperty(contents: depthImage.diffuse)
            let imageDepthProperty = SCNMaterialProperty(contents: imageDepth)
            
            for property in [imageProperty, imageDepthProperty] {
                property.wrapT = .clamp
                property.wrapS = .clamp
            }
            
            plane?.firstMaterial?.setValue(imageProperty, forKey: "diffuseTexture")
            plane?.firstMaterial?.setValue(imageDepthProperty, forKey: "depthTexture")
        }
    }
    
    public var animationType: ImageParallaxAnimationType {
        didSet {
            guard let coordinator = self.animationCoordinator else {return}
            coordinator.animationType = animationType
        }
    }
    
    private var sceneView: SCNView!
    private var scene: SCNScene!
    private var textNode: SKNode!
    private var plane: SCNPlane!
    
    private var imageProperty: SCNMaterialProperty!
    private var imageDepthProperty: SCNMaterialProperty!
    
    private var animationCoordinator: ImageParallaxAnimationCoordinator!
    private var animationCoordinatorShouldAnimate = true
    
    private var uniforms: Uniforms! {
        didSet {
            let data = NSData(bytes: &uniforms, length: MemoryLayout.size(ofValue: uniforms))
            plane?.firstMaterial?.setValue(data, forKey: "uniforms")
        }
    }
    
    init(depthImage: DepthImage?, animationType: ImageParallaxAnimationType) {
        self.depthImage = depthImage
        self.animationType = animationType
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let depthImage = depthImage else {return}
        
        let aspectRatio = depthImage.diffuse.size.height / depthImage.diffuse.size.width
        
        sceneView = SCNView(frame: .zero)
        sceneView.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(userDidPan))
        )
        
        view.addSubview(sceneView)
        
        scene = SCNScene()
        
        // Compute size of the view frustum at the orgin
        let cameraZPosition: CGFloat = 1
        let fieldOfView: CGFloat = 90
        let frustumHeight: CGFloat = 2 * cameraZPosition * tan(fieldOfView * 0.5 * .pi / 180)
        let frustumWidth: CGFloat = frustumHeight * 1 / aspectRatio

        // Set the plane size to exactly that computed size
        plane = SCNPlane(width: frustumWidth + 0.2, height: frustumHeight + 0.2)
        plane.widthSegmentCount = 1
        plane.heightSegmentCount = 1
        let planeNode = SCNNode(geometry: plane)
        scene.rootNode.addChildNode(planeNode)
        
        // Set up the shader program
        let program = SCNProgram()
        program.fragmentFunctionName = "myFragment"
        program.vertexFunctionName = "myVertex"
        plane.firstMaterial?.program = program
        
        let imageProperty = SCNMaterialProperty(contents: depthImage.diffuse)
        let imageDepthProperty = SCNMaterialProperty(contents: depthImage.trueDepth!)
        
        for property in [imageProperty, imageDepthProperty] {
            property.wrapT = .clamp
            property.wrapS = .clamp
        }
        
        plane?.firstMaterial?.setValue(imageProperty, forKey: "diffuseTexture")
        plane?.firstMaterial?.setValue(imageDepthProperty, forKey: "depthTexture")
        
        uniforms = .init(offset: .init(x: 0, y: 0))
        
        // Configure the camera
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = fieldOfView
        camera.zNear = 0
        cameraNode.camera = camera
        cameraNode.position = .init(0, 0, cameraZPosition)
        scene.rootNode.addChildNode(cameraNode)
        
        sceneView.scene = scene
        
        animationCoordinator = ImageParallaxAnimationCoordinator(animationDuration: 4, animationType: animationType)
        sceneView.delegate = animationCoordinator
        sceneView.preferredFramesPerSecond = 60
        animationCoordinator.delegate = self
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(saveVideo)))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let overlayScene = SKScene()
        textNode = SKNode()
        textNode.position = .init(x: view.frame.midX - 86, y: 256)
        let madeWith = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        madeWith.text = "Made with"
        madeWith.fontSize = 24
        madeWith.horizontalAlignmentMode = .left
        madeWith.fontColor = SKColor.white
        madeWith.position = .zero
        textNode.addChild(madeWith)
        let threeDeeIfy = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        threeDeeIfy.text = "3Dify"
        threeDeeIfy.fontSize = 24
        threeDeeIfy.horizontalAlignmentMode = .left
        threeDeeIfy.fontColor = SKColor.white
        threeDeeIfy.position = .init(x: 108, y: 0)
        textNode.addChild(threeDeeIfy)
        overlayScene.addChild(textNode)
        overlayScene.scaleMode = .resizeFill
        sceneView.overlaySKScene = overlayScene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneView?.isPlaying = true
    }
    
    @objc func saveVideo() {
        UISelectionFeedbackGenerator().selectionChanged()
        print("Attempting to save video...")
        animationCoordinatorShouldAnimate = false
        var screenShots = [UIImage]()
        let frames = Int(animationCoordinator.animationDuration * 30)
        for frameIndex in (0..<frames) {
            autoreleasepool {
                let progress = Double(frameIndex) / Double(frames)
                let offset = animationCoordinator.offset(at: progress)
                uniforms = Uniforms(offset: .init(x: Float(offset.x), y: Float(offset.y)))
                guard let image = sceneView?.snapshot() else {fatalError()}
                screenShots.append(image)
            }
        }
        animationCoordinatorShouldAnimate = true
        let videoConverter = VideoConverter(width: Int(screenShots.first!.size.width), height: Int(screenShots.first!.size.height))
        videoConverter.createMovieFrom(images: screenShots) { url in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { saved, error in
                if saved {
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alertController.addAction(defaultAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView?.isPlaying = false
    }
    
    override func viewWillLayoutSubviews() {
        sceneView?.frame = view.frame
    }
    
    @objc func userDidPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: view)
        switch gestureRecognizer.state {
        case .began:
            animationCoordinatorShouldAnimate = false
        case .ended:
            animationCoordinatorShouldAnimate = true
        default:
            break
        }
        uniforms = Uniforms.init(offset: .init(
            x: max(min(Float(translation.x / view.frame.width) * 0.3, 0.06), -0.06),
            y: max(min(Float(translation.y / view.frame.height) * 0.3, 0.06), -0.06)
        ))
    }
}


extension ImageParallaxViewController: ImageParallaxAnimationCoordinatorDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdateOffset offset: CGPoint) {
        guard animationCoordinatorShouldAnimate else {return}
        uniforms = Uniforms(offset: .init(x: Float(offset.x), y: Float(offset.y)))
    }
}


struct ImageParallaxViewControllerRepresentable: UIViewControllerRepresentable {
    
    public typealias UIViewControllerType = ImageParallaxViewController
    
    @Binding public var depthImage: DepthImage?
    @Binding public var animationTypeRawValue: Int
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<ImageParallaxViewControllerRepresentable>
    ) -> ImageParallaxViewController {
        let animationType = ImageParallaxAnimationType.init(rawValue: animationTypeRawValue)!
        return ImageParallaxViewController(depthImage: depthImage, animationType: animationType)
    }
    
    public func updateUIViewController(_ uiViewController: ImageParallaxViewController, context: UIViewControllerRepresentableContext<ImageParallaxViewControllerRepresentable>) {
        let animationType = ImageParallaxAnimationType.init(rawValue: animationTypeRawValue)!
        uiViewController.depthImage = depthImage
        uiViewController.animationType = animationType
    }
}


struct ImageParallaxView: View {
    
    @Binding var depthImage: DepthImage?
    
    @State var selectedAnimationTypeRawValue = ImageParallaxAnimationType.horizontalSwitch.rawValue
    
    var body: some View {
        ImageParallaxViewControllerRepresentable(depthImage: $depthImage, animationTypeRawValue: $selectedAnimationTypeRawValue)
    }
}


struct ImageParallaxView_Previews: PreviewProvider {
    static var previews: some View {
        ImageParallaxView(depthImage: .constant(DepthImage(diffuse: UIImage(named: "header-background")!, trueDepth: UIImage(named: "header-background-depth")!)))
    }
}
