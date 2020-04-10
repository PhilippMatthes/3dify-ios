//
//  Colors.swift
//  3Dify
//
//  Created by It's free real estate on 25.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import SwiftUI


internal extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


class Gradients {
    static let clouds = Gradient(colors: [
        Color(red: 236/255, green: 233/255, blue: 230/255),
        Color.white
    ])
    
    static let playingWithReds = Gradient(colors: [
        Color(red: 211/255, green: 16/255, blue: 39/255),
        Color(red: 234/255, green: 56/255, blue: 77/255),
    ])
    
    static let kimoby = Gradient(colors: [
        Color(red: 57/255, green: 106/255, blue: 252/255),
        Color(red: 41/255, green: 73/255, blue: 255/255),
    ])
    
    static let learningLeading = Gradient(colors: [
        Color(red: 247/255, green: 149/255, blue: 30/255),
        Color(red: 255/255, green: 210/255, blue: 0/255),
    ])
    
    static let royal = Gradient(colors: [
        Color(hex: "#141E30"), Color(hex: "#243B55")
    ])
    
    static let lush = Gradient(colors: [
        Color(hex: "#56ab2f"), Color(hex: "#a8e063")
    ])
}

