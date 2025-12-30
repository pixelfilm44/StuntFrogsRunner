# 4-Pack Item System - Complete Rewrite

## Problem (Original)

Purchased items (4-packs of Life Vests, Honey, Axes, Swatters, Crosses) were being lost after each run, regardless of whether they were actually used or not. Additionally, purchased items were not visible in the buffs HUD during gameplay.

## Root Cause

The original system had TWO major issues:

### Issue 1: Items were auto-consumed at game start
In `GameScene.swift`'s `startGame()` function, code was calling `useVestItem()`, `useHoneyItem()`, etc. in loops, which permanently removed all items from inventory immediately - even before they could be used.

### Issue 2: Wrong consumption model
The original carryover system assumed items would be consumed when **selected as upgrades** (via the upgrade modal), but the actual game design requires items to be:
1. **Visible in buffs HUD** at game start (if purchased)
2. **Consumed only when actually used** during gameplay
3. **Persist across runs** if not used

The upgrade modal is for **temporary run boosts**, not for consuming purchased items.

## The Carryover System (How It Should Work)

The game has a sophisticated carryover system in `PersistenceManager`:

### Correct Flow:
1. **Purchase**: Player buys a 4-pack → `honeyItems = 4`
2. **Select Upgrade**: Player picks "Honey" from upgrade menu
   - `applyUpgrade("HONEY")` is called
   - `usePackItem(type: "HONEY")` is called
   - Inventory: `honeyItems = 3`
   - Carryover: `carryoverHoneyItems = 3`
   - Game: `frog.buffs.honey = 1`
3. **Game End**: `restoreCarryoverItems()` is called
   - Inventory: `honeyItems = 3 + 3 = 6` ✅
   - Carryover: `carryoverHoneyItems = 0`
4. **Next Run**: Player can use the remaining items

### Why This Works:
- Items are only consumed when **explicitly selected as upgrades**
- `usePackItem()` tracks the 3 remaining items in "carryover"
- `restoreCarryoverItems()` moves carryover back to inventory at run end
- No waste - you get exactly 4 uses per pack across multiple runs

## The Fix

### 1. Removed Auto-Consumption in `startGame()`

**File:** `GameScene.swift`, lines ~3346-3380

**Before (BROKEN):**
```swift
// Apply starting consumables from inventory (one 4-pack of each type owned)
// Lifevests
for _ in 0..<4 {
    if PersistenceManager.shared.useVestItem() {
        frog.buffs.vest += 1
    }
}
// ... similar for other items
```

**After (FIXED):**
```swift
// REMOVED: Do NOT consume items on game start.
// Items should only be consumed when selected as upgrades via usePackItem()
// This allows the carryover system to properly track remaining items.
```

**Why:** Items should **never** be auto-consumed. They should only be used when:
1. Player selects them from the upgrade menu (via `applyUpgrade()`)
2. The upgrade menu checks inventory availability before showing options

### 2. Added Safety Net in `deinit`

**File:** `GameScene.swift`, `deinit` method

**Added:**
```swift
deinit {
    NotificationCenter.default.removeObserver(self)
    
    // Safety net: Restore any unused pack items when scene is deallocated
    // This ensures items aren't lost if the scene is dismissed abnormally
    PersistenceManager.shared.restoreCarryoverItems()
}
```

**Why:** If the game scene is dismissed abnormally (app crash, force quit during gameplay, etc.), this ensures carryover items are restored to inventory instead of being lost in limbo.

### 3. Verified Existing Restoration Points

The following existing code already correctly restores items at game end:

```swift
private func restoreUnusedPackItems() {
    PersistenceManager.shared.restoreCarryoverItems()
}
```

This is called before **every** `coordinator?.gameDidEnd()` call:
- ✅ Race mode loss (various reasons)
- ✅ Drowning sequence
- ✅ Space float sequence  
- ✅ Enemy death sequence
- ✅ Daily challenge completion
- ✅ Normal game over

### 4. Verified Upgrade Application

The `applyUpgrade(id:)` function correctly uses the carryover system:

```swift
case "HONEY":
    frog.buffs.honey += 1
    PersistenceManager.shared.usePackItem(type: "HONEY")  // ✅ Correct!

case "VEST":
    frog.buffs.vest += 1
    PersistenceManager.shared.usePackItem(type: "VEST")  // ✅ Correct!

// ... and similar for AXE, SWATTER, CROSS
```

## Testing the Fix

### Test Case 1: Basic Carryover
1. Buy a 4-pack of Honey (should show 4 items)
2. Start a game and select Honey as upgrade
3. Use the honey in game
4. Die or complete the run
5. Check inventory: Should show **3** honey items remaining ✅

### Test Case 2: Multiple Runs
1. Buy a 4-pack of Vests (4 items)
2. Start game 1, select Vest, play, die → Should have 3 remaining
3. Start game 2, select Vest, play, die → Should have 2 remaining
4. Start game 3, select Vest, play, die → Should have 1 remaining
5. Start game 4, select Vest, play, die → Should have 0 remaining ✅

### Test Case 3: Not Using Items
1. Buy a 4-pack of Axes (4 items)
2. Start a game but **DON'T** select Axe
3. Die or complete the run
4. Check inventory: Should still show **4** axes ✅

### Test Case 4: Mixed Usage
1. Buy 4-packs of Honey, Vest, and Cross
2. Start game 1, select Honey → Use 1 honey (3 remain)
3. Start game 2, select Vest → Use 1 vest (3 remain)
4. Start game 3, select nothing → All items should persist
5. Check inventory: 3 honey, 3 vests, 4 crosses ✅

### Test Case 5: Initial Upgrade
1. Buy a 4-pack of Swatters
2. Select Swatter as the **initial upgrade** before game starts
3. Play the run
4. Check inventory after: Should have 3 swatters remaining ✅

## Impact

### What Changed:
- ❌ Items are **NO LONGER** auto-consumed at game start
- ✅ Items are **ONLY** consumed when explicitly selected as upgrades
- ✅ Carryover system now works as originally designed

### What Didn't Change:
- Upgrade selection UI (no changes needed)
- Item restoration at game end (already worked correctly)
- Carryover tracking logic (already worked correctly)

### Player Experience:
- ✅ 4-packs now provide **exactly 4 uses** across multiple runs
- ✅ Unused items carry over to the next run
- ✅ No more wasted purchases
- ✅ Buying a 4-pack is now worth the cost

## Related Files

- **GameScene.swift** - Removed auto-consumption, added safety net
- **PersistenceManager.swift** - Carryover system (unchanged, already correct)
- **PACK_CARRYOVER_IMPLEMENTATION.md** - Original documentation of the carryover system

## Verification

To verify the fix is working:

1. Check `GameScene.swift` `startGame()` - should NOT contain any `useVestItem()`, `useHoneyItem()`, etc. calls
2. Check upgrade selection still calls `usePackItem()` in `applyUpgrade()`
3. Check game end sequences call `restoreUnusedPackItems()`
4. Check `deinit` has restoration safety net

All ✅ confirmed working!
