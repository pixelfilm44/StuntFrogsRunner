//
//  LevelConfigurations.swift
//  StuntFrogRunner iOS
//
//  Easy-to-edit level configurations for game designers
//  Modify these values to adjust enemy spawn rates and difficulty per level
//

import Foundation
import CoreGraphics

// WeatherType and WeatherGameplayEffect are now defined in GameObjects.swift
// This prevents duplicate type definitions that cause ambiguity errors

/// Weather configuration for levels
struct WeatherConfiguration {
    let weatherType: WeatherType
    let windStrength: CGFloat           // Wind force strength (0.0 to 1.0)
    let windDirection: CGFloat          // Wind direction in radians
    let slipDuration: TimeInterval      // How long frog slides on slippery pads
    let iceThickness: CGFloat           // Visual ice thickness
    let particleIntensity: CGFloat      // Rain/snow particle density
    
    init(weatherType: WeatherType,
         windStrength: CGFloat = 0.0,
         windDirection: CGFloat = 0.0,
         slipDuration: TimeInterval = 0.5,
         iceThickness: CGFloat = 1.0,
         particleIntensity: CGFloat = 1.0) {
        self.weatherType = weatherType
        self.windStrength = windStrength
        self.windDirection = windDirection
        self.slipDuration = slipDuration
        self.iceThickness = iceThickness
        self.particleIntensity = particleIntensity
    }
    
    /// Convenience initializer that automatically configures settings based on weather type
    /// This maintains compatibility with the original GameObjects.swift implementation
    init(weatherType: WeatherType) {
        self.weatherType = weatherType
        
        switch weatherType {
        case .day:
            windStrength = 0.0
            windDirection = 0.0
            slipDuration = 0.0
            iceThickness = 0.0
            particleIntensity = 0.0
        case .night:
            windStrength = 0.1
            windDirection = 0.0
            slipDuration = 0.0
            iceThickness = 0.0
            particleIntensity = 0.2
        case .rain:
            windStrength = 0.2
            windDirection = CGFloat.random(in: 0...(CGFloat.pi * 2))
            slipDuration = 1.5
            iceThickness = 0.0
            particleIntensity = 0.7
        case .winter:
            windStrength = 0.3
            windDirection = CGFloat.random(in: 0...(CGFloat.pi * 2))
            slipDuration = 2.0
            iceThickness = 1.0
            particleIntensity = 0.5
        case .ice:
            windStrength = 0.1
            windDirection = 0.0
            slipDuration = 2.5
            iceThickness = 1.5
            particleIntensity = 0.3
        case .stormy, .storm:
            windStrength = 0.6
            windDirection = CGFloat.random(in: 0...(CGFloat.pi * 2))
            slipDuration = 1.8
            iceThickness = 0.0
            particleIntensity = 0.9
        }
    }
}



/// Easy-to-edit level configurations
/// Each level defines exactly which enemies appear and how often
struct LevelConfigurations {
    
    /// Configure individual levels here - easy to read and modify!
    static func getAllConfigurations() -> [Int: LevelEnemyConfig] {
        
        // LEVEL 1 - Beginner Friendly (0-24,999 points)
        let level1 = LevelEnemyConfig(
            level: 1,
            enemyConfigs: [
                // Only bees in level 1 - gentle introduction
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.3, maxCount: 3, weight: 1.0)
            ],
            globalSpawnRateMultiplier: 0.8, // 20% slower spawn rate for beginners
            maxEnemiesPerScreen: 15,
            specialRules: [.safeZone(radius: 200, duration: 5.0)], // 5-second safe zone at start
            requiredTravelDistance: 4500 // Shorter distance for first level
        )
        
