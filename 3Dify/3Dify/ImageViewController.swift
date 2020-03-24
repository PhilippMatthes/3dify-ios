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
    private var sceneView: SCNView!
    private var scene: SCNScene!
    private var plane: SCNPlane!
    
    private var x: Float = 0
    private var y: Float = 0
    
    var imageDepth: UIImage!
    var image: UIImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        let aspectRatio = image.size.height / image.size.width
        let width = UIScreen.main.bounds.width
        let height = aspectRatio * width
        
        sceneView = SCNView(
            frame: .init(x: 0, y: 0, width: width, height: height),
            options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.openGLES2.rawValue]
        )
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
        plane = SCNPlane(width: frustumWidth, height: frustumHeight)
        plane.widthSegmentCount = 1
        plane.heightSegmentCount = 1
        let planeNode = SCNNode(geometry: plane)
        scene.rootNode.addChildNode(planeNode)
        
        // Set up the shader program
        let program = SCNProgram()
        program.setSemantic(SCNGeometrySource.Semantic.texcoord.rawValue, forSymbol: "texCoord", options: nil)
        program.setSemantic(SCNGeometrySource.Semantic.vertex.rawValue, forSymbol: "vertexPosition", options: nil)
        program.setSemantic(SCNModelViewProjectionTransform, forSymbol: "modelViewProjectionMatrix", options: nil)
        
        program.vertexShader = try! String(contentsOfFile: Bundle.main.path(forResource: "ImageParallax", ofType: "vert")!)
        program.fragmentShader = try! String(contentsOfFile: Bundle.main.path(forResource: "ImageParallax", ofType: "frag")!)
        
        plane.firstMaterial?.program = program
        
        let imageTexture = try! GLKTextureLoader.texture(with: image.cgImage!, options: nil)
        let imageDepthTexture = try! GLKTextureLoader.texture(withContentsOf: imageDepth.jpegData(compressionQuality: 1.0)!, options: nil)
        
        plane.firstMaterial?.handleBinding(ofSymbol: "image") { (programId:UInt32, location:UInt32, node:SCNNode!, renderer:SCNRenderer!) -> Void in
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), Float(GL_CLAMP_TO_EDGE) )
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), Float(GL_CLAMP_TO_EDGE) )
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), Float(GL_LINEAR) )
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), Float(GL_LINEAR) )
            glBindTexture(GLenum(GL_TEXTURE_2D), imageTexture.name)
        }
        
        plane.firstMaterial?.handleBinding(ofSymbol: "imageDepth") { (programId:UInt32, location:UInt32, node:SCNNode!, renderer:SCNRenderer!) -> Void in
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), Float(GL_CLAMP_TO_EDGE) )
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), Float(GL_CLAMP_TO_EDGE) )
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), Float(GL_LINEAR) )
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), Float(GL_LINEAR) )
            glBindTexture(GLenum(GL_TEXTURE_2D), imageDepthTexture.name)
        }
        
        plane.firstMaterial?.handleBinding(ofSymbol: "offset") { (programId:UInt32, location:UInt32, node:SCNNode!, renderer:SCNRenderer!) -> Void in
            let location = GLint(location)
            glUniform2f(location, 0.0, 0.1)
        }
        
        // Configure the camera
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = fieldOfView
        camera.zNear = 0
        cameraNode.camera = camera
        cameraNode.position = .init(0, 0, cameraZPosition)
        scene.rootNode.addChildNode(cameraNode)
        
        sceneView.scene = scene
        sceneView.backgroundColor = .red
    }
    
    @objc func userDidPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: view)
        self.x = Float(translation.x / view.frame.width)
        self.y = Float(translation.y / view.frame.height)
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
