//
//  UIManager.swift
//  Top-down lily pad hopping UI with Glide Support
//

import SpriteKit

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
        case .extraHeart: return "❤️"
        case .superJump: return "⚡"
        case .refillHearts: return "💚"
        case .lifeVest: return "🦺"
        case .scrollSaver: return "⏱"
        case .flySwatter: return "🪰"
        case .honeyJar: return "🍯"
        case .rocket: return "🚀"
        case .axe: return "🪓"
        }
    }
}

class UIManager {
    // UI Elements
    var scoreLabel: SKLabelNode?
    var tadpoleLabel: SKLabelNode?
    var healthIcons: [SKLabelNode] = []
    var pauseButton: SKLabelNode?
    
    // Power-up indicators
    var superJumpIndicator: SKLabelNode?
    var rocketIndicator: SKLabelNode?
    var glideIndicator: SKLabelNode?  // ⬅️ CRITICAL: This must be declared!
    
    var starIconTop: SKLabelNode?
    var starProgressBGTop: SKShapeNode?
    var starProgressFillTop: SKShapeNode?
    
    // Menus
    var menuLayer: SKNode?
    var abilityLayer: SKNode?
    
    weak var scene: SKScene?
    
    init(scene: SKScene) {
        self.scene = scene
    }
    
    func setupUI(sceneSize: CGSize) {
        guard let scene = scene else { return }
        
        // Score label
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel?.fontSize = 22
        scoreLabel?.fontColor = UIColor.white
        scoreLabel?.fontName = "Arial-BoldMT"
        scoreLabel?.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        scoreLabel?.position = CGPoint(x: 20, y: sceneSize.height - 85)
        scoreLabel?.zPosition = 200
        scene.addChild(scoreLabel!)
        
        // Tadpole counter removed from top UI; handled elsewhere
        tadpoleLabel = nil
        
        // Pause button
        pauseButton = SKLabelNode(text: "⏸")
        pauseButton?.fontSize = 32
        pauseButton?.name = "pauseButton"
        pauseButton?.position = CGPoint(x: sceneSize.width - 35, y: sceneSize.height - 85)
        pauseButton?.zPosition = 200
        scene.addChild(pauseButton!)
        
        // Star progress at top - replace emoji with star.png sprite
        let starTexture = SKTexture(imageNamed: "star")
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
        let pathAction = SKAction.customAction(withDuration: 0.18) { node, _ in
            if let shape = node as? SKShapeNode { shape.path = newPath }
        }
        pathAction.timingMode = .easeOut
        let moveAction = SKAction.moveTo(x: newCenterX, duration: 0.18)
        moveAction.timingMode = .easeOut
        fill.run(SKAction.group([pathAction, moveAction]))
    }
    
