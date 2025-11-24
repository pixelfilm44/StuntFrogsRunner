import UIKit
import SpriteKit

/// Centralized configuration for game balance, physics, and assets.
struct Configuration {
    
    struct Physics {
        static let gravityZ: CGFloat = 0.6
        static let frictionGround: CGFloat = 0.8
        static let frictionAir: CGFloat = 0.99
        static let baseJumpZ: CGFloat = 2.0
        static let maxDragDistance: CGFloat = 150.0
        
        static func dragPower(level: Int) -> CGFloat {
            return 0.08 + (CGFloat(level) * 0.0075)
        }
    }
    
    struct Dimensions {
        static let riverWidth: CGFloat = 600.0
        static let minPadRadius: CGFloat = 45.0
        static let maxPadRadius: CGFloat = 65.0
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
    }
    
    struct GameRules {
        static let coinsForUpgradeTrigger = 10
        static let rocketDuration: TimeInterval = 7.0
        static let rocketLandingDuration: TimeInterval = 5.0
        static let bootsDuration: TimeInterval = 5.0
        // NEW: SuperJump Duration
        static let superJumpDuration: TimeInterval = 10.0
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
        static let baseEnemyProbability: Double = 0.25
        /// Additional enemy probability per difficulty level
        static let enemyProbabilityPerLevel: Double = 0.65
        /// Maximum enemy spawn probability
        static let maxEnemyProbability: Double = 0.85
        
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
        /// Probability of spawning a crocodile near a water lily pad
        static let crocodileSpawnProbability: Double = 0.05
        
        // MARK: - Snake Spawning
        
        /// Difficulty level when snakes start appearing (level 2 = 1000m)
        static let snakeStartLevel: Int = 2
        /// Base probability of spawning a snake (once unlocked)
        static let baseSnakeProbability: Double = 0.08
        /// Additional snake probability per level after unlock
        static let snakeProbabilityPerLevel: Double = 0.03
        /// Maximum snake spawn probability
        static let maxSnakeProbability: Double = 0.25
        /// Maximum snakes on screen at once
        static let snakeMaxOnScreen: Int = 3
        
        static func snakeProbability(forLevel level: Int) -> Double {
            guard level >= snakeStartLevel else { return 0.0 }
            let effectiveLevel = level - snakeStartLevel
            return min(maxSnakeProbability, baseSnakeProbability + (Double(effectiveLevel) * snakeProbabilityPerLevel))
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
    }
    
    struct GameCenter {
        static let leaderboardID = "TopScores"
    }
}

enum WeatherType: String, CaseIterable {
    case sunny, rain, night, winter
}
