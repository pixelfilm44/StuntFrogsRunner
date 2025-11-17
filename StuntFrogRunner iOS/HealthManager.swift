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
    
    // SUPER POWERS: Ghost Magic escape charges
    var ghostEscapesUsed: Int = 0 {
        didSet {
            onAbilityChargesChanged?()
        }
    }
    
    private var healthDepletedAlreadyCalled: Bool = false
    
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
    
    // Helper to get max health including super power bonuses
    func getEffectiveMaxHealth() -> Int {
        var effectiveMax = maxHealth
        
        // SUPER POWERS: Add bonus max health from Max Health super power
        if let scene = onHealthChanged as? GameScene {
            // This is a bit of a hack - we'd ideally want a cleaner way to get the GameScene reference
            // For now, we'll handle this in the GameScene itself
        }
        
        return effectiveMax
    }
    
    // MARK: - Health Management
    func damageHealth(amount: Int = 1) {
        let previousHealth = health
        health -= amount
        
        // Only call onHealthDepleted if we just crossed from positive to zero/negative
        // and we haven't already called it
        if previousHealth > 0 && health <= 0 && !healthDepletedAlreadyCalled {
            healthDepletedAlreadyCalled = true
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
        
        if GameConfig.enableAbilitySelectionDebug {
            print("🐸 Tadpole collected! Total: \(tadpolesCollected)/\(GameConfig.tadpolesForAbility), pendingAbilitySelection: \(pendingAbilitySelection)")
        }
        
        // Check if we've reached the threshold for ability selection
        if tadpolesCollected >= GameConfig.tadpolesForAbility && !pendingAbilitySelection {
            pendingAbilitySelection = true
            tadpolesCollected = 0
            onTadpolesChanged?(tadpolesCollected)
            
            if GameConfig.enableAbilitySelectionDebug {
                print("🎯 ABILITY SELECTION TRIGGERED! pendingAbilitySelection set to true")
            }
            
            return true  // Ability selection triggered
        } else if tadpolesCollected >= GameConfig.tadpolesForAbility && pendingAbilitySelection {
            if GameConfig.enableAbilitySelectionDebug {
                print("⚠️ WARNING: Reached tadpole threshold but pendingAbilitySelection already true! This may indicate a stuck state.")
            }
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
    
    /// Debug method to check current tadpole collection state
    func debugTadpoleState() -> String {
        return """
        🐸 Tadpole Debug State:
        - tadpolesCollected: \(tadpolesCollected)
        - threshold: \(GameConfig.tadpolesForAbility) 
        - pendingAbilitySelection: \(pendingAbilitySelection)
        - ready for selection: \(tadpolesCollected >= GameConfig.tadpolesForAbility && !pendingAbilitySelection)
        """
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
    
    // MARK: - Ghost Magic Management (Super Power)
    func canUseGhostEscape(availableEscapes: Int) -> Bool {
        return ghostEscapesUsed < availableEscapes
    }
    
    func useGhostEscape() -> Bool {
        // Ghost escapes are managed by the super power level, not charges
        ghostEscapesUsed += 1
        return true
    }
    
    // MARK: - Reset
    func reset(startingHealth: Int, preserveMaxHealthBonus: Bool = false) {
        let previousMaxHealth = maxHealth
        
        // CRITICAL FIX: Set both health and maxHealth to the startingHealth which now includes super power bonuses
        health = startingHealth
        maxHealth = startingHealth
        
        // Reset other properties
        tadpolesCollected = 0
        scrollSaverCharges = 0
        flySwatterCharges = 0
        honeyJarCharges = 0
        axeCharges = 0
        ghostEscapesUsed = 0
        pendingAbilitySelection = false
        healthDepletedAlreadyCalled = false  // Reset the flag
        
        print("💚 HealthManager reset complete:")
        print("  - health: \(health)")
        print("  - maxHealth: \(maxHealth)")
    }
}