    func updateHealthDisplay(current: Int, max: Int) {
        guard let scene = scene else { return }
        
        healthIcons.forEach { $0.removeFromParent() }
        healthIcons.removeAll()
        
        for i in 0..<max {
            let heart = SKLabelNode(text: i < current ? "❤️" : "🤍")
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
        
        let indicator = SKLabelNode(text: "⚡ SUPER JUMP!")
        indicator.fontSize = 24
        indicator.fontColor = .yellow
        indicator.fontName = "Arial-BoldMT"
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
        
        let indicator = SKLabelNode(text: "🚀 ROCKET: 10s")
        indicator.fontSize = 24
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
    
    // MARK: - Glide Indicator ⬅️ NEW METHODS!
    func showGlideIndicator(sceneSize: CGSize, duration: Double) {
        // Prevent stacking multiple glide indicators
        if let existing = glideIndicator, existing.parent != nil {
            return
        }
        
        guard let scene = scene else { return }
        
        let indicator = SKLabelNode(text: "🪂 GLIDE: 3.0s")
        indicator.fontSize = 28
        indicator.fontColor = .orange
        indicator.fontName = "Arial-BoldMT"
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
        
        indicator.text = String(format: "🪂 GLIDE: %.1fs", remainingTime)
        
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
        
        // When main UI is visible, menus should be hidden, and vice versa
        menuLayer?.isHidden = visible
        abilityLayer?.isHidden = visible
    }
    
    // MARK: - Menu Methods
    func showMainMenu(sceneSize: CGSize) {
        // Remove any existing menus to prevent stacking
        hideMenus()
        guard let scene = scene else { return }

        // Hide HUD while menu is visible
        setUIVisible(false)

        let menu = SKNode()
        menu.zPosition = 300
        menu.name = "menuLayer"

        // Fullscreen dim background to ensure it fills entire scene
        let backdrop = SKShapeNode(rectOf: sceneSize)
        backdrop.fillColor = UIColor.black.withAlphaComponent(0.75)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: sceneSize.width/2, y: sceneSize.height/2)
        menu.addChild(backdrop)

        // Content panel with safe margins
        let outerMargin: CGFloat = 24
        let panelSize = CGSize(width: max(200, sceneSize.width - outerMargin*2),
                               height: max(200, sceneSize.height - outerMargin*2))
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 24)
        panel.fillColor = UIColor(white: 0.06, alpha: 0.95)
        panel.strokeColor = UIColor.white.withAlphaComponent(0.12)
        panel.lineWidth = 1.5
        panel.position = CGPoint(x: sceneSize.width/2, y: sceneSize.height/2)
        panel.zPosition = 1
        menu.addChild(panel)

        // Container for labels inside panel
        let content = SKNode()
        content.position = .zero
        content.zPosition = 2
        panel.addChild(content)

        // Title image (title.png). We'll scale it to fit within the panel width; fall back to text if not available.
        let maxContentWidth = panelSize.width - 40
        var subtitleTopY: CGFloat
        if let titleTexture = SKTexture(imageNamed: "title").copy() as? SKTexture, titleTexture.size().width > 0, titleTexture.size().height > 0 {
            let titleSprite = SKSpriteNode(texture: titleTexture)
            // Place near the top inside the panel
            titleSprite.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            titleSprite.position = CGPoint(x: 0, y: panelSize.height/2 - 24)
            // Scale to fit width with some padding
            let targetWidth = maxContentWidth
            let scale = min(1.0, targetWidth / max(1.0, titleTexture.size().width))
            titleSprite.setScale(scale)
            content.addChild(titleSprite)
            // Compute Y under the sprite for subsequent elements
            subtitleTopY = titleSprite.position.y - titleSprite.size.height * titleSprite.xScale - 14
        } else {
            // Fallback: Text title
            let title = SKLabelNode(text: "Stuntfrog Superstar")
            title.fontName = "Arial-BoldMT"
            title.fontSize = 56
            title.fontColor = UIColor(red: 0.25, green: 0.95, blue: 0.35, alpha: 1.0)
            title.horizontalAlignmentMode = .center
            title.verticalAlignmentMode = .top
            title.position = CGPoint(x: 0, y: panelSize.height/2 - 36)
            content.addChild(title)

            // Shadow
            let titleShadow = SKLabelNode(text: title.text)
            titleShadow.fontName = title.fontName
            titleShadow.fontSize = title.fontSize
            titleShadow.fontColor = UIColor.black.withAlphaComponent(0.8)
            titleShadow.horizontalAlignmentMode = .center
            titleShadow.verticalAlignmentMode = .top
            titleShadow.position = CGPoint(x: 3, y: panelSize.height/2 - 39)
            titleShadow.zPosition = title.zPosition - 1
            content.addChild(titleShadow)
            subtitleTopY = title.position.y - (title.frame.height + 20)
        }

        // Subtitle under the title image/text
        let subtitle = SKLabelNode(text: "Lily Pad Hopping Adventure!")
        subtitle.fontName = "Arial-BoldMT"
        subtitle.fontSize = 26
        subtitle.fontColor = UIColor(white: 1.0, alpha: 0.92)
        subtitle.horizontalAlignmentMode = .center
        subtitle.verticalAlignmentMode = .top
        subtitle.position = CGPoint(x: 0, y: subtitleTopY)
        content.addChild(subtitle)

        // If subtitle is wider than panel, scale it down
        let subtitleWidth = max(subtitle.frame.width, 1)
        if subtitleWidth > maxContentWidth {
            let scale = max(0.6, maxContentWidth / subtitleWidth)
            subtitle.setScale(scale)
        }

        // Start button near center
        let startButton = createButton(text: "▶ START HOPPING", name: "startButton")
        startButton.position = CGPoint(x: sceneSize.width/2, y: sceneSize.height/2 - 40)
        startButton.zPosition = 305
        menu.addChild(startButton)

        // Assign and add
        menuLayer = menu
        scene.addChild(menu)
    }
    
    func showPauseMenu(sceneSize: CGSize) {
        hideMenus()
        guard let scene = scene else { return }
        setUIVisible(false)
        
        let menu = SKNode()
        menu.zPosition = 300
        menu.name = "menuLayer"
        
        let bg = SKShapeNode(rectOf: sceneSize)
        bg.fillColor = UIColor.black.withAlphaComponent(0.85)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        menu.addChild(bg)
        
        let title = SKLabelNode(text: "⏸ PAUSED")
        title.fontSize = 40
        title.fontColor = UIColor.white
        title.fontName = "Arial-BoldMT"
        title.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2 + 60)
        menu.addChild(title)
        
