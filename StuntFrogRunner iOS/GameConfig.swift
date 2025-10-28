//
//  GameConfig.swift
//  StuntFrogRunner iOS
//
//  Top-down lily pad hopping game
//

import CoreGraphics

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
    
    // Spawn rates (per frame)
    static let lilyPadSpawnRate: CGFloat = 0.006  // HIGH - need lots of landing spots!
    static let enemySpawnRate: CGFloat = 0.012
    static let tadpoleSpawnRate: CGFloat = 0.018  // IMPROVED: Increased from 0.005 for better distribution
    static let logSpawnRate: CGFloat = 0.008
    
    // Enemy settings - all move on water surface
    static let snakeSpeed: CGFloat = 2.0
    static let beeSpeed: CGFloat = 1.5  // Bees hover and move
    static let dragonflySpeed: CGFloat = -2.5  // Moves up screen
    static let logSpeed: CGFloat = 0.5
    static let logBounceForce: CGFloat = 15.0
    
    // Game settings
    static let startingHealth: Int = 3
    static let tadpolesForAbility: Int = 5
    static let superJumpDurationFrames: Int = 420
    static let rocketDurationFrames: Int = 480  // 8 seconds at 60 fps (extended by 3s)
    static let invincibleDurationFrames: Int = 90
    
    // Object sizes
    static let snakeSize: CGFloat = 45
    static let beeSize: CGFloat = 35
    static let dragonflySize: CGFloat = 40
    static let tadpoleSize: CGFloat = 30
    static let logWidth: CGFloat = 110  // Visual width
    static let logHeight: CGFloat = 22  // Visual height
    // Use these for physics/collision checks to make logs feel fairer than their visuals
    static let logCollisionWidth: CGFloat = 90
    static let logCollisionHeight: CGFloat = 18
    
    // Lily pad settings - CRITICAL for landing!
    static let minLilyPadRadius: CGFloat = 45
    static let maxLilyPadRadius: CGFloat = 65
    static let lilyPadSpacing: CGFloat = 70  // Minimum distance between pads
    
    // Landing behavior
    static let disablePostLandingSnap: Bool = true  // If true, frog stays where it lands; if false, snaps to pad center
}



// Enemy types
enum EnemyType: String {
    case snake = "ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â"
    case bee = "ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â"
    case dragonfly = "ÃƒÂ°Ã…Â¸Ã‚Â¦Ã…Â¸"
    case log = "ÃƒÂ°Ã…Â¸Ã‚ÂªÃ‚Âµ"
}
