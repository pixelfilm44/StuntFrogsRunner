# Quick Reference: Desert Weather & Snake Spawning

## Configuration Changes Summary

### ✅ Completed Changes

1. **Snakes now spawn in Desert only** (scores 2400-3000)
   - Moved from space biome to desert biome
   - Increased spawn probability for better presence

2. **Bees/Dragonflies disabled in Desert**
   - They no longer spawn when weather is `.desert`
   - Continue spawning normally in all other weather types

3. **Desert has no precipitation**
   - Added `hasPrecipitation` property to `WeatherType`
   - Desert returns `false` (along with sunny, night, and space)

## Code Usage Examples

### Spawning Enemies (Bees/Dragonflies)
```swift
// Pass current weather to determine if enemies should spawn
let level = Configuration.Difficulty.level(forScore: currentScore)
let enemyChance = Configuration.Difficulty.enemyProbability(
    forLevel: level, 
    weather: currentWeather
)

if Double.random(in: 0...1) < enemyChance {
    // Determine if bee or dragonfly
    let dragonflyChance = Configuration.Difficulty.dragonflyProbability(
        forLevel: level,
        weather: currentWeather
    )
    
    let enemyType = Double.random(in: 0...1) < dragonflyChance ? "DRAGONFLY" : "BEE"
    let enemy = GameEntity.Enemy(position: pos, type: enemyType, weather: currentWeather)
}
```

### Spawning Snakes (Desert Only)
```swift
// Snakes only appear in desert biome
let snakeChance = Configuration.Difficulty.snakeProbability(
    forScore: currentScore,
    weather: currentWeather
)

if Double.random(in: 0...1) < snakeChance {
    let snake = GameEntity.Snake(position: lilyPadPosition)
    // Snake will only spawn if weather == .desert and score >= 2400
}
```

### Weather Precipitation Check
```swift
// Check if current weather should show rain/snow effects
if currentWeather.hasPrecipitation {
    // Show rain particles for .rain
    // Show snow particles for .winter
    showPrecipitationEffects()
} else {
    // Desert, sunny, night, and space have no precipitation
    hidePrecipitationEffects()
}
```

### Testing Desert
```swift
// In Configuration.swift
struct Debug {
    static let startingScore: Int = 2400  // Start at desert
    static let debugMode: Bool = true
}
```

## Desert Biome Characteristics

| Feature | Behavior |
|---------|----------|
| Score Range | 2400 - 3000 |
| Sky Color | Sandy (240/255, 210/255, 120/255) |
| Water | Instant death (black void) |
| Bees | ❌ None |
| Dragonflies | ❌ None |
| Snakes | ✅ Spawn on lily pads |
| Cacti | ✅ Spawn on lily pads |
| Crocodiles | ❌ None (instant death water) |
| Rain | ❌ None |
| Snow | ❌ None |

## Weather Precipitation Table

| Weather | hasPrecipitation | Visual Effect |
|---------|------------------|---------------|
| sunny | false | Clear sky |
| night | false | Clear night |
| rain | **true** | Rain particles |
| winter | **true** | Snow particles |
| desert | **false** | Clear sandy sky |
| space | false | Starfield |

## Function Signature Changes

### Before
```swift
// Old function signatures (missing weather parameter)
enemyProbability(forLevel: Int) -> Double
dragonflyProbability(forLevel: Int) -> Double  
snakeProbability(forScore: Int) -> Double
```

### After
```swift
// New function signatures (with weather parameter)
enemyProbability(forLevel: Int, weather: WeatherType) -> Double
dragonflyProbability(forLevel: Int, weather: WeatherType) -> Double
snakeProbability(forScore: Int, weather: WeatherType) -> Double
```

## 🎮 Expected Gameplay

When a player enters the desert (score 2400):
1. Sky transitions to sandy color
2. Bees stop spawning completely
3. Snakes start appearing on lily pads
4. Rain effects (if any) should stop
5. Cacti continue spawning as before
6. Water becomes instant death

This creates a distinct "desert challenge" where the player faces snakes instead of bees!
