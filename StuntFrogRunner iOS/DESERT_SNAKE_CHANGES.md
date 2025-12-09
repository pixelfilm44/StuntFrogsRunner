# Desert Snake Implementation - Bees Replaced with Snakes

## Summary
This document outlines the changes made to replace bees with snakes in the desert biome and ensure no rain occurs in the desert weather pattern.

## Changes Made

### 1. Configuration.swift

#### Enemy Spawning Rules Updated
- **Modified `enemyProbability(forLevel:weather:)`**: Now returns 0.0 for desert weather, preventing bee spawns
- **Modified `dragonflyProbability(forLevel:weather:)`**: Now returns 0.0 for desert weather, preventing dragonfly spawns
- Added weather parameter to both functions to enable weather-specific logic

#### Snake Spawning Moved to Desert
- **Changed `snakeStartScore`**: From 3000 → 2400 (start of desert biome)
- **Increased `baseSnakeProbability`**: From 0.12 → 0.15 for better desert presence
- **Increased `maxSnakeProbability`**: From 0.35 → 0.40 for consistent spawning
- **Added weather check to `snakeProbability()`**: Snakes now only spawn in desert weather
- Updated function signature: `snakeProbability(forScore:weather:)` instead of just `snakeProbability(forScore:)`

#### Weather Type Enhancements
- **Added `hasPrecipitation` property** to `WeatherType` enum
  - Returns `true` for `.rain` and `.winter`
  - Returns `false` for `.sunny`, `.night`, `.desert`, and `.space`
  - This ensures desert doesn't have rain/snow effects

#### Documentation Updates
- Added comprehensive comment in `GameRules.WeatherSpecificRules`:
  ```swift
  /// Desert biome rules:
  /// - No bees or dragonflies spawn (replaced by snakes)
  /// - No rain/precipitation
  /// - Snakes spawn on lily pads starting at score 2400
  /// - Instant death when falling in water
  ```

## Game Behavior Changes

### Before:
- Bees spawned in all weather types including desert
- Snakes started spawning at score 3000 (space biome)
- No explicit rain prevention for desert

### After:
- **Desert Biome (scores 2400-3000)**:
  - ✅ No bees or dragonflies spawn
  - ✅ Snakes spawn on lily pads (replacing bees as the flying enemy)
  - ✅ No rain/precipitation (hasPrecipitation returns false)
  - ✅ Instant death water still active
  - ✅ Cacti still spawn on pads (unchanged)

- **Other Biomes**: Unchanged behavior
  - Bees and dragonflies continue to spawn normally
  - Snakes no longer spawn in space biome

## Desert Score Range
The desert biome spans:
- **Start**: Score 2400 (240 meters)
- **End**: Score 3000 (300 meters)
- **Duration**: 600 score units (60 meters)

## API Changes
Code that spawns enemies or checks enemy probabilities will need to pass the current weather type:

```swift
// Old API
let probability = Configuration.Difficulty.enemyProbability(forLevel: level)

// New API
let probability = Configuration.Difficulty.enemyProbability(forLevel: level, weather: currentWeather)

// Old API
let snakeProb = Configuration.Difficulty.snakeProbability(forScore: score)

// New API
let snakeProb = Configuration.Difficulty.snakeProbability(forScore: score, weather: currentWeather)

// New Weather Check
if currentWeather.hasPrecipitation {
    // Show rain or snow effects
}
```

## Testing Recommendations

1. **Test Desert Entry**: Score 2400
   - Verify bees stop spawning
   - Verify snakes start appearing on lily pads
   - Verify no rain particles appear

2. **Test Desert Gameplay**: Scores 2400-3000
   - Confirm consistent snake spawning
   - Verify dragonflies don't appear
   - Check that desert sky color remains clear (no rain clouds)

3. **Test Space Entry**: Score 3000
   - Verify snakes stop spawning
   - Verify other space enemies work normally

4. **Debug Mode**: Use `Configuration.Debug.startingScore = 2400` to quickly test desert

## Notes
- The existing snake entity (`GameEntity.Snake`) is already implemented and functional
- Snake collision detection and animations are unchanged
- This change only affects spawn logic, not snake behavior
- Cacti and instant-death water remain active in desert as designed
