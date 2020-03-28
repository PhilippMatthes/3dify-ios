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
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let progress = 0.5 + (time.remainder(dividingBy: animationDuration)) / animationDuration
        
        let offset: CGPoint
        switch animationType {
        case .turnTable:
            offset = CGPoint(
                x: sin(CGFloat(progress) * 2 * CGFloat.pi),
                y: cos(CGFloat(progress) * 2 * CGFloat.pi)
            ).scaled(by: 0.02)
        case .horizontalSwitch:
            offset = CGPoint(
                x: progress < 0.5 ? (4 * progress - 1) : (-4 * progress + 3),
                y: 0
            ).scaled(by: 0.04)
        }
        
        delegate?.renderer(renderer, didUpdateOffset: offset)
    }
}


enum ImageParallaxType: Int {
    case imagePredictedDepth
    case imageTrueDepth
    case predictedDepthOnly
    case trueDepthOnly
}


final class ImageParallaxViewController: UIViewController {
    struct Uniforms {
        var offset: SIMD2<Float>
    }
    
    public var depthImage: DepthImage?
    public var parallaxType: ImageParallaxType {
        didSet {
            guard let depthImage = depthImage else {return}
            
            let imageProperty: SCNMaterialProperty
            let imageDepthProperty: SCNMaterialProperty
            
            switch self.parallaxType {
            case .imagePredictedDepth:
                imageProperty = SCNMaterialProperty(contents: depthImage.diffuse)
                imageDepthProperty = SCNMaterialProperty(contents: depthImage.predictedDepth)
            case .imageTrueDepth:
                imageProperty = SCNMaterialProperty(contents: depthImage.diffuse)
                imageDepthProperty = SCNMaterialProperty(contents: depthImage.trueDepth!)
            case .predictedDepthOnly:
                imageProperty = SCNMaterialProperty(contents: depthImage.predictedDepth)
                imageDepthProperty = SCNMaterialProperty(contents: depthImage.predictedDepth)
            case .trueDepthOnly:
                imageProperty = SCNMaterialProperty(contents: depthImage.trueDepth!)
                imageDepthProperty = SCNMaterialProperty(contents: depthImage.trueDepth!)
            }
            
            for property in [imageProperty, imageDepthProperty] {
                property.wrapT = .clamp
                property.wrapS = .clamp
            }
            
            plane.firstMaterial?.setValue(imageProperty, forKey: "diffuseTexture")
            plane.firstMaterial?.setValue(imageDepthProperty, forKey: "depthTexture")
        }
    }
    
    private var sceneView: SCNView!
    private var scene: SCNScene!
    private var plane: SCNPlane!
    
    private var imageProperty: SCNMaterialProperty!
    private var imageDepthProperty: SCNMaterialProperty!
    
    private var animationCoordinator: ImageParallaxAnimationCoordinator!
    private var animationCoordinatorShouldAnimate = true
    public var animationType: ImageParallaxAnimationType {
        didSet {
            guard let coordinator = self.animationCoordinator else {return}
            coordinator.animationType = animationType
        }
    }
    
    private var uniforms: Uniforms! {
        didSet {
            let data = NSData(bytes: &uniforms, length: MemoryLayout.size(ofValue: uniforms))
            plane?.firstMaterial?.setValue(data, forKey: "uniforms")
        }
    }
    
    init(depthImage: DepthImage?, parallaxType: ImageParallaxType, animationType: ImageParallaxAnimationType) {
        self.depthImage = depthImage
        self.parallaxType = parallaxType
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
        
        animationCoordinator = ImageParallaxAnimationCoordinator(animationDuration: 1, animationType: animationType)
        sceneView.delegate = animationCoordinator
        animationCoordinator.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneView?.isPlaying = true
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
    @Binding public var parallaxTypeRawValue: Int
    @Binding public var animationTypeRawValue: Int
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<ImageParallaxViewControllerRepresentable>
    ) -> ImageParallaxViewController {
        let parallaxType = ImageParallaxType.init(rawValue: parallaxTypeRawValue)!
        let animationType = ImageParallaxAnimationType.init(rawValue: animationTypeRawValue)!
        return ImageParallaxViewController(depthImage: depthImage, parallaxType: parallaxType, animationType: animationType)
    }
    
    public func updateUIViewController(_ uiViewController: ImageParallaxViewController, context: UIViewControllerRepresentableContext<ImageParallaxViewControllerRepresentable>) {
        let parallaxType = ImageParallaxType.init(rawValue: parallaxTypeRawValue)!
        let animationType = ImageParallaxAnimationType.init(rawValue: animationTypeRawValue)!
        uiViewController.parallaxType = parallaxType
        uiViewController.animationType = animationType
    }
}


struct ImageParallaxView: View {
    
    @Binding var depthImage: DepthImage?
    @State var cardOffset: CGFloat = min(UIScreen.main.bounds.height - 128, CardPosition.bottom.rawValue)
    
    @State var selectedImageParallaxRawValue = ImageParallaxType.imagePredictedDepth.rawValue
    @State var selectedAnimationTypeRawValue = ImageParallaxAnimationType.turnTable.rawValue
    
    var imageControllerHeight: CGFloat {
        guard let depthImage = depthImage else {return .zero}
        
        let aspectRatio = depthImage.diffuse.size.height / depthImage.diffuse.size.width
        let height = aspectRatio * UIScreen.main.bounds.width
        
        return height
    }
    
    var body: some View {
        ZStack {
            BlurView(style: .extraLight)
            .frame(height: 64)
            .mask(LinearGradient(gradient: Gradient(colors: [Color.white, Color.clear]), startPoint: .top, endPoint: .bottom))
            
            VStack {
                ImageParallaxViewControllerRepresentable(depthImage: $depthImage, parallaxTypeRawValue: $selectedImageParallaxRawValue, animationTypeRawValue: $selectedAnimationTypeRawValue)
                .frame(width: UIScreen.main.bounds.width, height: cardOffset + 24)
                .offset(x: 0, y: 0)
                Spacer()
            }
            
            SlideOverCard(onOffsetChange: { offset in
                DispatchQueue.main.async {
                    withAnimation {
                        self.cardOffset = offset
                    }
                }
            }) {
                VStack {
                    Handle()
                        .foregroundColor(Color.white.opacity(0.9))
                        .padding(.vertical, 4)
                    
                    Picker(selection: self.$selectedImageParallaxRawValue, label: Text("")) {
                        Text("AI 3D").tag(ImageParallaxType.imagePredictedDepth.rawValue)
                        Text("AI Depth").tag(ImageParallaxType.predictedDepthOnly.rawValue)
                        if (self.depthImage?.trueDepth != nil) {
                            Text("True 3D").tag(ImageParallaxType.imageTrueDepth.rawValue)
                            Text("True Depth").tag(ImageParallaxType.trueDepthOnly.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(4)
                    
                    Picker(selection: self.$selectedAnimationTypeRawValue, label: Text("")) {
                        Text("Turntable").tag(ImageParallaxAnimationType.turnTable.rawValue)
                        Text("Shaker").tag(ImageParallaxAnimationType.horizontalSwitch.rawValue)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(4)
                    
                    Spacer()
                }
                .background(LinearGradient(gradient: Gradients.learningLeading, startPoint: .bottomLeading, endPoint: .topTrailing))
                .cornerRadius(24)
            }
        }
    }
}


struct ImageParallaxView_Previews: PreviewProvider {
    static var previews: some View {
        ImageParallaxView(depthImage: .constant(DepthImage(diffuse: UIImage(named: "header-background")!, trueDepth: UIImage(named: "header-background-depth")!)))
    }
}
