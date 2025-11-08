//
//  UIManager.swift
//  Top-down lily pad hopping UI with Glide Support
//

import SpriteKit
import UIKit
import GameKit

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
    // Set this to your App Store Connect leaderboard identifier
    var leaderboardID: String = "com.yourcompany.yourapp.leaderboard"

    // UI Elements
    var scoreLabel: SKLabelNode?
    var tadpoleLabel: SKLabelNode?
    var healthIcons: [SKLabelNode] = []
    var pauseButton: SKLabelNode?
    
 
    
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
        self.scene = scene
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
        guard let scene = scene else { return }
        
        // Score label
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel?.fontSize = 18
        scoreLabel?.fontColor = UIColor.white
        scoreLabel?.fontName = "ArialRoundedMTBold"
        scoreLabel?.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        scoreLabel?.position = CGPoint(x: 20, y: sceneSize.height - 85)
        scoreLabel?.zPosition = 200
        scene.addChild(scoreLabel!)
        
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
            scene.addChild(pauseButton!)
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
        let pathAction = SKAction.customAction(withDuration: duration) { node, _ in
            if let shape = node as? SKShapeNode {
                shape.path = newPath
            }
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
        
        guard let scene = scene else { return }
        
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
    }
    
    // MARK: - Menu Methods
    func showMainMenu(sceneSize: CGSize) {
        // Remove any existing menus to prevent stacking
        hideMenus()
        setUIVisible(false)
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
        if titleTexture.size() != .zero {
            let texSize = titleTexture.size()
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

        // Single centered Play button
        let buttonSize = CGSize(width: sceneSize.width * 0.75, height: 60)
        let playButton = createButton(text: "Play", name: "playGameButton", size: buttonSize)
        playButton.position = CGPoint(x: sceneSize.width/2, y: 170)
        menu.addChild(playButton)

        // Add a smaller Leaderboard button below Play (8px spacing)
        let leaderboardSize = CGSize(width: sceneSize.width * 0.6, height: 48)
        let leaderboardButton = createButton(text: "Leaderboard", name: "leaderboardButton", size: leaderboardSize)
        // Play button bottom: 170 - 30 = 140, then 8px gap: 140 - 8 - 24 = 108
        leaderboardButton.position = CGPoint(x: sceneSize.width/2, y: 108)
        menu.addChild(leaderboardButton)
        
        // Add Tutorial button under Leaderboard (8px spacing)
        let tutorialButton = createButton(text: "Tutorial", name: "tutorialButton", size: leaderboardSize)
        // Leaderboard button bottom: 108 - 24 = 84, then 8px gap: 84 - 8 - 24 = 52
        tutorialButton.position = CGPoint(x: sceneSize.width/2, y: 52)
        menu.addChild(tutorialButton)

        // Assign and add
        menuLayer = menu
        scene.addChild(menu)
        
        // Ensure button taps (e.g., Leaderboard) are routed to Game Center
        enableButtonInput()
    }
    
    func showPauseMenu(sceneSize: CGSize) {
        hideMenus()
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
        
        // Slide up from bottom over 1.0s, with background fading in, and disable taps during animation
        let duration: TimeInterval = 1.0
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
  
        // Removed: menu.isUserInteractionEnabled = false
        // Removed: menu.run(slideUp) { [weak self] in menu.isUserInteractionEnabled = true }
        menu.run(sequence)
        
        abilityLayer = menu
        scene.addChild(menu)
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
        
        // Add fade-in animation
        modal.alpha = 0.0
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
        hideTutorialModal()
        menuLayer = nil
        abilityLayer = nil
        
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

        // Mark tappable area and default scale for animations
        button.setScale(1.0)
        bg.name = "tapTarget" // so touch handlers can hit-test the sprite easily

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
    func presentLeaderboard(leaderboardID: String) {
        // Authenticate if needed, then present
        if GKLocalPlayer.local.isAuthenticated {
            presentLeaderboardView(leaderboardID: leaderboardID)
        } else {
            GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
                if let vc = vc {
                    self?.present(viewController: vc)
                } else if GKLocalPlayer.local.isAuthenticated {
                    self?.presentLeaderboardView(leaderboardID: leaderboardID)
                } else {
                    #if DEBUG
                    print("Game Center authentication failed: \(error?.localizedDescription ?? "unknown error")")
                    #endif
                }
            }
        }
    }

    private func presentLeaderboardView(leaderboardID: String) {
        let gcVC = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        gcVC.gameCenterDelegate = self
        present(viewController: gcVC)
    }

    private func present(viewController: UIViewController) {
        guard let rootVC = topViewController() else { return }
        rootVC.present(viewController, animated: true)
    }

    private func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?
        .rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
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

    // MARK: - Button tap routing
    /// Call this from your scene when a node is tapped. It routes based on the node's name.
    /// - Parameter nodeName: The `name` of the tapped node (e.g., "leaderboardButton").
    func handleNamedButtonTap(_ nodeName: String) {
        switch nodeName {
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
        default:
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
    
    // MARK: - Enable Button Input Helper
    func enableButtonInput() {
        // This function can be expanded for enabling input on menu buttons if needed
        // For now, it is a placeholder to ensure taps on the leaderboard button work
    }
    
    // MARK: - Initial Game Upgrade Selection
    func showInitialUpgradeSelection(sceneSize: CGSize) {
        hideMenus()
        guard let scene = scene else { return }
        
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

