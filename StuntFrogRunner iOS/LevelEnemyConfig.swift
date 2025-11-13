//
//  LevelEnemyConfig.swift
//  StuntFrogRunner iOS
//
//  Level-based enemy spawn configuration system
//  Allows fine-tuned control over enemy types and spawn rates per level
//

import Foundation
import CoreGraphics

/// Configuration for enemy spawning behavior at a specific level
struct LevelEnemyConfig {
    let level: Int
    let scoreRange: ClosedRange<Int>
    let enemyConfigs: [EnemySpawnConfig]
    let globalSpawnRateMultiplier: CGFloat
    let maxEnemiesPerScreen: Int
    let specialRules: [SpecialSpawnRule]
    
    /// Initialize with level number (automatically calculates score range)
    init(level: Int, 
         enemyConfigs: [EnemySpawnConfig],
         globalSpawnRateMultiplier: CGFloat = 1.0,
         maxEnemiesPerScreen: Int = 20,
         specialRules: [SpecialSpawnRule] = []) {
        self.level = level
        // Each level spans 25,000 points (Level 1: 0-24999, Level 2: 25000-49999, etc.)
        let startScore = (level - 1) * 25000
        let endScore = level * 25000 - 1
        self.scoreRange = startScore...endScore
        self.enemyConfigs = enemyConfigs
        self.globalSpawnRateMultiplier = globalSpawnRateMultiplier
        self.maxEnemiesPerScreen = maxEnemiesPerScreen
        self.specialRules = specialRules
    }
}

/// Configuration for a specific enemy type's spawn behavior
struct EnemySpawnConfig {
    let enemyType: EnemyType
    let spawnRate: CGFloat           // Base spawn rate (0.0 to 1.0)
    let maxCount: Int                // Maximum of this enemy type on screen
    let canSpawnOnPads: Bool         // Whether this enemy can spawn on lily pads
    let canSpawnInWater: Bool        // Whether this enemy can spawn in water
    let minDistanceFromFrog: CGFloat // Minimum distance from frog when spawning
    let weight: CGFloat              // Relative probability weight when multiple enemies are available
    
    init(enemyType: EnemyType,
         spawnRate: CGFloat,
         maxCount: Int = 10,
         canSpawnOnPads: Bool = true,
         canSpawnInWater: Bool = true,
         minDistanceFromFrog: CGFloat = 100,
         weight: CGFloat = 1.0) {
        self.enemyType = enemyType
        self.spawnRate = spawnRate
        self.maxCount = maxCount
        self.canSpawnOnPads = canSpawnOnPads
        self.canSpawnInWater = canSpawnInWater
        self.minDistanceFromFrog = minDistanceFromFrog
        self.weight = weight
    }
}

/// Special spawn rules that can override normal behavior
enum SpecialSpawnRule {
    case noEnemiesNearFinishLine(distance: CGFloat)
    case increasedSpawnNearFinish(multiplier: CGFloat, distance: CGFloat)
    case guaranteedEnemyType(EnemyType, every: Int) // Guarantee spawn every N frames
    case bossWave(enemyType: EnemyType, count: Int, triggerScore: Int)
    case safeZone(radius: CGFloat, duration: TimeInterval) // No enemies in radius for duration
}

/// Central manager for level-based enemy spawn configurations
class LevelEnemyConfigManager {
    private static let shared = LevelEnemyConfigManager()
    private var levelConfigs: [Int: LevelEnemyConfig] = [:]
    
    private init() {
        // Load configurations from the easy-to-edit LevelConfigurations file
        levelConfigs = LevelConfigurations.getAllConfigurations()
    }
    
    static func getConfig(for level: Int) -> LevelEnemyConfig {
        return shared.levelConfigs[level] ?? shared.createFallbackConfig(for: level)
    }
    
    static func getConfig(forScore score: Int) -> LevelEnemyConfig {
        let level = (score / 25000) + 1
        return getConfig(for: level)
    }
    
    /// Get all enemy types that can spawn at the given level/score
    static func getAllowedEnemyTypes(for level: Int) -> [EnemyType] {
        let config = getConfig(for: level)
        return config.enemyConfigs.map { $0.enemyType }
    }
    
    /// Get spawn rate for a specific enemy type at the given level
    static func getSpawnRate(for enemyType: EnemyType, at level: Int) -> CGFloat {
        let config = getConfig(for: level)
        let enemyConfig = config.enemyConfigs.first { $0.enemyType == enemyType }
        return (enemyConfig?.spawnRate ?? 0.0) * config.globalSpawnRateMultiplier
    }
    
    /// Get maximum count for a specific enemy type at the given level
    static func getMaxCount(for enemyType: EnemyType, at level: Int) -> Int {
        let config = getConfig(for: level)
        let enemyConfig = config.enemyConfigs.first { $0.enemyType == enemyType }
        return enemyConfig?.maxCount ?? 0
    }
    
    /// Get weighted random enemy type selection for the given level
    static func getWeightedRandomEnemyType(for level: Int) -> EnemyType? {
        let config = getConfig(for: level)
        let totalWeight = config.enemyConfigs.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        
        let randomValue = CGFloat.random(in: 0.0..<totalWeight)
        var currentWeight: CGFloat = 0
        
        for enemyConfig in config.enemyConfigs {
            currentWeight += enemyConfig.weight
            if randomValue < currentWeight {
                return enemyConfig.enemyType
            }
        }
        
        return config.enemyConfigs.last?.enemyType
    }
    
    /// Check if an enemy type can spawn on lily pads at the given level
    static func canSpawnOnPads(enemyType: EnemyType, at level: Int) -> Bool {
        let config = getConfig(for: level)
        let enemyConfig = config.enemyConfigs.first { $0.enemyType == enemyType }
        return enemyConfig?.canSpawnOnPads ?? false
    }
    
    /// Check if an enemy type can spawn in water at the given level
    static func canSpawnInWater(enemyType: EnemyType, at level: Int) -> Bool {
        let config = getConfig(for: level)
        let enemyConfig = config.enemyConfigs.first { $0.enemyType == enemyType }
        return enemyConfig?.canSpawnInWater ?? false
    }
    
    
    /// Creates a fallback configuration for levels beyond the predefined ones
    private func createFallbackConfig(for level: Int) -> LevelEnemyConfig {
        return LevelConfigurations.createScaledConfiguration(for: level)
    }
}

// MARK: - Extensions for easier integration

extension LevelEnemyConfigManager {
    /// Get debug information about the current level configuration
    static func getDebugInfo(for level: Int) -> String {
        let config = getConfig(for: level)
        var info = "Level \(level) Enemy Config:\n"
        info += "  Score Range: \(config.scoreRange)\n"
        info += "  Global Multiplier: \(String(format: "%.1f", config.globalSpawnRateMultiplier))x\n"
        info += "  Max Enemies: \(config.maxEnemiesPerScreen)\n"
        info += "  Enemy Types:\n"
        
        for enemyConfig in config.enemyConfigs {
            let finalRate = enemyConfig.spawnRate * config.globalSpawnRateMultiplier
            info += "    \(enemyConfig.enemyType): rate=\(String(format: "%.2f", finalRate)), max=\(enemyConfig.maxCount), weight=\(String(format: "%.2f", enemyConfig.weight))\n"
        }
        
        if !config.specialRules.isEmpty {
            info += "  Special Rules: \(config.specialRules.count)\n"
        }
        
        return info
    }
    
    /// Print debug information for a range of levels
    static func printDebugInfo(for levels: ClosedRange<Int>) {
        for level in levels {
            print(getDebugInfo(for: level))
            print("---")
        }
    }
}
