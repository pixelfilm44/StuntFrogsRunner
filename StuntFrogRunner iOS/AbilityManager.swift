//
//  AbilityManager.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//


//
//  AbilityManager.swift
//  StuntFrog Runner
//
//  Manages ability selection and activation

import SpriteKit

class AbilityManager {
    // MARK: - Callbacks
    var onExtraHeartSelected: (() -> Void)?
    var onSuperJumpSelected: (() -> Void)?
    var onRefillHeartsSelected: (() -> Void)?
    var onLifeVestSelected: (() -> Void)?
    var onScrollSaverSelected: (() -> Void)?
    var onFlySwatterSelected: (() -> Void)?
    var onHoneyJarSelected: (() -> Void)?
    var onAxeSelected: (() -> Void)?
    var onRocketSelected: (() -> Void)?
    
    // MARK: - Ability Selection
    func selectAbility(_ abilityStr: String) {
        print("🎯 AbilityManager.selectAbility called with: \(abilityStr)")
        if abilityStr.contains("extraHeart") {
            print("🎯 Triggering extraHeart callback")
            onExtraHeartSelected?()
        } else if abilityStr.contains("superJump") {
            print("🎯 Triggering superJump callback")
            onSuperJumpSelected?()
        } else if abilityStr.contains("refillHearts") {
            print("🎯 Triggering refillHearts callback")
            onRefillHeartsSelected?()
        } else if abilityStr.contains("lifeVest") {
            print("🎯 Triggering lifeVest callback")
            onLifeVestSelected?()
        } else if abilityStr.contains("scrollSaver") {
            print("🎯 Triggering scrollSaver callback")
            onScrollSaverSelected?()
        } else if abilityStr.contains("flySwatter") {
            print("🎯 Triggering flySwatter callback")
            onFlySwatterSelected?()
        } else if abilityStr.contains("honeyJar") {
            print("🎯 Triggering honeyJar callback")
            onHoneyJarSelected?()
        } else if abilityStr.contains("axe") {
            print("🎯 Triggering axe callback")
            onAxeSelected?()
        } else if abilityStr.contains("rocket") {
            print("🎯 Triggering rocket callback")
            onRocketSelected?()
        } else {
            print("🎯 No matching callback found for: \(abilityStr)")
        }
    }
}