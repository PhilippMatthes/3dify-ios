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


final class ImageParallaxViewController: UIViewController {
    struct Uniforms {
        var offset: SIMD2<Float>
    }
    
    public var depthImage: DepthImage?
    
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
    
    init(depthImage: DepthImage?) {
        self.depthImage = depthImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let depthImage = depthImage else {return}
        
        let aspectRatio = depthImage.diffuse.size.height / depthImage.diffuse.size.width
        let width = UIScreen.main.bounds.width
        let height = aspectRatio * width
        
        sceneView = SCNView(frame: .init(x: 0, y: 0, width: width, height: height))
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
        let imageDepthProperty = SCNMaterialProperty(contents: depthImage.depth)
        
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
        
        sceneView.showsStatistics = true
        
        sceneView.scene = scene
        sceneView.backgroundColor = .red
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
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<ImageParallaxViewControllerRepresentable>
    ) -> ImageParallaxViewController {
        return ImageParallaxViewController(depthImage: depthImage)
    }
    
    public func updateUIViewController(_ uiViewController: ImageParallaxViewController, context: UIViewControllerRepresentableContext<ImageParallaxViewControllerRepresentable>) {
        // Do nothing
    }
}
