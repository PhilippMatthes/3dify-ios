//
//  ImageScene.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import SpriteKit

class ImageScene: SKScene {
    
    public var offset: CGPoint = .zero {
        didSet {
            u_offset.vectorFloat2Value = vector_float2(
                Float(offset.y), Float(offset.x)
            )
        }
    }
    
    private var u_intensity = SKUniform(name: "u_intensity", float: 0.2)
    private var u_offset = SKUniform(name: "u_offset", vectorFloat2: .zero)
    private var u_image: SKUniform!
    private var u_image_depth: SKUniform!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    init(size: CGSize, image: UIImage, depthImage: UIImage) {
        super.init(size: size)
        
        u_image = SKUniform(name: "u_image", texture: SKTexture(image: image))
        u_image_depth = SKUniform(name: "u_image_depth", texture: SKTexture(image: depthImage))
        
        
        let imageNode = SKSpriteNode()
        imageNode.position = .init(x: size.width / 2, y: size.height / 2)
        imageNode.zRotation = -CGFloat.pi / 2
        imageNode.size = .init(width: size.height, height: size.width)
        
        let imageShader = SKShader(fileNamed: "ImageParallax.fsh")
        imageNode.shader = imageShader
        
        imageShader.uniforms = [
            u_intensity,
            u_offset,
            u_image,
            u_image_depth
        ]
        
        shouldEnableEffects = true
        
        addChild(imageNode)
    }
    
}
