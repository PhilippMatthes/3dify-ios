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
    let sceneView = SKView()
    var scene: ImageScene?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.frame = .init(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
        )
        scene = ImageScene(size: sceneView.bounds.size)
        sceneView.presentScene(scene)
        view.addSubview(sceneView)
        
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(userDidPan)))
    }
    
    @objc func userDidPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: view)
        let offset = CGPoint(x: translation.x / view.frame.width, y: translation.y / view.frame.height)
        scene?.offset = offset
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
