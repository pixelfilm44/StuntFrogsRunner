# Cactus Spawn Fix

## Problem

Cacti were not spawning on lily pads in the desert biome, even though:
- The `Cactus` class was fully implemented
- The spawn probability logic existed in `Configuration.swift`
- The spawning code existed in `GameScene.swift`

## Root Cause

The issue was a **timing problem with the desert weather transition**:

1. When the player reaches score 2400 (desert start), the game triggers a **cutscene** for the desert transition
2. During the cutscene, `currentWeather` is still the previous weather (winter)
3. Only **after** the cutscene completes does `currentWeather` change to `.desert`
4. However, **pads (and their cacti) are generated continuously** during the cutscene transition period
5. The cactus spawn logic checked `currentWeather == .desert`, which was **false** during this crucial transition period

### Code Flow Issue

```swift
// generateNextLevelSlice() runs continuously
let canSpawnCactus = currentWeather == .desert  // ❌ FALSE during cutscene!

// Meanwhile...
// startDesertCutscene() -> plays animation -> endDesertCutscene() -> setWeather(.desert)
// Only NOW does currentWeather become .desert
```

## Solution

We fixed the issue in **two places**:

### 1. Configuration.swift - `cactusProbability()` function

**Before:**
```swift
guard weather == .desert, score >= cactusStartScore else { return 0.0 }
```

**After:**
```swift
// Check if score is in desert range (between desert start and space start)
let isInDesertScore = score >= cactusStartScore && score < Weather.spaceStart
// Allow spawning if EITHER the weather is desert OR we're in the desert score range
guard (weather == .desert || isInDesertScore), score >= cactusStartScore else { return 0.0 }
```

### 2. GameScene.swift - `generateNextLevelSlice()` function

**Before:**
```swift
let canSpawnCactus = (type == .normal || type == .moving || type == .waterLily) && 
                     currentWeather == .desert
```

**After:**
```swift
// Check BOTH the score threshold AND weather to handle the desert cutscene transition
let isInDesertScore = scoreVal >= Configuration.Weather.desertStart && scoreVal < Configuration.Weather.spaceStart
let canSpawnCactus = (type == .normal || type == .moving || type == .waterLily) && 
                     (currentWeather == .desert || isInDesertScore)
```

## Result

Now cacti will spawn correctly:
- ✅ During the desert cutscene transition (based on score)
- ✅ After the cutscene (based on weather)
- ✅ Throughout the entire desert biome (2400-3000 score range)
- ❌ Not in space (score >= 3000) even if returning from space back to desert later

## Why This Works

By checking **both** the score range AND the weather, we ensure:
1. Cacti start spawning immediately when the player enters desert score range (2400+)
2. Cacti continue spawning after the cutscene when weather officially changes to desert
3. Cacti stop spawning when entering space (score >= 3000)
4. The logic is future-proof for any weather transition delays or cutscenes

## Testing Checklist

To verify the fix works:
- [ ] Reach score 2400 (start of desert)
- [ ] Verify cacti appear on lily pads during the cutscene transition
- [ ] Complete the desert cutscene
- [ ] Verify cacti continue spawning after cutscene
- [ ] Check that cacti don't spawn on inappropriate pad types (shrinking, graves, logs, ice)
- [ ] Reach score 3000 (space) and verify cacti stop spawning
- [ ] Verify cacti have ~10% base spawn rate at desert start, increasing to ~30% max

## Related Code

- `Cactus` class: `GameEntity.swift` lines 1366-1500
- Collision detection: `CollisionManager.didCrash(into cactus:)`
- Cactus destruction: Can be destroyed by axes or cannon jumps
- Visual variants: Cacti have different textures for different weather types
