//
// 3Dify App
//
// Project website: https://github.com/3dify-app
//
// Authors:
// - Philipp Matthes 2020, Contact: mail@philippmatth.es
//
// Copyright notice: All rights reserved by the authors given above. Do not
// remove or change this copyright notice without confirmation of the authors.
//

import Foundation
import CoreGraphics

enum ParallaxAnimation: Int, CustomStringConvertible {
    case turnTable
    case horizontalSwitch
    case verticalSwitch
    
    static var all: [Self] {
        [turnTable, horizontalSwitch, verticalSwitch]
    }
    
    var description: String {
        switch self {
        case .turnTable:
            return "TurnTable"
        case .horizontalSwitch:
            return "HSwitch"
        case .verticalSwitch:
            return "VSwitch"
        }
    }
}


extension ParallaxAnimation {
    func computeOffset(
        at progress: CGFloat,
        selectedAnimationIntensity: CGFloat
    ) -> CGPoint {
        switch self {
        case .turnTable:
            return CGPoint(
                x: sin(CGFloat(progress) * 2 * CGFloat.pi) * selectedAnimationIntensity,
                y: cos(CGFloat(progress) * 2 * CGFloat.pi) * selectedAnimationIntensity
            )
        case .horizontalSwitch:
            return CGPoint(
                x: sin(progress * 2 * .pi) * selectedAnimationIntensity,
                y: 0
            )
        case .verticalSwitch:
            return CGPoint(
                x: 0,
                y: sin(progress * 2 * .pi) * selectedAnimationIntensity
            )
        }
    }
}