        let continueButton = createButton(text: "▶ Continue", name: "continueButton")
        continueButton.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2 - 40)
        menu.addChild(continueButton)
        
        let quitButton = createButton(text: "🏠 Quit to Menu", name: "quitButton")
        quitButton.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2 - 120)
        menu.addChild(quitButton)
        
        menuLayer = menu
        scene.addChild(menu)
    }
    
    func showGameOverMenu(sceneSize: CGSize, score: Int, highScore: Int, isNewHighScore: Bool, reason: GameScene.GameOverReason) {
        hideMenus()
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
            titleText = "💦 SPLASH! 💦"
            subtitleText = "Missed the lily pad!"
        case .healthDepleted:
            titleText = "💔 OUT OF HEARTS"
            subtitleText = "Your frog ran out of health."
        case .scrolledOffScreen:
            titleText = "⏱ Too Slow!"
            subtitleText = "You scrolled off the screen."
        case .tooSlow:
            titleText = "⏱ Too Slow!"
            subtitleText = "Keep up with the scroll!"
        }
        
        let title = SKLabelNode(text: titleText)
        title.fontSize = 32
        title.fontColor = UIColor.cyan
        title.fontName = "Arial-BoldMT"
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
        scoreText.fontName = "Arial-BoldMT"
        scoreText.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 220)
        menu.addChild(scoreText)
        
        let highScoreText = SKLabelNode(text: "High Score: \(highScore)")
        highScoreText.fontSize = 20
        highScoreText.fontColor = UIColor.white
        highScoreText.fontName = "Arial-BoldMT"
        highScoreText.position = CGPoint(x: sceneSize.width / 2, y: scoreText.position.y - 35)
        menu.addChild(highScoreText)

        var buttonStartY = highScoreText.position.y - 80
        
        if isNewHighScore {
            let badge = SKLabelNode(text: "🏆 NEW HIGH SCORE!")
            badge.fontSize = 20
            badge.fontColor = UIColor.yellow
            badge.fontName = "Arial-BoldMT"
            badge.position = CGPoint(x: sceneSize.width / 2, y: highScoreText.position.y - 45)
            menu.addChild(badge)

            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.25),
                SKAction.scale(to: 1.0, duration: 0.25)
            ])
            badge.run(SKAction.repeatForever(pulse))
            
            buttonStartY = badge.position.y - 60
        }
        
        let tryAgainButton = createButton(text: "🔄 Try Again", name: "tryAgainButton")
        tryAgainButton.position = CGPoint(x: sceneSize.width / 2, y: buttonStartY)
        menu.addChild(tryAgainButton)
        
        let backButton = createButton(text: "🏠 Back to Menu", name: "backToMenuButton")
        backButton.position = CGPoint(x: sceneSize.width / 2, y: buttonStartY - 70)
        menu.addChild(backButton)
        
        menuLayer = menu
        scene.addChild(menu)
    }
    
    func showAbilitySelection(sceneSize: CGSize) {
        hideMenus()
        guard let scene = scene else { return }
        setUIVisible(false)
        
        let menu = SKNode()
        menu.zPosition = 300
        menu.name = "abilityLayer"
        
        menu.setScale(0.7)
        menu.alpha = 0.0
        
        let bg = SKShapeNode(rectOf: sceneSize)
        bg.fillColor = UIColor.black.withAlphaComponent(0.92)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        menu.addChild(bg)
        
        let title = SKLabelNode(text: "⭐ Choose Your Power-Up! ⭐")
        title.fontSize = 28
        title.fontColor = UIColor.yellow
        title.fontName = "Arial-BoldMT"
        title.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 150)
        menu.addChild(title)
        
        var allAbilities: [AbilityType] = AbilityType.allPowerUps
        if let gs = scene as? GameScene {
            if gs.maxHealth >= 6 { allAbilities.removeAll { $0 == .extraHeart } }
            if gs.frogController.lifeVestCharges >= 6 { allAbilities.removeAll { $0 == .lifeVest } }
        }
        
        if let gs = scene as? GameScene {
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
        
        let abilities = Array(allAbilities.shuffled().prefix(2))
        
        for (index, ability) in abilities.enumerated() {
            let button = createAbilityButton(ability: ability, name: "ability_\(ability)")
            let baseY = sceneSize.height / 2 + 40
            button.position = CGPoint(x: sceneSize.width / 2 - 20, y: baseY - CGFloat(index) * 120)
            menu.addChild(button)
        }
        
        let grow = SKAction.scale(to: 1.0, duration: 0.22)
        grow.timingMode = .easeOut
        let fade = SKAction.fadeAlpha(to: 1.0, duration: 0.18)
        fade.timingMode = .easeOut
        menu.run(SKAction.group([grow, fade]))
        
        abilityLayer = menu
        scene.addChild(menu)
    }
    
    func hideMenus() {
        menuLayer?.removeFromParent()
        abilityLayer?.removeFromParent()
        menuLayer = nil
        abilityLayer = nil
    }
    
    private func createButton(text: String, name: String) -> SKNode {
        let button = SKNode()
        button.name = name
        
        let bg = SKShapeNode(rectOf: CGSize(width: 300, height: 60), cornerRadius: 12)
        bg.fillColor = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        bg.strokeColor = UIColor.white
        bg.lineWidth = 3
        button.addChild(bg)
        
        let shadow = SKShapeNode(rectOf: CGSize(width: 300, height: 60), cornerRadius: 12)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        button.addChild(shadow)
        
        let label = SKLabelNode(text: text)
        label.fontSize = 24
        label.fontColor = UIColor.white
        label.fontName = "Arial-BoldMT"
        label.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
        button.addChild(label)
        
        return button
    }
    
    private func createAbilityButton(ability: AbilityType, name: String) -> SKNode {
        let button = SKNode()
        button.name = name
        
        let bg = SKShapeNode(rectOf: CGSize(width: 360, height: 95), cornerRadius: 12)
        bg.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0)
        bg.strokeColor = UIColor.yellow
        bg.lineWidth = 4
        button.addChild(bg)
        
        let emoji = SKLabelNode(text: ability.emoji)
        emoji.fontSize = 45
        emoji.position = CGPoint(x: -130, y: 0)
        emoji.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
        button.addChild(emoji)
        
        let titleLabel = SKLabelNode(text: ability.title)
        titleLabel.fontSize = 19
        titleLabel.fontColor = UIColor.white
        titleLabel.fontName = "Arial-BoldMT"
        titleLabel.position = CGPoint(x: -40, y: 18)
        titleLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        button.addChild(titleLabel)
        
        let maxTextWidth: CGFloat = 220
        let wrapped = makeWrappedLabel(
            text: ability.description,
            fontName: "Arial-BoldMT",
            fontSize: 15,
            color: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),
            maxWidth: maxTextWidth,
            lineSpacing: 2,
            horizontalAlignment: .left
        )
        wrapped.position = CGPoint(x: -40, y: -18)
        button.addChild(wrapped)
        
        return button
    }

    private func makeWrappedLabel(text: String, fontName: String? = "Arial-BoldMT", fontSize: CGFloat, color: UIColor, maxWidth: CGFloat, lineSpacing: CGFloat = 4, horizontalAlignment: SKLabelHorizontalAlignmentMode = .left) -> SKNode {
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

        let splat = SKLabelNode(text: "🍯")
        splat.fontSize = 54
        splat.position = position
        splat.zPosition = 500
        splat.alpha = 0.0
        scene.addChild(splat)

        let drip1 = SKLabelNode(text: "•")
        drip1.fontSize = 20
        drip1.fontColor = .yellow
        drip1.position = CGPoint(x: position.x - 10, y: position.y - 8)
        drip1.alpha = 0.0
        drip1.zPosition = 499
        scene.addChild(drip1)

        let drip2 = SKLabelNode(text: "•")
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
        appear.timingMode = .easeOut

        let settle = SKAction.scale(to: 1.0, duration: 0.08)
        settle.timingMode = .easeIn

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

        let slash = SKLabelNode(text: "—")
        slash.fontName = "Arial-BoldMT"
        slash.fontSize = 60
        slash.fontColor = .white
        slash.position = position
        slash.zPosition = 500
        slash.alpha = 0.0
        slash.zRotation = direction
        scene.addChild(slash)

        let axe = SKLabelNode(text: "🪓")
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
        appear.timingMode = .easeOut

        let moveAxe = SKAction.moveBy(x: dx, y: dy, duration: 0.08)
        moveAxe.timingMode = .easeOut

        let settle = SKAction.group([
            SKAction.scale(to: 0.98, duration: 0.05),
            SKAction.fadeAlpha(to: 0.0, duration: 0.15)
        ])
        settle.timingMode = .easeIn

        let remove = SKAction.removeFromParent()

        slash.run(SKAction.sequence([appear, settle, remove]))
        axe.run(SKAction.sequence([appear, moveAxe, settle, remove]))
    }
}

