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
    weak var frogShadow: SKSpriteNode?
    
    // MARK: - Initialization
    init(frogContainer: SKNode?, frogSprite: SKSpriteNode?, frogShadow: SKSpriteNode?) {
        self.frogContainer = frogContainer
        self.frogSprite = frogSprite
        self.frogShadow = frogShadow
    }
    
    // MARK: - Low Health Flash
    func startLowHealthFlash() {
        guard let frogSprite = frogSprite,
              let frogShadow = frogShadow,
              let frogContainer = frogContainer else { return }
        
        frogSprite.removeAction(forKey: "lowHealthFlash")
        frogShadow.removeAction(forKey: "lowHealthFlash")
        frogContainer.removeAction(forKey: "lowHealthFlash")
        
        let flashRed = SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.4)
        let flashNormal = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.4)
        let pulseSequence = SKAction.sequence([flashRed, flashNormal])
        let repeatFlash = SKAction.repeatForever(pulseSequence)
        
        frogSprite.run(repeatFlash, withKey: "lowHealthFlash")
        
        let shadowDim = SKAction.fadeAlpha(to: 0.15, duration: 0.4)
        let shadowBright = SKAction.fadeAlpha(to: 0.3, duration: 0.4)
        let shadowPulse = SKAction.sequence([shadowDim, shadowBright])
        let repeatShadow = SKAction.repeatForever(shadowPulse)
        
        frogShadow.run(repeatShadow, withKey: "lowHealthFlash")
        
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.4)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.4)
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
        frogSprite.colorBlendFactor = 0.0
        frogShadow.alpha = 0.3
    }
}