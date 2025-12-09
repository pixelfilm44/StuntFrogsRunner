# Space Transition Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         SPACE TRANSITION FLOW                                 │
└──────────────────────────────────────────────────────────────────────────────┘

START GAME (Score 0)
    │
    ▼
┌─────────────────────────┐
│   SUNNY WEATHER         │
│   Score: 0-600         │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│   NIGHT WEATHER         │
│   Score: 600-1200      │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│   RAIN WEATHER          │
│   Score: 1200-1800     │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│   WINTER WEATHER        │
│   Score: 1800-2400     │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│   DESERT WEATHER        │
│   Score: 2400-2900     │
│   • Sand pads           │
│   • Cacti obstacles     │
│   • Instant death water │
└──────────┬──────────────┘
           │
           │ Score reaches 2,900
           ▼
     ┌──────────────┐
     │ LAUNCH PAD   │ ◄─── Spawns centered in river
     │   APPEARS    │       Only ONE launch pad spawns
     │   🚀         │       No more pads spawn after this
     └──────┬───────┘
            │
            │ Player MUST land on launch pad
            │ (Missing it = Game Over in race mode)
            ▼
    ┌───────────────┐
    │ LAUNCH        │
    │ SEQUENCE:     │
    │ 1. Sparkles   │
    │ 2. Frog spins │
    │ 3. Fade black │
    │ 4. → SPACE    │
    │ 5. Fade in    │
    │ 6. "SPACE" msg│
    └───────┬───────┘
            │
            ▼
┌─────────────────────────┐
│   SPACE WEATHER         │ ◄─── Launch pad disappears!
│   Score: 3000-25000    │       Normal space pads spawn
│   • Star pads           │
│   • Snakes appear       │
│   • Floating in space   │
└──────────┬──────────────┘
           │
           │ Score reaches 25,000
           ▼
     ┌──────────────┐
     │  WARP PAD    │ ◄─── Spawns centered in river
     │   APPEARS    │       Only ONE warp pad spawns
     │   🌀         │       No more pads spawn after this
     └──────┬───────┘
            │
            │ Player MUST land on warp pad
            │ (This is the ONLY way to leave space!)
            ▼
    ┌───────────────┐
    │ WARP          │
    │ SEQUENCE:     │
    │ 1. Sparkles   │
    │ 2. Pad spins  │
    │ 3. Fade black │
    │ 4. → DAY      │
    │ 5. Clear all  │
    │ 6. Fade in    │
    │ 7. "BACK!" msg│
    └───────┬───────┘
            │
            ▼
┌─────────────────────────┐
│   BACK TO SUNNY         │ ◄─── Warp pad disappears!
│   Score: Preserved     │       All entities cleared
│   • Fresh start         │       New pads spawn
│   • Same buffs/health   │       Can re-enter space!
│   • Continue playing    │
└──────────┬──────────────┘
           │
           │ If player survives to 2,900 again...
           └─────────────────────────────────────┐
                                                 │
                                                 ▼
                                        ┌──────────────┐
                                        │ LAUNCH PAD   │
                                        │ REAPPEARS!   │
                                        │ (Cycle loop) │
                                        └──────────────┘
```

## Key Behaviors

### 🚀 Launch Pad (Desert → Space)

**Spawn Conditions:**
- `currentWeather == .desert`
- `score >= 2900`
- `!hasSpawnedLaunchPad`

**Behavior:**
- ✅ Appears centered in river
- ✅ No more pads spawn after it appears
- ✅ Player must land on it
- ⚠️  Missing it = Game Over (race mode) or continue (endless mode)
- ✅ Disappears after successful use
- ✅ Triggers space transition

**After Use:**
- Weather → Space
- Score → 3000+ (preserved)
- Launch pad removed
- Can reappear if player warps back and reaches 2,900 again

---

### 🌀 Warp Pad (Space → Day)

**Spawn Conditions:**
- `currentWeather == .space`
- `score >= 25000`
- `!hasSpawnedWarpPad`

**Behavior:**
- ✅ Appears centered in river
- ✅ No more pads spawn after it appears
- ✅ Player must land on it
- ✅ This is the ONLY way to exit space
- ✅ Disappears after successful use
- ✅ Triggers day reset transition

**After Use:**
- Weather → Sunny
- Score → Preserved
- All entities cleared (enemies, coins, etc.)
- Fresh pads spawned
- Warp pad removed
- Can reappear if player reaches space again at 25,000

---

## State Management

```
Game Start
    ↓
hasSpawnedLaunchPad = false
hasHitLaunchPad = false
hasSpawnedWarpPad = false
hasHitWarpPad = false
    ↓
Desert Phase (score 2900)
    ↓
hasSpawnedLaunchPad = true ◄─── Launch pad spawns
    ↓
Player lands on launch pad
    ↓
hasHitLaunchPad = true ◄─── Triggers transition
    ↓
Space transition
    ↓
hasSpawnedLaunchPad = false ◄─── Reset for future use
hasHitLaunchPad = false
    ↓
Space Phase (score 25000)
    ↓
hasSpawnedWarpPad = true ◄─── Warp pad spawns
    ↓
Player lands on warp pad
    ↓
hasHitWarpPad = true ◄─── Triggers transition
    ↓
Day transition
    ↓
hasSpawnedWarpPad = false ◄─── Reset for future use
hasHitWarpPad = false
hasSpawnedLaunchPad = false ◄─── Allow launch pad again
hasHitLaunchPad = false
    ↓
Back to sunny, cycle can repeat!
```

---

## Comparison: Launch Pad vs Warp Pad

| Feature              | Launch Pad 🚀          | Warp Pad 🌀            |
|----------------------|------------------------|------------------------|
| **Weather**          | Desert                | Space                  |
| **Spawn Score**      | 2,900                 | 25,000                 |
| **Location**         | Center of river       | Center of river        |
| **Required?**        | Yes (or game over*)   | Yes (only exit)        |
| **Pad Spawning**     | Stops after spawn     | Stops after spawn      |
| **After Use**        | → Space weather       | → Sunny weather        |
| **Entities**         | Preserved             | All cleared            |
| **Score**            | Preserved             | Preserved              |
| **Buffs/Health**     | Preserved             | Preserved              |
| **Visual Effect**    | Frog shoots up        | Pad spins fast         |
| **Disappears?**      | Yes                   | Yes                    |
| **Can Reappear?**    | Yes (after warp back) | Yes (if back in space) |

*In endless mode, missing launch pad may allow continue; in race mode it's game over

---

## Example Run Timeline

```
Score 0      │ 🌤️  START - Sunny weather
Score 600    │ 🌙  Night begins
Score 1200   │ 🌧️  Rain begins
Score 1800   │ ❄️  Winter begins
Score 2400   │ 🏜️  Desert begins
Score 2900   │ 🚀  LAUNCH PAD appears ◄─── Critical!
             │     (Player must land)
Score 3000   │ 🌌  SPACE begins
             │     Normal space gameplay...
Score 10000  │ 🌌  Still in space...
Score 20000  │ 🌌  Still in space...
Score 25000  │ 🌀  WARP PAD appears ◄─── Critical!
             │     (Player must land)
Score 25000  │ ☀️  BACK TO SUNNY!
             │     All entities cleared
             │     Fresh start with same score
Score 26000  │ ☀️  Continue playing...
Score 27000  │ 🌙  Night again...
             │     ... cycle continues ...
Score 28500  │ 🏜️  Back in desert...
Score 28900  │ 🚀  LAUNCH PAD REAPPEARS!
             │     Can enter space again!
```

This creates an **infinite roguelike loop** where skilled players can keep cycling through all weather zones!

