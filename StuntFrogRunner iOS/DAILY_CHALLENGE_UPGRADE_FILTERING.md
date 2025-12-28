# Daily Challenge Upgrade Filtering

This document explains how the upgrade system filters upgrades based on the enemies and mechanics present in the current daily challenge.

## Overview

When playing daily challenges, upgrades are now filtered to only show items that are relevant to the challenge. This prevents situations like being offered honey when there are no bees in the challenge.

## How It Works

### 1. Upgrade Relevance System

The `DailyChallenges` class now provides methods to determine which upgrades are relevant for a given challenge:

```swift
// Check if an upgrade is relevant to the challenge
func isUpgradeRelevant(_ upgradeID: String, for challenge: DailyChallenge) -> Bool

// Get all relevant upgrade IDs for a challenge
func getRelevantUpgradeIDs(for challenge: DailyChallenge) -> [String]
```

### 2. Upgrade Categories

Upgrades are categorized as follows:

#### Evergreen Abilities (Always Available)
- **ROCKET** - Fly for 10 seconds
- **SUPERJUMP** - Double jump range + invincibility
- **CANNONBALL** - Cannon jump ability
- **HEART** - +1 Max HP & heal
- **HEARTBOOST** - Refill all hearts
- **VEST** - Float on water once

#### Enemy-Specific Upgrades
- **HONEY** - Only appears when bees are in the challenge
- **SWATTER** - Only appears when dragonflies are in the challenge
- **CROSS** - Always available (ghosts can spawn from graves in all challenges)

#### Environment-Specific Upgrades
- **BOOTS** - Only appears when:
  - Ice pads are in the challenge, OR
  - Weather is rain/winter (which makes pads slippery)

#### Utility Upgrades
- **AXE** - Always available (useful for clearing obstacles)

#### Legendary Upgrades (Always Available if Unlocked)
- **DOUBLESUPERJUMPTIME** - 2x Super Jump Time (Permanent)
- **DOUBLEROCKETTIME** - 2x Rocket Time (Permanent)

### 3. Integration with UpgradeViewController

The `UpgradeViewController` has been updated with two new properties:

```swift
/// Set to true when showing upgrades in daily challenge mode
var isDailyChallenge: Bool = false

/// The current daily challenge (required if isDailyChallenge is true)
var currentDailyChallenge: DailyChallenge?
```

When these are set, the upgrade pool is automatically filtered based on the challenge configuration.

## Usage Example

When presenting the upgrade screen during a daily challenge:

```swift
// Get the current daily challenge
let challenge = DailyChallenges.shared.getTodaysChallenge()

// Create and configure the upgrade view controller
let upgradeVC = UpgradeViewController()
upgradeVC.coordinator = gameCoordinator
upgradeVC.isDailyChallenge = true
upgradeVC.currentDailyChallenge = challenge
upgradeVC.hasFullHealth = (frog.currentHealth == frog.maxHealth)
upgradeVC.currentMaxHealth = frog.maxHealth
upgradeVC.distanceTraveled = score / 10 // Convert score to meters

// Present the upgrade screen
present(upgradeVC, animated: true)
```

## Examples

### Example 1: Bee-Focused Challenge

**Challenge Configuration:**
```swift
DailyChallenge(
    focusEnemyTypes: [.bee],
    focusPadTypes: [.mixed],
    climate: .sunny
)
```

**Available Upgrades:**
- ✅ ROCKET (evergreen)
- ✅ SUPERJUMP (evergreen)
- ✅ CANNONBALL (evergreen)
- ✅ HEART (evergreen)
- ✅ HEARTBOOST (evergreen)
- ✅ VEST (evergreen)
- ✅ HONEY (bee-specific)
- ✅ CROSS (always available)
- ✅ AXE (always available)
- ❌ SWATTER (no dragonflies)
- ❌ BOOTS (no ice/rain)

### Example 2: Dragonfly-Focused Ice Challenge

**Challenge Configuration:**
```swift
DailyChallenge(
    focusEnemyTypes: [.dragonfly],
    focusPadTypes: [.ice],
    climate: .winter
)
```

**Available Upgrades:**
- ✅ ROCKET (evergreen)
- ✅ SUPERJUMP (evergreen)
- ✅ CANNONBALL (evergreen)
- ✅ HEART (evergreen)
- ✅ HEARTBOOST (evergreen)
- ✅ VEST (evergreen)
- ✅ SWATTER (dragonfly-specific)
- ✅ BOOTS (ice pads + winter weather)
- ✅ CROSS (always available)
- ✅ AXE (always available)
- ❌ HONEY (no bees)

### Example 3: Mixed Challenge

**Challenge Configuration:**
```swift
DailyChallenge(
    focusEnemyTypes: [.mixed],
    focusPadTypes: [.mixed],
    climate: .rain
)
```

**Available Upgrades:**
- ✅ ROCKET (evergreen)
- ✅ SUPERJUMP (evergreen)
- ✅ CANNONBALL (evergreen)
- ✅ HEART (evergreen)
- ✅ HEARTBOOST (evergreen)
- ✅ VEST (evergreen)
- ✅ HONEY (mixed includes bees)
- ✅ SWATTER (mixed includes dragonflies)
- ✅ BOOTS (rain weather)
- ✅ CROSS (always available)
- ✅ AXE (always available)

## Implementation Details

### Filtering in `allOptions` Property

The upgrade pool is filtered in the `allOptions` computed property:

```swift
private var allOptions: [UpgradeOption] {
    // ... zone filtering ...
    
    // Filter upgrades for daily challenges based on challenge configuration
    if isDailyChallenge, let challenge = currentDailyChallenge {
        options = options.filter { option in
            DailyChallenges.shared.isUpgradeRelevant(option.id, for: challenge)
        }
    }
    
    // ... rest of filtering logic ...
}
```

### Filtering Special Upgrades

Special upgrades (Super Jump, Cannonball) are also filtered:

```swift
private func generateOptions() {
    // ... 
    
    // Filter out super jump if not relevant to daily challenge
    if isDailyChallenge, let challenge = currentDailyChallenge {
        shouldOfferSuperJump = shouldOfferSuperJump && 
            DailyChallenges.shared.isUpgradeRelevant("SUPERJUMP", for: challenge)
    }
    
    // Filter out cannonball if not relevant to daily challenge
    if isDailyChallenge, let challenge = currentDailyChallenge {
        shouldOfferCannonball = shouldOfferCannonball && 
            DailyChallenges.shared.isUpgradeRelevant("CANNONBALL", for: challenge)
    }
    
    // ...
}
```

## Benefits

1. **Better Player Experience** - Players only see upgrades that are useful for the current challenge
2. **Fair Gameplay** - No "dead" upgrade choices that won't help in the current challenge
3. **Strategic Depth** - Players can make meaningful choices between relevant upgrades
4. **Challenge Variety** - Different challenges naturally offer different upgrade pools

## Notes

- The filtering system is **only active during daily challenges**
- In endless mode and race mode, the full upgrade pool is available
- Evergreen upgrades like Rocket and Super Jump are always available (if unlocked)
- The system respects enemy focus types (.bee, .dragonfly, .mixed) to determine enemy-specific upgrades
- Weather and pad types are considered for environment-specific upgrades (Boots)
