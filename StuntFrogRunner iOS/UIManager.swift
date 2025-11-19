//
//  UIManager.swift
//  Top-down lily pad hopping UI with Glide Support
//

import SpriteKit
import UIKit
import GameKit
import QuartzCore

// Minimal definition to satisfy UI usage in this file
enum AbilityType: CaseIterable {
    case extraHeart
    case superJump
    case refillHearts
    case lifeVest
    case scrollSaver
    case flySwatter
    case honeyJar
    case rocket
    case axe
}

// MARK: - Super Power System
enum SuperPowerType: CaseIterable {
    case jumpRange
    case jumpRecoil
    case maxHealth
    case superJumpFocus
    case ghostMagic
    case impactJumps
    
    var name: String {
        switch self {
        case .jumpRange: return "Jump Range"
        case .jumpRecoil: return "Jump Speed"
        case .maxHealth: return "Max Health"
        case .superJumpFocus: return "Super Jump Longer"
        case .ghostMagic: return "Bust ghosts"
        case .impactJumps: return "Impact Jumps"
        }
    }
    
    var description: String {
        switch self {
        case .jumpRange: return "Jump farther"
        case .jumpRecoil: return "Jump faster"
        case .maxHealth: return "Permanent Max Heart increase (max 6)"
        case .superJumpFocus: return "Extend Super Jump Timer"
        case .ghostMagic: return "Destroy ghosts in your way"
        case .impactJumps: return "Jumps destroy enemies (limited per level)"
        }
    }
    
    var baseCost: Int {
        switch self {
        case .jumpRange: return 10
        case .jumpRecoil: return 20
        case .maxHealth: return 25
        case .superJumpFocus: return 40
        case .ghostMagic: return 50
        case .impactJumps: return 100
        }
    }
    
    var emoji: String {
        switch self {
        case .jumpRange: return "🦘"
        case .jumpRecoil: return "⚡"
        case .maxHealth: return "❤️"
        case .superJumpFocus: return "🎯"
        case .ghostMagic: return "👻"
        case .impactJumps: return "💥"
        }
    }
    
    var imageName: String {
        switch self {
        case .jumpRange: return "jumpRange.png"
        case .jumpRecoil: return "jumpRecoil.png"
        case .maxHealth: return "heartBoost.png"
        case .superJumpFocus: return "superJumpFocus.png"
        case .ghostMagic: return "ghostMagic.png"
        case .impactJumps: return "impactJumps.png"
        }
    }
    
    func effectDescription(level: Int) -> String {
        switch self {
        case .jumpRange:
            let percentage = level * 10
            return "+\(percentage)% jump distance"
        case .jumpRecoil:
            let reduction = level * 2
            return "-\(reduction)s jump speed"
        case .maxHealth:
            return "+\(level) max hearts"
        case .superJumpFocus:
            let extensionTime = level * 2
            return "+\(extensionTime)s super jump duration"
        case .ghostMagic:
            let escapes = level * 2
            return "\(escapes) ghost busts"
        case .impactJumps:
            let destroys = level * 3
            return "\(destroys) enemy destroys per level"
        }
    }
    
    func costForLevel(_ level: Int) -> Int {
        // Cost increases by base cost for each level
        return baseCost * level
    }
}

struct SuperPowerProgress {
    let type: SuperPowerType
    var level: Int = 0
    var isMaxed: Bool { 
        // Different max levels for different super powers
        let maxLevel = type == .maxHealth ? 6 : 10
        return level >= maxLevel
    }
    
    var nextLevelCost: Int {
        guard !isMaxed else { return 0 }
        return type.costForLevel(level + 1)
    }
}

extension AbilityType {
    static var allPowerUps: [AbilityType] { [.extraHeart, .superJump, .refillHearts, .lifeVest, .scrollSaver, .flySwatter, .honeyJar, .rocket, .axe] }

    var title: String {
        switch self {
        case .extraHeart: return "Extra Heart"
        case .superJump: return "Super Jump Power"
        case .refillHearts: return "Refill All Hearts"
        case .lifeVest: return "Life Vest"
        case .scrollSaver: return "Scroll Saver"
        case .flySwatter: return "Fly Swatter"
        case .honeyJar: return "Honey Jar"
        case .rocket: return "Rocket Boost"
        case .axe: return "Axe"
        }
    }

    var description: String {
        switch self {
        case .extraHeart: return "+1 Max Health & Heal"
        case .superJump: return "Temporary Jump Boost"
        case .refillHearts: return "Restore Full Health"
        case .lifeVest: return "Survive one water fall; jump to a pad"
        case .scrollSaver: return "Save yourself from scrolling off-screen once"
        case .flySwatter: return "Swat away one attacking enemy"
        case .honeyJar: return "Protect against one bee attack"
        case .rocket: return "Fly above all enemies for 10 seconds"
        case .axe: return "Chop down one log"
        }
    }

    var emoji: String {
        switch self {
        case .extraHeart: return "â¤ï¸"
        case .superJump: return "âš¡"
        case .refillHearts: return "ðŸ’š"
        case .lifeVest: return "ðŸ¦º"
        case .scrollSaver: return "â±"
        case .flySwatter: return "ðŸª°"
        case .honeyJar: return "ðŸ¯"
        case .rocket: return "ðŸš€"
        case .axe: return "ðŸª“"
        }
    }
    
    var imageName: String {
        switch self {
        case .extraHeart: return "heart.png" // extra heart icon
        case .superJump: return "lightning.png"
        case .refillHearts: return "refillHearts.png" // use provided asset name
        case .lifeVest: return "lifevest.png"
        case .scrollSaver: return "scroll.png"
        case .flySwatter: return "flySwatter.png"
        case .honeyJar: return "honeyPot.png"
        case .rocket: return "rocket.png"
        case .axe: return "ax.png"
        }
    }
}

class UIManager: NSObject {
    // Coins collected during the current session awaiting persistence
    var pendingTadpoleCoins: Int = 0

    // Set this to your App Store Connect leaderboard identifier
    var leaderboardID: String = "TopScores"
    
    // Touch interaction delay mechanism
    private var menuInteractionEnabledTime: TimeInterval = 0

    // UI Elements
    var scoreLabel: SKLabelNode?
    var tadpoleLabel: SKLabelNode?
    var healthIcons: [SKLabelNode] = []
    var pauseButton: SKLabelNode?
    
    // Super Powers System
    var tadpoleCoins: Int = 0 {
        didSet {
            updateTadpoleCoinsDisplay()
        }
    }
    var superPowers: [SuperPowerType: SuperPowerProgress] = [:]
    var superPowersMenu: SKNode?
    
    // Initialize super powers with default values
    private func initializeSuperPowers() {
        for powerType in SuperPowerType.allCases {
            superPowers[powerType] = SuperPowerProgress(type: powerType, level: 0)
        }
        
        // Add some debug coins if none exist (for testing)
        if tadpoleCoins == 0 {
            tadpoleCoins = 500 // Give some coins for testing
        }
    }
    
 
    
    // Power-up indicators
    var superJumpIndicator: SKLabelNode?
    var rocketIndicator: SKLabelNode?
    var glideIndicator: SKLabelNode?  // â¬…ï¸ CRITICAL: This must be declared!
    var rocketLandButton: SKNode?  // Button to land during rocket ride
    
    var starIconTop: SKLabelNode?
    var starProgressBGTop: SKShapeNode?
    var starProgressFillTop: SKShapeNode?
    
    // Menus
    var menuLayer: SKNode?
    var abilityLayer: SKNode?
    var tutorialModal: SKNode?
    
    weak var scene: SKScene?
    
    init(scene: SKScene) {
        print("🔧 UIManager.init: Starting initialization")
        self.scene = scene
        super.init()
        print("🔧 UIManager.init: Initializing super powers")
        initializeSuperPowers()
        print("🔧 UIManager.init: Loading super power progress")
        loadSuperPowerProgress()
        print("🔧 UIManager.init: Initialization complete")
    }
    
    deinit {
        print("🔧 UIManager.deinit: UIManager is being deallocated")
        
        // Stop all running actions on UI elements
        scoreLabel?.removeAllActions()
        healthIcons.forEach { $0.removeAllActions() }
        superJumpIndicator?.removeAllActions()
        rocketIndicator?.removeAllActions()
        glideIndicator?.removeAllActions()
        
        // Remove all UI elements from scene
        menuLayer?.removeFromParent()
        abilityLayer?.removeFromParent()
        tutorialModal?.removeFromParent()
        rocketLandButton?.removeFromParent()
        
        // Clear any remaining GameCenter delegate references
        if let presentedVC = topViewController()?.presentedViewController as? GKGameCenterViewController {
            presentedVC.gameCenterDelegate = nil
        }
        
        // Clear scene reference
        scene = nil
    }
    
    // MARK: - Haptics & Button Animations
    private func triggerTapHaptic() {
        // Use light impact for subtle feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func animateButtonPress(_ node: SKNode) {
        // Slight shrink to 0.95 with easeOut
        let press = SKAction.scale(to: 0.95, duration: 0.08)
        press.timingMode = .easeOut
        node.run(press, withKey: "pressScale")
        triggerTapHaptic()
    }

    func animateButtonRelease(_ node: SKNode) {
        // Return to normal scale with a tiny bounce
        let up1 = SKAction.scale(to: 1.02, duration: 0.10)
        up1.timingMode = .easeOut
        let up2 = SKAction.scale(to: 1.0, duration: 0.08)
        up2.timingMode = .easeIn
        node.run(SKAction.sequence([up1, up2]), withKey: "pressScale")
    }
    
    func setupUI(sceneSize: CGSize) {
        guard let scene = scene else { 
            print("⚠️ UIManager.setupUI: Scene is nil")
            return 
        }
        
        // Score label
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel?.fontSize = 18
        scoreLabel?.fontColor = UIColor.white
        scoreLabel?.fontName = "ArialRoundedMTBold"
        scoreLabel?.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        scoreLabel?.position = CGPoint(x: 20, y: sceneSize.height - 85)
        scoreLabel?.zPosition = 200
        if let scoreLabel = scoreLabel {
            scene.addChild(scoreLabel)
        }
        
        // Tadpole counter removed from top UI; handled elsewhere
        tadpoleLabel = nil
        
        // Pause button - use pause.png sprite instead of emoji
        let pauseTexture = SKTexture(imageNamed: "pause.png")
        if pauseTexture.size() != .zero {
            // Use PNG sprite
            let pauseSprite = SKSpriteNode(texture: pauseTexture)
            pauseSprite.size = CGSize(width: 32, height: 32)
            pauseSprite.name = "pauseButton"
            pauseSprite.position = CGPoint(x: sceneSize.width - 35, y: sceneSize.height - 85)
            pauseSprite.zPosition = 200
            scene.addChild(pauseSprite)
            // Store reference (though it's not a label, we keep the property name for compatibility)
            pauseButton = nil
        } else {
            // Fallback to emoji if PNG not available
            pauseButton = SKLabelNode(text: "⏸")
            pauseButton?.fontSize = 32
            pauseButton?.name = "pauseButton"
            pauseButton?.position = CGPoint(x: sceneSize.width - 35, y: sceneSize.height - 85)
            pauseButton?.zPosition = 200
            if let pauseButton = pauseButton {
                scene.addChild(pauseButton)
            }
        }
        
        // Star progress at top - replace emoji with star.png sprite
        let starTexture = SKTexture(imageNamed: "star.png")
        let starSprite = SKSpriteNode(texture: starTexture)
        // Size similar to prior label icon (~26pt height)
        let iconSize: CGFloat = 26
        starSprite.size = CGSize(width: iconSize, height: iconSize)
        starSprite.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        starSprite.position = CGPoint(x: 20, y: sceneSize.height - 120)
        starSprite.zPosition = 200
        scene.addChild(starSprite)
        // Keep a label reference nil; we now use a sprite
        starIconTop = nil

        let barWidth: CGFloat = sceneSize.width * 0.35
        let barSize = CGSize(width: barWidth, height: 14)
        let bg = SKShapeNode(rectOf: barSize, cornerRadius: 7)
        bg.fillColor = UIColor.white.withAlphaComponent(0.18)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.35)
        bg.lineWidth = 1.0
        // Align to the right of the star sprite with 8pt gap
        bg.position = CGPoint(x: starSprite.position.x + iconSize + 8 + barSize.width/2, y: starSprite.position.y)
        bg.zPosition = 200
        scene.addChild(bg)
        starProgressBGTop = bg

