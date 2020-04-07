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

class HostingController: UIHostingController<HomeView> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        let contentView = HomeView(depthImage: DepthImage(diffuse: UIImage(named: "city-image")!, depth: UIImage(named: "city-depth")!, isArtificial: true))

        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}

