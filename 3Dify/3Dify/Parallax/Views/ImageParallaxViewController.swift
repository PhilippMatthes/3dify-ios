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
            viewDidLoad()
        }
    }
    
    private var sceneView: SCNView!
    private var scene: SCNScene!
    private var plane: SCNPlane!
    
    private var imageProperty: SCNMaterialProperty!
    private var imageDepthProperty: SCNMaterialProperty!
    
    private var uniforms: Uniforms! {
        didSet {
            let data = NSData(bytes: &uniforms, length: MemoryLayout.size(ofValue: uniforms))
            plane?.firstMaterial?.setValue(data, forKey: "uniforms")
        }
    }
    
    init(depthImage: DepthImage?, parallaxType: ImageParallaxType) {
        self.depthImage = depthImage
        self.parallaxType = parallaxType
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
    }
    
    override func viewWillLayoutSubviews() {
        sceneView?.frame = view.frame
    }
    
    @objc func userDidPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: view)
        
        uniforms = Uniforms.init(offset: .init(
            x: max(min(Float(translation.x / view.frame.width) * 0.3, 0.06), -0.06),
            y: max(min(Float(translation.y / view.frame.height) * 0.3, 0.06), -0.06)
        ))
    }
}


struct ImageParallaxViewControllerRepresentable: UIViewControllerRepresentable {
    
    public typealias UIViewControllerType = ImageParallaxViewController
    
    @Binding public var depthImage: DepthImage?
    @Binding public var parallaxTypeRawValue: Int
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<ImageParallaxViewControllerRepresentable>
    ) -> ImageParallaxViewController {
        let parallaxType = ImageParallaxType.init(rawValue: parallaxTypeRawValue)!
        return ImageParallaxViewController(depthImage: depthImage, parallaxType: parallaxType)
    }
    
    public func updateUIViewController(_ uiViewController: ImageParallaxViewController, context: UIViewControllerRepresentableContext<ImageParallaxViewControllerRepresentable>) {
        let parallaxType = ImageParallaxType.init(rawValue: parallaxTypeRawValue)!
        uiViewController.parallaxType = parallaxType
    }
}

struct BlurView: UIViewRepresentable {

    let style: UIBlurEffect.Style

    func makeUIView(context: UIViewRepresentableContext<BlurView>) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        return view
    }

    func updateUIView(_ uiView: UIView,
                      context: UIViewRepresentableContext<BlurView>) {

    }
}


struct ImageParallaxView: View {
    
    @Binding var depthImage: DepthImage?
    @State var cardOffset: CGFloat = min(UIScreen.main.bounds.height - 128, CardPosition.bottom.rawValue)
    
    @State var selectedImageParallaxRawValue = ImageParallaxType.imagePredictedDepth.rawValue
    
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
                ImageParallaxViewControllerRepresentable(depthImage: $depthImage, parallaxTypeRawValue: $selectedImageParallaxRawValue)
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
                    
                    Picker(selection: self.$selectedImageParallaxRawValue, label: Text("What is your favorite color?")) {
                        Text("AI 3D").tag(ImageParallaxType.imagePredictedDepth.rawValue)
                        Text("AI Depth").tag(ImageParallaxType.predictedDepthOnly.rawValue)
                        if (self.depthImage?.trueDepth != nil) {
                            Text("True 3D").tag(ImageParallaxType.imageTrueDepth.rawValue)
                            Text("True Depth").tag(ImageParallaxType.trueDepthOnly.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(12)
                    
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