        // Fill starts near-zero width. We'll animate path updates in updateStarProgress
        let fillHeight = barSize.height - 4
        let fill = SKShapeNode(rectOf: CGSize(width: 1, height: fillHeight), cornerRadius: 5)
        fill.fillColor = .yellow
        fill.strokeColor = .clear
        fill.position = CGPoint(x: bg.position.x - (barSize.width/2) + 2 + 0.5, y: bg.position.y)
        fill.zPosition = 200
        scene.addChild(fill)
        starProgressFillTop = fill
    }
    
    func updateScore(_ score: Int) {
        scoreLabel?.text = "Score: \(score)"
    }
    
    func highlightScore(isHighScore: Bool) {
        if isHighScore {
            scoreLabel?.fontColor = UIColor.yellow
            scoreLabel?.run(SKAction.sequence([
                SKAction.scale(to: 1.25, duration: 0.15),
                SKAction.scale(to: 1.0, duration: 0.15)
            ]))
        } else {
            scoreLabel?.fontColor = UIColor.white
            scoreLabel?.removeAllActions()
            scoreLabel?.setScale(1.0)
        }
    }
    
    func updateTadpoles(_ count: Int) {
        // Bottom HUD owns star progress; no top label update needed
        tadpoleLabel?.isHidden = true
    }
    
    func updateStarProgress(current: Int, threshold: Int) {
        guard let bg = starProgressBGTop, let fill = starProgressFillTop, let scene = scene else { return }
        let clamped = min(max(CGFloat(current) / CGFloat(max(1, threshold)), 0.0), 1.0)
        let bgWidth = bg.frame.width
        let inset: CGFloat = 4
        let targetWidth = max(1, (bgWidth - inset) * clamped)
        let fillHeight = bg.frame.height - 4
        let newRect = CGRect(x: -targetWidth / 2, y: -fillHeight / 2, width: targetWidth, height: fillHeight)
        let newPath = CGPath(roundedRect: newRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        let bgLeftX = bg.position.x - (bgWidth / 2)
        let newCenterX = bgLeftX + 2 + targetWidth / 2
        
        let duration: TimeInterval = 0.18
        let pathAction = SKAction.customAction(withDuration: duration) { [weak fill] node, _ in
            guard let fill = fill, let shape = node as? SKShapeNode else { return }
            shape.path = newPath
        }
        pathAction.timingMode = SKActionTimingMode.easeOut
        
        let moveAction = SKAction.moveTo(x: newCenterX, duration: duration)
        moveAction.timingMode = SKActionTimingMode.easeOut
        fill.run(SKAction.group([pathAction, moveAction]))
    }
    
    func updateHealthDisplay(current: Int, max: Int) {
        guard let scene = scene else { return }
        
        healthIcons.forEach { $0.removeFromParent() }
        healthIcons.removeAll()
        
        for i in 0..<max {
            let heart = SKLabelNode(text: i < current ? "â¤ï¸" : "ðŸ¤")
            heart.fontSize = 20
            heart.position = CGPoint(x: 35 + CGFloat(i) * 35, y: 60)
            heart.zPosition = 200
            scene.addChild(heart)
            healthIcons.append(heart)
        }
    }
    
    // MARK: - Super Jump Indicator
    func showSuperJumpIndicator(sceneSize: CGSize) {
        // Prevent stacking multiple super jump indicators
        if let existing = superJumpIndicator, existing.parent != nil {
            return
        }
        
        guard let scene = scene else { return }
        
        let indicator = SKLabelNode(text: "SUPER JUMP!")
        indicator.fontSize = 24
        indicator.fontColor = .yellow
        indicator.fontName = "ArialRoundedMTBold"
        indicator.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 90)
        indicator.zPosition = 200
        
        // Pulsing effect
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        indicator.run(SKAction.repeatForever(pulse))
        
        scene.addChild(indicator)
        superJumpIndicator = indicator
    }
    
    func hideSuperJumpIndicator() {
        if let indicator = superJumpIndicator {
            indicator.removeAllActions()
            indicator.removeFromParent()
            superJumpIndicator = nil
        }
    }
    
    // MARK: - Rocket Indicator
    func showRocketIndicator(sceneSize: CGSize) {
        // Prevent stacking multiple rocket indicators
        if let existing = rocketIndicator, existing.parent != nil {
            return
        }
        
        guard let scene = scene else { return }
        
        let indicator = SKLabelNode(text: "ROCKET: 10s")
        indicator.fontSize = 24
        indicator.fontName = "ArialRoundedMTBold"
        indicator.fontColor = .orange
        indicator.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 140)
        indicator.zPosition = 200
        
        // Pulsing effect
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        indicator.run(SKAction.repeatForever(pulse))
        
        scene.addChild(indicator)
        rocketIndicator = indicator
    }
    
    func hideRocketIndicator() {
        if let indicator = rocketIndicator {
            indicator.removeAllActions()
            indicator.removeFromParent()
            rocketIndicator = nil
        }
    }
    
    // MARK: - Glide Indicator â¬…ï¸ NEW METHODS!
    func showGlideIndicator(sceneSize: CGSize, duration: Double) {
        // Prevent stacking multiple glide indicators
        if let existing = glideIndicator, existing.parent != nil {
            return
        }
        
        guard let scene = scene else { 
            print("⚠️ UIManager.showGlideIndicator: Scene is nil")
            return 
        }
        
        let indicator = SKLabelNode(text: String(format: "ðŸª‚ GLIDE: %.1fs", duration))
        indicator.fontSize = 28
        indicator.fontColor = .orange
        indicator.fontName = "ArialRoundedMTBold"
        indicator.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 180)
        indicator.zPosition = 200
        
        // Pulsing effect with urgency
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.25),
            SKAction.scale(to: 1.0, duration: 0.25)
        ])
        indicator.run(SKAction.repeatForever(pulse))
        
        scene.addChild(indicator)
        glideIndicator = indicator
    }
    
    func updateGlideIndicator(remainingTime: Double) {
        guard let indicator = glideIndicator else { return }
        
        indicator.text = String(format: "ðŸª‚ GLIDE: %.1fs", remainingTime)
        
        // Change color based on remaining time
        if remainingTime < 1.0 {
            indicator.fontColor = .red
        } else if remainingTime < 2.0 {
            indicator.fontColor = .yellow
        } else {
            indicator.fontColor = .orange
        }
    }
    
    func hideGlideIndicator() {
        if let indicator = glideIndicator {
            indicator.removeAllActions()
            indicator.removeFromParent()
            glideIndicator = nil
        }
    }
    
    func setUIVisible(_ visible: Bool) {
        pauseButton?.isHidden = !visible
        scoreLabel?.isHidden = !visible
        starIconTop?.isHidden = !visible
        starProgressBGTop?.isHidden = !visible
        starProgressFillTop?.isHidden = !visible
        
        // Keep temporary indicators in sync with HUD visibility
        superJumpIndicator?.isHidden = !visible
        rocketIndicator?.isHidden = !visible
        glideIndicator?.isHidden = !visible
        
        // Control bottom HUD visibility
        if let gameScene = scene as? GameScene {
            gameScene.hudController?.setHUDVisible(visible)
        }
        
        // When main UI is visible, menus should be hidden, and vice versa
        menuLayer?.isHidden = visible
        abilityLayer?.isHidden = visible
        superPowersMenu?.isHidden = visible
    }
    
    // MARK: - Menu Methods
    func showMainMenu(sceneSize: CGSize) {
        // Ensure any pending tadpole coins are saved before showing main menu
        savePendingTadpoleCoins()
        
        // Remove any existing menus to prevent stacking
        hideMenus()
        setUIVisible(false)
        
        // Reset interaction delay for main menu (it should be immediately interactive)
        menuInteractionEnabledTime = 0
        
        guard let scene = scene else { return }

        let menu = SKNode()
        menu.zPosition = 300
        menu.name = "menuLayer"

        // Title background image
        let titleTexture = SKTexture(imageNamed: "title.png")
        let titleBG = SKSpriteNode(texture: titleTexture)
        titleBG.name = "titleBackground"
        titleBG.zPosition = -1 // behind menu contents
        titleBG.position = CGPoint(x: sceneSize.width/2, y: sceneSize.height/2)
        // Scale to fill the screen while preserving aspect ratio
        let texSize = titleTexture.size()
        if texSize != .zero {
            let xScale = sceneSize.width / texSize.width
            let yScale = sceneSize.height / texSize.height
            let scale = max(xScale, yScale)
            titleBG.xScale = scale
            titleBG.yScale = scale
        } else {
            // Fallback size in case texture is missing
            titleBG.size = sceneSize
        }
        menu.addChild(titleBG)

        

        // Top-centered title text image (from titleText.svg in assets)
        let titleTextTexture = SKTexture(imageNamed: "titleText")
        if titleTextTexture.size() != .zero {
            let titleTextSprite = SKSpriteNode(texture: titleTextTexture)
            // Fit within 70% of the scene width, cap height to 180pt
            let maxWidth = sceneSize.width * 0.95
            let maxHeight: CGFloat = 600
            let texSize = titleTextTexture.size()
            let widthScale = maxWidth / texSize.width
            let heightScale = maxHeight / texSize.height
            let scale = min(widthScale, heightScale)
            titleTextSprite.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
            titleTextSprite.position = CGPoint(x: sceneSize.width/2, y: sceneSize.height - 340)
            titleTextSprite.zPosition = 1 // above backdrop/titleBG within menu
            menu.addChild(titleTextSprite)
        }

        // Button layout based on whether player can continue
        let scoreManager = ScoreManager.shared
        let canContinue = scoreManager.shouldContinueFromLastLevel()
        let maxLevel = scoreManager.getMaxCompletedLevel()
        
        if canContinue {
            // Show both level selector and "New Game" options
            let levelButtonSize = CGSize(width: sceneSize.width * 0.75, height: 55)
            let regularButtonSize = CGSize(width: sceneSize.width * 0.6, height: 48)
            
            // Calculate button positions with equal spacing, starting higher up
            let startY: CGFloat = 350  // Start higher than before
            let buttonSpacing: CGFloat = 56  // Equal spacing between all buttons
            
            var currentY = startY
            
            // Level selector button (primary action - largest)
            let levelSelectorButton = createButton(text: "Select Level to Play", name: "levelSelectorButton", size: levelButtonSize)
            levelSelectorButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(levelSelectorButton)
            
           
            
            currentY -= buttonSpacing
            
            // New Game button
            let newGameButton = createButton(text: "New Game", name: "newGameButton", size: regularButtonSize)
            newGameButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(newGameButton)
            
            currentY -= buttonSpacing
            
            // Leaderboard button
            let leaderboardButton = createButton(text: "Leaderboard", name: "leaderboardButton", size: regularButtonSize)
            leaderboardButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(leaderboardButton)
            
            currentY -= buttonSpacing
            
            // Tutorial button
            let tutorialButton = createButton(text: "Tutorial", name: "tutorialButton", size: regularButtonSize)
            tutorialButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(tutorialButton)
            
            currentY -= buttonSpacing
            
            // Super Powers button
            let superPowersButton = createButton(text: "Super Powers", name: "superPowersButton", size: regularButtonSize)
            superPowersButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(superPowersButton)
            
        } else {
            // Show single Play button for new players
            let playButtonSize = CGSize(width: sceneSize.width * 0.75, height: 60)
            let regularButtonSize = CGSize(width: sceneSize.width * 0.6, height: 48)
            
            // Calculate button positions with equal spacing, starting higher up
            let startY: CGFloat = 350  // Start higher than before
            let buttonSpacing: CGFloat = 56  // Equal spacing between all buttons
            
            var currentY = startY
            
            // Play button (primary action - largest)
            let playButton = createButton(text: "Play", name: "playGameButton", size: playButtonSize)
            playButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(playButton)
            
            currentY -= buttonSpacing
            
            // Leaderboard button
            let leaderboardButton = createButton(text: "Leaderboard", name: "leaderboardButton", size: regularButtonSize)
            leaderboardButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(leaderboardButton)
            
            currentY -= buttonSpacing
            
            // Tutorial button
            let tutorialButton = createButton(text: "Tutorial", name: "tutorialButton", size: regularButtonSize)
            tutorialButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(tutorialButton)
            
            currentY -= buttonSpacing
            
            // Super Powers button
            let superPowersButton = createButton(text: "Super Powers", name: "superPowersButton", size: regularButtonSize)
            superPowersButton.position = CGPoint(x: sceneSize.width/2, y: currentY)
            menu.addChild(superPowersButton)
        }

        // Assign and add
        menuLayer = menu
        scene.addChild(menu)
        
        // Ensure button taps (e.g., Leaderboard) are routed to Game Center
        enableButtonInput()
    }
    
    func showPauseMenu(sceneSize: CGSize) {
        hideMenus()
        // CRITICAL: Ensure tutorial modal is cleared
        tutorialModal = nil
        guard let scene = scene else { return }
        setUIVisible(false)
        
        let menu = SKNode()
        menu.zPosition = 300
        menu.name = "menuLayer"
        
        // Fullscreen dim background
        let bg = SKShapeNode(rectOf: sceneSize)
        bg.fillColor = UIColor.black.withAlphaComponent(0.85)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        menu.addChild(bg)
        
        // The center panel matching the UX (simpler than showMainMenu)
        let panelSize = CGSize(width: sceneSize.width * 0.8, height: sceneSize.height * 0.5)
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: panelSize.height/2)
        panel.fillColor = UIColor(red: 0.06, green: 0.35, blue: 0.3, alpha: 0.85) // Dark teal fill
        panel.strokeColor = UIColor.white.withAlphaComponent(0.5)
        panel.lineWidth = 2.5
        panel.position = CGPoint(x: sceneSize.width/2, y: sceneSize.height/2)
        menu.addChild(panel)
        
        // PAUSED Title (Styled as a small button)
        let titleButton = createButton(text: "PAUSED", name: "pausedTitle", size: CGSize(width: 150, height: 40))
        if let _ = titleButton.childNode(withName: "background") as? SKSpriteNode, let label = titleButton.childNode(withName: "label") as? SKLabelNode {
            label.fontColor = .white
            label.fontSize = 18
            titleButton.position = CGPoint(x: sceneSize.width / 2, y: panel.frame.maxY - 40)
        }
        menu.addChild(titleButton)
        
        let buttonSize = CGSize(width: 250, height: 65)
        
        // Continue Button
        let continueButton = createButton(text: "Continue", name: "continueButton", size: buttonSize)
        continueButton.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2 + 50)
        menu.addChild(continueButton)
        
        // Quit to Menu Button
        let quitButton = createButton(text: "Back to main menu", name: "quitButton", size: buttonSize)
        quitButton.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2 - 50)
        menu.addChild(quitButton)
        
        menuLayer = menu
        scene.addChild(menu)
    }
    
    func showGameOverMenu(sceneSize: CGSize, score: Int, highScore: Int, isNewHighScore: Bool, reason: GameOverReason) {
        // CRITICAL FIX: Save pending tadpole coins immediately when game is over
        savePendingTadpoleCoins()
        
        hideMenus()
        setUIVisible(false)
        guard let scene = scene else { return }
        
        let menu = SKNode()
        menu.zPosition = 300
        
        let bg = SKShapeNode(rectOf: sceneSize)
        bg.fillColor = UIColor.black.withAlphaComponent(0.92)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        menu.addChild(bg)
        
        // Determine title/subtitle based on game over reason
        let titleText: String
        let subtitleText: String
        switch reason {
        case .splash:
            titleText = "SPLASH!"
            subtitleText = "Missed the lily pad!"
        case .healthDepleted:
            titleText = "OUT OF HEARTS"
            subtitleText = "Your frog ran out of health."
        case .scrolledOffScreen:
            titleText = "Too Slow!"
            subtitleText = "You scrolled off the screen."
        case .tooSlow:
            titleText = "Too Slow!"
            subtitleText = "Keep up with the scroll!"
        case .timeUp:
            titleText = "TIME'S UP!"
            subtitleText = "You ran out of time!"
        }
        
        let title = SKLabelNode(text: titleText)
        title.fontSize = 32
        title.fontColor = UIColor.cyan
        title.fontName = "ArialRoundedMTBold"
        title.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 120)
        menu.addChild(title)
        
        let subtitle = SKLabelNode(text: subtitleText)
        subtitle.fontSize = 18
        subtitle.fontColor = UIColor.white
        subtitle.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 160)
        menu.addChild(subtitle)
        
        let scoreText = SKLabelNode(text: "Final Score: \(score)")
        scoreText.fontSize = 26
        scoreText.fontColor = UIColor.yellow
        scoreText.fontName = "ArialRoundedMTBold"
        scoreText.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 220)
        menu.addChild(scoreText)
        
        let highScoreText = SKLabelNode(text: "High Score: \(highScore)")
        highScoreText.fontSize = 20
        highScoreText.fontColor = UIColor.white
        highScoreText.fontName = "ArialRoundedMTBold"
        highScoreText.position = CGPoint(x: sceneSize.width / 2, y: scoreText.position.y - 35)
        menu.addChild(highScoreText)

        var buttonStartY = highScoreText.position.y - 80
        
        if isNewHighScore {
            let badge = SKLabelNode(text: "NEW HIGH SCORE!")
            badge.fontSize = 20
            badge.fontColor = UIColor.yellow
            badge.fontName = "ArialRoundedMTBold"
            badge.position = CGPoint(x: sceneSize.width / 2, y: highScoreText.position.y - 45)
            menu.addChild(badge)

            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.25),
                SKAction.scale(to: 1.0, duration: 0.25)
            ])
            badge.run(SKAction.repeatForever(pulse))
            
            buttonStartY = badge.position.y - 60
        }
        
        let buttonSize = CGSize(width: 300, height: 60)
        
        let tryAgainButton = createButton(text: "Try Again", name: "tryAgainButton", size: buttonSize)
        tryAgainButton.position = CGPoint(x: sceneSize.width / 2, y: buttonStartY)
        menu.addChild(tryAgainButton)
        
        let backButton = createButton(text: "Back to Menu", name: "backToMenuButton", size: buttonSize)
        backButton.position = CGPoint(x: sceneSize.width / 2, y: buttonStartY - 70)
        menu.addChild(backButton)
        
        menuLayer = menu
        scene.addChild(menu)
    }
    
    func showAbilitySelection(sceneSize: CGSize) {
        hideMenus()
        guard let scene = scene else { return }
        // Don't hide UI completely - we want the bottom HUD to remain visible
        // Only hide top UI elements
        pauseButton?.isHidden = true
        scoreLabel?.isHidden = true
        starIconTop?.isHidden = true
        starProgressBGTop?.isHidden = true
        starProgressFillTop?.isHidden = true
        
        // Keep temporary indicators visible but dimmed
        superJumpIndicator?.isHidden = true
        rocketIndicator?.isHidden = true
        glideIndicator?.isHidden = true
    
        self.presentAbilityMenu(sceneSize: sceneSize)
    }
    
    private func presentAbilityMenu(sceneSize: CGSize) {
        guard let scene = scene else { return }
        let menu = SKNode()
        menu.zPosition = 300
        menu.name = "abilityLayer"
        
        // Calculate menu height to leave space for bottom HUD (approximately 120pt from bottom)
        let hudHeight: CGFloat = 120
        let menuHeight = sceneSize.height - hudHeight
        
        menu.alpha = 1.0
        menu.position = CGPoint(x: 0, y: -menuHeight)
        
        // Add interaction delay to prevent touch carry-over from play button
        menuInteractionEnabledTime = CACurrentMediaTime() + 0.5
        
        // Create a smaller background that doesn't cover the bottom HUD
        let bg = SKShapeNode(rectOf: CGSize(width: sceneSize.width, height: menuHeight))
        bg.fillColor = UIColor.black.withAlphaComponent(0.0) // Start invisible
        bg.strokeColor = .clear
        bg.position = CGPoint(x: sceneSize.width / 2, y: menuHeight / 2)
        bg.name = "background"
        bg.zPosition = 0
        menu.addChild(bg)
        
        let title = SKLabelNode(text: "Choose Your Power-Up!")
        title.fontSize = 28
        title.fontColor = UIColor.yellow
        title.fontName = "ArialRoundedMTBold"
        title.position = CGPoint(x: sceneSize.width / 2, y: menuHeight - 80) // Adjust for smaller menu
        title.zPosition = 12
        menu.addChild(title)
        
        // Determine allowed abilities based on score using HUDConfigurable logic
        var abilities: [AbilityType] = []
        if let gs = scene as? GameScene {
            let currentScore = gs.score
            // Try to get allowed upgrades from HUD
            if let hud = gs.hudController as? HUDConfigurable {
                let allowedUpgradeTypes = hud.upgradeOptions(for: currentScore)
                // Map UpgradeType to AbilityType
                func mapUpgrade(_ u: UpgradeType) -> AbilityType? {
                    switch u {
                    case .honeypot: return .honeyJar
                    case .extraHeart: return .extraHeart
                    case .lifeVests: return .lifeVest
                    case .refillHearts: return .refillHearts
                    case .flySwatters: return .flySwatter
                    case .rockets: return .rocket
                    case .superJump: return .superJump
                    case .axe: return .axe
                    
                    }
                }
                var mapped: [AbilityType] = allowedUpgradeTypes.compactMap { mapUpgrade($0) }
                // Ensure Super Jump is always a potential option
                if !mapped.contains(.superJump) {
                    mapped.append(.superJump)
                }
                // Capacity-based filters (preserve existing logic)
                if gs.maxHealth >= 6 { mapped.removeAll { $0 == .extraHeart } }
                if gs.healthManager.health >= gs.healthManager.maxHealth { mapped.removeAll { $0 == .refillHearts } }
                if gs.frogController.lifeVestCharges >= 6 { mapped.removeAll { $0 == .lifeVest } }
                // Mirror-based checks for other charges (keep behavior)
                let mirror = Mirror(reflecting: gs)
                if let prop = mirror.children.first(where: { $0.label == "scrollSaverCharges" }), let count = prop.value as? Int, count >= 6 {
                    mapped.removeAll { $0 == .scrollSaver }
                }
                if let prop = mirror.children.first(where: { $0.label == "flySwatterCharges" }), let count = prop.value as? Int, count >= 6 {
                    mapped.removeAll { $0 == .flySwatter }
                }
                if let prop = mirror.children.first(where: { $0.label == "honeyJarCharges" }), let count = prop.value as? Int, count >= 6 {
                    mapped.removeAll { $0 == .honeyJar }
                }
                if let prop = mirror.children.first(where: { $0.label == "axeCharges" }), let count = prop.value as? Int, count >= 6 {
                    mapped.removeAll { $0 == .axe }
                }
                // If nothing remains (e.g., all capped), fall back to all power-ups
                if mapped.isEmpty { mapped = AbilityType.allPowerUps }
                abilities = Array(mapped.shuffled().prefix(2))
            }
        }
        // Fallback: if we couldn't compute from HUD/score, keep previous behavior
        if abilities.isEmpty {
            var allAbilities: [AbilityType] = AbilityType.allPowerUps
            if let gs = scene as? GameScene {
                if gs.maxHealth >= 6 { allAbilities.removeAll { $0 == .extraHeart } }
                if gs.healthManager.health >= gs.healthManager.maxHealth { allAbilities.removeAll { $0 == .refillHearts } }
                if gs.frogController.lifeVestCharges >= 6 { allAbilities.removeAll { $0 == .lifeVest } }
                let mirror = Mirror(reflecting: gs)
                if let prop = mirror.children.first(where: { $0.label == "scrollSaverCharges" }), let count = prop.value as? Int, count >= 6 {
                    allAbilities.removeAll { $0 == .scrollSaver }
                }
                if let prop = mirror.children.first(where: { $0.label == "flySwatterCharges" }), let count = prop.value as? Int, count >= 6 {
                    allAbilities.removeAll { $0 == .flySwatter }
                }
                if let prop = mirror.children.first(where: { $0.label == "honeyJarCharges" }), let count = prop.value as? Int, count >= 6 {
                    allAbilities.removeAll { $0 == .honeyJar }
                }
                if let prop = mirror.children.first(where: { $0.label == "axeCharges" }), let count = prop.value as? Int, count >= 6 {
                    allAbilities.removeAll { $0 == .axe }
                }
            }
            abilities = Array(allAbilities.shuffled().prefix(2))
        }
        
        for (index, ability) in abilities.enumerated() {
            let button = createAbilityButton(ability: ability, name: "ability_\(ability)")
            let baseY = menuHeight / 2 + 40 // Center vertically in the reduced menu height
            button.position = CGPoint(x: sceneSize.width / 2 - 20, y: baseY - CGFloat(index) * 120)
            menu.addChild(button)
        }
        
        // Slide up from bottom with background fading in, with touch protection during animation
        let duration: TimeInterval = 0.5
        let totalAnimationDuration = duration + 0.08 + 0.12 // slideUp + dip + settle
        
        // Update interaction delay to cover the full animation plus the initial delay
        menuInteractionEnabledTime = max(menuInteractionEnabledTime, CACurrentMediaTime() + totalAnimationDuration + 0.1)
        
        // Replace single slideUp action with bounce sequence:
        let slideUp = SKAction.moveTo(y: 8, duration: duration)
        slideUp.timingMode = .easeOut
        let dip = SKAction.moveTo(y: -4, duration: 0.08)
        dip.timingMode = .easeIn
        let settle = SKAction.moveTo(y: 0, duration: 0.12)
        settle.timingMode = .easeOut
        let sequence = SKAction.sequence([slideUp, dip, settle])
  
        // Background fade to target alpha over same duration
        if let background = menu.childNode(withName: "background") as? SKShapeNode {
            let targetAlpha: CGFloat = 0.92
            let bgFade = SKAction.customAction(withDuration: duration) { node, elapsed in
                let progress = max(0, min(1, elapsed / duration))
                if let shape = node as? SKShapeNode {
                    shape.fillColor = UIColor.black.withAlphaComponent(targetAlpha * progress)
                }
            }
            bgFade.timingMode = .easeOut
            background.run(bgFade)
        }
  
        menu.run(sequence)
        
        abilityLayer = menu
        scene.addChild(menu)
    }
    
    func showLevelSelectionModal(sceneSize: CGSize) {
        hideMenus()
        guard let scene = scene else { return }
        setUIVisible(false)
        
        let modal = SKNode()
        modal.zPosition = 400 // Higher than other menus
        modal.name = "levelSelectionModal"
        
        // Fullscreen dim background
        let bg = SKShapeNode(rectOf: sceneSize)
        bg.fillColor = UIColor.black.withAlphaComponent(0.85)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        bg.name = "levelSelectionBackground"
        modal.addChild(bg)
        
        // Modal panel
        let panelWidth = sceneSize.width * 0.85
        let panelHeight = sceneSize.height * 0.7
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 20)
        panel.fillColor = UIColor(red: 0.1, green: 0.15, blue: 0.3, alpha: 0.95)
        panel.strokeColor = UIColor.white.withAlphaComponent(0.5)
        panel.lineWidth = 2
        panel.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        modal.addChild(panel)
        
        // Title
        let title = SKLabelNode(text: "Select Level")
        title.fontSize = 28
        title.fontColor = UIColor.white
        title.fontName = "ArialRoundedMTBold"
        title.position = CGPoint(x: sceneSize.width / 2, y: panel.frame.maxY - 60)
        title.zPosition = 1
        modal.addChild(title)
        
        // Get current progress
        let scoreManager = ScoreManager.shared
        let maxLevel = scoreManager.getMaxCompletedLevel()
        
        // Create level buttons in a 3x3 grid
        let buttonsPerRow = 3
        let buttonSize = CGSize(width: 80, height: 80)
        let spacing: CGFloat = 30
        let totalWidth = CGFloat(buttonsPerRow) * buttonSize.width + CGFloat(buttonsPerRow - 1) * spacing
        let startX = sceneSize.width / 2 - totalWidth / 2 + buttonSize.width / 2
        let startY = panel.frame.midY + 50
        
        for level in 1...9 {
            let row = (level - 1) / buttonsPerRow
            let col = (level - 1) % buttonsPerRow
            
            let x = startX + CGFloat(col) * (buttonSize.width + spacing)
            let y = startY - CGFloat(row) * (buttonSize.height + spacing)
            
            let levelButton = createLevelButton(
                level: level,
                maxCompletedLevel: maxLevel,
                size: buttonSize
            )
            levelButton.position = CGPoint(x: x, y: y)
            modal.addChild(levelButton)
        }
        
        // Close button
        let closeButton = createButton(text: "Close", name: "closeLevelSelectionButton", size: CGSize(width: 120, height: 50))
        closeButton.position = CGPoint(x: sceneSize.width / 2, y: panel.frame.minY + 40)
        closeButton.zPosition = 1
        modal.addChild(closeButton)
        
        // Add fade-in animation with touch delay
        modal.alpha = 0.0
        
        // Set interaction delay (500ms from now)
        menuInteractionEnabledTime = CACurrentMediaTime() + 0.5
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        modal.run(fadeIn)
        
        menuLayer = modal
        scene.addChild(modal)
    }
    
    private func createLevelButton(level: Int, maxCompletedLevel: Int, size: CGSize) -> SKNode {
        let button = SKNode()
        button.name = "levelButton_\(level)"
        
        // Determine button state
        let isCompleted = level <= maxCompletedLevel
        let isNext = level == maxCompletedLevel + 1
        let isLocked = level > maxCompletedLevel + 1
        
        // Background color based on state
        let backgroundColor: UIColor
        let borderColor: UIColor
        let textColor: UIColor
        
        if isCompleted {
            backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 0.8) // Green for completed
            borderColor = UIColor.green
            textColor = UIColor.white
        } else if isNext {
            backgroundColor = UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.8) // Blue for next
            borderColor = UIColor.systemBlue
            textColor = UIColor.white
        } else {
            backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8) // Gray for locked
            borderColor = UIColor.gray
            textColor = UIColor.lightGray
        }
        
        // Button background
        let bg = SKShapeNode(rectOf: size, cornerRadius: 12)
        bg.fillColor = backgroundColor
        bg.strokeColor = borderColor
        bg.lineWidth = 2
        bg.name = "background"
        button.addChild(bg)
        
        // Level number
        let levelLabel = SKLabelNode(text: "\(level)")
        levelLabel.fontSize = 24
        levelLabel.fontColor = textColor
        levelLabel.fontName = "ArialRoundedMTBold"
        levelLabel.verticalAlignmentMode = .center
        levelLabel.position = CGPoint(x: 0, y: 8)
        button.addChild(levelLabel)
        
        // Status indicator
        var statusText = ""
        if isCompleted {
            statusText = "✓"
        } else if isNext {
            statusText = "▶"
        } else {
            statusText = "🔒"
        }
        
        let statusLabel = SKLabelNode(text: statusText)
        statusLabel.fontSize = 16
        statusLabel.fontColor = textColor
        statusLabel.verticalAlignmentMode = .center
        statusLabel.position = CGPoint(x: 0, y: -15)
        button.addChild(statusLabel)
        
        // Only make completed and next levels tappable
        if isCompleted || isNext {
            bg.name = "tapTarget"
            button.setScale(1.0)
        } else {
            button.alpha = 0.6
        }
        
        return button
    }
    
    func hideLevelSelectionModal() {
        if let modal = menuLayer, modal.name == "levelSelectionModal" {
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            let remove = SKAction.removeFromParent()
            modal.run(SKAction.sequence([fadeOut, remove]))
            menuLayer = nil
        }
    }
    
    func showTutorialModal(sceneSize: CGSize) {
        hideTutorialModal() // Remove any existing modal
        guard let scene = scene else { return }
        
        let modal = SKNode()
        modal.zPosition = 400 // Higher than other menus
        modal.name = "tutorialModal"
        
        // Fullscreen dim background
        let bg = SKShapeNode(rectOf: sceneSize)
        bg.fillColor = UIColor.black.withAlphaComponent(0.85)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        bg.name = "tutorialBackground"
        modal.addChild(bg)
        
        // Tutorial image
        let tutorialTexture = SKTexture(imageNamed: "tutorial.png")
        let tutorialImage = SKSpriteNode(texture: tutorialTexture)
        
        // Scale the image to fit nicely on screen while maintaining aspect ratio
        let maxWidth = sceneSize.width * 0.9
        let maxHeight = sceneSize.height * 0.75
        
        if tutorialTexture.size() != .zero {
            let texSize = tutorialTexture.size()
            let widthScale = maxWidth / texSize.width
            let heightScale = maxHeight / texSize.height
            let scale = min(widthScale, heightScale)
            tutorialImage.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
        } else {
            // Fallback size if image is missing
            tutorialImage.size = CGSize(width: maxWidth, height: maxHeight)
            tutorialImage.color = .gray
            tutorialImage.colorBlendFactor = 1.0
        }
        
        tutorialImage.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2 + 20)
        tutorialImage.zPosition = 1
        modal.addChild(tutorialImage)
        
        // Close button
        let closeButtonSize = CGSize(width: 120, height: 50)
        let closeButton = createButton(text: "Close", name: "closeTutorialButton", size: closeButtonSize)
        closeButton.position = CGPoint(x: sceneSize.width / 2, y: 80)
        closeButton.zPosition = 2
        modal.addChild(closeButton)
        
        // Add fade-in animation with touch delay
        modal.alpha = 0.0
        
        // Set interaction delay (500ms from now)
        menuInteractionEnabledTime = CACurrentMediaTime() + 0.5
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        modal.run(fadeIn)
        
        tutorialModal = modal
        scene.addChild(modal)
    }
    
    func hideTutorialModal() {
        if let modal = tutorialModal {
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            let remove = SKAction.removeFromParent()
            modal.run(SKAction.sequence([fadeOut, remove]))
            tutorialModal = nil
        }
    }
    
    func hideMenus() {
        menuLayer?.removeFromParent()
        abilityLayer?.removeFromParent()
        superPowersMenu?.removeFromParent()
        hideTutorialModal()
        hideLevelSelectionModal()
        menuLayer = nil
        abilityLayer = nil
        superPowersMenu = nil
        
        // Reset interaction delay when menus are hidden
        menuInteractionEnabledTime = 0
        
        // Restore all UI elements to visible
        pauseButton?.isHidden = false
        scoreLabel?.isHidden = false
        starIconTop?.isHidden = false
        starProgressBGTop?.isHidden = false
        starProgressFillTop?.isHidden = false
        
        // Restore temporary indicators if they were active
        superJumpIndicator?.isHidden = false
        rocketIndicator?.isHidden = false
        glideIndicator?.isHidden = false
        
        // Ensure bottom HUD stays visible
        if let gameScene = scene as? GameScene {
            gameScene.hudController?.setHUDVisible(true)
        }
    }
    
    private func createButton(text: String, name: String, size: CGSize = CGSize(width: 300, height: 60)) -> SKNode {
        let button = SKNode()
        button.name = name

        // Use button.png as the background image for all buttons
        let texture = SKTexture(imageNamed: "button.png")
        let bg = SKSpriteNode(texture: texture)
        bg.name = "background"
        bg.size = size
        bg.zPosition = 1
        button.addChild(bg)

        // Centered label on top
        let label = SKLabelNode(text: text)
        label.name = "label"
        label.fontSize = 20
        label.fontColor = UIColor.white
        label.fontName = "ArialRoundedMTBold"
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        button.addChild(label)

        // Add invisible tap target that covers the entire button area
        let tapTarget = SKSpriteNode(color: .clear, size: CGSize(width: size.width + 20, height: size.height + 20))
        tapTarget.name = "tapTarget"
        tapTarget.zPosition = 10 // Highest z-position to catch taps first
        button.addChild(tapTarget)

        // Mark tappable area and default scale for animations
        button.setScale(1.0)

        return button
    }
    
    private func createAbilityButton(ability: AbilityType, name: String) -> SKNode {
        let button = SKNode()
        button.name = name
        
        let bg = SKShapeNode(rectOf: CGSize(width: 360, height: 95), cornerRadius: 12)
        bg.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0)
        bg.strokeColor = UIColor.yellow
        bg.lineWidth = 4
        bg.zPosition = 10
        button.addChild(bg)
        
        
        // Use PNG sprite for ability icon with emoji fallback
        let iconTexture = SKTexture(imageNamed: ability.imageName)
        if iconTexture.size() != .zero {
            // Use PNG sprite
            let iconSprite = SKSpriteNode(texture: iconTexture)
            iconSprite.size = CGSize(width: 45, height: 45)
            iconSprite.position = CGPoint(x: -130, y: 0)
            iconSprite.zPosition = 11
            button.addChild(iconSprite)
        } else {
            // Fallback to emoji if PNG not available
            let emoji = SKLabelNode(text: ability.emoji)
            emoji.fontSize = 45
            emoji.position = CGPoint(x: -130, y: 0)
            emoji.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
            emoji.zPosition = 11
            button.addChild(emoji)
        }
        
        let titleLabel = SKLabelNode(text: ability.title)
        titleLabel.fontSize = 19
        titleLabel.fontColor = UIColor.white
        titleLabel.fontName = "ArialRoundedMTBold"
        titleLabel.position = CGPoint(x: -40, y: 18)
        titleLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        titleLabel.zPosition = 12
        button.addChild(titleLabel)
        
        let maxTextWidth: CGFloat = 220
        let wrapped = makeWrappedLabel(
            text: ability.description,
            fontName: "ArialRoundedMTBold",
            fontSize: 15,
            color: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),
            maxWidth: maxTextWidth,
            lineSpacing: 2,
            horizontalAlignment: .left
        )
        wrapped.position = CGPoint(x: -40, y: -18)
        wrapped.zPosition = 12
        button.addChild(wrapped)
        
        // Prepare for tap animations
        button.setScale(1.0)
        bg.name = "tapTarget"

        return button
    }

    private func makeWrappedLabel(text: String, fontName: String? = "ArialRoundedMTBold", fontSize: CGFloat, color: UIColor, maxWidth: CGFloat, lineSpacing: CGFloat = 4, horizontalAlignment: SKLabelHorizontalAlignmentMode = .left) -> SKNode {
        let container = SKNode()
        let words = text.split(separator: " ")
        var currentLine = ""
        var lines: [String] = []
        
        func width(of string: String) -> CGFloat {
            let probe = SKLabelNode(text: string.isEmpty ? " " : string)
            probe.fontName = fontName
            probe.fontSize = fontSize
            return probe.frame.width
        }
        
        for word in words {
            let tentative = currentLine.isEmpty ? String(word) : currentLine + " " + word
            if width(of: tentative) <= maxWidth {
                currentLine = tentative
            } else {
                if !currentLine.isEmpty { lines.append(currentLine) }
                currentLine = String(word)
            }
        }
        if !currentLine.isEmpty { lines.append(currentLine) }
        
        for (i, line) in lines.enumerated() {
            let label = SKLabelNode(text: line)
            label.fontName = fontName
            label.fontSize = fontSize
            label.fontColor = color
            label.horizontalAlignmentMode = horizontalAlignment
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -CGFloat(i) * (fontSize + lineSpacing))
            container.addChild(label)
        }
        
        return container
    }

    func playHoneyJarEffect(at position: CGPoint) {
        guard let scene = scene else { return }

        let splat = SKLabelNode(text: "ðŸ¯")
        splat.fontSize = 54
        splat.position = position
        splat.zPosition = 500
        splat.alpha = 0.0
        scene.addChild(splat)

        let drip1 = SKLabelNode(text: "â€¢")
        drip1.fontSize = 20
        drip1.fontColor = .yellow
        drip1.position = CGPoint(x: position.x - 10, y: position.y - 8)
        drip1.alpha = 0.0
        drip1.zPosition = 499
        scene.addChild(drip1)

        let drip2 = SKLabelNode(text: "â€¢")
        drip2.fontSize = 16
        drip2.fontColor = .yellow
        drip2.position = CGPoint(x: position.x + 12, y: position.y - 14)
        drip2.alpha = 0.0
        drip2.zPosition = 499
        scene.addChild(drip2)

        let appear = SKAction.group([
            SKAction.fadeAlpha(to: 1.0, duration: 0.06),
            SKAction.scale(to: 1.15, duration: 0.08)
        ])
        appear.timingMode = SKActionTimingMode.easeOut

        let settle = SKAction.scale(to: 1.0, duration: 0.08)
        settle.timingMode = SKActionTimingMode.easeIn

        let wait = SKAction.wait(forDuration: 0.35)
        let fade = SKAction.fadeOut(withDuration: 0.18)
        let remove = SKAction.removeFromParent()

        splat.run(SKAction.sequence([appear, settle, wait, fade, remove]))

        let dripAppear = SKAction.fadeAlpha(to: 1.0, duration: 0.06)
        drip1.run(SKAction.sequence([dripAppear, wait, fade, remove]))
        drip2.run(SKAction.sequence([dripAppear, wait, fade, remove]))
    }

    func playAxeChopEffect(at position: CGPoint, direction: CGFloat) {
        guard let scene = scene else { return }

        let slash = SKLabelNode(text: "â€”")
        slash.fontName = "ArialRoundedMTBold"
        slash.fontSize = 60
        slash.fontColor = .white
        slash.position = position
        slash.zPosition = 500
        slash.alpha = 0.0
        slash.zRotation = direction
        scene.addChild(slash)

        let axe = SKLabelNode(text: "ðŸª“")
        axe.fontSize = 42
        axe.position = position
        axe.zPosition = 501
        axe.alpha = 0.0
        scene.addChild(axe)

        let dx: CGFloat = cos(direction) * 18
        let dy: CGFloat = sin(direction) * 18

        let appear = SKAction.group([
            SKAction.fadeAlpha(to: 1.0, duration: 0.05),
            SKAction.scale(to: 1.1, duration: 0.08)
        ])
        appear.timingMode = SKActionTimingMode.easeOut

        let moveAxe = SKAction.moveBy(x: dx, y: dy, duration: 0.08)
        moveAxe.timingMode = SKActionTimingMode.easeOut

        let settle = SKAction.group([
            SKAction.scale(to: 0.98, duration: 0.05),
            SKAction.fadeAlpha(to: 0.0, duration: 0.15)
        ])
        settle.timingMode = SKActionTimingMode.easeIn

        let remove = SKAction.removeFromParent()

        slash.run(SKAction.sequence([appear, settle, remove]))
        axe.run(SKAction.sequence([appear, moveAxe, settle, remove]))
    }
    
    // MARK: - Game Center Leaderboard
    
    // MARK: - Level Selection Methods
    
    /// Presents an iOS dropdown (UIAlertController) allowing the user to select which level to play (1-9).
    /// The selected level is stored in UserDefaults with key "selectedStartLevel" and a notification is posted.
    func presentLevelSelector(maxLevel: Int) {
        // Ensure we're on the main thread and add safety checks
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showLevelSelectorAlert(maxLevel: maxLevel)
        }
    }
    
    private func showLevelSelectorAlert(maxLevel: Int) {
        guard let rootVC = topViewController() else { 
            print("❌ Could not find root view controller for level selector")
            return 
        }
        
        print("🎮 Presenting level selector with maxLevel: \(maxLevel)")
        
        let alertController = UIAlertController(
            title: "Select Level", 
            message: "Choose which level to play (1-9)", 
            preferredStyle: .actionSheet
        )
        
        // Add level options (1 through maxLevel + 1, since they can play the next level, but cap at 9)
        let availableLevels = min(maxLevel + 1, 9)
        
        for level in 1...availableLevels {
            let title: String
            if level <= maxLevel {
                title = "Level \(level) ✓"  // Completed levels show checkmark
            } else {
                title = "Level \(level) (Next)"  // Next available level
            }
            
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                print("🎮 Selected level \(level)")
                self?.startGameAtLevel(level)
            }
            alertController.addAction(action)
        }
        
        // Add separator and option to play beyond completed levels if maxLevel < 9
        if maxLevel < 9 {
            // Add levels beyond the current progress (locked levels)
            for level in (maxLevel + 2)...9 {
                let title = "Level \(level) 🔒"  // Locked levels
                let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                    print("🎮 Selected locked level \(level)")
                    self?.confirmPlayAheadToLevel(level, from: rootVC)
                }
                alertController.addAction(action)
            }
        }
        
        // Add cancel option
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            print("🎮 Level selection cancelled")
        }
        alertController.addAction(cancelAction)
        
        // Configure for iPad popover
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = [.up, .down]
        }
        
        rootVC.present(alertController, animated: true) {
            print("✅ Level selector presented successfully")
        }
    }
    
    private func confirmPlayAheadToLevel(_ level: Int, from viewController: UIViewController) {
        let alertController = UIAlertController(
            title: "Play Ahead?", 
            message: "This will start you at Level \(level), skipping earlier levels. You won't unlock achievements for skipped levels. Continue?",
            preferredStyle: .alert
        )
        
        let playAction = UIAlertAction(title: "Play Level \(level)", style: .default) { [weak self] _ in
            self?.startGameAtLevel(level)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(playAction)
        alertController.addAction(cancelAction)
        
        viewController.present(alertController, animated: true)
    }
    
    private func startGameAtLevel(_ level: Int) {
        print("🎮 Starting game at level \(level)")
        
        // Store the selected level for the game to use
        UserDefaults.standard.set(level, forKey: "selectedStartLevel")
        UserDefaults.standard.synchronize()
        
        // Hide menus and show game UI
        hideMenus()
        hideLevelSelectionModal()
        setUIVisible(true)
        
        // Post a notification that the game should start at a specific level
        NotificationCenter.default.post(name: NSNotification.Name("StartGameAtLevel"), object: level)
        
        print("🎮 Level \(level) selection stored and notification posted")
    }
    
    // MARK: - GameScene Integration Helpers
    
    /// Call this from GameScene to check if a specific level was selected and retrieve it.
    /// This method automatically clears the stored selection after reading it.
    /// - Returns: The selected level (1-9) or nil if no specific level was selected
    static func getAndClearSelectedStartLevel() -> Int? {
        let defaults = UserDefaults.standard
        let selectedLevel = defaults.object(forKey: "selectedStartLevel") as? Int
        
        if selectedLevel != nil {
            // Clear the selection so it doesn't affect future games
            defaults.removeObject(forKey: "selectedStartLevel")
            defaults.synchronize()
            print("🎮 Retrieved selected start level: \(selectedLevel!) (now cleared)")
        }
        
        return selectedLevel
    }
    
    /// Call this from GameScene to check if a specific level was selected without clearing it.
    /// - Returns: The selected level (1-9) or nil if no specific level was selected
    static func peekSelectedStartLevel() -> Int? {
        return UserDefaults.standard.object(forKey: "selectedStartLevel") as? Int
    }
    
    func presentLeaderboard(leaderboardID: String) {
        // Ensure Game Center operations happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🎮 Attempting to present leaderboard: \(leaderboardID)")
            
            // Authenticate if needed, then present
            if GKLocalPlayer.local.isAuthenticated {
                print("✅ Player already authenticated, presenting leaderboard")
                self.presentLeaderboardView(leaderboardID: leaderboardID)
            } else {
                print("🔐 Player not authenticated, starting authentication")
                GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if let vc = vc {
                            print("📱 Presenting authentication view controller")
                            self.present(viewController: vc)
                        } else if GKLocalPlayer.local.isAuthenticated {
                            print("✅ Authentication successful, presenting leaderboard")
                            self.presentLeaderboardView(leaderboardID: leaderboardID)
                        } else {
                            print("❌ Game Center authentication failed: \(error?.localizedDescription ?? "unknown error")")
                            #if DEBUG
                            // Show a user-friendly message in debug builds
                            let alert = UIAlertController(
                                title: "Game Center Unavailable", 
                                message: "Please sign in to Game Center in Settings to view leaderboards.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(viewController: alert)
                            #endif
                        }
                    }
                }
            }
        }
    }

    private func presentLeaderboardView(leaderboardID: String) {
        // Ensure this runs on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🏆 Creating Game Center leaderboard view for ID: \(leaderboardID)")
            
            let gcVC = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
            gcVC.gameCenterDelegate = self
            
            self.present(viewController: gcVC)
        }
    }

    private func present(viewController: UIViewController) {
        // Ensure presentation happens on main thread
        if Thread.isMainThread {
            guard let rootVC = topViewController() else { 
                print("❌ Could not find root view controller to present leaderboard")
                return 
            }
            rootVC.present(viewController, animated: true)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.present(viewController: viewController)
            }
        }
    }

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseViewController: UIViewController?
        
        if let base = base {
            baseViewController = base
        } else {
            // Thread-safe way to get the root view controller
            if Thread.isMainThread {
                // Try multiple approaches to find the key window safely
                var keyWindow: UIWindow?
                
                // iOS 15+ approach
                if #available(iOS 15.0, *) {
                    keyWindow = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first { $0.isKeyWindow }
                }
                
                // Fallback for iOS 13-14
                if keyWindow == nil {
                    keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
                }
                
                // Final fallback - get any window
                if keyWindow == nil {
                    if #available(iOS 15.0, *) {
                        keyWindow = UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .flatMap { $0.windows }
                            .first
                    } else {
                        keyWindow = UIApplication.shared.windows.first
                    }
                }
                
                guard let window = keyWindow else {
                    print("⚠️ Could not find any window")
                    return nil
                }
                
                baseViewController = window.rootViewController
            } else {
                // If not on main thread, dispatch to main thread and return nil for now
                print("⚠️ topViewController called from background thread")
                return nil
            }
        }
        
        guard let rootVC = baseViewController else {
            return nil
        }
        
        if let nav = rootVC as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = rootVC as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = rootVC.presentedViewController {
            return topViewController(base: presented)
        }
        return rootVC
    }

    // MARK: - Rocket Land Button
    func showRocketLandButton(sceneSize: CGSize) {
        guard let scene = scene, rocketLandButton == nil else { return }
        
        let button = createButton(text: "LAND", name: "rocketLandButton", size: CGSize(width: 180, height: 60))
        // Position below the middle of the screen
        button.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2 - 120)
        button.zPosition = 250
        
        // Add a subtle pulsing animation to attract attention
        let scaleUp = SKAction.scale(to: 1.08, duration: 0.6)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.6)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        button.run(SKAction.repeatForever(pulse))
        
        rocketLandButton = button
        scene.addChild(button)
    }
    
    func hideRocketLandButton() {
        rocketLandButton?.removeAllActions()
        rocketLandButton?.removeFromParent()
        rocketLandButton = nil
        // Also hide the rocket timer text when landing
        hideRocketIndicator()
    }

    // MARK: - Super Powers Menu
    
    func showSuperPowersMenu(sceneSize: CGSize) {
        hideMenus()
        setUIVisible(false)
        
        // Create and present the UIKit-based Super Powers modal
        presentSuperPowersViewController()
    }
    
    private func presentSuperPowersViewController() {
        let superPowersVC = SuperPowersViewController()
        superPowersVC.uiManager = self
        superPowersVC.modalPresentationStyle = .overFullScreen
        superPowersVC.modalTransitionStyle = .crossDissolve
        
        guard let rootVC = topViewController() else { 
            print("❌ Could not find root view controller to present super powers modal")
            return 
        }
        
        print("🚀 Presenting Super Powers modal with \(SuperPowerType.allCases.count) super powers")
        print("💰 Current tadpole coins: \(tadpoleCoins)")
        
        rootVC.present(superPowersVC, animated: true) {
            print("✅ Super Powers modal presented successfully")
        }
    }
    
    private func createTadpoleCoinsDisplay() -> SKNode {
        let container = SKNode()
        container.name = "tadpoleCoinsDisplay"
        
        // Tadpole icon
        let tadpoleTexture = SKTexture(imageNamed: "tadpole.png")
        let tadpoleIcon: SKNode
        
        if tadpoleTexture.size() != .zero {
            let sprite = SKSpriteNode(texture: tadpoleTexture)
            sprite.size = CGSize(width: 24, height: 24)
            tadpoleIcon = sprite
        } else {
            let emoji = SKLabelNode(text: "🐸")
            emoji.fontSize = 24
            emoji.verticalAlignmentMode = .center
            tadpoleIcon = emoji
        }
        
        tadpoleIcon.position = CGPoint(x: -60, y: 0)
        container.addChild(tadpoleIcon)
        
        // Coins label
        let coinsLabel = SKLabelNode(text: "\(tadpoleCoins)")
        coinsLabel.name = "coinsLabel"
        coinsLabel.fontSize = 24
        coinsLabel.fontColor = .white
        coinsLabel.fontName = "ArialRoundedMTBold"
        coinsLabel.horizontalAlignmentMode = .left
        coinsLabel.verticalAlignmentMode = .center
        coinsLabel.position = CGPoint(x: -30, y: 0)
        container.addChild(coinsLabel)
        
        // "Tadpole Coins" text
        let titleLabel = SKLabelNode(text: "Tadpole Coins")
        titleLabel.fontSize = 16
        titleLabel.fontColor = UIColor.white.withAlphaComponent(0.8)
        titleLabel.fontName = "ArialRoundedMTBold"
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 20, y: 0)
        container.addChild(titleLabel)
        
        return container
    }
    
    private func createStyledTadpoleCoinsDisplay() -> SKNode {
        let container = SKNode()
        container.name = "tadpoleCoinsDisplay"
        
        // Felt tag background
        let tagWidth: CGFloat = 200
        let tag = SKShapeNode(rectOf: CGSize(width: tagWidth, height: 35), cornerRadius: 6)
        tag.fillColor = UIColor(red: 0.7, green: 0.5, blue: 0.2, alpha: 0.9) // Brown felt
        tag.strokeColor = UIColor.white.withAlphaComponent(0.7)
        tag.lineWidth = 1.5
        container.addChild(tag)
        
        // Add subtle stitching effect with small dashes
        let stitchContainer = SKNode()
        let stitchRect = CGRect(x: -95, y: -15, width: 190, height: 30)
        let dashLength: CGFloat = 3
        let gapLength: CGFloat = 2
        let perimeter = 2 * (stitchRect.width + stitchRect.height)
        let dashCount = Int(perimeter / (dashLength + gapLength))
        
        for i in 0..<dashCount {
            let progress = CGFloat(i) / CGFloat(dashCount)
            let dash = SKShapeNode(rectOf: CGSize(width: dashLength, height: 1))
            dash.fillColor = UIColor.white.withAlphaComponent(0.6)
            dash.strokeColor = .clear
            
            // Position dash along the rectangle perimeter
            let side = progress * 4.0 // 4 sides
            if side < 1.0 { // Top side
                dash.position = CGPoint(x: -95 + side * 190, y: 15)
            } else if side < 2.0 { // Right side
                dash.position = CGPoint(x: 95, y: 15 - (side - 1.0) * 30)
                dash.zRotation = .pi / 2
            } else if side < 3.0 { // Bottom side
                dash.position = CGPoint(x: 95 - (side - 2.0) * 190, y: -15)
            } else { // Left side
                dash.position = CGPoint(x: -95, y: -15 + (side - 3.0) * 30)
                dash.zRotation = .pi / 2
            }
            
            stitchContainer.addChild(dash)
        }
        container.addChild(stitchContainer)
        
        // Coins display with star icon
        let coinsContainer = SKNode()
        coinsContainer.name = "coinsLabel"
        
        // Star icon
        let starTexture = SKTexture(imageNamed: "star.png")
        let starSprite = SKSpriteNode(texture: starTexture)
        starSprite.size = CGSize(width: 18, height: 18)
        starSprite.position = CGPoint(x: -80, y: 0)
        coinsContainer.addChild(starSprite)
        
        // Coins text
        let coinsText = SKLabelNode(text: "[\(tadpoleCoins) Tadpole Coins]")
        coinsText.fontSize = 18
        coinsText.fontColor = UIColor.white
        coinsText.fontName = "ArialRoundedMTBold"
        coinsText.horizontalAlignmentMode = .left
        coinsText.verticalAlignmentMode = .center
        coinsText.position = CGPoint(x: -65, y: 0)
        coinsContainer.addChild(coinsText)
        
        container.addChild(coinsContainer)
        
        return container
    }
    
    private func createStyledSuperPowerItem(power: SuperPowerProgress, sceneSize: CGSize) -> SKNode {
        let container = SKNode()
        container.name = "superPower_\(power.type)"
        container.zPosition = 301 // Ensure container is above other elements
        
        let itemWidth = sceneSize.width * 0.92
        let itemHeight: CGFloat = 70
        
        print("🔧 Creating super power item: \(power.type.name) (Level \(power.level))")
        print("  - Container name: \(container.name ?? "nil")")
        print("  - Item width: \(itemWidth), height: \(itemHeight)")
        
        // Separator line at top - positioned relative to container center
        let separator = SKShapeNode(rectOf: CGSize(width: itemWidth * 0.9, height: 1))
        separator.fillColor = UIColor.white.withAlphaComponent(0.3)
        separator.strokeColor = .clear
        separator.position = CGPoint(x: 0, y: 25) // Centered horizontally, top of item
        separator.zPosition = 1
        container.addChild(separator)
        
        // Status indicator dot - positioned relative to container center
        let statusDot = SKShapeNode(circleOfRadius: 4)
        statusDot.fillColor = power.isMaxed ? .green : (power.level > 0 ? .orange : .gray)
        statusDot.strokeColor = .white
        statusDot.lineWidth = 1
        statusDot.position = CGPoint(x: -itemWidth/2 + 30, y: 0) // Left side with margin
        statusDot.zPosition = 1
        container.addChild(statusDot)
        
        // Power icon - positioned relative to container center
        let iconTexture = SKTexture(imageNamed: power.type.imageName)
        let icon: SKNode
        
        if iconTexture.size() != .zero {
            let sprite = SKSpriteNode(texture: iconTexture)
            sprite.size = CGSize(width: 28, height: 28)
            icon = sprite
            print("  - Using PNG icon: \(power.type.imageName)")
        } else {
            // Create a colored rectangle placeholder instead of emoji
            let placeholderSize = CGSize(width: 28, height: 28)
            let placeholder = SKShapeNode(rectOf: placeholderSize, cornerRadius: 4)
            placeholder.fillColor = .systemBlue
            placeholder.strokeColor = .white
            placeholder.lineWidth = 1
            
            // Add abbreviated text
            let abbreviation: String
            switch power.type {
            case .jumpRange: abbreviation = "JR"
            case .jumpRecoil: abbreviation = "JRC"
            case .maxHealth: abbreviation = "HP"
            case .superJumpFocus: abbreviation = "SJ"
            case .ghostMagic: abbreviation = "GM"
            case .impactJumps: abbreviation = "IJ"
            }
            
            let label = SKLabelNode(text: abbreviation)
            label.fontSize = 10
            label.fontColor = .white
            label.fontName = "ArialRoundedMTBold"
            label.verticalAlignmentMode = .center
            placeholder.addChild(label)
            
            icon = placeholder
            print("  - Using placeholder for missing icon: \(power.type.imageName)")
        }
        
        icon.position = CGPoint(x: -itemWidth/2 + 60, y: 0) // After status dot
        icon.zPosition = 1
        container.addChild(icon)
        
        // Power name and level - positioned relative to container center
        let titleText = power.isMaxed ? "\(power.type.name) MAX" : "\(power.type.name) Lv.\(power.level)"
        let title = SKLabelNode(text: titleText)
        title.fontSize = 18
        title.fontColor = power.isMaxed ? .green : .white
        title.fontName = "ArialRoundedMTBold"
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -itemWidth/2 + 90, y: 8) // After icon, upper text
        title.zPosition = 1
        container.addChild(title)
        print("  - Title: '\(titleText)' at position \(title.position)")
        
        // Effect description - positioned relative to container center
        let effectDesc = power.type.effectDescription(level: max(1, power.level))
        let description = SKLabelNode(text: effectDesc)
        description.fontSize = 14
        description.fontColor = UIColor.white.withAlphaComponent(0.8)
        description.fontName = "ArialRoundedMTBold"
        description.horizontalAlignmentMode = .left
        description.verticalAlignmentMode = .center
        description.position = CGPoint(x: -itemWidth/2 + 90, y: -12) // Same x as title, lower text
        description.zPosition = 1
        container.addChild(description)
        print("  - Description: '\(effectDesc)' at position \(description.position)")
        
        // Cost and upgrade button (if not maxed) - positioned relative to container center
        if !power.isMaxed {
            let cost = power.nextLevelCost
            let canAfford = tadpoleCoins >= cost
            
            // Cost display with star icon
            let costContainer = SKNode()
            
            // Cost text
            let costText = "Cost: \(cost) "
            let costLabel = SKLabelNode(text: costText)
            costLabel.fontSize = 14
            costLabel.fontColor = canAfford ? .yellow : .red
            costLabel.fontName = "ArialRoundedMTBold"
            costLabel.horizontalAlignmentMode = .right
            costLabel.verticalAlignmentMode = .center
            costLabel.position = CGPoint(x: itemWidth/2 - 140, y: 8)
            costLabel.zPosition = 1
            container.addChild(costLabel)
            
            // Star icon
            let starTexture = SKTexture(imageNamed: "star.png")
            let starSprite = SKSpriteNode(texture: starTexture)
            starSprite.size = CGSize(width: 14, height: 14)
            starSprite.position = CGPoint(x: itemWidth/2 - 120, y: 8)
            starSprite.zPosition = 1
            container.addChild(starSprite)
            
            // Styled upgrade button
            let buttonText = canAfford ? "UPGRADE" : "NEED MORE"
            let upgradeButton = createStyledButton(
                text: buttonText,
                name: "upgrade_\(power.type)",
                size: CGSize(width: 100, height: 28),
                color: canAfford ? UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 0.9) : UIColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 0.9)
            )
            upgradeButton.position = CGPoint(x: itemWidth/2 - 50, y: -12) // Right side, lower position
            upgradeButton.zPosition = 1
            
            // Disable button if can't afford
            if !canAfford {
                upgradeButton.alpha = 0.6
            }
            
            container.addChild(upgradeButton)
            print("  - Cost: \(cost), Can afford: \(canAfford), Button: '\(buttonText)'")
        } else {
            print("  - Power is maxed, no upgrade button")
        }
        
        print("  - Container children count: \(container.children.count)")
        return container
    }
    
    private func createStyledButton(text: String, name: String, size: CGSize, color: UIColor) -> SKNode {
        let button = SKNode()
        button.name = name
        button.zPosition = 30 // Ensure button is above everything else
        
        // Button background with felt texture
        let bg = SKShapeNode(rectOf: size, cornerRadius: 6)
        bg.name = "background"
        bg.fillColor = color
        bg.strokeColor = UIColor.white.withAlphaComponent(0.7)
        bg.lineWidth = 1.5
        bg.zPosition = 31
        button.addChild(bg)
        
        // Add subtle stitching effect with small dashes
        let stitchContainer = SKNode()
        stitchContainer.zPosition = 32
        let stitchRect = CGRect(x: -size.width/2 + 2, y: -size.height/2 + 2, 
                               width: size.width - 4, height: size.height - 4)
        let dashLength: CGFloat = 2
        let gapLength: CGFloat = 2
        let perimeter = 2 * (stitchRect.width + stitchRect.height)
        let dashCount = Int(perimeter / (dashLength + gapLength))
        
        for i in 0..<dashCount {
            let progress = CGFloat(i) / CGFloat(dashCount)
            let dash = SKShapeNode(rectOf: CGSize(width: dashLength, height: 0.8))
            dash.fillColor = UIColor.white.withAlphaComponent(0.4)
            dash.strokeColor = .clear
            
            // Position dash along the rectangle perimeter
            let side = progress * 4.0 // 4 sides
            let top = stitchRect.minY + stitchRect.height
            let right = stitchRect.minX + stitchRect.width
            
            if side < 1.0 { // Top side
                dash.position = CGPoint(x: stitchRect.minX + side * stitchRect.width, y: top)
            } else if side < 2.0 { // Right side
                dash.position = CGPoint(x: right, y: top - (side - 1.0) * stitchRect.height)
                dash.zRotation = .pi / 2
            } else if side < 3.0 { // Bottom side
                dash.position = CGPoint(x: right - (side - 2.0) * stitchRect.width, y: stitchRect.minY)
            } else { // Left side
                dash.position = CGPoint(x: stitchRect.minX, y: stitchRect.minY + (side - 3.0) * stitchRect.height)
                dash.zRotation = .pi / 2
            }
            
            stitchContainer.addChild(dash)
        }
        button.addChild(stitchContainer)
        
        // Button label
        let label = SKLabelNode(text: text)
        label.name = "label"
        label.fontSize = size.height * 0.4 // Scale font to button height
        label.fontColor = UIColor.white
        label.fontName = "ArialRoundedMTBold"
        label.verticalAlignmentMode = .center
        label.zPosition = 33
        button.addChild(label)
        
        // Prepare for tap animations
        button.setScale(1.0)
        bg.name = "tapTarget"
        
        return button
    }
    
    private func createSuperPowerButton(power: SuperPowerProgress, sceneSize: CGSize) -> SKNode {
        let container = SKNode()
        container.name = "superPower_\(power.type)"
        
        let buttonWidth = sceneSize.width * 0.9
        let buttonHeight: CGFloat = 90
        
        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        bg.fillColor = power.isMaxed ? 
            UIColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 0.8) : // Green for maxed
            UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)   // Dark blue for upgradeable
        bg.strokeColor = power.isMaxed ? .green : .white
        bg.lineWidth = 2
        bg.zPosition = 0
        container.addChild(bg)
        
        // Icon
        let iconTexture = SKTexture(imageNamed: power.type.imageName)
        let icon: SKNode
        
        if iconTexture.size() != .zero {
            let sprite = SKSpriteNode(texture: iconTexture)
            sprite.size = CGSize(width: 40, height: 40)
            icon = sprite
        } else {
            // Create a colored rectangle placeholder instead of emoji
            let placeholderSize = CGSize(width: 40, height: 40)
            let placeholder = SKShapeNode(rectOf: placeholderSize, cornerRadius: 6)
            placeholder.fillColor = .systemBlue
            placeholder.strokeColor = .white
            placeholder.lineWidth = 1.5
            
            // Add abbreviated text
            let abbreviation: String
            switch power.type {
            case .jumpRange: abbreviation = "JR"
            case .jumpRecoil: abbreviation = "JRC"
            case .maxHealth: abbreviation = "HP"
            case .superJumpFocus: abbreviation = "SJ"
            case .ghostMagic: abbreviation = "GM"
            case .impactJumps: abbreviation = "IJ"
            }
            
            let label = SKLabelNode(text: abbreviation)
            label.fontSize = 12
            label.fontColor = .white
            label.fontName = "ArialRoundedMTBold"
            label.verticalAlignmentMode = .center
            placeholder.addChild(label)
            
            icon = placeholder
        }
        
        icon.position = CGPoint(x: -buttonWidth/2 + 40, y: 0)
        icon.zPosition = 1
        container.addChild(icon)
        
        // Title and level
        let titleText = power.isMaxed ? "\(power.type.name) MAX" : "\(power.type.name) Lv.\(power.level)"
        let title = SKLabelNode(text: titleText)
        title.fontSize = 18
        title.fontColor = power.isMaxed ? .green : .white
        title.fontName = "ArialRoundedMTBold"
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -buttonWidth/2 + 80, y: 15)
        title.zPosition = 1
        container.addChild(title)
        
        // Description
        let description = SKLabelNode(text: power.type.effectDescription(level: max(1, power.level)))
        description.fontSize = 12
        description.fontColor = UIColor.white.withAlphaComponent(0.8)
        description.fontName = "ArialRoundedMTBold"
        description.horizontalAlignmentMode = .left
        description.verticalAlignmentMode = .center
        description.position = CGPoint(x: -buttonWidth/2 + 80, y: -5)
        description.zPosition = 1
        container.addChild(description)
        
        // Cost and upgrade button (if not maxed)
        if !power.isMaxed {
            let cost = power.nextLevelCost
            let canAfford = tadpoleCoins >= cost
            
            // Cost display
            let costText = "Cost: \(cost)"
            let costLabel = SKLabelNode(text: costText)
            costLabel.fontSize = 12
            costLabel.fontColor = canAfford ? .yellow : .red
            costLabel.fontName = "ArialRoundedMTBold"
            costLabel.horizontalAlignmentMode = .right
            costLabel.verticalAlignmentMode = .center
            costLabel.position = CGPoint(x: buttonWidth/2 - 100, y: 0)
            costLabel.zPosition = 1
            container.addChild(costLabel)
            
            // Upgrade button
            let upgradeButton = createButton(
                text: canAfford ? "UPGRADE" : "NEED MORE",
                name: "upgrade_\(power.type)",
                size: CGSize(width: 120, height: 30)
            )
            upgradeButton.position = CGPoint(x: buttonWidth/2 - 50, y: -10)
            upgradeButton.zPosition = 1
            
            // Disable button if can't afford
            if !canAfford {
                upgradeButton.alpha = 0.5
            }
            
            container.addChild(upgradeButton)
        }
        
        return container
    }
    
    private func updateTadpoleCoinsDisplay() {
        guard let menu = superPowersMenu,
              let display = menu.childNode(withName: "tadpoleCoinsDisplay"),
              let coinsContainer = display.childNode(withName: "coinsLabel") else { return }
        
        // Update the text label within the coins container
        if let textLabel = coinsContainer.children.compactMap({ $0 as? SKLabelNode }).first {
            textLabel.text = "[\(tadpoleCoins) Tadpole Coins]"
        }
        
        // Add a little animation when coins change
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        coinsContainer.run(pulse)
    }
    
    // MARK: - Super Power Purchase Logic
    
    func purchaseSuperPower(_ powerType: SuperPowerType) -> Bool {
        guard let progress = superPowers[powerType], !progress.isMaxed else { return false }
        
        let cost = progress.nextLevelCost
        guard tadpoleCoins >= cost else { return false }
        
        // Deduct coins and upgrade
        tadpoleCoins -= cost
        superPowers[powerType]?.level += 1
        
        // Apply the upgrade effect immediately
        if powerType == .maxHealth {
            // Apply the max health bonus to the game (maxed at 6 levels)
            if let gameScene = scene as? GameScene {
                let newBonusHealth = getBonusMaxHealth()
                // Calculate how much bonus we should have vs what we currently have
                let currentMaxHealth = gameScene.healthManager.maxHealth
                let baseMaxHealth = 3 // Default starting health (from GameConfig.startingHealth)
                let currentBonus = currentMaxHealth - baseMaxHealth
                let additionalBonus = newBonusHealth - currentBonus
                
                if additionalBonus > 0 {
                    gameScene.healthManager.maxHealth += additionalBonus
                    gameScene.healthManager.health += additionalBonus // Give the bonus health immediately
                    print("❤️ Max Health Super Power upgraded: +\(additionalBonus) bonus hearts (total bonus: \(newBonusHealth), max possible: 6)")
                }
            }
        }
        
        // Save progress
        saveSuperPowerProgress()
        
        // Refresh the menu if it's currently shown
        if let _ = superPowersMenu, let scene = scene {
            showSuperPowersMenu(sceneSize: scene.size)
        }
        
        return true
    }
    
    func addTadpoleCoins(_ amount: Int) {
        tadpoleCoins += amount
        saveSuperPowerProgress()
    }
    
    // MARK: - Debug Helper for Testing Super Powers
    func testSuperPowerIntegration() {
        print("🧪 Testing Super Power Integration:")
        
        // Test health integration
        let baseHealth = GameConfig.startingHealth
        let bonusHealth = getBonusMaxHealth()
        print("  Health: Base=\(baseHealth), Bonus=\(bonusHealth)")
        
        // Test other super powers
        print("  Jump Range: \(getJumpRangeMultiplier())x")
        print("  Jump Recoil: -\(getJumpRecoilReduction())s")
        print("  Super Jump Extension: +\(getSuperJumpExtension())s")
        print("  Ghost Escapes: \(getGhostEscapes())")
        print("  Impact Jump Destroys: \(getImpactJumpDestroysRemaining())")
        
        // Verify health integration if we have access to the game scene
        if let gameScene = scene as? GameScene {
            let expectedHealth = baseHealth + bonusHealth
            if gameScene.healthManager.maxHealth == expectedHealth {
                print("✅ Health integration working correctly")
            } else {
                print("❌ Health integration issue: expected \(expectedHealth), got \(gameScene.healthManager.maxHealth)")
            }
        }
    }
    
    func debugMaxHealthSuperPower() {
        guard let maxHealthProgress = superPowers[.maxHealth] else {
            print("❌ Max Health super power not found")
            return
        }
        
        print("🔍 Max Health Super Power Debug:")
        print("  - Current level: \(maxHealthProgress.level)")
        print("  - Is maxed: \(maxHealthProgress.isMaxed)")
        print("  - Max level cap: 6")
        print("  - Next level cost: \(maxHealthProgress.nextLevelCost)")
        print("  - Current bonus health: \(getBonusMaxHealth())")
    }
    
    /// Test function to simulate max health upgrade (for debugging)
    func testMaxHealthUpgrade() {
        print("🧪 Testing Max Health upgrade process...")
        debugMaxHealthSuperPower()
        
        // Give enough coins for testing
        if tadpoleCoins < 200 {
            tadpoleCoins = 200
            print("💰 Added tadpole coins for testing")
        }
        
        let success = purchaseSuperPower(.maxHealth)
        print("✅ Purchase attempt result: \(success ? "SUCCESS" : "FAILED")")
        
        debugMaxHealthSuperPower()
        
        // Test hitting the limit
        if let progress = superPowers[.maxHealth], progress.level < 6 {
            print("🔄 Attempting to max out Max Health Super Power...")
            for i in progress.level..<6 {
                tadpoleCoins = 1000 // Ensure we have enough coins
                let levelUp = purchaseSuperPower(.maxHealth)
                print("  Level \(i+1) -> \(i+2): \(levelUp ? "SUCCESS" : "FAILED")")
            }
            
            // Try to go beyond the limit
            print("🚫 Attempting to go beyond level 6...")
            tadpoleCoins = 1000
            let beyondLimit = purchaseSuperPower(.maxHealth)
            print("  Beyond level 6: \(beyondLimit ? "SUCCESS (BUG!)" : "CORRECTLY BLOCKED")")
            
            debugMaxHealthSuperPower()
        }
    }
    
    // MARK: - Super Power Persistence
    
    private func saveSuperPowerProgress() {
        let defaults = UserDefaults.standard
        defaults.set(tadpoleCoins, forKey: "tadpoleCoins")
        
        for (type, progress) in superPowers {
            let key = "superPower_\(type)"
            defaults.set(progress.level, forKey: key)
        }
    }
    
    /// Immediately save any pending tadpole coins to persistent storage
    /// This should be called when the game ends to ensure coins aren't lost
    func savePendingTadpoleCoins() {
        guard pendingTadpoleCoins > 0 else { return }
        
        let defaults = UserDefaults.standard
        let currentSavedCoins = defaults.integer(forKey: "tadpoleCoins")
        let newTotal = currentSavedCoins + pendingTadpoleCoins
        
        defaults.set(newTotal, forKey: "tadpoleCoins")
        defaults.synchronize()
        
        print("💰 Saved \(pendingTadpoleCoins) pending tadpole coins. New total: \(newTotal)")
        
        // Update in-memory cache
        tadpoleCoins = newTotal
        pendingTadpoleCoins = 0
    }
    
    private func loadSuperPowerProgress() {
        let defaults = UserDefaults.standard
        var current = defaults.integer(forKey: "tadpoleCoins")
        // Add any pending newly collected coins
        if pendingTadpoleCoins > 0 {
            current += pendingTadpoleCoins
            // Persist updated total
            defaults.set(current, forKey: "tadpoleCoins")
            defaults.synchronize()
            // Clear pending amount now that it's saved
            pendingTadpoleCoins = 0
        }
        // Update in-memory cache
        tadpoleCoins = current
        
        for powerType in SuperPowerType.allCases {
            let key = "superPower_\(powerType)"
            let level = defaults.integer(forKey: key)
            superPowers[powerType] = SuperPowerProgress(type: powerType, level: level)
        }
    }
    
    // MARK: - Super Power Effects (for integration with game logic)
    
    func getSuperPowerLevel(_ type: SuperPowerType) -> Int {
        return superPowers[type]?.level ?? 0
    }
    
    func getJumpRangeMultiplier() -> CGFloat {
        let level = getSuperPowerLevel(.jumpRange)
        return 1.0 + (CGFloat(level) * 0.1) // 10% per level
    }
    
    func getJumpRecoilReduction() -> TimeInterval {
        let level = getSuperPowerLevel(.jumpRecoil)
        return TimeInterval(level * 2) // 2 seconds per level
    }
    
    func getBonusMaxHealth() -> Int {
        return getSuperPowerLevel(.maxHealth) // 1 heart per level
    }
    
    func getSuperJumpExtension() -> TimeInterval {
        let level = getSuperPowerLevel(.superJumpFocus)
        return TimeInterval(level * 2) // 2 seconds per level
    }
    
    // Legacy method - returns total ghost escapes available (use getGhostEscapesRemaining() for remaining count)
    func getGhostEscapes() -> Int {
        return getSuperPowerLevel(.ghostMagic) * 2 // 2 escapes per level
    }
    
    // MARK: - Impact Jumps Tracking (Per Level Limit)
    private var impactJumpDestroysUsed: Int = 0
    private var currentLevelForImpactJumps: Int = -1
    
    func getImpactJumpDestroysRemaining() -> Int {
        let totalAllowed = getSuperPowerLevel(.impactJumps) * 3 // 3 destroys per level
        return max(0, totalAllowed - impactJumpDestroysUsed)
    }
    
    func useImpactJumpDestroy() -> Bool {
        let remaining = getImpactJumpDestroysRemaining()
        if remaining > 0 {
            impactJumpDestroysUsed += 1
            return true
        }
        return false
    }
    
    func resetImpactJumpsForNewLevel(_ level: Int) {
        if level != currentLevelForImpactJumps {
            currentLevelForImpactJumps = level
            impactJumpDestroysUsed = 0
            print("💥 Impact Jumps reset for level \(level). Available destroys: \(getImpactJumpDestroysRemaining())")
        }
    }
    
    // MARK: - Ghost Escapes Tracking (Per Level Limit)
    private var currentLevelForGhostEscapes: Int = -1
    
    func getGhostEscapesRemaining() -> Int {
        let totalAllowed = getSuperPowerLevel(.ghostMagic) * 2 // 2 escapes per level
        // Get the used count from health manager
        if let gameScene = scene as? GameScene {
            let usedEscapes = gameScene.healthManager.ghostEscapesUsed
            return max(0, totalAllowed - usedEscapes)
        }
        return totalAllowed
    }
    
    func resetGhostEscapesForNewLevel(_ level: Int) {
        if level != currentLevelForGhostEscapes {
            currentLevelForGhostEscapes = level
            // Reset the counter in health manager through the game scene
            if let gameScene = scene as? GameScene {
                gameScene.healthManager.ghostEscapesUsed = 0
                print("👻 Ghost Escapes reset for level \(level). Available escapes: \(getGhostEscapesRemaining())")
            }
        }
    }
    
    // Legacy method for backward compatibility - now checks remaining uses
    func getImpactJumpDestroys() -> Int {
        return getImpactJumpDestroysRemaining() > 0 ? 1 : 0 // Can destroy 1 enemy if uses remain
    }
    
    // MARK: - Button tap routing update
    /// Call this from your scene when a node is tapped. It routes based on the node's name.
    /// - Parameter nodeName: The `name` of the tapped node (e.g., "leaderboardButton").
    func handleNamedButtonTap(_ nodeName: String) {
        switch nodeName {
        case "levelSelectorButton":
            // Present the level selection modal
            if let scene = scene {
                showLevelSelectionModal(sceneSize: scene.size)
            }
        case "closeLevelSelectionButton":
            // Close the level selection modal and return to main menu
            hideLevelSelectionModal()
            if let scene = scene {
                showMainMenu(sceneSize: scene.size)
            }
        case "leaderboardButton":
            // Present the Game Center leaderboard
            presentLeaderboard(leaderboardID: leaderboardID)
        case "tutorialButton":
            // Show the tutorial modal
            if let scene = scene {
                showTutorialModal(sceneSize: scene.size)
            }
        case "closeTutorialButton":
            // Close the tutorial modal
            hideTutorialModal()
        case "superPowersButton":
            // Show the Super Powers menu
            presentSuperPowersViewController()
        case "backFromSuperPowersButton":
            // Return to main menu
            if let scene = scene {
                showMainMenu(sceneSize: scene.size)
            }
        case "continueButton":
            // Resume the game from pause
            hideMenus()
            setUIVisible(true)
            // Notify GameScene to unpause
            NotificationCenter.default.post(name: NSNotification.Name("ResumeGame"), object: nil)
        case "quitButton":
            // Quit to main menu
            hideMenus()
            // Notify GameScene to quit to main menu
            NotificationCenter.default.post(name: NSNotification.Name("QuitToMainMenu"), object: nil)
        case "playGameButton", "newGameButton":
            // Start a new game from the main menu
            hideMenus()
            setUIVisible(true)
            // Notify GameScene to start a new game
            NotificationCenter.default.post(name: NSNotification.Name("StartNewGame"), object: nil)
        case "tryAgainButton":
            // Restart the current game from game over menu
            hideMenus()
            setUIVisible(true)
            // Notify GameScene to restart
            NotificationCenter.default.post(name: NSNotification.Name("RestartGame"), object: nil)
        case "backToMenuButton":
            // Return to main menu from game over
            hideMenus()
            // Notify GameScene to go back to main menu
            NotificationCenter.default.post(name: NSNotification.Name("BackToMainMenu"), object: nil)
        default:
            // Handle level button taps
            if nodeName.hasPrefix("levelButton_") {
                let levelString = String(nodeName.dropFirst("levelButton_".count))
                if let level = Int(levelString) {
                    startGameAtLevel(level)
                }
            }
            // Handle initial upgrade selection buttons
            else if nodeName.hasPrefix("initialUpgrade_") {
                print("🎯 UIManager handling initial upgrade: \(nodeName)")
                // Forward to GameScene for processing
                if let gameScene = scene as? GameScene {
                    gameScene.handleInitialUpgradeSelection(nodeName)
                } else {
                    print("❌ Could not forward initial upgrade to GameScene")
                }
            }
            // Handle super power upgrade buttons
            else if nodeName.hasPrefix("upgrade_") {
                let powerName = String(nodeName.dropFirst("upgrade_".count))
                if let powerType = SuperPowerType.allCases.first(where: { "\($0)" == powerName }) {
                    let success = purchaseSuperPower(powerType)
                    if success {
                        // Add purchase success feedback
                        triggerTapHaptic()
                        // Could add a purchase success animation here
                    } else {
                        // Add failure feedback (different haptic or sound)
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.error)
                    }
                }
            }
            break
        }
    }
    
    // MARK: - External convenience for GameScene touch handling
    func handleButtonPress(node: SKNode?) {
        guard let node = node else { return }
        animateButtonPress(node)
    }

    func handleButtonRelease(node: SKNode?) {
        guard let node = node else { return }
        animateButtonRelease(node)
    }
    
    /// Handle touch events in menus - call this from GameScene's touch methods
    func handleTouch(_ touch: UITouch, phase: TouchPhase, in scene: SKScene) {
        guard let activeMenu = menuLayer ?? abilityLayer ?? superPowersMenu ?? tutorialModal else { return }
        
        // Check if enough time has passed since menu appeared to prevent touch propagation
        if CACurrentMediaTime() < menuInteractionEnabledTime {
            print("🚫 Menu interaction blocked - too soon after opening")
            return
        }
        
        let location = touch.location(in: activeMenu)
        let tappedNode = activeMenu.atPoint(location)
        
        switch phase {
        case .began:
            if let buttonNode = findButtonParent(from: tappedNode) {
                handleButtonPress(node: buttonNode)
                print("🎯 Button press detected: \(buttonNode.name ?? "unknown")")
            }
            
        case .ended:
            if let buttonNode = findButtonParent(from: tappedNode) {
                handleButtonRelease(node: buttonNode)
                
                // Handle the actual button action
                if let buttonName = buttonNode.name {
                    print("🎯 Button tap: \(buttonName)")
                    handleNamedButtonTap(buttonName)
                } else {
                    print("⚠️ Button has no name")
                }
            }
            
        case .cancelled:
            // Just release any pressed state
            if let buttonNode = findButtonParent(from: tappedNode) {
                handleButtonRelease(node: buttonNode)
            }
        }
    }
    
    /// Find the button container from a tapped child node
    private func findButtonParent(from node: SKNode) -> SKNode? {
        var currentNode: SKNode? = node
        
        while let current = currentNode {
            // Check if this node is a button based on its name or structure
            if let name = current.name {
                if name.contains("Button") || name.contains("button") {
                    return current
                }
                
                // Check if it has button-like children (background, label, tapTarget)
                if current.childNode(withName: "background") != nil || 
                   current.childNode(withName: "tapTarget") != nil {
                    return current
                }
            }
            
            currentNode = current.parent
        }
        
        return nil // No button parent found
    }
    
    enum TouchPhase {
        case began
        case ended  
        case cancelled
    }
    
    // MARK: - Super Powers Menu Scroll Support (Legacy - now handled by UIKit)
    func handleSuperPowersScroll(_ scrollDelta: CGFloat) {
        // No longer needed with UIKit implementation
        // UITableView handles scrolling automatically
    }
    
    // Check if super powers menu is currently scrollable (Legacy)
    func isSuperPowersMenuScrollable() -> Bool {
        // No longer needed with UIKit implementation
        return false
    }
    
    // MARK: - Enable Button Input Helper
    func enableButtonInput() {
        // This function can be expanded for enabling input on menu buttons if needed
        // For now, it is a placeholder to ensure taps on the leaderboard button work
    }
    
    // MARK: - Initial Game Upgrade Selection
    func showInitialUpgradeSelection(sceneSize: CGSize) {
        hideMenus()
        guard let scene = scene else { return }
        
        // CRITICAL FIX: Add interaction delay to prevent touch carry-over from play button
        menuInteractionEnabledTime = CACurrentMediaTime() + 0.5
        
        let menu = SKNode()
        menu.zPosition = 350 // Higher than normal menus
        menu.name = "initialUpgradeLayer"
        
        // Calculate safe areas - leave space for bottom HUD (about 140pt) and top safe area
        let bottomHudHeight: CGFloat = 140
        let topSafeArea: CGFloat = 80
        let availableHeight = sceneSize.height - bottomHudHeight - topSafeArea
        
        // Full screen background with attractive appearance
        let bg = SKShapeNode(rectOf: sceneSize)
        bg.fillColor = UIColor(red: 0.05, green: 0.15, blue: 0.3, alpha: 0.95)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.2)
        bg.lineWidth = 2.0
        bg.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        bg.name = "background"
        bg.zPosition = 0
        menu.addChild(bg)
        
        // Title - positioned in safe area at top
        let title = SKLabelNode(text: "Choose Your Starting Upgrade!")
        title.fontSize = 18 // Slightly smaller to fit better
        title.fontColor = UIColor.yellow
        title.fontName = "ArialRoundedMTBold"
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 160) // More margin from top
        title.zPosition = 12
        
       
        menu.addChild(title)
        
        // Create the three initial upgrade options
        let initialAbilities: [AbilityType] = [.lifeVest, .honeyJar, .extraHeart]
        
        // Calculate button positions - center them in the available space above the HUD
        let contentCenterY = topSafeArea + (availableHeight / 2)
        
        // For iPhone-sized screens, use smaller button spacing to fit better
        let baseButtonSpacing: CGFloat = min(180, sceneSize.width * 0.28) // Adaptive spacing
        let buttonSpacing = min(baseButtonSpacing, (sceneSize.width - 60) / 3) // Ensure buttons fit with margins
        
        let centerX = sceneSize.width / 2
        
        for (index, ability) in initialAbilities.enumerated() {
            let xOffset = CGFloat(index - 1) * buttonSpacing // -1, 0, 1 for left, center, right
            let buttonX = centerX + xOffset
            
            let button = createInitialUpgradeButton(ability: ability, name: "initialUpgrade_\(ability)")
            button.position = CGPoint(x: buttonX, y: contentCenterY)
            menu.addChild(button)
        }
        
        // Add instructions - position them below buttons but above HUD
        let instructions = SKLabelNode(text: "Tap to select your starting advantage")
        instructions.fontSize = 16
        instructions.fontColor = UIColor.white.withAlphaComponent(0.8)
        instructions.fontName = "ArialRoundedMTBold"
        instructions.horizontalAlignmentMode = .center
        instructions.verticalAlignmentMode = .center
        // Position instructions between buttons and bottom HUD
        instructions.position = CGPoint(x: sceneSize.width / 2, y: bottomHudHeight + 40)
        instructions.zPosition = 12
        menu.addChild(instructions)
        
        // Add fade-in animation
        menu.alpha = 0.0
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        menu.run(fadeIn)
        
        abilityLayer = menu
        scene.addChild(menu)
    }
    
    private func createInitialUpgradeButton(ability: AbilityType, name: String) -> SKNode {
        let container = SKNode()
        container.name = name
        
        // Smaller buttons to fit better on screen
        let buttonWidth: CGFloat = 100
        let buttonHeight: CGFloat = 180
        let cornerRadius: CGFloat = 16
        
        let bgRect = CGRect(x: -buttonWidth/2, y: -buttonHeight/2, width: buttonWidth, height: buttonHeight)
        let background = SKShapeNode(path: CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        background.fillColor = UIColor(red: 0.1, green: 0.4, blue: 0.2, alpha: 0.9)
        background.strokeColor = UIColor.white.withAlphaComponent(0.6)
        background.lineWidth = 2.0
        background.zPosition = 1
        container.addChild(background)
        
        // Icon/Image - slightly smaller
        let iconSize: CGFloat = 56
        let iconNode: SKNode
        
        // Fix the texture loading issue
        let texture = SKTexture(imageNamed: ability.imageName)
        if texture.size() != .zero {
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: iconSize, height: iconSize)
            iconNode = sprite
        } else {
            // Fallback to emoji if image not available
            let emoji = SKLabelNode(text: ability.emoji)
            emoji.fontSize = 42
            emoji.horizontalAlignmentMode = .center
            emoji.verticalAlignmentMode = .center
            iconNode = emoji
        }
        
        iconNode.position = CGPoint(x: 0, y: 35)
        iconNode.zPosition = 2
        container.addChild(iconNode)
        
        // Title - adjusted for smaller button
        let title = SKLabelNode(text: ability.title)
        title.fontSize = 15
        title.fontColor = UIColor.white
        title.fontName = "ArialRoundedMTBold"
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: -5)
        title.zPosition = 2
        
        // Handle multi-line titles if needed
        if title.text!.count > 12 {
            title.fontSize = 13
        }
        container.addChild(title)
        
        // Description (shorter for initial selection) - smaller font and positioned lower
        let description = SKLabelNode()
        description.fontSize = 11
        description.fontColor = UIColor.white.withAlphaComponent(0.9)
        description.fontName = "ArialRoundedMTBold"
        description.horizontalAlignmentMode = .center
        description.verticalAlignmentMode = .center
        description.position = CGPoint(x: 0, y: -35)
        description.zPosition = 2
        description.numberOfLines = 2 // Allow line wrapping
        
        // Simplified descriptions for initial selection
        switch ability {
        case .lifeVest:
            description.text = "Survive water\nfalls once"
        case .honeyJar:
            description.text = "Protect against\nbee attacks"
        case .extraHeart:
            description.text = "Start with\n+1 health"
        default:
            description.text = ability.description
        }
        
        container.addChild(description)
        
        // Add tap target for better touch detection - slightly smaller to match button
        let tapTarget = SKShapeNode(path: CGPath(roundedRect: bgRect.insetBy(dx: -10, dy: -10), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        tapTarget.fillColor = .clear
        tapTarget.strokeColor = .clear
        tapTarget.name = "tapTarget"
        tapTarget.zPosition = 10
        container.addChild(tapTarget)
        
        return container
    }
}

