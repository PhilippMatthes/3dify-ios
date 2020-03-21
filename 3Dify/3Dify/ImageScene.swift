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
                Float(offset.x), Float(offset.y)
            )
        }
    }
    
    private var u_intensity = SKUniform(name: "u_intensity", float: 0.1)
    private var u_offset = SKUniform(name: "u_offset", vectorFloat2: .zero)
    private var u_image = SKUniform(name: "u_image", texture: SKTexture(image: UIImage(named: "header-background")!))
    private var u_image_depth = SKUniform(name: "u_image_depth", texture: SKTexture(image: UIImage(named: "header-background-depth")!))
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(size: CGSize) {
        super.init(size: size)
        
        let imageNode = SKSpriteNode()
        imageNode.position = .init(x: size.width / 2, y: size.height / 2)
        imageNode.size = size
        
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
