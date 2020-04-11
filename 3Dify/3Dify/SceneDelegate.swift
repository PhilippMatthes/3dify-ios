//
//  SceneDelegate.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import UIKit
import SwiftUI
import MetalKit
import SwiftRater

class HostingController: UIHostingController<HomeView> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        SwiftRater.check()
    }
}


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        let imageIndexToPick = Int.random(in: 0...6)
        
        let contentView = HomeView(
            depthImage: DepthImage(
                diffuse: UIImage(named: "\(imageIndexToPick)_diffuse")!,
                depth: UIImage(named: "\(imageIndexToPick)_depth")!,
                isArtificial: true
            )
        )

        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = HostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}