extension UIManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

// MARK: - CGPath sampling helper
private extension CGPath {
    // Returns a point along the path by sampling its bounding box and flattening to line segments.
    // t should be in [0,1]. This is an approximation good enough for placing decorative dashes.
    func point(atNormalizedLength t: CGFloat) -> CGPoint? {
        let clampedT: CGFloat = max(0, min(1, t))
        var points: [CGPoint] = []
        var lastPoint: CGPoint?
        self.applyWithBlock { elementPtr in
            let e = elementPtr.pointee
            switch e.type {
            case .moveToPoint:
                lastPoint = e.points[0]
                points.append(e.points[0])
            case .addLineToPoint:
                if let last = lastPoint {
                    let to = e.points[0]
                    let segs: Int = 4
                    for s in 1...segs {
                        let su: CGFloat = CGFloat(s)
                        let segsF: CGFloat = CGFloat(segs)
                        let u: CGFloat = su / segsF
                        let x: CGFloat = last.x + (to.x - last.x) * u
                        let y: CGFloat = last.y + (to.y - last.y) * u
                        points.append(CGPoint(x: x, y: y))
                    }
                    lastPoint = to
                } else {
                    lastPoint = e.points[0]
                    points.append(e.points[0])
                }
            case .addQuadCurveToPoint:
                if let last = lastPoint {
                    let c = e.points[0]
                    let to = e.points[1]
                    let segs: Int = 12
                    for s in 1...segs {
                        let su: CGFloat = CGFloat(s)
                        let segsF: CGFloat = CGFloat(segs)
                        let u: CGFloat = su / segsF
                        
                        // FIXED: Breaking up the Quadratic Bezier curve expressions
                        let u2 = pow(u, 2)
                        let u_minus_1 = 1 - u
                        let u_minus_1_2 = pow(u_minus_1, 2)
                        let u_times_u_minus_1_2 = 2 * u_minus_1 * u

                        let x: CGFloat = u_minus_1_2 * last.x + u_times_u_minus_1_2 * c.x + u2 * to.x
                        let y: CGFloat = u_minus_1_2 * last.y + u_times_u_minus_1_2 * c.y + u2 * to.y
                        
                        points.append(CGPoint(x: x, y: y))
                    }
                    lastPoint = to
                }
            case .addCurveToPoint:
                if let last = lastPoint {
                    let c1 = e.points[0]
                    let c2 = e.points[1]
                    let to = e.points[2]
                    let segs: Int = 16
                    for s in 1...segs {
                        let su: CGFloat = CGFloat(s)
                        let segsF: CGFloat = CGFloat(segs)
                        let u: CGFloat = su / segsF
                        
                        // FIXED: Breaking up the Cubic Bezier curve expressions
                        let u2 = pow(u, 2)
                        let u3 = u2 * u
                        let u_minus_1 = 1 - u
                        let u_minus_1_2 = pow(u_minus_1, 2)
                        let u_minus_1_3 = u_minus_1_2 * u_minus_1

                        let x: CGFloat = u_minus_1_3 * last.x + 3 * u_minus_1_2 * u * c1.x + 3 * u_minus_1 * u2 * c2.x + u3 * to.x
                        let y: CGFloat = u_minus_1_3 * last.y + 3 * u_minus_1_2 * u * c1.y + 3 * u_minus_1 * u2 * c2.y + u3 * to.y
                        
                        points.append(CGPoint(x: x, y: y))
                    }
                    lastPoint = to
                }
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        guard !points.isEmpty else { return nil }
        let countMinusOne: Int = max(0, points.count - 1)
        let countMinusOneF: CGFloat = CGFloat(countMinusOne)
        let idx: Int = Int((clampedT * countMinusOneF).rounded())
        return points[idx]
    }
}

// MARK: - SuperPowersViewController

class SuperPowersViewController: UIViewController {
    weak var uiManager: UIManager?
    
    // UI Components
    private let backgroundView = UIView()
    private let backgroundImageView = UIImageView()
    private let containerView = UIView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let coinsLabel = UILabel()
    private let tableView = UITableView()
    private let closeButton = UIButton(type: .system)
    
    private var didPerformInitialReload = false
    
    // Data
    private var superPowers: [SuperPowerProgress] = []
    
    deinit {
        print("🧹 SuperPowersViewController deinitializing")
        uiManager = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        setupViews()
        setupConstraints()
        setupTableView()
        
        // Debug: Force a reload after everything is set up
        DispatchQueue.main.async {
            print("🔄 Forcing table view reload after setup")
            self.tableView.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didPerformInitialReload {
            didPerformInitialReload = true
            tableView.reloadData()
        }
    }
    
    private func setupData() {
        guard let uiManager = uiManager else { return }
        
        // Convert the dictionary to an array for table view, sorted by name for consistency
        superPowers = SuperPowerType.allCases.compactMap { type in
            uiManager.superPowers[type]
        }.sorted { $0.type.name < $1.type.name }
        
        print("📊 SuperPowersViewController: Loaded \(superPowers.count) super powers")
        for power in superPowers {
            print("  - \(power.type.name): Level \(power.level), Cost: \(power.nextLevelCost), Maxed: \(power.isMaxed)")
        }
    }
    
    private func setupViews() {
        view.backgroundColor = UIColor.clear
        
        // Optional PNG background image behind the dim view
        if let bgImage = UIImage(named: "superPowersBG.png") {
            backgroundImageView.image = bgImage
            backgroundImageView.contentMode = .scaleAspectFill
            backgroundImageView.alpha = 1.0
            backgroundImageView.isUserInteractionEnabled = false
            view.addSubview(backgroundImageView)
        }
        
        // Background view with blur effect
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        backgroundView.alpha = 0
        view.addSubview(backgroundView)
        
        // Container view with transparent background to show table background, rounded corners and shadow
        containerView.backgroundColor = UIColor.clear
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.3
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        containerView.clipsToBounds = true
        view.addSubview(containerView)
        
        // Header view with PNG background
        headerView.backgroundColor = UIColor.clear // Clear background to show the image
        headerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        headerView.layer.cornerRadius = 16
        headerView.clipsToBounds = true // Ensure image respects rounded corners
        
        // Add PNG background image to header
        if let headerImage = UIImage(named: "superPowersTop.png") {
            let headerImageView = UIImageView(image: headerImage)
            headerImageView.contentMode = .scaleAspectFill
            headerImageView.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(headerImageView)
            
            // Pin the image to fill the entire header view
            NSLayoutConstraint.activate([
                headerImageView.topAnchor.constraint(equalTo: headerView.topAnchor),
                headerImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                headerImageView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                headerImageView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
            ])
            print("✅ Using superPowersTop.png for header background")
        } else {
            // Fallback to blue background if PNG not found
            headerView.backgroundColor = UIColor.systemBlue
            print("⚠️ superPowersTop.png not found, using blue fallback")
        }
        
        containerView.addSubview(headerView)
        
        // Title label
        titleLabel.text = "Super Powers"
        titleLabel.font = UIFont(name: "ArialRoundedMTBold", size: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)
        
        // Coins label
        updateCoinsLabel()
        coinsLabel.font = UIFont(name: "ArialRoundedMT", size: 18)
        coinsLabel.textColor = .systemYellow
        coinsLabel.textAlignment = .center
        headerView.addSubview(coinsLabel)
        
        // Table view with PNG background
        tableView.backgroundColor = UIColor.clear // Make table view transparent
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = true
        tableView.layer.cornerRadius = 12
        tableView.clipsToBounds = true // Respect rounded corners
        
        // Add PNG background image to table view
        if let tableBackgroundImage = UIImage(named: "superPowersBG.png") {
            let backgroundImageView = UIImageView(image: tableBackgroundImage)
            backgroundImageView.contentMode = .scaleAspectFill
            backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
            tableView.backgroundView = backgroundImageView
            print("✅ Using superPowersBG.png for table view background")
        } else {
            // Fallback to system background if PNG not found
            tableView.backgroundColor = UIColor.systemBackground
            print("⚠️ superPowersBG.png not found, using system background fallback")
        }
        
        containerView.addSubview(tableView)
        
        // Close button
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont(name: "ArialRoundedMT", size: 18)
        closeButton.backgroundColor = UIColor.systemRed
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        containerView.addSubview(closeButton)
    }
    
    private func setupConstraints() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        coinsLabel.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Background view
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Pin background image if present
        if backgroundImageView.superview != nil {
            backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
                backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        NSLayoutConstraint.activate([
            // Container view – pin to safe area with insets (prevents table from collapsing)
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            
            // Header view
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            // Coins label
            coinsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            coinsLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            coinsLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            coinsLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            
            // Table view - ensure it has enough space
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            tableView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -12),
            
            // Close button
            closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SuperPowerCell.self, forCellReuseIdentifier: "SuperPowerCell")
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false
        tableView.bounces = true
        tableView.alwaysBounceVertical = true
        tableView.contentInsetAdjustmentBehavior = .never
        
        // Add some padding to the table view content
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.tableFooterView = UIView()
        tableView.scrollIndicatorInsets = tableView.contentInset
        
        print("📋 Table view setup complete. Estimated row height: 120pt")
    }
    
    private func updateCoinsLabel() {
        let coins = uiManager?.tadpoleCoins ?? 0
        coinsLabel.font = UIFont(name: "ArialRoundedMT", size: 18)

        coinsLabel.text = "\(coins) Tadpole Coins"
    }
    
    private func animateIn() {
        UIView.animate(withDuration: 0.6, delay: 0, options: [.curveEaseOut]) {
            self.backgroundView.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: [.curveEaseOut]) {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            self.backgroundView.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.containerView.alpha = 0
        } completion: { _ in
            completion()
        }
    }
    
    @objc private func closeButtonTapped() {
        animateOut { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: false) {
                // Restore game UI
                guard let uiManager = self.uiManager,
                      let scene = uiManager.scene as? GameScene else {
                    print("⚠️ closeButtonTapped: UIManager or scene is nil")
                    return
                }
                uiManager.setUIVisible(true)
                // Return to main menu
                uiManager.showMainMenu(sceneSize: scene.size)
            }
        }
    }
    
    private func purchaseSuperPower(_ powerType: SuperPowerType) {
        guard let uiManager = uiManager else { return }
        
        print("💰 Attempting to purchase \(powerType.name)")
        
        let success = uiManager.purchaseSuperPower(powerType)
        
        if success {
            print("✅ Purchase successful for \(powerType.name)")
            
            // Update local data
            setupData()
            // Update coins display
            updateCoinsLabel()
            
            // Reload table with animation
            DispatchQueue.main.async {
                self.tableView.performBatchUpdates({
                    self.tableView.reloadData()
                }, completion: nil)
            }
            
            // Add purchase success haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Add a brief success animation
            animateCoinsUpdate()
        } else {
            print("❌ Purchase failed for \(powerType.name)")
            
            // Add failure feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            // Show brief error feedback
            showPurchaseError()
        }
    }
    
    private func showPurchaseError() {
        // Briefly flash the coins label red to indicate insufficient funds
        let originalColor = coinsLabel.textColor
        UIView.animate(withDuration: 0.2) {
            self.coinsLabel.textColor = .systemRed
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.coinsLabel.textColor = originalColor
            }
        }
    }
    
    private func animateCoinsUpdate() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            self.coinsLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
                self.coinsLabel.transform = .identity
            }
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension SuperPowersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("📊 Table view requesting number of rows: \(superPowers.count)")
        return superPowers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuperPowerCell", for: indexPath) as! SuperPowerCell
        let power = superPowers[indexPath.row]
        let coins = uiManager?.tadpoleCoins ?? 0
        
