# Treasure Chest Daily Challenge Integration

## Overview
Treasure chests now provide **contextually relevant rewards** based on the daily challenge's enemy types and climate. This ensures players receive items that actually help them complete the challenge they're facing.

## Changes Made

### 1. GameEntity.swift - TreasureChest.Reward Enum

**Added new method:** `randomForChallenge(_ challenge: DailyChallenge) -> Reward`

This method uses **weighted random selection** to prioritize enemy-defeating items:

```swift
/// Returns a contextually relevant reward for a daily challenge
/// Prioritizes items that help defeat the challenge's enemies
static func randomForChallenge(_ challenge: DailyChallenge) -> Reward {
    var relevantRewards: [Reward] = []
    var weights: [Int] = []
    
    // Hearts are always useful (30% weight)
    relevantRewards.append(.heartsRefill)
    weights.append(30)
    
    // Lifevest is always useful for protection (20% weight)
    relevantRewards.append(.lifevest4Pack)
    weights.append(20)
    
    // Enemy-specific items get HIGHEST priority (50% weight each)
    if challenge.focusEnemyTypes.contains(.dragonfly) {
        relevantRewards.append(.swatter4Pack)
        weights.append(50)
    }
    
    if challenge.focusEnemyTypes.contains(.snake) || challenge.climate == .desert {
        relevantRewards.append(.axe4Pack)
        weights.append(50)
    }
    
    if challenge.climate == .night {
        relevantRewards.append(.cross4Pack)
        weights.append(50)
    }
    
    // Mixed challenges include all items with lower weights
    if challenge.focusEnemyTypes.contains(.mixed) {
        if !relevantRewards.contains(.swatter4Pack) {
            relevantRewards.append(.swatter4Pack)
            weights.append(25)
        }
        if !relevantRewards.contains(.axe4Pack) {
            relevantRewards.append(.axe4Pack)
            weights.append(25)
        }
        if challenge.climate == .night && !relevantRewards.contains(.cross4Pack) {
            relevantRewards.append(.cross4Pack)
            weights.append(25)
        }
    }
    
    // Weighted random selection
    let totalWeight = weights.reduce(0, +)
    var randomValue = Int.random(in: 0..<totalWeight)
    
    for (index, weight) in weights.enumerated() {
        if randomValue < weight {
            return relevantRewards[index]
        }
        randomValue -= weight
    }
    
    return relevantRewards.first ?? .heartsRefill
}
```

### 2. GameEntity.swift - TreasureChest Initializer

**Updated initializer** to accept optional daily challenge:

```swift
init(position: CGPoint, challenge: DailyChallenge? = nil) {
    // Use contextual reward selection if in a daily challenge
    if let challenge = challenge {
        self.reward = Reward.randomForChallenge(challenge)
    } else {
        self.reward = Reward.random()
    }
    // ... rest of initialization
}
```

**Backward compatible:** Existing code without the challenge parameter continues to work with random rewards.

### 3. GameScene.swift - Treasure Chest Spawning

**Updated spawning logic** to pass daily challenge context:

```swift
// Treasure Chest spawning - rare but valuable!
// ~8% chance on normal/moving lilypads, not on logs, ice, graves, or shrinking pads
let canSpawnChest = (type == .normal || type == .moving || type == .waterLily)
if canSpawnChest && Double.random(in: 0...1) < 0.01 {
    // Pass daily challenge context to get relevant rewards for challenge enemies
    let chest = TreasureChest(position: pad.position, challenge: currentChallenge)
    worldNode.addChild(chest)
    treasureChests.append(chest)
}
```

### 4. GameScene.swift - Collection Logging

**Added debug logging** to track contextual reward selection:

```swift
func didCollect(treasureChest: TreasureChest) {
    guard !isGameEnding else { return }
    guard !treasureChest.isCollected else { return }
    
    let reward = treasureChest.open()
    
    // Debug: Log contextual reward selection in daily challenges
    if let challenge = currentChallenge {
        print("📦 Treasure chest opened in daily challenge '\(challenge.name)'")
        print("   → Reward: \(reward.displayName) (contextually selected for challenge)")
    } else {
        print("📦 Treasure chest opened (random reward): \(reward.displayName)")
    }
    
    // ... rest of collection handling
}
```

