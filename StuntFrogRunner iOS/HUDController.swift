//
//  HUDController.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//

//
//  HUDController.swift
//  StuntFrog Runner
//
//  Manages the bottom HUD bar with hearts and ability icons

import SpriteKit

class HUDController {
    // Rocket final approach banner
    private var rocketBannerLabel: SKLabelNode?
    /// Called when the final-approach state toggles so the game can slow/restore scroll speed
    var onRocketFinalApproachChanged: ((Bool) -> Void)?
    private var isShowingRocketBanner: Bool = false

    /// Emits distance-based score gains so the scene/ScoreManager can own the single score source of truth
    var onScoreGained: ((Int) -> Void)?
    /// Points per point of vertical scroll (tune as needed)
    private let pointsPerPointY: CGFloat = 0.25

    // MARK: - Properties
    weak var hudBar: SKShapeNode?
    weak var heartsContainer: SKNode?
    weak var lifeVestsContainer: SKNode?
    weak var scrollSaverContainer: SKNode?
    
    weak var scene: SKScene?
    
    // Vertical layout constants
    private let heartsY: CGFloat = 50   // slightly higher hearts row
    private let bottomRowY: CGFloat = 12  // middle row slightly higher
    private let secondRowYOffset: CGFloat = -40 // more separation to bottom row
    
    // Allow default construction and later configuration via HUDConfigurable.configure
    init() {}
    
    // Convenience initializer for full configuration
    convenience init(scene: SKScene, hudBar: SKShapeNode, heartsContainer: SKNode, lifeVestsContainer: SKNode, scrollSaverContainer: SKNode) {
        self.init()
        self.scene = scene
        self.hudBar = hudBar
        self.heartsContainer = heartsContainer
        self.lifeVestsContainer = lifeVestsContainer
        self.scrollSaverContainer = scrollSaverContainer
    }
    
    // Ensures the HUD bar is anchored to the bottom of the visible scene area
    private func anchorHUDToBottom() {
        guard let scene = scene, let hudBar = hudBar else { return }
        // Bottom safe padding
        let bottomInset: CGFloat = 22
        let height = max(hudBar.frame.height, 96)
        // Center horizontally, sit just above the bottom edge (using bottom-left origin coordinates)
        hudBar.position = CGPoint(x: scene.size.width / 2, y: height / 2 + bottomInset)
    }
    
