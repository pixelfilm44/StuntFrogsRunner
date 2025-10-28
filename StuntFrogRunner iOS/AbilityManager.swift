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
        if abilityStr.contains("extraHeart") {
            onExtraHeartSelected?()
        } else if abilityStr.contains("superJump") {
            onSuperJumpSelected?()
        } else if abilityStr.contains("refillHearts") {
            onRefillHeartsSelected?()
        } else if abilityStr.contains("lifeVest") {
            onLifeVestSelected?()
        } else if abilityStr.contains("scrollSaver") {
            onScrollSaverSelected?()
        } else if abilityStr.contains("flySwatter") {
            onFlySwatterSelected?()
        } else if abilityStr.contains("honeyJar") {
            onHoneyJarSelected?()
        } else if abilityStr.contains("axe") {
            onAxeSelected?()
        } else if abilityStr.contains("rocket") {
            onRocketSelected?()
        }
    }
}