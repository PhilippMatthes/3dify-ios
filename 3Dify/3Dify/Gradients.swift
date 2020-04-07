//
//  Gradients.swift
//  3Dify
//
//  Created by It's free real estate on 25.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import SwiftUI


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

