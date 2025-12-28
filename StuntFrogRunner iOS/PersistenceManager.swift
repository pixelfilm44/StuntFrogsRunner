import Foundation

class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let highScore = "sf_highscore"
        static let totalCoins = "sf_coins"
        static let highestCombo = "sf_highest_combo"
        static let jumpLevel = "sf_upgrade_jump"
        static let healthLevel = "sf_upgrade_health"
        static let logJumper = "sf_upgrade_log_jumper" // NEW Key
        static let superJump = "sf_upgrade_super_jump"
        static let rocketJump = "sf_upgrade_rocket_jump"
        static let hasSeenHelp = "sf_has_seen_help"
        static let honeyItems = "sf_consumable_honey_items"
        static let vestItems = "sf_consumable_vest_items"
        static let cannonJump = "sf_upgrade_cannonJump" // NEW Key
        static let crossItems = "sf_consumable_cross_items"
        static let swatterItems = "sf_consumable_swatter_items"
        static let axeItems = "sf_consumable_axe_items"
        static let doubleSuperJumpTime = "sf_upgrade_double_superjump_time"
        static let doubleRocketTime = "sf_upgrade_double_rocket_time"
        static let hasSeenTutorial = "sf_has_seen_tutorial"
        
        // Carryover tracking for 4-pack items
        static let carryoverHoneyItems = "sf_carryover_honey_items"
        static let carryoverVestItems = "sf_carryover_vest_items"
        static let carryoverCrossItems = "sf_carryover_cross_items"
        static let carryoverSwatterItems = "sf_carryover_swatter_items"
        static let carryoverAxeItems = "sf_carryover_axe_items"
    }
    
    private init() {}
    
    // MARK: - Coins
    
    var totalCoins: Int {
        return defaults.integer(forKey: Keys.totalCoins)
    }
    
    func addCoins(_ amount: Int) {
        let newTotal = totalCoins + amount
        defaults.set(newTotal, forKey: Keys.totalCoins)
    }
    
    func spendCoins(_ amount: Int) -> Bool {
        if totalCoins >= amount {
            let newTotal = totalCoins - amount
            defaults.set(newTotal, forKey: Keys.totalCoins)
            return true
        }
        return false
    }
    
    // MARK: - Consumables
    
    var honeyItems: Int {
        return defaults.integer(forKey: Keys.honeyItems)
    }

    func addHoneyItems(_ amount: Int) {
        let newTotal = honeyItems + amount
        defaults.set(newTotal, forKey: Keys.honeyItems)
    }

    func useHoneyItem() -> Bool {
        if honeyItems > 0 {
            defaults.set(honeyItems - 1, forKey: Keys.honeyItems)
            return true
        }
        return false
    }

    var vestItems: Int {
        return defaults.integer(forKey: Keys.vestItems)
    }

    func addVestItems(_ amount: Int) {
        let newTotal = vestItems + amount
        defaults.set(newTotal, forKey: Keys.vestItems)
    }

    func useVestItem() -> Bool {
        if vestItems > 0 {
            defaults.set(vestItems - 1, forKey: Keys.vestItems)
            return true
        }
        return false
    }
    
    var crossItems: Int {
        return defaults.integer(forKey: Keys.crossItems)
    }
    
    func addCrossItems(_ amount: Int) {
        let newTotal = crossItems + amount
        defaults.set(newTotal, forKey: Keys.crossItems)
    }
    
    func useCrossItem() -> Bool {
        if crossItems > 0 {
            defaults.set(crossItems - 1, forKey: Keys.crossItems)
            return true
        }
        return false
    }
    
    var swatterItems: Int {
        return defaults.integer(forKey: Keys.swatterItems)
    }
    
    func addSwatterItems(_ amount: Int) {
        let newTotal = swatterItems + amount
        defaults.set(newTotal, forKey: Keys.swatterItems)
    }
    
    func useSwatterItem() -> Bool {
        if swatterItems > 0 {
            defaults.set(swatterItems - 1, forKey: Keys.swatterItems)
            return true
        }
        return false
    }
    
    var axeItems: Int {
        return defaults.integer(forKey: Keys.axeItems)
    }
    
    func addAxeItems(_ amount: Int) {
        let newTotal = axeItems + amount
        defaults.set(newTotal, forKey: Keys.axeItems)
    }
    
    func useAxeItem() -> Bool {
        if axeItems > 0 {
            defaults.set(axeItems - 1, forKey: Keys.axeItems)
            return true
        }
        return false
    }
    
    // MARK: - Upgrades
    
    
    var jumpLevel: Int {
        let level = defaults.integer(forKey: Keys.jumpLevel)
        return max(1, level) // Default to level 1
    }
    
    func upgradeJump() {
        let next = jumpLevel + 1
        defaults.set(next, forKey: Keys.jumpLevel)
    }
    
    var healthLevel: Int {
        let level = defaults.integer(forKey: Keys.healthLevel)
        return max(1, level)
    }
    
    func upgradeHealth() {
        let next = healthLevel + 1
        defaults.set(next, forKey: Keys.healthLevel)
    }
    
    // NEW: Log Jumper Persistence
    var hasLogJumper: Bool {
        return defaults.bool(forKey: Keys.logJumper)
    }
    
    var hasCannonJump: Bool {
        return defaults.bool(forKey: Keys.cannonJump)
    }
    
    
    
    func unlockLogJumper() {
        defaults.set(true, forKey: Keys.logJumper)
    }
    
    func unlockCannonJump() {
        defaults.set(true, forKey: Keys.cannonJump)
    }
    
    // NEW: Super Jump Persistence
    var hasSuperJump: Bool {
        return defaults.bool(forKey: Keys.superJump)
    }
    
    func unlockSuperJump() {
        defaults.set(true, forKey: Keys.superJump)
    }
    
    // NEW: Rocket Jump Persistence
    var hasRocketJump: Bool {
        return defaults.bool(forKey: Keys.rocketJump)
    }
    
    func unlockRocketJump() {
        defaults.set(true, forKey: Keys.rocketJump)
    }
    
    // MARK: - Permanent Power-Up Upgrades
    
    var hasDoubleSuperJumpTime: Bool {
        return defaults.bool(forKey: Keys.doubleSuperJumpTime)
    }
    
    func unlockDoubleSuperJumpTime() {
        defaults.set(true, forKey: Keys.doubleSuperJumpTime)
    }
    
    var hasDoubleRocketTime: Bool {
        return defaults.bool(forKey: Keys.doubleRocketTime)
    }
    
    func unlockDoubleRocketTime() {
        defaults.set(true, forKey: Keys.doubleRocketTime)
    }
    
    // MARK: - Help Tutorial
    
    var hasSeenHelp: Bool {
        return defaults.bool(forKey: Keys.hasSeenHelp)
    }
    
    func markHelpAsSeen() {
        defaults.set(true, forKey: Keys.hasSeenHelp)
    }
    
    // MARK: - Tutorial Overlay
    
    var hasSeenTutorial: Bool {
        return defaults.bool(forKey: Keys.hasSeenTutorial)
    }
    
    func markTutorialAsSeen() {
        defaults.set(true, forKey: Keys.hasSeenTutorial)
    }
    
    // MARK: - High Score
    
    var highScore: Int {
        return defaults.integer(forKey: Keys.highScore)
    }
    
    func saveScore(_ score: Int) -> Bool {
        if score > highScore {
            defaults.set(score, forKey: Keys.highScore)
            return true
        }
        return false
    }
    
    // MARK: - Highest Combo
    
    var highestCombo: Int {
        return defaults.integer(forKey: Keys.highestCombo)
    }
    
    func saveCombo(_ combo: Int) -> Bool {
        if combo > highestCombo {
            defaults.set(combo, forKey: Keys.highestCombo)
            return true
        }
        return false
    }
    
    // MARK: - 4-Pack Carryover System
    
    /// Tracks remaining items from 4-packs when starting a run
    /// Call this when an upgrade is selected to deduct from the total and track carryover
    func usePackItem(type: String) {
        switch type {
        case "HONEY":
            // Check if we already have carryover items from a previous run
            var carryover = defaults.integer(forKey: Keys.carryoverHoneyItems)
            if carryover > 0 {
                // Use one from carryover and decrease the carryover count
                carryover -= 1
                defaults.set(carryover, forKey: Keys.carryoverHoneyItems)
            } else if honeyItems > 0 {
                // No carryover, start a new pack: deduct 1 from total inventory and save 3 for carryover
                defaults.set(honeyItems - 1, forKey: Keys.honeyItems)
                defaults.set(3, forKey: Keys.carryoverHoneyItems)
            }
            
        case "VEST":
            var carryover = defaults.integer(forKey: Keys.carryoverVestItems)
            if carryover > 0 {
                carryover -= 1
                defaults.set(carryover, forKey: Keys.carryoverVestItems)
            } else if vestItems > 0 {
                defaults.set(vestItems - 1, forKey: Keys.vestItems)
                defaults.set(3, forKey: Keys.carryoverVestItems)
            }
            
        case "CROSS":
            var carryover = defaults.integer(forKey: Keys.carryoverCrossItems)
            if carryover > 0 {
                carryover -= 1
                defaults.set(carryover, forKey: Keys.carryoverCrossItems)
            } else if crossItems > 0 {
                defaults.set(crossItems - 1, forKey: Keys.crossItems)
                defaults.set(3, forKey: Keys.carryoverCrossItems)
            }
            
        case "SWATTER":
            var carryover = defaults.integer(forKey: Keys.carryoverSwatterItems)
            if carryover > 0 {
                carryover -= 1
                defaults.set(carryover, forKey: Keys.carryoverSwatterItems)
            } else if swatterItems > 0 {
                defaults.set(swatterItems - 1, forKey: Keys.swatterItems)
                defaults.set(3, forKey: Keys.carryoverSwatterItems)
            }
            
        case "AXE":
            var carryover = defaults.integer(forKey: Keys.carryoverAxeItems)
            if carryover > 0 {
                carryover -= 1
                defaults.set(carryover, forKey: Keys.carryoverAxeItems)
            } else if axeItems > 0 {
                defaults.set(axeItems - 1, forKey: Keys.axeItems)
                defaults.set(3, forKey: Keys.carryoverAxeItems)
            }
            
        default:
            break
        }
    }
    
    /// Returns the number of carryover items for a given type
    func getCarryoverItems(type: String) -> Int {
        switch type {
        case "HONEY": return defaults.integer(forKey: Keys.carryoverHoneyItems)
        case "VEST": return defaults.integer(forKey: Keys.carryoverVestItems)
        case "CROSS": return defaults.integer(forKey: Keys.carryoverCrossItems)
        case "SWATTER": return defaults.integer(forKey: Keys.carryoverSwatterItems)
        case "AXE": return defaults.integer(forKey: Keys.carryoverAxeItems)
        default: return 0
        }
    }
    
    /// Restores carryover items back to the inventory (called when run ends)
    func restoreCarryoverItems() {
        // Honey
        let carryoverHoney = defaults.integer(forKey: Keys.carryoverHoneyItems)
        if carryoverHoney > 0 {
            defaults.set(honeyItems + carryoverHoney, forKey: Keys.honeyItems)
            defaults.set(0, forKey: Keys.carryoverHoneyItems)
        }
        
        // Vest
        let carryoverVest = defaults.integer(forKey: Keys.carryoverVestItems)
        if carryoverVest > 0 {
            defaults.set(vestItems + carryoverVest, forKey: Keys.vestItems)
            defaults.set(0, forKey: Keys.carryoverVestItems)
        }
        
        // Cross
        let carryoverCross = defaults.integer(forKey: Keys.carryoverCrossItems)
        if carryoverCross > 0 {
            defaults.set(crossItems + carryoverCross, forKey: Keys.crossItems)
            defaults.set(0, forKey: Keys.carryoverCrossItems)
        }
        
        // Swatter
        let carryoverSwatter = defaults.integer(forKey: Keys.carryoverSwatterItems)
        if carryoverSwatter > 0 {
            defaults.set(swatterItems + carryoverSwatter, forKey: Keys.swatterItems)
            defaults.set(0, forKey: Keys.carryoverSwatterItems)
        }
        
        // Axe
        let carryoverAxe = defaults.integer(forKey: Keys.carryoverAxeItems)
        if carryoverAxe > 0 {
            defaults.set(axeItems + carryoverAxe, forKey: Keys.axeItems)
            defaults.set(0, forKey: Keys.carryoverAxeItems)
        }
    }
    
    /// Clears all carryover items without restoring (use if player uses all items in a run)
    func clearCarryoverItems() {
        defaults.set(0, forKey: Keys.carryoverHoneyItems)
        defaults.set(0, forKey: Keys.carryoverVestItems)
        defaults.set(0, forKey: Keys.carryoverCrossItems)
        defaults.set(0, forKey: Keys.carryoverSwatterItems)
        defaults.set(0, forKey: Keys.carryoverAxeItems)
    }
}
