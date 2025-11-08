//
//  HealthManager.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//

//
//  HealthManager.swift
//  StuntFrog Runner
//
//  Manages health, tadpoles, and ability charges

import Foundation

class HealthManager {
    // MARK: - Properties
    var health: Int {
        didSet {
            // Clamp health to valid range [0, maxHealth]
            if health < 0 {
                health = 0
                return
            }
            if health > maxHealth {
                health = maxHealth
                return
            }
            onHealthChanged?(health, oldValue)
        }
    }
    
    var maxHealth: Int {
        didSet {
            onMaxHealthChanged?(maxHealth)
        }
    }
    
    var tadpolesCollected: Int {
        didSet {
            onTadpolesChanged?(tadpolesCollected)
        }
    }
    
    var scrollSaverCharges: Int = 0 {
        didSet {
            onAbilityChargesChanged?()
        }
    }
    
    var flySwatterCharges: Int = 0 {
        didSet {
            onAbilityChargesChanged?()
        }
    }
    
    var honeyJarCharges: Int = 0 {
        didSet {
            onAbilityChargesChanged?()
        }
    }
    
    var axeCharges: Int = 0 {
        didSet {
            onAbilityChargesChanged?()
        }
    }
    
    var pendingAbilitySelection: Bool = false {
        didSet {
            if GameConfig.enableAbilitySelectionDebug {
                print("🔧 pendingAbilitySelection changed to: \(pendingAbilitySelection)")
            }
            // Notify spawn manager of state change
            onAbilitySelectionStateChanged?(pendingAbilitySelection)
        }
    }
    
    // MARK: - Callbacks
    var onHealthChanged: ((Int, Int) -> Void)?  // newHealth, oldHealth
    var onMaxHealthChanged: ((Int) -> Void)?
    var onTadpolesChanged: ((Int) -> Void)?
    var onAbilityChargesChanged: (() -> Void)?
    var onAbilitySelectionStateChanged: ((Bool) -> Void)?  // NEW: Notify when ability selection state changes
    var onHealthDepleted: (() -> Void)?
    
    // MARK: - Initialization
    init(startingHealth: Int) {
        self.health = startingHealth
        self.maxHealth = startingHealth
        self.tadpolesCollected = 0
    }
    
    // MARK: - Health Management
    func damageHealth(amount: Int = 1) {
        health -= amount
        if health <= 0 {
            onHealthDepleted?()
        }
    }
    
    func healHealth(amount: Int = 1) {
        health = min(maxHealth, health + amount)
    }
    
    func refillHealth() {
        health = maxHealth
    }
    
    func increaseMaxHealth(by amount: Int = 1) {
        maxHealth += amount
        health += amount
    }
    
    /// Applies the "Extra Heart" ability.
    /// - Note: Adds one to max health and fills only the newly added heart.
    ///         It does NOT replenish any previously lost hearts beyond the new one.
    func applyExtraHeart() {
        // This increases capacity by 1 and also increases current health by 1,
        // which fills only the newly added heart.
        increaseMaxHealth(by: 1)
    }
    
    /// Applies the "Refill Hearts" ability.
    /// - Note: Refills all existing hearts up to current max health.
    func applyRefillHearts() {
        refillHealth()
    }
    
    // MARK: - Tadpole Management
    func collectTadpole() -> Bool {
        tadpolesCollected += 1
        
        // Check if we've reached the threshold for ability selection
        if tadpolesCollected >= GameConfig.tadpolesForAbility && !pendingAbilitySelection {
            pendingAbilitySelection = true
            tadpolesCollected = 0
            onTadpolesChanged?(tadpolesCollected)
            return true  // Ability selection triggered
        }
        return false
    }
    
    func resetTadpoles() {
        tadpolesCollected = 0
    }
    
    // MARK: - Safety Methods for Stuck States
    func forceClearAbilitySelection(reason: String = "manual") {
        if GameConfig.enableAbilitySelectionDebug {
            print("🔧 Force clearing pendingAbilitySelection. Reason: \(reason)")
        }
        pendingAbilitySelection = false
    }
    
    // MARK: - Ability Charge Management
    func addScrollSaverCharge() {
        scrollSaverCharges = min(6, scrollSaverCharges + 1)
    }
    
    func useScrollSaverCharge() -> Bool {
        guard scrollSaverCharges > 0 else { return false }
        scrollSaverCharges -= 1
        return true
    }
    
    func addFlySwatterCharge() {
        flySwatterCharges = min(6, flySwatterCharges + 1)
    }
    
    func useFlySwatterCharge() -> Bool {
        guard flySwatterCharges > 0 else { return false }
        flySwatterCharges -= 1
        return true
    }
    
    func addHoneyJarCharge() {
        honeyJarCharges = min(6, honeyJarCharges + 1)
    }
    
    func maxOutHoneyJarCharges() {
        honeyJarCharges = 4 // Set to max as specified in requirements
    }
    
    func useHoneyJarCharge() -> Bool {
        guard honeyJarCharges > 0 else { return false }
        honeyJarCharges -= 1
        return true
    }
    
    func addAxeCharge() {
        axeCharges = min(6, axeCharges + 1)
    }
    
    func useAxeCharge() -> Bool {
        guard axeCharges > 0 else { return false }
        axeCharges -= 1
        return true
    }
    
    // MARK: - Reset
    func reset(startingHealth: Int) {
        health = startingHealth
        maxHealth = startingHealth
        tadpolesCollected = 0
        scrollSaverCharges = 0
        flySwatterCharges = 0
        honeyJarCharges = 0
        axeCharges = 0
        pendingAbilitySelection = false
    }
}
