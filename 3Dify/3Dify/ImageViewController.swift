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
import SpriteKit


final class ImageViewController: UIViewController {
    private var sceneView: ImageView?
    private var scene: ImageScene?
    
    var depthImage: UIImage!
    var image: UIImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        let aspectRatio = image.size.height / image.size.width
        let width = UIScreen.main.bounds.width - 16
        let height = min(
            UIScreen.main.bounds.height - 88,
            aspectRatio * width
        )
        let y = UIScreen.main.bounds.height - height - 88
        
        sceneView = ImageView(
            frame: .init(x: 8, y: y, width: width, height: height),
            image: image,
            depthImage: depthImage
        )
        sceneView!.layer.cornerRadius = 12
        sceneView!.clipsToBounds = true
        view.addSubview(sceneView!)
        
        sceneView!.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(userDidPan))
        )
    }
    
    @objc func userDidPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: view)
        let offset = CGPoint(x: translation.x / view.frame.width, y: translation.y / view.frame.height)
        sceneView?.offset = offset
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