    // MARK: - Rocket Final Approach Banner
    /// Shows or hides the flashing "Fly to a lilypad" banner centered on the HUD
    private func setRocketBanner(visible: Bool) {
        guard let hudBar = hudBar else { return }
        if visible {
            if rocketBannerLabel == nil {
                let label = SKLabelNode(text: "Find a lilypad to land on!")
                label.fontName = "HelveticaNeue-Bold"
                label.fontSize = 22
                label.fontColor = .white
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.zPosition = 100 // above tokens
                rocketBannerLabel = label
                hudBar.addChild(label)
            }
            // Position above ability rows but below hearts
            let y = heartsY - 22 // between hearts row and ability rows
            rocketBannerLabel?.position = CGPoint(x: 0, y: y)

            // Start flashing
            if rocketBannerLabel?.action(forKey: "flash") == nil {
                let fadeOut = SKAction.fadeAlpha(to: 0.25, duration: 0.25)
                let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.25)
                let sequence = SKAction.sequence([fadeOut, fadeIn])
                let repeatFlash = SKAction.repeatForever(sequence)
                rocketBannerLabel?.run(repeatFlash, withKey: "flash")
            }
            rocketBannerLabel?.isHidden = false
        } else {
            rocketBannerLabel?.removeAction(forKey: "flash")
            rocketBannerLabel?.isHidden = true
        }
    }

    /// External API: call this every frame (or on state change) with seconds remaining in rocket ride.
    /// When `timeRemaining <= 3`, we show the banner and trigger the slow-scroll callback.
    func updateRocketFinalApproach(timeRemaining: TimeInterval?) {
        let shouldShow = (timeRemaining ?? .infinity) <= 3.0
        if shouldShow != isShowingRocketBanner {
            isShowingRocketBanner = shouldShow
            setRocketBanner(visible: shouldShow)
            onRocketFinalApproachChanged?(shouldShow)
        } else if shouldShow {
            // keep position updated if HUD re-anchors
            setRocketBanner(visible: true)
        }
    }
    
    // MARK: - Score
    /// Call this when the world scrolls upward; positive deltaY means the level moved up (frog progressed)
    func updateScoreForVerticalScroll(deltaY: CGFloat) {
        guard deltaY > 0 else { return }
        let gained = Int((deltaY * pointsPerPointY).rounded(.toNearestOrAwayFromZero))
        if gained > 0 {
            onScoreGained?(gained)
        }
    }
    
    // MARK: - Rendering helpers
    private func makeToken(size: CGFloat, color: UIColor, alpha: CGFloat = 1.0) -> SKShapeNode {
        let token = SKShapeNode(circleOfRadius: size/2)
        token.fillColor = color.withAlphaComponent(alpha)
        token.strokeColor = UIColor.white.withAlphaComponent(0.85)
        token.lineWidth = 1.5
        token.zPosition = 0
        return token
    }
    
    private func computeRowLayout(count: Int, itemSize: CGFloat, minSpacing: CGFloat, maxWidth: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }
        let neededWidth = CGFloat(count) * itemSize
        let gaps = max(count - 1, 1)
        // Compute spacing that fits in maxWidth, but never below a tiny minimum
        let maxSpacingThatFits = (maxWidth - neededWidth) / CGFloat(gaps)
        let spacing = max(6, minSpacing, maxSpacingThatFits)
        // If still negative, shrink item size proportionally
        var finalItemSize = itemSize
        var finalSpacing = spacing
        if neededWidth + spacing * CGFloat(max(count - 1, 0)) > maxWidth {
            let totalGaps = CGFloat(max(count - 1, 0))
            let totalAvailableForItems = max(0, maxWidth - max(6, totalGaps * 6))
            finalItemSize = totalAvailableForItems / CGFloat(count)
            finalSpacing = max(6, (maxWidth - finalItemSize * CGFloat(count)) / CGFloat(gaps))
        }
        let totalWidth = CGFloat(count) * finalItemSize + finalSpacing * CGFloat(max(count - 1, 0))
        var x = -totalWidth/2 + finalItemSize/2
        var positions: [CGFloat] = []
        for _ in 0..<count {
            positions.append(x)
            x += finalItemSize + finalSpacing
        }
        return positions
    }

    private func layoutCenteredRow(in container: SKNode, count: Int, itemSize: CGFloat, spacing: CGFloat) {
        container.removeAllChildren()
        guard count > 0 else { return }
        let totalWidth = CGFloat(count) * itemSize + CGFloat(max(0, count - 1)) * spacing
        let startX = -totalWidth / 2 + itemSize/2
        for i in 0..<count {
            let x = startX + CGFloat(i) * (itemSize + spacing)
            let node = SKNode()
            node.position = CGPoint(x: x, y: 0)
            container.addChild(node)
        }
    }
    
    // Computes the usable horizontal width for laying out HUD content without clipping rounded corners
    private func safeContentWidth() -> CGFloat {
        // Prefer the hudBar path/frame if available, otherwise fall back to scene width
        guard let hudBar = hudBar else {
            if let scene = scene { return max(0, scene.size.width - 48) }
            return 320 // conservative fallback
        }
        // If the hudBar has a path (rounded rect), use its bounding box width
        let barWidth: CGFloat
        if let path = hudBar.path {
            barWidth = path.boundingBox.width
        } else {
            barWidth = hudBar.frame.width
        }
        // Apply horizontal insets to avoid clipping against the bar's rounded corners and stroke
        let horizontalInset: CGFloat = 48 // 24pt per side
        return max(0, barWidth - horizontalInset)
    }

    // MARK: - HUD Updates
    func updateHUD(health: Int, maxHealth: Int, lifeVestCharges: Int, scrollSaverCharges: Int, flySwatterCharges: Int, honeyJarCharges: Int, axeCharges: Int, tadpolesCollected: Int, tadpolesThreshold: Int) {
        guard let hudBar = hudBar else { return }
        
        anchorHUDToBottom()
        
        // Stretch the background container to the full device width
        if let scene = scene {
            // If the hud bar is a rounded rect shape, update its path to span edge-to-edge
            let targetWidth = scene.size.width - 16 // slight inset so stroke doesn't clip
            let barHeight: CGFloat = 88 // changed from 100 to 88
            let radius: CGFloat = min(28, barHeight/2 - 2)
            let rect = CGRect(x: -targetWidth/2, y: -barHeight/2, width: targetWidth, height: barHeight)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            hudBar.path = path.cgPath
            hudBar.fillColor = .clear
            hudBar.strokeColor = .clear
            hudBar.lineWidth = 0
            hudBar.position.x = scene.size.width / 2  // Center horizontally in bottom-left origin
            // Update vertical anchor as well
            anchorHUDToBottom()
        }
        
        // Keep rocket banner aligned if showing
        if isShowingRocketBanner { setRocketBanner(visible: true) }

        // Hearts row at top center
        updateHearts(health: health, maxHealth: maxHealth)

        // Use full scene width minus margins so we don't clip to the rounded bar path
        let safeWidth = safeContentWidth()

        // Arrange abilities into two rows: left cluster (life vests + scroll saver) on first row,
        // right cluster (fly swatter + honey jar + axe) on second row. This avoids overlap on narrow screens.
        // Each updater will place its container relative to the hudBar center using computed x positions.
        updateLifeVests(charges: lifeVestCharges)
        // Removed updateScrollSaver(charges: scrollSaverCharges)
        updateFlySwatter(charges: flySwatterCharges)
        updateHoneyJar(charges: honeyJarCharges)
        updateAxe(charges: axeCharges)

        // Position containers: query by name and set y offsets consistently
        // Removed these fixed y positions that were overwritten below
        //hudBar.childNode(withName: "flySwatterContainer")?.position.y = bottomRowY + secondRowYOffset
        //hudBar.childNode(withName: "honeyJarContainer")?.position.y = bottomRowY + secondRowYOffset
        //hudBar.childNode(withName: "axeContainer")?.position.y = bottomRowY + secondRowYOffset
        //lifeVestsContainer?.position.y = bottomRowY
        // Removed scrollSaverContainer?.position.y = bottomRowY
        heartsContainer?.position.y = heartsY

        // Distribute containers by centering clusters within left/right halves
        let halfWidth = safeWidth / 2
        let quarter = halfWidth / 2

        // Row Y positions
        let middleY = bottomRowY
        let bottomY = bottomRowY + secondRowYOffset

        // Containers
        let swatter = hudBar.childNode(withName: "flySwatterContainer")
        let honey = hudBar.childNode(withName: "honeyJarContainer")
        let axe = hudBar.childNode(withName: "axeContainer")
        let vests = lifeVestsContainer

        // Middle row: honey left, life vests right
        honey?.position = CGPoint(x: -quarter, y: middleY)
        vests?.position = CGPoint(x: quarter, y: middleY)

        // Bottom row: fly swatter left, axe right
        swatter?.position = CGPoint(x: -quarter, y: bottomY)
        axe?.position = CGPoint(x: quarter, y: bottomY)
    }
    
    // MARK: - Hearts
    private func updateHearts(health: Int, maxHealth: Int) {
        guard let heartsContainer = heartsContainer else { return }
        heartsContainer.removeAllChildren()

        // heartsContainer.position = CGPoint(x: 0, y: heartsY)  <-- removed as per instructions

        let itemSize: CGFloat = 32
        let spacing: CGFloat = 8
        let count = maxHealth
        let totalWidth = CGFloat(count) * itemSize + CGFloat(max(0, count - 1)) * spacing
        var x = -totalWidth/2 + itemSize/2
        
        // Try to load heart textures
        let heartFilledTexture = SKTexture(imageNamed: "heart.png")
        let heartEmptyTexture = SKTexture(imageNamed: "heartEmpty.png")
        let useTextures = heartFilledTexture.size() != .zero
        
        for i in 0..<count {
            let token = makeToken(size: itemSize, color: UIColor.systemRed, alpha: 0.9)
            token.position = CGPoint(x: x, y: 0)
            heartsContainer.addChild(token)

            if i < health {
                // Filled heart
                if useTextures {
                    let sprite = SKSpriteNode(texture: heartFilledTexture)
                    sprite.size = CGSize(width: 20, height: 20)
                    sprite.zPosition = 2
                    token.addChild(sprite)
                } else {
                    let label = SKLabelNode(text: "â¤ï¸")
                    label.fontSize = 20
                    label.verticalAlignmentMode = .center
                    label.zPosition = 2
                    token.addChild(label)
                }
            } else {
                // Empty heart
                if useTextures && heartEmptyTexture.size() != .zero {
                    let sprite = SKSpriteNode(texture: heartEmptyTexture)
                    sprite.size = CGSize(width: 20, height: 20)
                    sprite.zPosition = 2
                    token.addChild(sprite)
                } else {
                    let label = SKLabelNode(text: "ðŸ¤")
                    label.fontSize = 20
                    label.verticalAlignmentMode = .center
                    label.zPosition = 2
                    token.addChild(label)
                }
                token.alpha = 0.35
            }
            x += itemSize + spacing
        }
    }
    
    // MARK: - Life Vests
    private func updateLifeVests(charges: Int) {
        guard let lifeVestsContainer = lifeVestsContainer else { return }
        lifeVestsContainer.removeAllChildren()
        
        lifeVestsContainer.position.x = 0 // actual x will be assigned in updateHUD layout
        lifeVestsContainer.position.y = bottomRowY

        let maxSlots = 4
        let size: CGFloat = 26
        let spacing: CGFloat = 8
        let total = maxSlots
        let totalWidth = CGFloat(total) * size + CGFloat(total - 1) * spacing
        var x = -totalWidth/2 + size/2
        let texture = SKTexture(imageNamed: "lifevest.png")
        let useTexture = texture.size() != .zero
        for i in 0..<total {
            let token = makeToken(size: size, color: UIColor.systemBlue, alpha: 0.9)
            token.position = CGPoint(x: x, y: 0)
            lifeVestsContainer.addChild(token)
            if i < charges {
                if useTexture { let s = SKSpriteNode(texture: texture); s.size = CGSize(width: 20, height: 20); s.zPosition = 2; token.addChild(s) }
                else { let l = SKLabelNode(text: "Ã°Å¸â€ºÅ¸"); l.fontSize = 18; l.verticalAlignmentMode = .center; l.zPosition = 2; token.addChild(l) }
            } else {
                token.alpha = 0.25
            }
            x += size + spacing
        }
    }
    
    // MARK: - Scroll Saver
    private func updateScrollSaver(charges: Int) {
        guard let scrollSaverContainer = scrollSaverContainer else { return }
        scrollSaverContainer.removeAllChildren()

        scrollSaverContainer.position.x = 0
        scrollSaverContainer.position.y = bottomRowY

        let maxSlots = 4
        let size: CGFloat = 26
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(maxSlots) * size + CGFloat(maxSlots - 1) * spacing
        var x = -totalWidth/2 + size/2
        let texture = SKTexture(imageNamed: "scroll.png")
        let useTexture = texture.size() != .zero
        for i in 0..<maxSlots {
            let token = makeToken(size: size, color: UIColor.systemOrange, alpha: 0.9)
            token.position = CGPoint(x: x, y: 0)
            scrollSaverContainer.addChild(token)
            if i < charges {
                if useTexture { let s = SKSpriteNode(texture: texture); s.size = CGSize(width: 18, height: 18); s.zPosition = 2; token.addChild(s) }
                else { let l = SKLabelNode(text: "Ã¢ÂÂ±"); l.fontSize = 18; l.verticalAlignmentMode = .center; l.zPosition = 2; token.addChild(l) }
            } else { token.alpha = 0.25 }
            x += size + spacing
        }
    }
    
    // MARK: - Fly Swatter
    private func updateFlySwatter(charges: Int) {
        guard let hudBar = hudBar else { return }
        hudBar.childNode(withName: "flySwatterContainer")?.removeFromParent()
        let flyContainer = SKNode(); flyContainer.name = "flySwatterContainer"; hudBar.addChild(flyContainer)
        flyContainer.position = CGPoint(x: 0, y: bottomRowY + secondRowYOffset)
        let maxSlots = 4
        let size: CGFloat = 26
        let spacing: CGFloat = 8
        let texture = SKTexture(imageNamed: "flySwatter.png")
        let useTexture = texture.size() != .zero
        let totalWidth = CGFloat(maxSlots) * size + CGFloat(maxSlots - 1) * spacing
        var x = -totalWidth/2 + size/2
        for i in 0..<maxSlots {
            let token = makeToken(size: size, color: UIColor.systemPurple, alpha: 0.9)
            token.position = CGPoint(x: x, y: 0)
            flyContainer.addChild(token)
            if i < charges {
                if useTexture { let s = SKSpriteNode(texture: texture); s.size = CGSize(width: 18, height: 18); s.zPosition = 2; token.addChild(s) }
                else { let l = SKLabelNode(text: "Ã°Å¸ÂªÂ°"); l.fontSize = 18; l.verticalAlignmentMode = .center; l.zPosition = 2; token.addChild(l) }
            } else { token.alpha = 0.25 }
            x += size + spacing
        }
    }
    
    // MARK: - Honey Jar
    private func updateHoneyJar(charges: Int) {
        guard let hudBar = hudBar else { return }
        hudBar.childNode(withName: "honeyJarContainer")?.removeFromParent()
        let honeyContainer = SKNode(); honeyContainer.name = "honeyJarContainer"; hudBar.addChild(honeyContainer)
        honeyContainer.position = CGPoint(x: 0, y: bottomRowY + secondRowYOffset)
        let maxSlots = 4
        let size: CGFloat = 26
        let spacing: CGFloat = 8
        let texture = SKTexture(imageNamed: "honeyPot.png")
        let useTexture = texture.size() != .zero
        let totalWidth = CGFloat(maxSlots) * size + CGFloat(maxSlots - 1) * spacing
        var x = -totalWidth/2 + size/2
        for i in 0..<maxSlots {
            let token = makeToken(size: size, color: UIColor.systemTeal, alpha: 0.9)
            token.position = CGPoint(x: x, y: 0)
            honeyContainer.addChild(token)
            if i < charges {
                if useTexture { let s = SKSpriteNode(texture: texture); s.size = CGSize(width: 18, height: 18); s.zPosition = 2; token.addChild(s) }
                else { let l = SKLabelNode(text: "Ã°Å¸ÂÂ¯"); l.fontSize = 18; l.verticalAlignmentMode = .center; l.zPosition = 2; token.addChild(l) }
            } else { token.alpha = 0.25 }
            x += size + spacing
        }
    }
    
    // MARK: - Axe
    private func updateAxe(charges: Int) {
        guard let hudBar = hudBar else { return }
        hudBar.childNode(withName: "axeContainer")?.removeFromParent()
        let axeContainer = SKNode(); axeContainer.name = "axeContainer"; hudBar.addChild(axeContainer)
        axeContainer.position = CGPoint(x: 0, y: bottomRowY + secondRowYOffset)
        let maxSlots = 4
        let size: CGFloat = 26
        let spacing: CGFloat = 8
        let texture = SKTexture(imageNamed: "ax.png")
        let useTexture = texture.size() != .zero
        let totalWidth = CGFloat(maxSlots) * size + CGFloat(maxSlots - 1) * spacing
        var x = -totalWidth/2 + size/2
        for i in 0..<maxSlots {
            let token = makeToken(size: size, color: UIColor.systemGray4, alpha: 0.9)
            token.position = CGPoint(x: x, y: 0)
            axeContainer.addChild(token)
            if i < charges {
                if useTexture { let s = SKSpriteNode(texture: texture); s.size = CGSize(width: 18, height: 18); s.zPosition = 2; token.addChild(s) }
                else { let l = SKLabelNode(text: "Ã°Å¸Âªâ€œ"); l.fontSize = 18; l.verticalAlignmentMode = .center; l.zPosition = 2; token.addChild(l) }
            } else { token.alpha = 0.25 }
            x += size + spacing
        }
    }
}
