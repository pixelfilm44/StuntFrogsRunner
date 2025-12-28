# 4-Pack Carryover System Implementation

## Overview
This document describes the implementation of the 4-pack carryover system, which ensures that when players buy 4-packs (Honey Jars, Life Vests, Crosses, Swatters, Axes) and don't use all of them in a run, the remaining items carry over to the next run.

## Problem Statement
Previously, when a player purchased a 4-pack and selected it as an upgrade at the start of a run, the game would only give them 1 item from the pack. The remaining 3 items were lost, wasting the player's coins.

## Solution
The new system tracks "carryover" items separately from the main inventory. When a player selects a pack item upgrade:
1. If there are carryover items from a previous run, use one of those
2. If no carryover items exist, open a new pack: deduct 1 from inventory and mark 3 as carryover
3. When a run ends, restore all carryover items back to the main inventory

## Implementation Details

### 1. PersistenceManager Changes

#### New Keys
Added five new UserDefaults keys to track carryover items:
- `sf_carryover_honey_items`
- `sf_carryover_vest_items`
- `sf_carryover_cross_items`
- `sf_carryover_swatter_items`
- `sf_carryover_axe_items`

#### New Methods

**`usePackItem(type: String)`**
- Called when a player selects a pack item as an upgrade
- Checks if carryover items exist:
  - If yes: Use one carryover item (decrement carryover count)
  - If no: Open a new pack (deduct 1 from main inventory, set 3 in carryover)

**`getCarryoverItems(type: String) -> Int`**
- Returns the number of carryover items for a given type
- Useful for debugging or displaying to the player

**`restoreCarryoverItems()`**
- Called when a run ends
- Adds all carryover items back to the main inventory
- Resets carryover counts to 0

**`clearCarryoverItems()`**
- Utility method to clear all carryover without restoring
- Currently unused but available for future features

### 2. GameScene Changes

#### New Method
**`restoreUnusedPackItems()`**
- Helper method that calls `PersistenceManager.shared.restoreCarryoverItems()`
- Provides a clear interface for the game scene

#### Modified Method
**`applyUpgrade(id: String)`**
- Updated cases for "HONEY", "VEST", "AXE", "SWATTER", and "CROSS"
- Now calls `PersistenceManager.shared.usePackItem(type:)` after applying the upgrade
- This ensures proper tracking of pack item usage

#### Game Over Integration
Added `restoreUnusedPackItems()` calls before all `coordinator?.gameDidEnd` invocations:
- Race mode loss (various reasons)
- Drowning sequence
- Space float sequence
- Enemy death sequence
- Daily challenge completion

## Example Flow

### Scenario: Player buys and uses Honey Jars

1. **Purchase**: Player buys a 4-pack of Honey Jars
   - `honeyItems` = 4

2. **First Run**: Player selects Honey as upgrade
   - `usePackItem(type: "HONEY")` is called
   - `honeyItems` reduced to 3
   - `carryoverHoneyItems` set to 3
   - Player gets 1 honey buff in game

3. **First Run Ends**: Game over
   - `restoreUnusedPackItems()` is called
   - `honeyItems` restored to 6 (3 + 3 carryover)
   - `carryoverHoneyItems` reset to 0

4. **Second Run**: Player selects Honey again
   - `usePackItem(type: "HONEY")` is called
   - `honeyItems` reduced to 5
   - `carryoverHoneyItems` set to 3
   - Player gets 1 honey buff in game

5. **Second Run Ends**: Player reaches 2000m
   - `restoreUnusedPackItems()` is called
   - `honeyItems` restored to 8 (5 + 3 carryover)
   - `carryoverHoneyItems` reset to 0

### Scenario: Player uses multiple items from same pack

1. **Start**: Player has 4 Honey Jars
   - `honeyItems` = 4

2. **First Run**: Player selects Honey
   - `honeyItems` = 3
   - `carryoverHoneyItems` = 3

3. **Second Run**: Player selects Honey again (using carryover)
   - `carryoverHoneyItems` reduced to 2
   - `honeyItems` remains 3

4. **Third Run**: Player selects Honey again (using carryover)
   - `carryoverHoneyItems` reduced to 1
   - `honeyItems` remains 3

5. **Third Run Ends**:
   - `honeyItems` restored to 4 (3 + 1 carryover)
   - `carryoverHoneyItems` reset to 0

## Benefits

1. **No Waste**: Players get full value from their 4-pack purchases
2. **Fair**: Each pack provides exactly 4 uses across multiple runs
3. **Seamless**: Works automatically without player intervention
4. **Consistent**: Applies to all 5 types of pack items (Honey, Vest, Cross, Swatter, Axe)

## Testing Recommendations

1. Buy a 4-pack and verify count increases by 4
2. Use the item in a run and end the run normally
3. Check that inventory shows correct count (original - 1 + 3 carryover)
4. Start multiple runs using the same item type
5. Verify that the 4th use depletes the pack completely
6. Test with multiple different pack types simultaneously
7. Test in both endless mode and race mode
8. Test with daily challenges

## Future Enhancements

Possible improvements to consider:
1. Show carryover count in shop UI (e.g., "You have: 3 + 2 carryover")
2. Add visual indicator in upgrade selection showing items come from carryover
3. Statistics tracking for "Total packs opened" vs "Total items used"
4. Achievement for "Used all 4 items from a pack in one run" (would require additional tracking)