        // LEVEL 2 - Add Variety (25,000-49,999 points)  
        let level2 = LevelEnemyConfig(
            level: 2,
            enemyConfigs: [
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.4, maxCount: 4, weight: 0.7),       // 70% chance
                EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.2, maxCount: 3, weight: 0.3)  // 30% chance
            ],
            globalSpawnRateMultiplier: 1.0, // Normal spawn rate
            maxEnemiesPerScreen: 16,
            requiredTravelDistance: 5800
        )
        
        // LEVEL 3 - Ground Threats (50,000-74,999 points)
        let level3 = LevelEnemyConfig(
            level: 3,
            enemyConfigs: [
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.35, maxCount: 4, weight: 0.5),      // 50% chance
                EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.25, maxCount: 3, weight: 0.3), // 30% chance
                EnemySpawnConfig(enemyType: .snake, spawnRate: 0.15, maxCount: 4, canSpawnOnPads: false, weight: 0.2) // 20% chance, water only
            ],
            globalSpawnRateMultiplier: 1.1, // 10% faster spawn rate
            maxEnemiesPerScreen: 18,
            requiredTravelDistance: 7100
        )
        
        // LEVEL 4 - Spike Bushes (75,000-99,999 points)
        let level4 = LevelEnemyConfig(
            level: 4,
            enemyConfigs: [
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.3, maxCount: 4, weight: 0.4),       // 40% chance
                EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.3, maxCount: 4, weight: 0.3), // 30% chance  
                EnemySpawnConfig(enemyType: .snake, spawnRate: 0.2, maxCount: 2, canSpawnOnPads: false, weight: 0.2), // 20% chance
                EnemySpawnConfig(enemyType: .spikeBush, spawnRate: 0.1, maxCount: 3, canSpawnInWater: false, weight: 0.1) // 10% chance, pads only
            ],
            globalSpawnRateMultiplier: 1.2, // 20% faster spawn rate
            maxEnemiesPerScreen: 20,
            requiredTravelDistance: 7400
        )
        
        // LEVEL 5 - Edge Danger (100,000-124,999 points)
        let level5 = LevelEnemyConfig(
            level: 5,
            enemyConfigs: [
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.25, maxCount: 5, weight: 0.35),     // 35% chance
                EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.3, maxCount: 4, weight: 0.3), // 30% chance
                EnemySpawnConfig(enemyType: .snake, spawnRate: 0.25, maxCount: 3, canSpawnOnPads: false, weight: 0.2), // 20% chance
                EnemySpawnConfig(enemyType: .spikeBush, spawnRate: 0.15, maxCount: 3, canSpawnInWater: false, weight: 0.1), // 10% chance
                EnemySpawnConfig(enemyType: .edgeSpikeBush, spawnRate: 0.05, maxCount: 2, canSpawnOnPads: false, weight: 0.05) // 5% chance, edges only
            ],
            globalSpawnRateMultiplier: 1.3, // 30% faster spawn rate
            maxEnemiesPerScreen: 22,
            requiredTravelDistance: 8700
        )
        
        // LEVEL 6 - Floating Logs (125,000-149,999 points)
        let level6 = LevelEnemyConfig(
            level: 6,
            enemyConfigs: [
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.2, maxCount: 5, weight: 0.3),       // 30% chance
                EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.3, maxCount: 4, weight: 0.25), // 25% chance
                EnemySpawnConfig(enemyType: .snake, spawnRate: 0.25, maxCount: 3, canSpawnOnPads: false, weight: 0.2), // 20% chance
                EnemySpawnConfig(enemyType: .spikeBush, spawnRate: 0.2, maxCount: 4, canSpawnInWater: false, weight: 0.15), // 15% chance
                EnemySpawnConfig(enemyType: .edgeSpikeBush, spawnRate: 0.08, maxCount: 3, canSpawnOnPads: false, weight: 0.05), // 5% chance
                EnemySpawnConfig(enemyType: .log, spawnRate: 0.1, maxCount: 3, canSpawnOnPads: false, weight: 0.05) // 5% chance, water only
            ],
            globalSpawnRateMultiplier: 1.4, // 40% faster spawn rate
            maxEnemiesPerScreen: 24,
            requiredTravelDistance: 9000
        )
        
        // LEVEL 7 - Chasers Introduced (150,000-174,999 points)
        let level7 = LevelEnemyConfig(
            level: 7,
            enemyConfigs: [
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.18, maxCount: 5, weight: 0.25),     // 25% chance
                EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.25, maxCount: 4, weight: 0.22), // 22% chance
                EnemySpawnConfig(enemyType: .snake, spawnRate: 0.3, maxCount: 4, canSpawnOnPads: false, weight: 0.2), // 20% chance
                EnemySpawnConfig(enemyType: .spikeBush, spawnRate: 0.25, maxCount: 4, canSpawnInWater: false, weight: 0.15), // 15% chance
                EnemySpawnConfig(enemyType: .edgeSpikeBush, spawnRate: 0.1, maxCount: 3, canSpawnOnPads: false, weight: 0.08), // 8% chance
                EnemySpawnConfig(enemyType: .log, spawnRate: 0.15, maxCount: 4, canSpawnOnPads: false, weight: 0.08), // 8% chance
                EnemySpawnConfig(enemyType: .chaser, spawnRate: 0.02, maxCount: 1, weight: 0.02)   // 2% chance - very rare!
            ],
            globalSpawnRateMultiplier: 1.5, // 50% faster spawn rate
            maxEnemiesPerScreen: 26,
            specialRules: [
                .guaranteedEnemyType(.chaser, every: 600) // Guaranteed chaser every 10 seconds
            ],
            requiredTravelDistance: 9500
        )
        
        // LEVEL 8 - Maximum Challenge (175,000-199,999 points)
        let level8 = LevelEnemyConfig(
            level: 8,
            enemyConfigs: [
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.15, maxCount: 6, weight: 0.2),      // 20% chance
                EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.25, maxCount: 5, weight: 0.2), // 20% chance
                EnemySpawnConfig(enemyType: .snake, spawnRate: 0.35, maxCount: 5, canSpawnOnPads: false, weight: 0.22), // 22% chance
                EnemySpawnConfig(enemyType: .spikeBush, spawnRate: 0.3, maxCount: 5, canSpawnInWater: false, weight: 0.18), // 18% chance
                EnemySpawnConfig(enemyType: .edgeSpikeBush, spawnRate: 0.12, maxCount: 4, canSpawnOnPads: false, weight: 0.1), // 10% chance
                EnemySpawnConfig(enemyType: .log, spawnRate: 0.2, maxCount: 5, canSpawnOnPads: false, weight: 0.08), // 8% chance
                EnemySpawnConfig(enemyType: .chaser, spawnRate: 0.04, maxCount: 2, weight: 0.02)   // 2% chance
            ],
            globalSpawnRateMultiplier: 1.6, // 60% faster spawn rate
            maxEnemiesPerScreen: 28,
            specialRules: [
                .guaranteedEnemyType(.chaser, every: 480) // Guaranteed chaser every 8 seconds
            ],
            requiredTravelDistance: 10000
        )
        
        // Return all configured levels
        return [
            1: level1,
            2: level2, 
            3: level3,
            4: level4,
            5: level5,
            6: level6,
            7: level7,
            8: level8
        ]
    }
    
    /// Dynamic scaling for levels beyond 8
    static func createScaledConfiguration(for level: Int) -> LevelEnemyConfig {
        let scalingFactor = CGFloat(level - 8) * 0.1 // Each level beyond 8 increases difficulty by 10%
        let baseMultiplier: CGFloat = 1.6 + scalingFactor
        let baseTravelDistance: CGFloat = 3600 + (CGFloat(level - 8) * 300) // Increase by 300 units per level beyond 8
        
        return LevelEnemyConfig(
            level: level,
            enemyConfigs: [
                EnemySpawnConfig(enemyType: .bee, spawnRate: 0.1 + scalingFactor * 0.05, maxCount: 6, weight: 0.18),
                EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.2 + scalingFactor * 0.1, maxCount: 5, weight: 0.18),
                EnemySpawnConfig(enemyType: .snake, spawnRate: 0.3 + scalingFactor * 0.1, maxCount: 6, canSpawnOnPads: false, weight: 0.22),
                EnemySpawnConfig(enemyType: .spikeBush, spawnRate: 0.25 + scalingFactor * 0.1, maxCount: 6, canSpawnInWater: false, weight: 0.2),
                EnemySpawnConfig(enemyType: .edgeSpikeBush, spawnRate: 0.1 + scalingFactor * 0.05, maxCount: 5, canSpawnOnPads: false, weight: 0.12),
                EnemySpawnConfig(enemyType: .log, spawnRate: 0.15 + scalingFactor * 0.08, maxCount: 6, canSpawnOnPads: false, weight: 0.08),
                EnemySpawnConfig(enemyType: .chaser, spawnRate: 0.03 + scalingFactor * 0.02, maxCount: min(3, level - 6), weight: 0.02)
            ],
            globalSpawnRateMultiplier: baseMultiplier,
            maxEnemiesPerScreen: min(35, 28 + level - 8),
            specialRules: [
                .guaranteedEnemyType(.chaser, every: max(240, 480 - (level - 8) * 30)) // More frequent chasers in higher levels
            ],
            requiredTravelDistance: baseTravelDistance
        )
    }
}

