import SpriteKit

/// A fly that buzzes around lily pads
/// When collected by the frog, it heals 1 heart (if there's an empty heart slot)
class Fly: GameEntity {
    
    // MARK: - Properties
    private let buzzRadius: CGFloat = 30  // Radius of buzzing circle around the pad
    private var buzzAngle: CGFloat = 0
    private let buzzSpeed: CGFloat = 3.0  // Speed of buzzing motion
    private let anchorPosition: CGPoint  // Center position (the lily pad it's buzzing around)
    
    var isCollected: Bool = false
    
    // MARK: - Initialization
    
    init(position: CGPoint) {
        self.anchorPosition = position
        self.buzzAngle = CGFloat.random(in: 0...(2 * .pi))  // Random starting angle
        
        let texture = SKTexture(imageNamed: "fly")
        super.init(texture: texture, color: .clear, size: CGSize(width: 20, height: 20))
        
        self.position = position
        self.zPosition = Layer.item  // Same layer as coins and enemies
        self.zHeight = 25
        self.name = "fly"
        
        // Add a subtle pulsing animation to make the fly more noticeable
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.2)
        let scaleDown = SKAction.scale(to: 0.9, duration: 0.2)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        self.run(SKAction.repeatForever(pulse))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Update
    
    /// Updates the fly's buzzing motion around the lily pad
    func update(dt: TimeInterval) {
        guard !isCollected else { return }
        
        // Increment the buzzing angle
        buzzAngle += buzzSpeed * CGFloat(dt)
        if buzzAngle > 2 * .pi {
            buzzAngle -= 2 * .pi
        }
        
        // Calculate new position in a circle around the anchor
        let offsetX = cos(buzzAngle) * buzzRadius
        let offsetY = sin(buzzAngle) * buzzRadius
        
        position = CGPoint(
            x: anchorPosition.x + offsetX,
            y: anchorPosition.y + offsetY
        )
        
        // Slight rotation based on movement direction for visual effect
        zRotation = buzzAngle + .pi / 2
    }
    
    // MARK: - Collection
    
    /// Marks the fly as collected and plays a collection animation
    func collect(completion: @escaping () -> Void) {
        guard !isCollected else { return }
        isCollected = true
        
        // Stop the pulsing animation
        removeAllActions()
        
        // Play collection animation: scale up and fade out
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        run(SKAction.sequence([group, remove])) {
            completion()
        }
    }
}