## Enemy-Item Mapping

The system intelligently matches rewards to challenge enemies:

| Challenge Type | Primary Enemy | Treasure Chest Priority | Weight | Why? |
|---------------|---------------|------------------------|--------|------|
| **Dragonfly Challenge** | 🐉 Dragonflies | 🏸 Swatter 4-Pack | 50% | Swatters instantly defeat dragonflies |
| **Snake Challenge** | 🐍 Snakes | 🪓 Axe 4-Pack | 50% | Axes defeat snakes |
| **Desert Climate** | 🌵 Cacti | 🪓 Axe 4-Pack | 50% | Axes chop cacti |
| **Night Climate** | 👻 Ghosts | ✝️ Holy Cross 4-Pack | 50% | Crosses banish ghosts |
| **Bee Challenge** | 🐝 Bees | 🦺 Lifevest 4-Pack | 20% | Vest protects while standing still |
| **Mixed Challenge** | Various | All items | 25% each | Balanced mix of all tools |
| **All Challenges** | N/A | ❤️‍🔥 Hearts Refill | 30% | Universal healing |

## Weighted Random System

The system uses **weighted random selection** to ensure relevant items appear more frequently:

- **High Priority (50%):** Enemy-specific defeating items (Swatter, Axe, Cross)
- **Medium Priority (30%):** Universal healing (Hearts)
- **Standard Priority (20%):** Universal protection (Lifevest)
- **Balanced Priority (25%):** Mixed challenge items

Example: In a **Dragonfly Challenge**, you have:
- 50% chance: Swatter 4-Pack (defeats dragonflies!)
- 30% chance: Hearts Refill (universal healing)
- 20% chance: Lifevest 4-Pack (universal protection)

## Testing

To test the contextual rewards:

1. **Start a daily challenge** with specific enemy types (e.g., dragonfly challenge)
2. **Find a treasure chest** during gameplay
3. **Collect the chest** and check the console logs:
   ```
   📦 Treasure chest opened in daily challenge 'Dragonfly Dash'
      → Reward: 4x Swatter (contextually selected for challenge)
   ```
4. **Verify** that the reward matches the challenge's enemies

## Benefits

✅ **Fairer gameplay:** Players get items they can actually use in the challenge  
✅ **Better progression:** Reduces frustration from getting irrelevant items  
✅ **Strategic depth:** Chests become more valuable in daily challenges  
✅ **Backward compatible:** Endless mode still uses random rewards  
✅ **Smart weighting:** High-priority items appear more often  
✅ **Universal items:** Hearts and lifevest always available as backup  

## Future Enhancements

Possible improvements:

1. **Visual indication:** Add a special glow color to challenge-mode chests
2. **Guaranteed drops:** Consider guaranteeing at least one enemy-specific item per challenge
3. **Difficulty scaling:** Adjust weights based on challenge difficulty
4. **Player feedback:** Show a tooltip explaining why the item is useful for this challenge
5. **Rarity tiers:** Make enemy-specific items "legendary" in their relevant challenges

## Code Flow Diagram

```
Daily Challenge Started
    ↓
GameScene.currentChallenge = DailyChallenges.shared.getTodaysChallenge()
    ↓
Treasure Chest Spawns on Lilypad
    ↓
TreasureChest(position: pad.position, challenge: currentChallenge)
    ↓
Reward.randomForChallenge(challenge)
    ↓
[Weighted Selection Based on Enemy Types]
    ↓
Player Collects Chest
    ↓
didCollect(treasureChest:)
    ↓
Logs: "📦 Treasure chest opened in daily challenge 'Dragonfly Dash'"
      "   → Reward: 4x Swatter (contextually selected for challenge)"
    ↓
Apply Reward & Update HUD
```

## Implementation Complete! ✨

The treasure chest system now intelligently provides items that help players defeat the specific enemies in their daily challenge, making treasure chests much more valuable and meaningful in challenge mode!
