import Foundation
import SpriteKit

class ParallaxViewOverlay: SKView {
    var overlayTextNode: SKNode?
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        let overlaySKScene = SKScene()
        overlaySKScene.backgroundColor = .clear
        overlayTextNode = SKNode()
        let backgroundNode = SKShapeNode(
            rect: .init(x: 0, y: 0, width: 183, height: 36),
            cornerRadius: 18
        )
        backgroundNode.fillColor = UIColor.black.withAlphaComponent(0.1)
        backgroundNode.strokeColor = .clear
        overlayTextNode!.addChild(backgroundNode)
        let madeWith = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        madeWith.text = "Made with"
        madeWith.fontSize = 24
        madeWith.horizontalAlignmentMode = .left
        madeWith.fontColor = SKColor.white
        madeWith.position = .init(x: 8, y: 8)
        overlayTextNode!.addChild(madeWith)
        let threeDeeIfy = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        threeDeeIfy.text = "3Dify"
        threeDeeIfy.fontSize = 24
        threeDeeIfy.horizontalAlignmentMode = .left
        threeDeeIfy.fontColor = SKColor.white
        threeDeeIfy.position = .init(x: 118, y: 8)
        overlayTextNode!.addChild(threeDeeIfy)
        overlaySKScene.addChild(overlayTextNode!)
        overlaySKScene.scaleMode = .resizeFill
        presentScene(overlaySKScene)
        allowsTransparency = true
        backgroundColor = .clear
        isPaused = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        overlayTextNode?.position = .init(x: frame.midX - 92, y: 64)
    }
}
