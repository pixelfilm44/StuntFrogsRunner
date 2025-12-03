import UIKit
import SpriteKit

/// Centralized configuration for game balance, physics, and assets.
struct Configuration {
    
    struct Physics {
        static let gravityZ: CGFloat = 0.8
        static let frictionGround: CGFloat = 0.8
        static let frictionAir: CGFloat = 0.90
        static let baseJumpZ: CGFloat = 4.0
        static let maxDragDistance: CGFloat = 150.0  // Reduced from 150 - shorter drag needed for full power
        
        static func dragPower(level: Int) -> CGFloat {
            return 0.12 + (CGFloat(level) * 0.0075)  // 0.08 orig
        }
    }
    
    struct Dimensions {
        static let riverWidth: CGFloat = 600.0
        static let minPadRadius: CGFloat = 45.0
        static let maxPadRadius: CGFloat = 105.0
        static let padSpacing: CGFloat = 10.0  // Minimum gap between lily pads
        static let frogRadius: CGFloat = 20.0
        
        /// Generates a random pad radius between min and max
        static func randomPadRadius() -> CGFloat {
            return CGFloat.random(in: minPadRadius...maxPadRadius)
        }
    }
    
    struct Colors {
        static let sunny = SKColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1)
        static let rain = SKColor(red: 44/255, green: 62/255, blue: 80/255, alpha: 1)
        static let night = SKColor(red: 12/255, green: 21/255, blue: 32/255, alpha: 1)
        static let winter = SKColor(red: 160/255, green: 190/255, blue: 220/255, alpha: 1)
        static let desert = SKColor(red: 240/255, green: 210/255, blue: 120/255, alpha: 1) // Sandy sky for desert
        static let blackVoid = SKColor.black // Instant death water for desert
    }
    
    /// Centralized font configuration for all UI elements
    ///
    /// Usage examples:
    /// ```swift
    /// // SpriteKit (SKLabelNode)
    /// let label = SKLabelNode(fontNamed: Configuration.Fonts.hudScore.name)
    /// label.fontSize = Configuration.Fonts.hudScore.size
    ///
    /// // UIKit
    /// label.font = Configuration.Fonts.menuTitle
    /// button.titleLabel?.font = Configuration.Fonts.shopBackButton
    /// ```
    struct Fonts {
        // MARK: - Font Names
        static let primaryBold = "Nunito-Bold"
        static let primaryHeavy = "Fredoka-Bold"
        static let cardHeader = "Nunito-ExtraBold"

        
        
        // MARK: - SpriteKit Fonts (SKLabelNode)
        
        /// Primary HUD score display
        static let hudScore: (name: String, size: CGFloat) = (primaryBold, 36)
        
        /// Coin counter in HUD
        static let hudCoins: (name: String, size: CGFloat) = (primaryBold, 24)
        
        /// Descend button
        static let descendButton: (name: String, size: CGFloat) = (primaryBold, 24)
        
        /// Pause icon
        static let pauseIcon: (name: String, size: CGFloat) = (primaryHeavy, 24)
        
        /// Achievement card title
        static let achievementTitle: (name: String, size: CGFloat) = (primaryHeavy, 16)
        
        /// Achievement card name
        static let achievementName: (name: String, size: CGFloat) = (primaryBold, 18)
        
        /// Power-up/buff indicator labels
        static let buffIndicator: (name: String, size: CGFloat) = (primaryBold, 14)
        
        /// Healing indicator (+❤️)
        static let healingIndicator: (name: String, size: CGFloat) = (primaryHeavy, 28)
        
        /// Treasure chest reward display
        static let treasureReward: (name: String, size: CGFloat) = (primaryHeavy, 24)
        
        /// Coin collection reward (+⭐️)
        static let coinReward: (name: String, size: CGFloat) = (primaryHeavy, 28)
        
        // MARK: - UIKit Fonts
        
        /// Menu screen title (STUNT FROG SUPERSTAR)
        static let menuTitle: (name: String, size: CGFloat) = (primaryBold, 46)
        
        /// Menu screen stats text
        static let menuStats = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        /// Play button
        static let menuPlayButton: (name: String, size: CGFloat) = (primaryBold, 36)
        
        /// Shop, Leaderboard, Challenges buttons
        static let menuSecondaryButton = UIFont.systemFont(ofSize: 24, weight: .bold)
        
        /// Challenge badge notification
        static let menuChallengeBadge: (name: String, size: CGFloat) = (primaryBold, 14)
        
        /// Help button
        static let menuHelpButton = UIFont.systemFont(ofSize: 24, weight: .bold)
        
        /// Shop header (FROG SHOP)
        static let shopHeader: (name: String, size: CGFloat) = (primaryHeavy, 36)
        
        /// Shop coins counter
        static let shopCoins = UIFont.systemFont(ofSize: 20, weight: .bold)
        
        /// Shop upgrade card title
        static let shopCardTitle: (name: String, size: CGFloat) = (primaryHeavy, 20)
        
        /// Shop upgrade card cost
        static let shopCardCost = UIFont.systemFont(ofSize: 18, weight: .heavy)
        
        /// Shop upgrade button
        static let shopUpgradeButton = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        /// Shop badge (NEW, OWNED)
        static let shopBadge = UIFont.systemFont(ofSize: 10, weight: .bold)
        
        /// Shop level indicator
        static let shopLevelIndicator = UIFont.systemFont(ofSize: 9, weight: .bold)
        
        /// Shop section title
        static let shopSectionTitle = UIFont.systemFont(ofSize: 16, weight: .heavy)
        
        /// Shop back button
        static let shopBackButton = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        /// Challenges screen title
        static let challengesTitle : (name: String, size: CGFloat) = (primaryHeavy, 32)
        
        /// Challenges back button
        static let challengesBackButton = UIFont.systemFont(ofSize: 20, weight: .bold)
        
        /// Challenge card title
        static let challengeCardTitle = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        /// Challenge card description
        static let challengeCardDescription = UIFont.systemFont(ofSize: 14, weight: .regular)
        
        /// Challenge card progress
        static let challengeCardProgress = UIFont.systemFont(ofSize: 12, weight: .medium)
        
        /// Challenge card reward
        static let challengeCardReward = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        /// Challenge claim badge
        static let challengeClaimBadge = UIFont.systemFont(ofSize: 12, weight: .heavy)
        
        /// Game over screen title (WIPEOUT!)
        static let gameOverTitle : (name: String, size: CGFloat) = (primaryHeavy, 42)
        
        /// Game over score display
        static let gameOverScore = UIFont.systemFont(ofSize: 32, weight: .bold)
        
        /// Game over high score banner
        static let gameOverHighScore = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        /// Game over coins display
        static let gameOverCoins = UIFont.systemFont(ofSize: 18, weight: .medium)
        
        /// Game over retry/menu buttons
        static let gameOverButton = UIFont.systemFont(ofSize: 20, weight: .bold)
    }
    
    struct GameRules {
        static let coinsForUpgradeTrigger = 10
        static let rocketDuration: TimeInterval = 7.0
        static let rocketLandingDuration: TimeInterval = 5.0
        static let bootsDuration: TimeInterval = 5.0
        static let superJumpDuration: TimeInterval = 10.0
        
        // MARK: - Beat the Boat Challenge
        static let boatRaceFinishY: CGFloat = 10000.0 // 2000m * 10 score units/meter
        static let boatSpeed: CGFloat = 2.8 // Adjust for balanced difficulty
        static let boatRaceReward: Int = 100
        static let cannonJumpsPerRun = 3

        // MARK: - Weather-Specific Rules
        
        /// Determines if falling in water is instant death for a given weather type.
        static func isInstantDeathWater(for weather: WeatherType) -> Bool {
            return weather == .desert
        }
    }
    
    /// Progressive difficulty settings - scales every 500m traveled
    struct Difficulty {
        /// Distance interval (in score units) for difficulty increases
        static let scalingInterval: Int = 500
        
        /// Returns the current difficulty level (0 = easiest, increases every 500m)
        static func level(forScore score: Int) -> Int {
            return score / scalingInterval
        }
        
        // MARK: - Enemy Spawning
        
        /// Base probability of spawning an enemy (at level 0)
        static let baseEnemyProbability: Double = 0.15
        /// Additional enemy probability per difficulty level
        static let enemyProbabilityPerLevel: Double = 0.25
        /// Maximum enemy spawn probability
        static let maxEnemyProbability: Double = 0.65
        
        static func enemyProbability(forLevel level: Int) -> Double {
            return min(maxEnemyProbability, baseEnemyProbability + (Double(level) * enemyProbabilityPerLevel))
        }
        
        // MARK: - Log Spawning
        
        /// Difficulty level when logs start appearing
        static let logStartLevel: Int = 1
        /// Base probability of spawning a log (once unlocked)
        static let baseLogProbability: Double = 0.1
        /// Additional log probability per level after unlock
        static let logProbabilityPerLevel: Double = 0.05
        /// Maximum log spawn probability
        static let maxLogProbability: Double = 0.4
        
        static func logProbability(forLevel level: Int) -> Double {
            guard level >= logStartLevel else { return 0.0 }
            let effectiveLevel = level - logStartLevel
            return min(maxLogProbability, baseLogProbability + (Double(effectiveLevel) * logProbabilityPerLevel))
        }
        
        // MARK: - Enemy Types
        
        /// Difficulty level when dragonflies start appearing
        static let dragonflyStartLevel: Int = 2
        /// Probability of dragonfly (vs bee) once unlocked, scales with level
        static func dragonflyProbability(forLevel level: Int) -> Double {
            guard level >= dragonflyStartLevel else { return 0.0 }
            let effectiveLevel = level - dragonflyStartLevel
            return min(0.5, 0.2 + (Double(effectiveLevel) * 0.1))
        }
        
        // MARK: - Pad Types
        
        /// Difficulty level when moving pads start appearing
        static let movingPadStartLevel: Int = 1
        static let movingPadProbability: Double = 0.15
        
        /// Difficulty level when ice pads start appearing
        static let icePadStartLevel: Int = 2
        static let icePadProbability: Double = 0.1
        
        /// Difficulty level when shrinking pads start appearing
        static let shrinkingPadStartLevel: Int = 1
        /// Shrinking probability scales with level
        static func shrinkingProbability(forLevel level: Int) -> Double {
            guard level >= shrinkingPadStartLevel else { return 0.0 }
            let effectiveLevel = level - shrinkingPadStartLevel
            return min(0.35, 0.05 + (Double(effectiveLevel) * 0.05))
        }
        
        // MARK: - Crocodile Spawning
        
        /// Minimum score before crocodiles can appear
        static let crocodileMinScore: Int = 2500
        /// Maximum number of crocodiles that can appear in a single run
        static let crocodileMaxPerRun: Int = 2
        /// Probability of spawning a crocodile near a water lily pad. Zero in desert.
        static func crocodileSpawnProbability(for weather: WeatherType) -> Double {
            guard weather != .desert else { return 0.0 }
            return 0.15
        }
        
        // MARK: - Snake Spawning
        
        /// Minimum score before snakes can appear
        static let snakeStartScore: Int = 3000
        /// Base probability of spawning a snake (once unlocked)
        static let baseSnakeProbability: Double = 0.08
        /// Additional snake probability per level after unlock
        static let snakeProbabilityPerLevel: Double = 0.03
        /// Maximum snake spawn probability
        static let maxSnakeProbability: Double = 0.25
        /// Maximum snakes on screen at once
        static let snakeMaxOnScreen: Int = 3
        
        static func snakeProbability(forScore score: Int) -> Double {
            guard score >= snakeStartScore else { return 0.0 }
            let snakeStartLevel = snakeStartScore / scalingInterval
            let currentLevel = level(forScore: score)
            let effectiveLevel = currentLevel - snakeStartLevel
            return min(maxSnakeProbability, baseSnakeProbability + (Double(effectiveLevel) * snakeProbabilityPerLevel))
        }
        
        // MARK: - Cactus Spawning (Desert Only)
        
        /// Minimum score before cacti can appear in the desert
        static let cactusStartScore: Int = 2000
        /// Base probability of a cactus spawning on a lily pad (once unlocked)
        static let baseCactusProbability: Double = 0.10
        /// Additional cactus probability per difficulty level
        static let cactusProbabilityPerLevel: Double = 0.03
        /// Maximum cactus spawn probability
        static let maxCactusProbability: Double = 0.30
        
        /// Calculates the probability of a cactus spawning. Returns 0 if not in desert.
        static func cactusProbability(forScore score: Int, weather: WeatherType) -> Double {
            guard weather == .desert, score >= cactusStartScore else { return 0.0 }
            let cactusStartLevel = cactusStartScore / scalingInterval
            let currentLevel = level(forScore: score)
            let effectiveLevel = currentLevel - cactusStartLevel
            return min(maxCactusProbability, baseCactusProbability + (Double(effectiveLevel) * cactusProbabilityPerLevel))
        }
    }
    
    struct Shop {
        static let maxJumpLevel = 10
        static let maxHealthLevel = 5
        
        static func jumpUpgradeCost(currentLevel: Int) -> Int {
            return currentLevel * 100
        }
        
        static func healthUpgradeCost(currentLevel: Int) -> Int {
            return currentLevel * 250
        }
        
        static let logJumperCost = 300
        static let superJumpCost = 500
        static let rocketJumpCost = 500
        static let lifevest4PackCost = 500
        static let honey4PackCost = 500
        static let cannonJumpCost = 1000
    }
    
    struct GameCenter {
        static let leaderboardID = "TopScores"
    }
}

enum WeatherType: String, CaseIterable {
    case sunny, night, rain, winter, desert
}
