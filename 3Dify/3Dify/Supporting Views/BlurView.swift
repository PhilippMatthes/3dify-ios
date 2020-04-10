//
//  BlurView.swift
//  3Dify
//
//  Created by It's free real estate on 10.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: UIViewRepresentableContext<BlurView>) -> UIView {
        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        return blurView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Do nothing
    }
}