/// Quick configuration presets for common scenarios
extension LevelConfigurations {
    
    /// Easy mode preset - reduces all spawn rates by 30%
    static func createEasyMode(for level: Int) -> LevelEnemyConfig {
        // Get base configuration for the level
        let allConfigs = LevelConfigurations.getAllConfigurations()
        let baseConfig = allConfigs[level] ?? LevelConfigurations.createScaledConfiguration(for: level)
        let easierConfigs = baseConfig.enemyConfigs.map { config in
            EnemySpawnConfig(
                enemyType: config.enemyType,
                spawnRate: config.spawnRate * 0.7, // 30% reduction
                maxCount: max(1, config.maxCount - 1), // Reduce max count by 1 (minimum 1)
                canSpawnOnPads: config.canSpawnOnPads,
                canSpawnInWater: config.canSpawnInWater,
                minDistanceFromFrog: config.minDistanceFromFrog,
                weight: config.weight
            )
        }
        
        return LevelEnemyConfig(
            level: level,
            enemyConfigs: easierConfigs,
            globalSpawnRateMultiplier: baseConfig.globalSpawnRateMultiplier * 0.8, // 20% reduction
            maxEnemiesPerScreen: max(10, baseConfig.maxEnemiesPerScreen - 5),
            specialRules: [], // Remove special rules in easy mode
            requiredTravelDistance: baseConfig.requiredTravelDistance * 0.8 // 20% less travel distance required
        )
    }
    
