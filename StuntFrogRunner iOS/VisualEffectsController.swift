//
//  VisualEffectsController.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//

//
//  VisualEffectsController.swift
//  StuntFrog Runner
//
//  Manages visual effects for the frog (health flash, invincibility, etc.)

import SpriteKit

class VisualEffectsController {
    // MARK: - Properties
    weak var frogContainer: SKNode?
    weak var frogSprite: SKSpriteNode?
    weak var frogShadow: SKNode?
    private var isLowHealthFlashing: Bool = false
    
    // MARK: - Initialization
    init(frogContainer: SKNode?, frogSprite: SKSpriteNode?, frogShadow: SKNode?) {
        self.frogContainer = frogContainer
        self.frogSprite = frogSprite
        self.frogShadow = frogShadow
    }
    
    // MARK: - Low Health Flash
    func startLowHealthFlash() {
        guard let frogSprite = frogSprite,
              let frogShadow = frogShadow,
              let frogContainer = frogContainer else { return }
        
        isLowHealthFlashing = true
        
        frogSprite.removeAction(forKey: "lowHealthFlash")
        frogShadow.removeAction(forKey: "lowHealthFlash")
        frogContainer.removeAction(forKey: "lowHealthFlash")
        
        let flashRed = SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.25)
        let flashNormal = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.25)
        let pulseSequence = SKAction.sequence([flashRed, flashNormal])
        let repeatFlash = SKAction.repeatForever(pulseSequence)
        
        frogSprite.run(repeatFlash, withKey: "lowHealthFlash")
        
        let shadowDim = SKAction.fadeAlpha(to: 0.15, duration: 0.4)
        let shadowBright = SKAction.fadeAlpha(to: 0.3, duration: 0.4)
        let shadowPulse = SKAction.sequence([shadowDim, shadowBright])
        let repeatShadow = SKAction.repeatForever(shadowPulse)
        
        frogShadow.run(repeatShadow, withKey: "lowHealthFlash")
        
        let scaleUp = SKAction.scale(to: 1.12, duration: 0.25)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.25)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let scalePulse = SKAction.sequence([scaleUp, scaleDown])
        let repeatScale = SKAction.repeatForever(scalePulse)
        
        frogContainer.run(repeatScale, withKey: "lowHealthFlash")
    }
    
    func stopLowHealthFlash() {
        guard let frogSprite = frogSprite,
              let frogShadow = frogShadow,
              let frogContainer = frogContainer else { return }
        
        isLowHealthFlashing = false
        
        frogSprite.removeAction(forKey: "lowHealthFlash")
        frogShadow.removeAction(forKey: "lowHealthFlash")
        frogContainer.removeAction(forKey: "lowHealthFlash")
        
        frogSprite.colorBlendFactor = 0.0
        frogShadow.alpha = 0.3
        frogContainer.setScale(1.0)
    }
    
    // MARK: - Invincibility Flicker
    func startInvincibilityFlicker() {
        guard let frogSprite = frogSprite,
              let frogShadow = frogShadow else { return }
        
        // Clear any previous flicker
        frogSprite.removeAction(forKey: "invincibleFlicker")
        frogShadow.removeAction(forKey: "invincibleFlicker")
        
        // Quick alpha flicker on the frog sprite
        let fadeDown = SKAction.fadeAlpha(to: 0.4, duration: 0.08)
        let fadeUp = SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        let flicker = SKAction.sequence([fadeDown, fadeUp])
        let repeatFlicker = SKAction.repeat(flicker, count: 12) // ~2 seconds total
        
        // Optional: subtle color tint to reinforce state
        let tintOn = SKAction.colorize(with: .yellow, colorBlendFactor: 0.35, duration: 0.0)
        let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.0)
        let tintSeq = SKAction.sequence([tintOn, repeatFlicker, tintOff])
        
        frogSprite.run(tintSeq, withKey: "invincibleFlicker")
        
        // Slight shadow pulsing for extra clarity
        let shadowDim = SKAction.fadeAlpha(to: 0.15, duration: 0.08)
        let shadowBright = SKAction.fadeAlpha(to: 0.3, duration: 0.08)
        let shadowPulse = SKAction.sequence([shadowDim, shadowBright])
        frogShadow.run(SKAction.repeat(shadowPulse, count: 12), withKey: "invincibleFlicker")
    }
    
    func stopInvincibilityFlicker() {
        guard let frogSprite = frogSprite,
              let frogShadow = frogShadow else { return }
        
        frogSprite.removeAction(forKey: "invincibleFlicker")
        frogShadow.removeAction(forKey: "invincibleFlicker")
        frogSprite.alpha = 1.0
        // Preserve low-health tint if active
        if !isLowHealthFlashing {
            frogSprite.colorBlendFactor = 0.0
        }
        frogShadow.alpha = 0.3
    }
    
    // MARK: - Upgrade Cue
    func playUpgradeCue(completion: (() -> Void)? = nil) {
        guard let frogContainer = frogContainer,
              let frogSprite = frogSprite,
              let frogShadow = frogShadow else { return }
        
        // Clear any previous cue
        frogContainer.removeAction(forKey: "upgradeCue")
        frogSprite.removeAction(forKey: "upgradeCue")
        frogShadow.removeAction(forKey: "upgradeCue")
        
        // 1) Big scale pop with a bounce back
        let scaleUp1 = SKAction.scale(to: 1.9, duration: 0.18)
        scaleUp1.timingMode = .easeOut
        let scaleDown1 = SKAction.scale(to: 1.1, duration: 0.16)
        scaleDown1.timingMode = .easeIn
        let scaleSettle = SKAction.scale(to: 1.0, duration: 0.18)
        scaleSettle.timingMode = .easeInEaseOut
        let scaleBounce = SKAction.sequence([scaleUp1, scaleDown1, scaleSettle])
        
        // 2) Quick rotation wobble for extra punch
        let rotateLeft = SKAction.rotate(byAngle: .pi/24, duration: 0.06)
        let rotateRight = SKAction.rotate(byAngle: -.pi/12, duration: 0.10)
        let rotateCenter = SKAction.rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true)
        rotateLeft.timingMode = .easeOut
        rotateRight.timingMode = .easeInEaseOut
        rotateCenter.timingMode = .easeInEaseOut
        let wobble = SKAction.sequence([rotateLeft, rotateRight, rotateCenter])
        
        // 3) Brief white flash overlay on the sprite via colorize
        let flashOn = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.06)
        let flashOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.18)
        let flashSeq = SKAction.sequence([flashOn, flashOff])
        
        // 4) Stronger cyan tint pulse to reinforce upgrade
        let tintOn = SKAction.colorize(with: .cyan, colorBlendFactor: 1.0, duration: 0.10)
        let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.20)
        let tintSeq = SKAction.sequence([tintOn, tintOff])
        let spriteSequence = SKAction.group([flashSeq, tintSeq])
        
        // 5) Shadow pulse to accentuate pop
        let shadowUp = SKAction.fadeAlpha(to: 0.5, duration: 0.10)
        let shadowDown = SKAction.fadeAlpha(to: 0.3, duration: 0.20)
        let shadowSeq = SKAction.sequence([shadowUp, shadowDown])
        
        // 6) Subtle container shake to sell impact
        let shakeLeft = SKAction.moveBy(x: -6, y: 0, duration: 0.04)
        let shakeRight = SKAction.moveBy(x: 12, y: 0, duration: 0.06)
        let shakeCenter = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
        shakeLeft.timingMode = .easeOut
        shakeRight.timingMode = .easeInEaseOut
        shakeCenter.timingMode = .easeInEaseOut
        let shake = SKAction.sequence([shakeLeft, shakeRight, shakeCenter])
        
        // 7) Optional: quick glow ring effect around the frog using an ephemeral node
        let glowNode = SKShapeNode(circleOfRadius: max(frogSprite.size.width, frogSprite.size.height) * 0.7)
        glowNode.strokeColor = .cyan
        glowNode.lineWidth = 6
        glowNode.fillColor = .clear
        glowNode.alpha = 0.0
        glowNode.zPosition = (frogContainer.zPosition + 1)
        frogContainer.addChild(glowNode)
        let glowIn = SKAction.group([
            SKAction.fadeAlpha(to: 0.9, duration: 0.06),
            SKAction.scale(to: 1.25, duration: 0.18)
        ])
        let glowOut = SKAction.group([
            SKAction.fadeOut(withDuration: 0.22),
            SKAction.scale(to: 1.6, duration: 0.22)
        ])
        glowNode.setScale(0.9)
        glowNode.run(SKAction.sequence([glowIn, glowOut, .removeFromParent()]))
        
        // Completion action
        let completionAction = SKAction.run { completion?() }
        
        // Run actions
        frogContainer.run(SKAction.group([scaleBounce, wobble, shake]), withKey: "upgradeCue")
        frogSprite.run(spriteSequence, withKey: "upgradeCue")
        frogShadow.run(shadowSeq, withKey: "upgradeCue")
        
        // Ensure completion fires roughly when the container settles
        frogContainer.run(SKAction.sequence([SKAction.wait(forDuration: 0.26), completionAction]), withKey: "upgradeCueCompletion")
    }
    
    func cancelUpgradeCue() {
        guard let frogContainer = frogContainer,
              let frogSprite = frogSprite,
              let frogShadow = frogShadow else { return }
        
        frogContainer.removeAction(forKey: "upgradeCue")
        frogSprite.removeAction(forKey: "upgradeCue")
        frogShadow.removeAction(forKey: "upgradeCue")
        
        frogSprite.colorBlendFactor = 0.0
        frogShadow.alpha = 0.3
        frogContainer.setScale(1.0)
    }
}

