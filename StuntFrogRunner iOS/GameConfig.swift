//
//  GameConfig.swift
//  StuntFrogRunner iOS
//
//  Top-down lily pad hopping game
//

import CoreGraphics
import Foundation

struct GameConfig {
    // Physics for top-down jumping
    static let jumpSpeed: CGFloat = 8.0  // How fast frog moves during jump
    static let launchMultiplier: CGFloat = 0.08
    static let superJumpMultiplier: CGFloat = 1.0
    static let maxPullDistance: CGFloat = 150
    static let minPullDistance: CGFloat = 50
    
    // Super Jump distance tuning (farther, not faster)
    static let maxPullDistanceSuperJump: CGFloat = 220
    static let superJumpDistanceMultiplier: CGFloat = 1.6
    
    // Reachability (world distance a regular jump can cover)
    static let maxRegularJumpDistance: CGFloat = GameConfig.maxPullDistance * 1.5
    static let maxSuperJumpDistance: CGFloat = GameConfig.maxPullDistanceSuperJump * 1.5 * GameConfig.superJumpDistanceMultiplier
    
    // Frog settings
    static let frogSize: CGFloat = 50
    static let frogShadowScale: CGFloat = 0.6  // Shadow shows "height"
    
    // Scroll settings - world moves UP, objects move DOWN
    // Ensure background never stops: enforce a minimum base speed
    static let minScrollSpeed: CGFloat = 0.4  // Hard floor to prevent halting
    static let scrollSpeed: CGFloat = 0.4  // Base constant scroll speed (must be >= minScrollSpeed)
    static let driftScrollSpeed: CGFloat = 0.3  // Target speed during drift (between min and base)
    static let scrollSpeedWhileJumping: CGFloat = 4.0  // Faster when jumping
    static let scrollSpeedIncrement: CGFloat = 0.15  // Speed increase every 2000 points
    static let maxScrollSpeed: CGFloat = 5.0  // Maximum scroll speed cap
    static let scoreIntervalForSpeedIncrease: Int = 2000  // Points needed for speed increase
    static let rocketScrollSpeed: CGFloat = 8.0  // Scroll speed during rocket mode
    static let rocketFinalApproachScrollSpeed: CGFloat = 4.0  // 50% speed during last 3 seconds
    static let rocketLandingSlowScrollSpeed: CGFloat = 1.0  // Temporary slow scroll to help landing
    
    // Spawn rates (per frame) - BALANCED for gameplay and performance
    static let lilyPadSpawnRate: CGFloat = 0.006  // Increased slightly to ensure enough lily pads for tadpoles
    static let enemySpawnRate: CGFloat = 0.4   // Increased from 0.008 to see more enemies
    static let tadpoleSpawnRate: CGFloat = 0.03   // Reduced to match lower lily pad availability
    static let logSpawnRate: CGFloat = 0.45      // Increased for better visibility
    
    // Enemy settings - all move on water surface
    static let snakeSpeed: CGFloat = 2.0
    static let beeSpeed: CGFloat = 1.20  // Bees hover and move
    static let dragonflySpeed: CGFloat = -3  // Moves up screen
    static let logSpeed: CGFloat = 0.5
    static let logBounceForce: CGFloat = 15.0
    static let chaserSpeed: CGFloat = 1.5  // Chaser moves towards frog
    
    // Game settings
    static let startingHealth: Int = 3
    static let tadpolesForAbility: Int = 10
    static let superJumpDurationFrames: Int = 420
    static let rocketDurationFrames: Int = 480  // 8 seconds at 60 fps (extended by 3s)
    static let invincibleDurationFrames: Int = 90
    
    // Ability selection safety
    static let abilitySelectionTimeoutSeconds: Double = 30.0  // Auto-clear stuck ability selection after 30s
    static let maxAbilitySelectionRetries: Int = 3  // Max retries before forcing clear
    
    
    // Object sizes
    static let snakeSize: CGFloat = 165
    static let beeSize: CGFloat = 30
    static let dragonflySize: CGFloat = 40
    static let spikeBushSize: CGFloat = 36
    static let chaserSize: CGFloat = 50  // Same size as frog
    static let tadpoleSize: CGFloat = 30
    static let tadpolePickupPadding: CGFloat = 6
    
    // Snake-specific collision dimensions (tighter vertical hit zone)
    static let snakeCollisionWidth: CGFloat = 165  // Keep full width
    static let snakeCollisionHeight: CGFloat = 80  // Reduced height for fairer gameplay
    
    // Edge spike bush settings
    static let edgeSpikeBushSize: CGFloat = 125
    static let edgeSpikeBushSpacing: CGFloat = 40  // Vertical spacing between edge spike bushes
    static let edgeSpikeBushMargin: CGFloat = -75   // Distance from screen edge
    static let logWidth: CGFloat = 110  // Visual width
    static let logHeight: CGFloat = 22  // Visual height
    // Use these for physics/collision checks to make logs feel fairer than their visuals
    static let logCollisionWidth: CGFloat = 90
    static let logCollisionHeight: CGFloat = 18
    
    // Lily pad settings - CRITICAL for landing!
    static let minLilyPadRadius: CGFloat = 65
    static let maxLilyPadRadius: CGFloat = 95
    static let lilyPadSpacing: CGFloat = 30  // Reduced slightly to allow more lily pads for tadpoles
    
    static let tadpolePerPadProbability: CGFloat = 0.6  // Reduced slightly to balance with increased lily pad density
    
