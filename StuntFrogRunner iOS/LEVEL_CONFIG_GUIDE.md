# Level-Based Enemy Configuration System

## Overview

The Level-Based Enemy Configuration System provides fine-grained control over enemy spawn behavior across different game levels. Instead of using simple score-based thresholds, this system allows you to configure exactly which enemies appear, how often they spawn, and their behavioral constraints for each level.

## Quick Start

### Configuring Enemy Spawn Rates

The easiest way to modify enemy behavior is through the `LevelConfigurations.swift` file. Each level is defined with:

```swift
let level1 = LevelEnemyConfig(
    level: 1,
    enemyConfigs: [
        // Only bees in level 1 - gentle introduction
        EnemySpawnConfig(enemyType: .bee, spawnRate: 0.3, maxCount: 3, weight: 1.0)
    ],
    globalSpawnRateMultiplier: 0.8, // 20% slower spawn rate
    maxEnemiesPerScreen: 15,
    specialRules: [.safeZone(radius: 200, duration: 5.0)]
)
```

### Key Configuration Parameters

#### EnemySpawnConfig Parameters:
- **spawnRate**: Base probability (0.0-1.0) that this enemy will spawn
- **maxCount**: Maximum number of this enemy type on screen at once
- **canSpawnOnPads**: Whether enemy can appear on lily pads
- **canSpawnInWater**: Whether enemy can appear in water areas
- **weight**: Relative probability when multiple enemies are eligible (higher = more likely)

#### LevelEnemyConfig Parameters:
- **globalSpawnRateMultiplier**: Scales all spawn rates for this level
- **maxEnemiesPerScreen**: Total enemy limit for performance
- **specialRules**: Advanced behaviors like safe zones or guaranteed spawns

## Example Configurations

### Beginner Level (Easy)
```swift
enemyConfigs: [
    EnemySpawnConfig(enemyType: .bee, spawnRate: 0.3, maxCount: 3, weight: 1.0)
],
globalSpawnRateMultiplier: 0.8  // 20% slower
```

### Intermediate Level
```swift
enemyConfigs: [
    EnemySpawnConfig(enemyType: .bee, spawnRate: 0.35, maxCount: 4, weight: 0.5),      // 50% chance
    EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.25, maxCount: 3, weight: 0.3), // 30% chance
    EnemySpawnConfig(enemyType: .snake, spawnRate: 0.15, maxCount: 2, canSpawnOnPads: false, weight: 0.2) // 20% chance, water only
],
globalSpawnRateMultiplier: 1.1  // 10% faster
```

### Advanced Level (Challenging)
```swift
enemyConfigs: [
    EnemySpawnConfig(enemyType: .bee, spawnRate: 0.15, maxCount: 6, weight: 0.2),
    EnemySpawnConfig(enemyType: .dragonfly, spawnRate: 0.25, maxCount: 5, weight: 0.2),
    EnemySpawnConfig(enemyType: .snake, spawnRate: 0.35, maxCount: 5, canSpawnOnPads: false, weight: 0.22),
    EnemySpawnConfig(enemyType: .spikeBush, spawnRate: 0.3, maxCount: 5, canSpawnInWater: false, weight: 0.18),
    EnemySpawnConfig(enemyType: .chaser, spawnRate: 0.04, maxCount: 2, weight: 0.02)
],
globalSpawnRateMultiplier: 1.6  // 60% faster
```

## Enemy Types and Constraints

### Movement Constraints:
- **Bees**: Can spawn anywhere (pads + water)
- **Dragonflies**: Can spawn anywhere 
- **Snakes**: Water only (`canSpawnOnPads: false`)
- **Spike Bushes**: Pads only (`canSpawnInWater: false`)
- **Edge Spike Bushes**: Edges only (`canSpawnOnPads: false`)
- **Logs**: Water only (`canSpawnOnPads: false`)
- **Chasers**: Can spawn anywhere (special AI behavior)

## Special Rules

### Available Special Rules:
```swift
.safeZone(radius: 200, duration: 5.0)  // No enemies within radius for duration
.guaranteedEnemyType(.chaser, every: 600)  // Force spawn every N frames
.noEnemiesNearFinishLine(distance: 300)  // Clear area near finish line
.increasedSpawnNearFinish(multiplier: 2.0, distance: 500)  // Intensify near finish
```

