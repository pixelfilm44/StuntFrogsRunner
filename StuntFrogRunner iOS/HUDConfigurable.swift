import SpriteKit

public enum UpgradeType: CaseIterable, Equatable {
    case honeypot
    case extraHeart
    case lifeVests
    case refillHearts
    case flySwatters
    case rockets
}

public protocol HUDConfigurable {
    func configure(
        gameScene: SKScene,
        hudBar: SKShapeNode,
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
        heartsContainer: SKNode,
        lifeVestsContainer: SKNode,
        scrollSaverContainer: SKNode
    ) {
        self.scene = gameScene
        self.hudBar = hudBar
        self.heartsContainer = heartsContainer
        self.lifeVestsContainer = lifeVestsContainer
    }

    public func upgradeOptions(for currentScore: Int) -> [UpgradeType] {
        if currentScore <= 4000 {
            return [.honeypot, .extraHeart, .lifeVests, .refillHearts]
        } else {
            return [.honeypot, .extraHeart, .lifeVests, .flySwatters, .refillHearts, .rockets]
        }
    }
}
