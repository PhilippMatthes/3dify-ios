import Foundation

class ParallaxViewEnvironment: NSObject, ObservableObject {
    @Published var selectedAnimationInterval: TimeInterval
    @Published var selectedAnimationIntensity: Float
    @Published var selectedFocalPoint: Float
    @Published var selectedBlurIntensity: Float
    @Published var selectedAnimation: ParallaxAnimation
    @Published var depthImage: DepthImage
    
    init(
        selectedAnimationInterval: TimeInterval = 4,
        selectedAnimationIntensity: Float = 0.05,
        selectedFocalPoint: Float = 0.5,
        selectedBlurIntensity: Float = 0,
        selectedAnimation: ParallaxAnimation = .horizontalSwitch,
        depthImage: DepthImage
    ) {
        self.selectedAnimationInterval = selectedAnimationInterval
        self.selectedAnimationIntensity = selectedAnimationIntensity
        self.selectedFocalPoint = selectedFocalPoint
        self.selectedBlurIntensity = selectedBlurIntensity
        self.selectedAnimation = selectedAnimation
        self.depthImage = depthImage
    }
}