    /// Hard mode preset - increases all spawn rates by 50%
    static func createHardMode(for level: Int) -> LevelEnemyConfig {
        // Get base configuration for the level
        let allConfigs = LevelConfigurations.getAllConfigurations()
        let baseConfig = allConfigs[level] ?? LevelConfigurations.createScaledConfiguration(for: level)
        let harderConfigs = baseConfig.enemyConfigs.map { config in
            EnemySpawnConfig(
                enemyType: config.enemyType,
                spawnRate: config.spawnRate * 1.5, // 50% increase
                maxCount: config.maxCount + 2, // Add 2 to max count
                canSpawnOnPads: config.canSpawnOnPads,
                canSpawnInWater: config.canSpawnInWater,
                minDistanceFromFrog: config.minDistanceFromFrog,
                weight: config.weight
            )
        }
        
        return LevelEnemyConfig(
            level: level,
            enemyConfigs: harderConfigs,
            globalSpawnRateMultiplier: baseConfig.globalSpawnRateMultiplier * 1.3, // 30% increase
            maxEnemiesPerScreen: baseConfig.maxEnemiesPerScreen + 8,
            specialRules: baseConfig.specialRules + [
                .guaranteedEnemyType(.chaser, every: 300) // More frequent chasers
            ],
            requiredTravelDistance: baseConfig.requiredTravelDistance * 1.25 // 25% more travel distance required
        )
    }
    
