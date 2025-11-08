import SpriteKit

public enum UpgradeType: CaseIterable, Equatable {
    case honeypot
    case extraHeart
    case lifeVests
    case refillHearts
    case flySwatters
    case rockets
    case superJump
    case axe
}

public protocol HUDConfigurable {
    func configure(
        gameScene: SKScene,
        hudBar: SKShapeNode,
        hudBarShadow: SKShapeNode?,
        heartsContainer: SKNode,
        lifeVestsContainer: SKNode,
        scrollSaverContainer: SKNode
    )
    /// Returns the list of upgrade options to show for the provided score.
    /// - Parameter currentScore: The player's current score.
    /// - Returns: The ordered list of upgrades that should be presented.
    func upgradeOptions(for currentScore: Int) -> [UpgradeType]
}

// Single, unambiguous conformance
extension HUDController: HUDConfigurable {
    public func configure(
        gameScene: SKScene,
        hudBar: SKShapeNode,
        hudBarShadow: SKShapeNode?,
        heartsContainer: SKNode,
        lifeVestsContainer: SKNode,
        scrollSaverContainer: SKNode
    ) {
        self.scene = gameScene
        self.hudBar = hudBar
        self.hudBarShadow = hudBarShadow
        self.heartsContainer = heartsContainer
        self.lifeVestsContainer = lifeVestsContainer
    }

    public func upgradeOptions(for currentScore: Int) -> [UpgradeType] {
        if currentScore <= 4000 {
            return [.honeypot, .extraHeart, .lifeVests, .refillHearts, .superJump]
        } else {
            if currentScore > 8000 { // Lowered from 15000 to 8000
                return [.honeypot, .extraHeart, .lifeVests, .flySwatters, .refillHearts, .rockets, .superJump, .axe]
            } else {
                return [.honeypot, .extraHeart, .lifeVests, .flySwatters, .refillHearts, .rockets, .superJump]
            }
        }
    }
}
