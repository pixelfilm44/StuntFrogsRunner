# Upgrade Filtering System - Implementation Guide

## Overview
This document explains the context-aware upgrade filtering system that ensures players only see upgrades that are relevant to their current game situation.

## Problem Solved
Previously, upgrades could appear even when they had no use in the current game context:
- **Holy Cross** appeared even when there were no ghosts (ghosts only spawn at night)
- **Fly Swatter** appeared when there were no dragonflies
- **Honey Jar** appeared when there were no bees (bees don't spawn in desert)
- **Rain Boots** appeared in climates without rain or ice
- **Woodcutter's Axe** appeared in space (where no logs or cacti spawn)

## Solution Architecture

### 1. Weather/Climate Tracking
**File: `UpgradeOption.swift`**
- Added `currentWeather: WeatherType` property to `UpgradeViewController`
- Weather is now passed from `GameScene` through the coordinator when triggering upgrades

### 2. Context-Aware Filtering
**File: `UpgradeOption.swift`**

Two new methods handle upgrade filtering:

#### `isUpgradeUsableInCurrentContext(_ upgradeID: String, weather: WeatherType) -> Bool`
Checks if an upgrade can be used based on the current weather/climate:

| Upgrade | Weather Requirements |
|---------|---------------------|
| **HONEY** (Bee protection) | Any weather except `.desert` (bees don't spawn in desert) |
| **CROSS** (Ghost protection) | Only `.night` (ghosts only spawn at night) |
| **SWATTER** (Dragonfly protection) | Any weather except `.desert` (dragonflies don't spawn in desert) |
| **BOOTS** (Anti-slip) | Only `.rain` or `.winter` (where sliding occurs) |
| **AXE** (Log/cactus chopper) | Any weather except `.space` (logs in natural weathers, cacti in desert) |
| **VEST**, **HEART**, **HEARTBOOST** | Always useful (universal survival items) |
| **SUPERJUMP**, **ROCKET**, **CANNONBALL** | Always useful (universal mobility items) |

#### `isUpgradeRelevantForChallenge(_ upgradeID: String, challenge: DailyChallenge) -> Bool`
Extends the weather-based filtering for daily challenges by also checking:
- Challenge's enemy focus types (bee/dragonfly/snake/etc.)
- Challenge's pad focus types (ice/moving/shrinking/etc.)
- Whether prerequisite items are unlocked (e.g., DOUBLESUPERJUMPTIME requires SUPERJUMP)

### 3. Protocol Updates
**File: `GameState.swift`**

Updated `GameCoordinatorDelegate` protocol:
```swift
// Before
func triggerUpgradeMenu(hasFullHealth: Bool, distanceTraveled: Int)

// After
func triggerUpgradeMenu(hasFullHealth: Bool, distanceTraveled: Int, currentWeather: WeatherType, currentMaxHealth: Int)
```

### 4. Daily Challenge Filtering
**File: `DailyChallenges.swift`**

Improved `getRelevantUpgradeIDs(for challenge:)` to properly filter upgrades:
- Cross only appears in night challenges
- Axe excluded from space challenges
- Boots only appear in rain/winter/ice challenges
- Enemy-specific items only appear when those enemies can spawn

## Weather Types and Spawning Rules

### Climate → Enemy/Obstacle Matrix

| Climate | Bees | Dragonflies | Ghosts | Snakes | Logs | Cacti | Rain/Ice |
|---------|------|-------------|--------|--------|------|-------|----------|
| **Sunny** | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Night** | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| **Rain** | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ |
| **Winter** | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ |
| **Desert** | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| **Space** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

## Implementation Details

### Game Start Initialization
When starting a game, the initial weather is set:
- **Endless Mode**: Always starts at `.sunny`
- **Race Mode**: Always starts at `.sunny`
- **Daily Challenge**: Uses the challenge's specified climate

### Mid-Game Upgrades
During gameplay, `GameScene` calls:
```swift
coordinator?.triggerUpgradeMenu(
    hasFullHealth: frog.currentHealth == frog.maxHealth,
    distanceTraveled: score,
    currentWeather: currentWeather,
    currentMaxHealth: frog.maxHealth
)
```

### Filtering Flow
```
1. User earns upgrade opportunity
2. GameScene calls triggerUpgradeMenu with current weather
3. UpgradeViewController receives weather information
4. allOptions computed property filters base options:
   a. Filter by zone (early/mid/late based on distance)
   b. Filter by weather context (isUpgradeUsableInCurrentContext)
   c. Filter by daily challenge relevance (if applicable)
   d. Filter by player state (full health, max hearts, etc.)
5. generateOptions() picks 2 options from filtered pool
6. Player sees only relevant upgrades
```

## Testing Checklist

To verify the system works correctly:

### Sunny Weather Tests
- [ ] Bees can appear → Honey should be offered
- [ ] Dragonflies can appear → Swatter should be offered
- [ ] No ghosts → Cross should NOT be offered
- [ ] No rain → Boots should NOT be offered
- [ ] Logs can appear → Axe should be offered

### Night Weather Tests
- [ ] Ghosts can appear → Cross should be offered
- [ ] Bees can appear → Honey should be offered
- [ ] Dragonflies can appear → Swatter should be offered
- [ ] Logs can appear → Axe should be offered

### Rain Weather Tests
- [ ] Rain/sliding occurs → Boots should be offered
- [ ] No ghosts → Cross should NOT be offered
- [ ] Logs can appear → Axe should be offered

### Desert Weather Tests
- [ ] No bees → Honey should NOT be offered
- [ ] No dragonflies → Swatter should NOT be offered
- [ ] No ghosts → Cross should NOT be offered
- [ ] Cacti can appear → Axe should be offered
- [ ] No rain → Boots should NOT be offered

### Space Weather Tests
- [ ] No obstacles at all → Axe should NOT be offered
- [ ] No enemies → Honey/Swatter/Cross should NOT be offered
- [ ] No rain → Boots should NOT be offered
- [ ] Universal items (Heart, Vest, etc.) should still be offered

### Daily Challenge Tests
- [ ] Night challenge → Cross should be offered
- [ ] Sunny challenge → Cross should NOT be offered
- [ ] Bee-focus challenge → Honey should be offered
- [ ] Dragonfly-focus challenge → Swatter should be offered
- [ ] Ice pad challenge → Boots should be offered

## Future Enhancements

Potential improvements to consider:

1. **Snake-Specific Upgrades**: If snake-blocking items are added, filter them to desert only
2. **Crocodile-Specific Upgrades**: Filter to water lily areas only
3. **Dynamic Probability**: Increase spawn rate of relevant upgrades based on recent obstacle density
4. **Weather Forecast**: If weather changes are predictable, offer items for upcoming biomes
5. **Combo Suggestions**: Offer complementary upgrades (e.g., if player has honey, offer swatter)

## Code Locations

| Feature | File | Line Range (approx) |
|---------|------|-------------------|
| Context filtering logic | `UpgradeOption.swift` | Lines 115-220 |
| Weather property | `UpgradeOption.swift` | Line 38 |
| Protocol update | `GameState.swift` | Lines 26-38 |
| Coordinator implementation | `GameState.swift` | Lines 191-220 |
| Daily challenge filtering | `DailyChallenges.swift` | Lines 540-580 |

## Notes

- Universal upgrades (Heart, Vest, SuperJump, etc.) are never filtered out as they're always useful
- Legendary upgrades (Double Super Jump Time, Double Rocket Time) require the base upgrade to be purchased
- The filtering is layered: first by weather context, then by daily challenge specifics
- If the filtered pool has fewer than 2 options, the system will still work (though edge cases should be tested)
