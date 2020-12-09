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

class ParallaxViewEnvironment: NSObject, ObservableObject {
    @Published var selectedAnimationInterval: TimeInterval
    @Published var selectedAnimationIntensity: Float
    @Published var selectedFocalPoint: Float
    @Published var selectedBlurIntensity: Float
    @Published var selectedAnimation: ParallaxAnimation
    @Published var parallaxImage: ParallaxImage
    
    init(
        selectedAnimationInterval: TimeInterval = 4,
        selectedAnimationIntensity: Float = 0.05,
        selectedFocalPoint: Float = 0.5,
        selectedBlurIntensity: Float = 0,
        selectedAnimation: ParallaxAnimation = .horizontalSwitch,
        parallaxImage: ParallaxImage
    ) {
        self.selectedAnimationInterval = selectedAnimationInterval
        self.selectedAnimationIntensity = selectedAnimationIntensity
        self.selectedFocalPoint = selectedFocalPoint
        self.selectedBlurIntensity = selectedBlurIntensity
        self.selectedAnimation = selectedAnimation
        self.parallaxImage = parallaxImage
    }
}