    // Pulsing lily pad clustering prevention
    static let pulsingPadClusterRadius: CGFloat = 200.0  // Distance to check for nearby pulsing pads
    static let maxPulsingPadsInCluster: Int = 2  // Maximum pulsing pads allowed within cluster radius

    
    // Finish line settings
    static let finishLineWidth: CGFloat = 400
    static let finishLineHeight: CGFloat = 60
    static let finishLineDistance: CGFloat = 3000  // Distance above starting position where finish line appears
    
    // Landing behavior
    static let disablePostLandingSnap: Bool = true  // If true, frog stays where it lands; if false, snaps to pad center
    
    // Performance settings
    static let maxActiveLilyPads: Int = 30        // Maximum lily pads to keep active
    static let maxActiveEnemies: Int = 20          // Maximum enemies to keep active
    static let objectCleanupDistance: CGFloat = 1000  // Distance below frog to remove objects
    static let performanceCheckInterval: Int = 300  // Frames between performance checks (5 seconds at 60fps)
    
    // Persistent tadpole tracking
    static var tadpoleCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: "TadpoleCount")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TadpoleCount")
            UserDefaults.standard.synchronize()
        }
    }
    
    // Persistent upgrade variables
    static var bonusHearts: Int {
        get {
            let value = UserDefaults.standard.object(forKey: "BonusHearts") as? Int
            return value ?? 0  // Default to 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "BonusHearts")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var jumpBoost: Int {
        get {
            let value = UserDefaults.standard.object(forKey: "JumpBoost") as? Int
            return value ?? 1  // Default to 1
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "JumpBoost")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var jumpRecoil: Int {
        get {
            let value = UserDefaults.standard.object(forKey: "JumpRecoil") as? Int
            return value ?? 1  // Default to 1
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "JumpRecoil")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var superJumpBoost: Int {
        get {
            let value = UserDefaults.standard.object(forKey: "SuperJumpBoost") as? Int
            return value ?? 0  // Default to 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "SuperJumpBoost")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var powerJump: Int {
        get {
            let value = UserDefaults.standard.object(forKey: "PowerJump") as? Int
            return value ?? 0  // Default to 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "PowerJump")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var ghostBust: Int {
        get {
            let value = UserDefaults.standard.object(forKey: "GhostBust") as? Int
            return value ?? 0  // Default to 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "GhostBust")
            UserDefaults.standard.synchronize()
        }
    }
    
    // Helper methods for tadpole management
    static func addTadpole() {
        tadpoleCount += 1
        if enableDebugLogging {
            print("🐸 Tadpole collected! Total count: \(tadpoleCount)")
        }
    }
    
    static func addTadpoles(_ count: Int) {
        tadpoleCount += count
        if enableDebugLogging {
            print("🐸 \(count) tadpoles collected! Total count: \(tadpoleCount)")
        }
    }
    
    static func resetTadpoleCount() {
        tadpoleCount = 0
        if enableDebugLogging {
            print("🐸 Tadpole count reset to 0")
        }
    }
    
    // Helper methods for upgrade management
    static func resetAllUpgrades() {
        bonusHearts = 0
        jumpBoost = 1
        jumpRecoil = 1
        superJumpBoost = 0
        powerJump = 0
        ghostBust = 0
        tadpoleCount = 0
        if enableDebugLogging {
            print("🔄 All upgrades and tadpole count reset to defaults")
        }
    }
    
    static func printUpgradeStatus() {
        if enableDebugLogging {
            print("🎮 Current Upgrades:")
            print("   Tadpoles: \(tadpoleCount)")
            print("   Bonus Hearts: \(bonusHearts)")
            print("   Jump Boost: \(jumpBoost)")
            print("   Jump Recoil: \(jumpRecoil)")
            print("   Super Jump Boost: \(superJumpBoost)")
            print("   Power Jump: \(powerJump)")
            print("   Ghost Bust: \(ghostBust)")
        }
    }
    
    // Debug settings
    static let enableDebugLogging: Bool = false    // Set to false to reduce performance impact of logging
    static let enableAbilitySelectionDebug: Bool = true  // Debug ability selection state issues
    static let enableTadpoleSpawnDebug: Bool = false  // Debug tadpole spawning issues
    
    // Chaser settings
    static let chaserEnabledByDefault: Bool = true  // Whether Chaser is enabled by default
    static let chaserSpawnRate: CGFloat = 0.01  // Lower spawn rate for challenging enemy
    static let chaserTestMode: Bool = true  // Set to true to enable Chaser from the start for testing
    
    // Level-based enemy configuration
    static func getCurrentLevel(score: Int) -> Int {
        // Each level represents 5000 points
        return (score / 5000) + 1
    }
    
    // Score carryover settings
    static let enableScoreCarryover: Bool = true  // When true, score carries over between levels
    static let levelCompletionBonus: Int = 1000  // Bonus points awarded when completing a level
    
    // Level timer settings
    static let levelTimeLimit: Double = 300.0  // Time limit per level in seconds (5 minutes)
    static let timeBonus: Int = 50  // Points awarded per second remaining when completing level
    
    static func isChaserEnabled(forScore score: Int) -> Bool {
        // Enable for testing if test mode is on
        if chaserTestMode { return true }
        
        let level = getCurrentLevel(score: score)
        // Enable Chaser starting from level 3 (score 10000+)
        return level >= 3
    }
}




// Enemy types
enum EnemyType: String {
    case snake = "ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â"
    case bee = "ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â"
    case dragonfly = "ÃƒÂ°Ã…Â¸Ã‚Â¦Ã…Â¸"
    case log = "ÃƒÂ°Ã…Â¸Ã‚ÂªÃ‚Âµ"
    case spikeBush = "🌿"
    case edgeSpikeBush = "🌵"  // Different icon for edge spike bushes
    case chaser = "🖤"  // Black frog clone
}
