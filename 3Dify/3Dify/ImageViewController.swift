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


final class ImageViewController: UIViewController {
    struct Uniforms {
        var offset: SIMD2<Float>
    }
    
    public var image: UIImage!
    public var imageDepth: UIImage!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        let aspectRatio = image.size.height / image.size.width
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
        let frustumWidth: CGFloat = 2 * cameraZPosition * tan(fieldOfView * 0.5 * .pi / 180)
        let frustumHeight: CGFloat = frustumWidth * 1 / aspectRatio

        // Set the plane size to exactly that computed size
        plane = SCNPlane(width: frustumWidth, height: frustumHeight)
        plane.widthSegmentCount = 1
        plane.heightSegmentCount = 1
        let planeNode = SCNNode(geometry: plane)
        planeNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: -CGFloat.pi / 2, duration: 0.0))
        scene.rootNode.addChildNode(planeNode)
        
        // Set up the shader program
        let program = SCNProgram()
        program.fragmentFunctionName = "myFragment"
        program.vertexFunctionName = "myVertex"
        plane.firstMaterial?.program = program
        
        let imageProperty = SCNMaterialProperty(contents: image!)
        plane.firstMaterial?.setValue(imageProperty, forKey: "diffuseTexture")
        let imageDepthProperty = SCNMaterialProperty(contents: imageDepth!)
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
        
        sceneView.antialiasingMode = .multisampling4X
        
        sceneView.scene = scene
        sceneView.backgroundColor = .red
    }
    
    @objc func userDidPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: view)
        uniforms = Uniforms.init(offset: .init(
            x: Float(translation.y / view.frame.width),
            y: Float(translation.x / view.frame.height)
        ))
    }
}


extension ImageViewController: UIViewControllerRepresentable {
    public typealias UIViewControllerType = ImageViewController
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<ImageViewController>
    ) -> ImageViewController {
        return ImageViewController()
    }
    
    public func updateUIViewController(_ uiViewController: ImageViewController, context: UIViewControllerRepresentableContext<ImageViewController>) {
        // Do nothing
    }
}
