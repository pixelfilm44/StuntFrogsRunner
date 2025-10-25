//
//  GameConfig.swift
//  StuntFrogRunner iOS
//
//  Top-down lily pad hopping game
//

import CoreGraphics

struct GameConfig {
    // Landing precision settings
    // When enabled, the frog's trajectory is computed to end exactly at the aimed point.
    // No post-landing correction/recalibration should be applied by game logic.
    static let exactLandingEnabled: Bool = true
    
    // Maximum allowed difference (in points) between the computed landing point and the aimed point
    // during collision resolution. If exceeded, treat as a miss.
    static let landingAimTolerance: CGFloat = 2.0
    
    // If true, disable any code paths that "snap" or adjust the frog to the center of pads after landing.
    static let disablePostLandingSnap: Bool = true

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
    static let scrollSpeed: CGFloat = 0.6  // Constant upward scroll
    static let scrollSpeedWhileJumping: CGFloat = 4.0  // Faster when jumping
    static let rocketScrollSpeed: CGFloat = 8.0  // Fast scroll during rocket flight
    
    // Spawn rates (per frame)
    static let lilyPadSpawnRate: CGFloat = 0.006  // HIGH - need lots of landing spots!
    static let enemySpawnRate: CGFloat = 0.012
    static let tadpoleSpawnRate: CGFloat = 0.005
    static let logSpawnRate: CGFloat = 0.008
    
    // Enemy settings - all move on water surface
    static let snakeSpeed: CGFloat = 2.0
    static let beeSpeed: CGFloat = 1.5  // Bees hover and move
    static let dragonflySpeed: CGFloat = -2.5  // Moves up screen
    static let logSpeed: CGFloat = 2.5
    static let logBounceForce: CGFloat = 15.0
    
    // Game settings
    static let startingHealth: Int = 3
    static let tadpolesForAbility: Int = 5
    static let superJumpDurationFrames: Int = 420
    static let rocketDurationFrames: Int = 600  // 10 seconds at 60fps
    static let invincibleDurationFrames: Int = 90
    
    // Object sizes
    static let snakeSize: CGFloat = 45
    static let beeSize: CGFloat = 35
    static let dragonflySize: CGFloat = 40
    static let tadpoleSize: CGFloat = 30
    static let logWidth: CGFloat = 120
    static let logHeight: CGFloat = 25
    
    // Hitbox multipliers
    static let dragonflyHitboxMultiplier: CGFloat = 0.8  // Smaller hitbox for dragonflies
    
    // Lily pad settings - CRITICAL for landing!
    static let minLilyPadRadius: CGFloat = 45
    static let maxLilyPadRadius: CGFloat = 65
    static let lilyPadSpacing: CGFloat = 100  // Minimum distance between pads
}

// Game states
enum GameState {
    case menu
    case playing
    case paused
    case abilitySelection
    case gameOver
}

// Enemy types
enum EnemyType: String {
    case snake = "🐍"
    case bee = "🐝"
    case dragonfly = "🦟"
    case log = "🪵"
}