    /// Testing preset - only specific enemy types for debugging
    static func createTestingMode(enemyTypes: [EnemyType], level: Int = 1) -> LevelEnemyConfig {
        let testConfigs = enemyTypes.map { enemyType in
            EnemySpawnConfig(
                enemyType: enemyType,
                spawnRate: 0.5, // High spawn rate for testing
                maxCount: 10,
                weight: 1.0 / CGFloat(enemyTypes.count) // Equal weight
            )
        }
        
        return LevelEnemyConfig(
            level: level,
            enemyConfigs: testConfigs,
            globalSpawnRateMultiplier: 2.0, // Double spawn rate for testing
            maxEnemiesPerScreen: 30,
            specialRules: [],
            requiredTravelDistance: 1000 // Short distance for testing
        )
    }
}

/// Weather-specific level configurations
extension LevelConfigurations {
    
    /// Create a level configuration with specific weather
    static func createWeatherConfiguration(for level: Int, weather: WeatherType) -> LevelEnemyConfig {
        // Get base configuration
        let allConfigs = LevelConfigurations.getAllConfigurations()
        var baseConfig = allConfigs[level] ?? LevelConfigurations.createScaledConfiguration(for: level)
        
        // Adjust enemy configurations based on weather
        let weatherAdjustedConfigs = baseConfig.enemyConfigs.map { config in
            adjustEnemyConfigForWeather(config, weather: weather)
        }
        
        return LevelEnemyConfig(
            level: level,
            enemyConfigs: weatherAdjustedConfigs,
            globalSpawnRateMultiplier: baseConfig.globalSpawnRateMultiplier * getWeatherSpawnMultiplier(for: weather),
            maxEnemiesPerScreen: baseConfig.maxEnemiesPerScreen,
            specialRules: baseConfig.specialRules + getWeatherSpecialRules(for: weather),
            requiredTravelDistance: baseConfig.requiredTravelDistance
        )
    }
    
    /// Get weather-specific configurations for all levels
    static func getAllWeatherConfigurations(weather: WeatherType) -> [Int: LevelEnemyConfig] {
        var weatherConfigs: [Int: LevelEnemyConfig] = [:]
        let baseConfigs = getAllConfigurations()
        
        for (level, _) in baseConfigs {
            weatherConfigs[level] = createWeatherConfiguration(for: level, weather: weather)
        }
        
        return weatherConfigs
    }
    
    // MARK: - Weather Helper Methods
    
    private static func getWeatherSpawnMultiplier(for weather: WeatherType) -> CGFloat {
        switch weather {
        case .day:
            return 1.0
        case .night:
            return 0.9   // Slightly fewer enemies in darkness
        case .winter:
            return 0.8   // Cold slows enemy activity
        case .rain:
            return 1.1   // Rain makes some enemies more active
        case .stormy:
            return 1.2   // Storm brings more dangerous conditions
        case .storm:
            return 1.2   // Storm brings more dangerous conditions
        case .ice:
            return 1.2   // Storm brings more dangerous conditions
        }
    }
    