## Quick Configuration Examples

### Make Level Easier:
```swift
// Reduce spawn rates by 30%
spawnRate: originalRate * 0.7

// Reduce max counts
maxCount: max(1, originalMaxCount - 1)

// Slower overall pace
globalSpawnRateMultiplier: 0.8
```

### Make Level Harder:
```swift
// Increase spawn rates by 50%
spawnRate: originalRate * 1.5

// Increase max counts
maxCount: originalMaxCount + 2

// Faster overall pace  
globalSpawnRateMultiplier: 1.3
```

### Testing Specific Enemies:
```swift
// Use testing preset for specific enemy types
let testConfig = LevelConfigurations.createTestingMode(
    enemyTypes: [.bee, .snake], 
    level: 1
)
```

## Debugging and Testing

### Debug Methods Available:
```swift
// In GameScene, call these methods for testing:
debugLevelInfo()  // Shows current level configuration
debugPreviewLevels(range: 1...5)  // Preview multiple level configs
debugSetLevel(3)  // Jump to specific level for testing
debugCurrentLevelEnemyRates()  // Show all enemy spawn rates
```

### Console Output:
The system provides detailed logging when enemies spawn:
```
🐛 DEBUG Level 3: baseChance=0.320, globalMultiplier=1.1x, finalChance=0.352
🐛 Available enemy types: [bee, dragonfly, snake]
🐛 Spawned dragonfly on new pad at (245, 1240)
```

## Level Progression

### Score-Based Levels:
- Level 1: 0-24,999 points
- Level 2: 25,000-49,999 points  
- Level 3: 50,000-74,999 points
- Level 4: 75,000-99,999 points
- And so on...

### Dynamic Scaling:
For levels beyond 8, the system automatically creates scaled configurations:
```swift
// Each level beyond 8 increases difficulty by 10%
let scalingFactor = CGFloat(level - 8) * 0.1
let baseMultiplier: CGFloat = 1.6 + scalingFactor
```

## Advanced Customization

### Creating Custom Presets:
```swift
extension LevelConfigurations {
    static func createMyCustomMode(for level: Int) -> LevelEnemyConfig {
        return LevelEnemyConfig(
            level: level,
            enemyConfigs: [
                // Your custom enemy configuration
            ],
            globalSpawnRateMultiplier: 1.2,
            maxEnemiesPerScreen: 25
        )
    }
}
```

### Weighted Probability System:
The system uses weighted random selection. If you have:
- Bee (weight: 0.5)
- Snake (weight: 0.3) 
- Dragonfly (weight: 0.2)

The actual probabilities will be:
- Bee: 50% (0.5/1.0)
- Snake: 30% (0.3/1.0)
- Dragonfly: 20% (0.2/1.0)

## Performance Considerations

### Recommended Limits:
- **maxEnemiesPerScreen**: 15-30 (higher values may impact performance)
- **maxCount per enemy**: 3-8 (varies by enemy type)
- **globalSpawnRateMultiplier**: 0.5-2.0 (extreme values may cause issues)

### Performance Monitoring:
The system includes automatic performance monitoring and will log warnings if object counts become excessive.

## Common Modifications

### Adjust Overall Difficulty:
```swift
// In LevelConfigurations.swift, modify globalSpawnRateMultiplier values:
globalSpawnRateMultiplier: 0.9  // 10% easier
globalSpawnRateMultiplier: 1.2  // 20% harder
```

### Change Enemy Introduction Levels:
```swift
// Move chasers from level 7 to level 5:
// In level5 configuration, add:
EnemySpawnConfig(enemyType: .chaser, spawnRate: 0.01, maxCount: 1, weight: 0.01)
```

### Create Boss Levels:
```swift
specialRules: [
    .bossWave(enemyType: .chaser, count: 3, triggerScore: 75000),
    .guaranteedEnemyType(.chaser, every: 300)  // Every 5 seconds
]
```

This system provides complete control over enemy spawning behavior while maintaining good performance and clear readability. Modify the configurations in `LevelConfigurations.swift` to achieve your desired gameplay balance!