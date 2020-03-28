//
//  SceneDelegate.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let sampleDepthImages = [
            DepthImage(diffuse: UIImage(named: "mango-image")!, trueDepth: UIImage(named: "mango-depth")!),
            DepthImage(diffuse: UIImage(named: "flowers-image")!, trueDepth: UIImage(named: "flowers-depth")!),
            DepthImage(diffuse: UIImage(named: "tunnel-image")!, trueDepth: UIImage(named: "tunnel-depth")!),
            DepthImage(diffuse: UIImage(named: "hut-image")!, trueDepth: UIImage(named: "hut-depth")!)
        ]
        
        let contentView = ContentView(depthImage: sampleDepthImages.randomElement()!)

        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}

