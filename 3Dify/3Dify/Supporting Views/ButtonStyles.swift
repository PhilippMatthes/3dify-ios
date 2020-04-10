//
//  ButtonStyles.swift
//  3Dify
//
//  Created by It's free real estate on 07.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import SwiftUI


struct FatButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 24
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(configuration.isPressed ? 0.5 : 0.9))
        )
        .animation(.interpolatingSpring(stiffness: 300.0, damping: 20.0, initialVelocity: 10.0))
    }
}

struct OutlinedFatButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 24
    var color: Color = .white
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(self.color.opacity(configuration.isPressed ? 0.5 : 0.9), lineWidth: 2))
        .animation(.interpolatingSpring(stiffness: 300.0, damping: 20.0, initialVelocity: 10.0))
    }
}