        print("📱 Configuring cell for row \(indexPath.row): \(power.type.name)")
        
        cell.configure(with: power, coins: coins)
        cell.onUpgrade = { [weak self] powerType in
            self?.purchaseSuperPower(powerType)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}

// MARK: - SuperPowerCell

class SuperPowerCell: UITableViewCell {
    var onUpgrade: ((SuperPowerType) -> Void)?
    private var powerType: SuperPowerType?
    
    // UI Components
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let levelLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let costLabel = UILabel()
    private let upgradeButton = UIButton(type: .system)
    private let maxedLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("🧹 SuperPowerCell deinitializing")
        onUpgrade = nil
        powerType = nil
    }
    
    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        
        // Container view with rounded corners and semi-transparent background
        containerView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.8) // Semi-transparent
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.separator.withAlphaComponent(0.6).cgColor // Lighter border
        contentView.addSubview(containerView)
        
        // Icon image view
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 4
        iconImageView.backgroundColor = UIColor.tertiarySystemBackground
        containerView.addSubview(iconImageView)
        
        // Title label
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = UIColor.label
        containerView.addSubview(titleLabel)
        
        // Level label
        levelLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        levelLabel.textColor = UIColor.secondaryLabel
        containerView.addSubview(levelLabel)
        
        // Description label
        descriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = UIColor.secondaryLabel
        descriptionLabel.numberOfLines = 2
        containerView.addSubview(descriptionLabel)
        
        // Cost label
        costLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        costLabel.textAlignment = .right
        containerView.addSubview(costLabel)
        
        // Upgrade button
        upgradeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        upgradeButton.layer.cornerRadius = 8
        upgradeButton.addTarget(self, action: #selector(upgradeButtonTapped), for: .touchUpInside)
        containerView.addSubview(upgradeButton)
        
        // Maxed label
        maxedLabel.text = "MAX LEVEL"
        maxedLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        maxedLabel.textColor = UIColor.systemGreen
        maxedLabel.textAlignment = .center
        maxedLabel.isHidden = true
        containerView.addSubview(maxedLabel)
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        costLabel.translatesAutoresizingMaskIntoConstraints = false
        upgradeButton.translatesAutoresizingMaskIntoConstraints = false
        maxedLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container view with proper margins
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Icon image view - positioned at fixed distance from left edge for consistent alignment
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.heightAnchor.constraint(equalToConstant: 44),
            
            // Title label
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: costLabel.leadingAnchor, constant: -8),
            
            // Level label
            levelLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            levelLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            levelLabel.trailingAnchor.constraint(lessThanOrEqualTo: costLabel.leadingAnchor, constant: -8),
            
            // Description label
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 6),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: costLabel.leadingAnchor, constant: -8),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16),
            
            // Cost label
            costLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            costLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            costLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Upgrade button
            upgradeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            upgradeButton.topAnchor.constraint(equalTo: costLabel.bottomAnchor, constant: 8),
            upgradeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            upgradeButton.heightAnchor.constraint(equalToConstant: 36),
            upgradeButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16),
            
            // Maxed label
            maxedLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            maxedLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            maxedLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }
    
    func configure(with power: SuperPowerProgress, coins: Int) {
        powerType = power.type
        
        // Icon - load PNG image, create placeholder if not found
        let imageName = power.type.imageName
        if let image = UIImage(named: imageName) {
            iconImageView.image = image
        } else {
            // Create a placeholder image with the power type name if PNG not found
            iconImageView.image = createPlaceholderImage(for: power.type, size: CGSize(width: 40, height: 40))
            
            #if DEBUG
            print("⚠️ Missing PNG icon for \(power.type.name): \(imageName)")
            #endif
        }
        
        // Title and level
        if power.isMaxed {
            titleLabel.text = power.type.name
            titleLabel.textColor = UIColor.systemGreen
            levelLabel.text = "MAX LEVEL"
            levelLabel.textColor = UIColor.systemGreen
        } else {
            titleLabel.text = power.type.name
            titleLabel.textColor = UIColor.label
            levelLabel.text = "Level \(power.level)"
            levelLabel.textColor = UIColor.secondaryLabel
        }
        
        // Description
        descriptionLabel.text = power.type.effectDescription(level: max(1, power.level))
        
        // Cost and button
        if power.isMaxed {
            costLabel.isHidden = true
            upgradeButton.isHidden = true
            maxedLabel.isHidden = false
        } else {
            let cost = power.nextLevelCost
            let canAfford = coins >= cost
            
            // Create attributed string with star image
            let costText = "Cost: \(cost) "
            let attributedString = NSMutableAttributedString(string: costText)
            
            // Add star image if available
            if let starImage = UIImage(named: "star.png") {
                let attachment = NSTextAttachment()
                attachment.image = starImage
                // Scale the image to match text height
                let fontSize = costLabel.font.pointSize
                let imageSize = CGSize(width: fontSize, height: fontSize)
                attachment.bounds = CGRect(origin: CGPoint(x: 0, y: -fontSize * 0.1), size: imageSize)
                
                let imageAttributedString = NSAttributedString(attachment: attachment)
                attributedString.append(imageAttributedString)
            } else {
                // Fallback to star emoji if image not found
                attributedString.append(NSAttributedString(string: "⭐"))
            }
            
            costLabel.attributedText = attributedString
            costLabel.textColor = canAfford ? UIColor.systemYellow : UIColor.systemRed
            costLabel.isHidden = false
            
            upgradeButton.setTitle(canAfford ? "UPGRADE" : "NEED MORE", for: .normal)
            upgradeButton.backgroundColor = canAfford ? UIColor.systemGreen : UIColor.systemGray
            upgradeButton.setTitleColor(.white, for: .normal)
            upgradeButton.isEnabled = canAfford
            upgradeButton.alpha = canAfford ? 1.0 : 0.6
            upgradeButton.isHidden = false
            
            maxedLabel.isHidden = true
        }
    }
    
    private func createPlaceholderImage(for powerType: SuperPowerType, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Draw a rounded rectangle background
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            
            // Use different colors for different power types
            let backgroundColor: UIColor
            switch powerType {
            case .jumpRange:
                backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
            case .jumpRecoil:
                backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
            case .maxHealth:
                backgroundColor = UIColor.systemRed.withAlphaComponent(0.3)
            case .superJumpFocus:
                backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
            case .ghostMagic:
                backgroundColor = UIColor.systemPurple.withAlphaComponent(0.3)
            case .impactJumps:
                backgroundColor = UIColor.systemOrange.withAlphaComponent(0.3)
            }
            
            backgroundColor.setFill()
            path.fill()
            
            // Draw border
            UIColor.systemGray.setStroke()
            path.lineWidth = 1
            path.stroke()
            
            // Draw abbreviated text
            let abbreviation: String
            switch powerType {
            case .jumpRange: abbreviation = "JR"
            case .jumpRecoil: abbreviation = "JRC"
            case .maxHealth: abbreviation = "HP"
            case .superJumpFocus: abbreviation = "SJ"
            case .ghostMagic: abbreviation = "GM"
            case .impactJumps: abbreviation = "IJ"
            }
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.height * 0.3, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let attributedString = NSAttributedString(string: abbreviation, attributes: attributes)
            let textSize = attributedString.size()
            let drawPoint = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            attributedString.draw(at: drawPoint)
        }
    }

    private func createEmojiImage(_ emoji: String, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.height * 0.8),
                .foregroundColor: UIColor.label
            ]
            let attributedString = NSAttributedString(string: emoji, attributes: attributes)
            let textSize = attributedString.size()
            let drawPoint = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            attributedString.draw(at: drawPoint)
        }
    }
    
    @objc private func upgradeButtonTapped() {
        guard let powerType = powerType else { return }
        
        // Add button press animation
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut]) {
            self.upgradeButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseIn]) {
                self.upgradeButton.transform = .identity
            }
        }
        
        onUpgrade?(powerType)
    }
}