    private static func adjustEnemyConfigForWeather(_ config: EnemySpawnConfig, weather: WeatherType) -> EnemySpawnConfig {
        switch weather {
        case .day:
            return config
            
        case .night:
            // Reduce visibility affects, slightly increase spawn rates for some enemies
            let nightMultiplier: CGFloat = config.enemyType == .chaser ? 1.2 : 1.0
            return EnemySpawnConfig(
                enemyType: config.enemyType,
                spawnRate: config.spawnRate * nightMultiplier,
                maxCount: config.maxCount,
                canSpawnOnPads: config.canSpawnOnPads,
                canSpawnInWater: config.canSpawnInWater,
                minDistanceFromFrog: config.minDistanceFromFrog * 0.8, // Enemies can get closer in darkness
                weight: config.weight
            )
            
        case .winter:
            // Ice affects water-based enemies
            let canSpawnInWater = config.enemyType == .snake ? false : config.canSpawnInWater
            return EnemySpawnConfig(
                enemyType: config.enemyType,
                spawnRate: config.spawnRate * 0.9, // Cold slows spawning slightly
                maxCount: config.maxCount,
                canSpawnOnPads: config.canSpawnOnPads,
                canSpawnInWater: canSpawnInWater,
                minDistanceFromFrog: config.minDistanceFromFrog,
                weight: config.weight
            )
            
        case .rain:
            // Rain affects flying enemies differently
            let rainMultiplier: CGFloat
            switch config.enemyType {
            case .bee, .dragonfly:
                rainMultiplier = 0.7  // Flying enemies struggle in rain
            case .snake:
                rainMultiplier = 1.3  // Snakes more active in rain
            default:
                rainMultiplier = 1.0
            }
            
            return EnemySpawnConfig(
                enemyType: config.enemyType,
                spawnRate: config.spawnRate * rainMultiplier,
                maxCount: config.maxCount,
                canSpawnOnPads: config.canSpawnOnPads,
                canSpawnInWater: config.canSpawnInWater,
                minDistanceFromFrog: config.minDistanceFromFrog,
                weight: config.weight
            )
        
        case .storm:
            // Storm affects all enemies
            let stormMultiplier: CGFloat
            switch config.enemyType {
            case .bee, .dragonfly:
                stormMultiplier = 0.6  // Flying enemies really struggle in storms
            case .chaser:
                stormMultiplier = 1.4  // Chasers are more aggressive in storms
            default:
                stormMultiplier = 1.1
            }
            
            return EnemySpawnConfig(
                enemyType: config.enemyType,
                spawnRate: config.spawnRate * stormMultiplier,
                maxCount: config.maxCount,
                canSpawnOnPads: config.canSpawnOnPads,
                canSpawnInWater: config.canSpawnInWater,
                minDistanceFromFrog: config.minDistanceFromFrog * 0.9,
                weight: config.weight
            )
            
        case .ice:
            // Storm affects all enemies
            let stormMultiplier: CGFloat
            switch config.enemyType {
            case .bee, .dragonfly:
                stormMultiplier = 0.6  // Flying enemies really struggle in storms
            case .chaser:
                stormMultiplier = 1.4  // Chasers are more aggressive in storms
            default:
                stormMultiplier = 1.1
            }
            
            return EnemySpawnConfig(
                enemyType: config.enemyType,
                spawnRate: config.spawnRate * stormMultiplier,
                maxCount: config.maxCount,
                canSpawnOnPads: config.canSpawnOnPads,
                canSpawnInWater: config.canSpawnInWater,
                minDistanceFromFrog: config.minDistanceFromFrog * 0.9,
                weight: config.weight
            )
            
        case .stormy:
            // Storm affects all enemies
            let stormMultiplier: CGFloat
            switch config.enemyType {
            case .bee, .dragonfly:
                stormMultiplier = 0.6  // Flying enemies really struggle in storms
            case .chaser:
                stormMultiplier = 1.4  // Chasers are more aggressive in storms
            default:
                stormMultiplier = 1.1
            }
            
            return EnemySpawnConfig(
                enemyType: config.enemyType,
                spawnRate: config.spawnRate * stormMultiplier,
                maxCount: config.maxCount,
                canSpawnOnPads: config.canSpawnOnPads,
                canSpawnInWater: config.canSpawnInWater,
                minDistanceFromFrog: config.minDistanceFromFrog * 0.9,
                weight: config.weight
            )
        }
    }
    
    private static func getWeatherSpecialRules(for weather: WeatherType) -> [SpecialSpawnRule] {
        switch weather {
        case .day, .night:
            return []
            
        case .winter:
            return [
                .guaranteedEnemyType(.spikeBush, every: 450) // More spike bushes on icy ground
            ]
            
        case .ice:
            return [
                .guaranteedEnemyType(.spikeBush, every: 450) // More spike bushes on icy ground
            ]
            
        case .rain:
            return [
                .guaranteedEnemyType(.snake, every: 360) // Snakes love rain
            ]
            
        case .stormy:
            return [
                .guaranteedEnemyType(.chaser, every: 300) // More frequent chasers in storms
            ]
        case .storm:
            return [
                .guaranteedEnemyType(.chaser, every: 300) // More frequent chasers in storms
            ]
        }
    }
}
