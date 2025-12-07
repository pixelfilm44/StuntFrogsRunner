# Launch Pad Flow Diagram

```
GAME PROGRESSION
═══════════════════════════════════════════════════════════════════

Score: 0m ─────────> 2400m ─────────> 2900m ─────────> 3000m+ ────>
       │              │                │                │
       │    DESERT    │   LAUNCH PAD   │     SPACE      │
       │    BEGINS    │   SPAWNS HERE  │    BEGINS      │
       └──────────────┴────────────────┴────────────────┘


LAUNCH PAD INTERACTION (at 2900m)
═══════════════════════════════════════════════════════════════════

                    ┌───────────────────┐
                    │  FROG APPROACHES  │
                    │   LAUNCH PAD      │
                    │   (Y = 2900m)     │
                    └─────────┬─────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
         ┌──────▼──────┐             ┌──────▼──────┐
         │  LANDS ON   │             │  HAS ROCKET │
         │  LAUNCH PAD │             │  POWER-UP?  │
         └──────┬──────┘             └──────┬──────┘
                │                           │
                │                    ┌──────┴──────┐
                │             ┌──────▼──────┐      │
                │             │ PASSES NEAR │      │
                │             │  (<150 units│      │
                │             │  from pad)  │      │
                │             └──────┬──────┘      │
                │                    │             │
                └────────────────────┴─────────┐   │
                                                │   │
                                         ┌──────▼───▼───┐
                                         │   SUCCESS!   │
                                         │ hasHitLaunch │
                                         │   Pad = true │
                                         └──────┬───────┘
                                                │
                                    ┌───────────▼───────────┐
                                    │  launchToSpace()      │
                                    │  - Fade to black      │
                                    │  - transitionToSpace()│
                                    │  - Fade back in       │
                                    └───────────┬───────────┘
                                                │
                                         ┌──────▼──────┐
                                         │   SPACE!    │
                                         │ Weather = .space
                                         │ Score >= 3000m
                                         └─────────────┘


MISS DETECTION (checkLaunchPadInteraction)
═══════════════════════════════════════════════════════════════════

                    ┌───────────────────┐
                    │  Every Frame in   │
                    │     update()      │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Has launch pad    │
                    │ spawned?          │
                    │ hasSpawnedLaunchPad
                    └─────────┬─────────┘
                              │ YES
                    ┌─────────▼─────────┐
                    │ Has frog hit it?  │
                    │ hasHitLaunchPad   │
                    └─────────┬─────────┘
                              │ NO
                    ┌─────────▼─────────┐
                    │ Check frog.pos.y  │
                    │ vs launchPadY     │
                    └─────────┬─────────┘
                              │
         ┌────────────────────┴────────────────────┐
         │                                         │
  ┌──────▼──────┐                          ┌──────▼──────┐
  │ frog.pos.y  │                          │ frog.pos.y  │
  │ < launchPadY│                          │ > launchPadY│
  │   + 300     │                          │   + 300     │
  └──────┬──────┘                          └──────┬──────┘
         │                                         │
         ▼                                         ▼
    Keep Playing                          ┌────────────────┐
                                          │  MISSED IT!    │
                                          │  handleMissed  │
                                          │  LaunchPad()   │
                                          └────────┬───────┘
                                                   │
                                          ┌────────▼───────┐
                                          │  GAME OVER     │
                                          │ "MISSED IT!"   │
                                          │ "You missed the│
                                          │  launch pad."  │
                                          └────────────────┘


GRACE PERIOD VISUALIZATION
═══════════════════════════════════════════════════════════════════

   Launch Pad Y Position: 2900m
   │
   │  ◄─── 150 units ───►  [Rocket fly-over detection zone]
   │        ╔═════════╗
   │        ║ LAUNCH  ║
   │════════║   PAD   ║════════  (Y = 2900m)
   │        ║  🚀     ║
   │        ╚═════════╝
   │
   ├─────────────────────────  (Y = 2900 + 0 to 300m)
   │    [GRACE PERIOD]
   │    Frog can still be
   │    mid-jump or landing
   │
   ├─────────────────────────  (Y = 3200m)
   │
   ▼  MISSED! Game Over
   

TRACKING VARIABLES STATE MACHINE
═══════════════════════════════════════════════════════════════════

┌─────────────────┐
│  NEW GAME       │  hasSpawnedLaunchPad = false
│  startGame()    │  hasHitLaunchPad = false
└────────┬────────┘  launchPadY = 0
         │           isLaunchingToSpace = false
         │
         ▼
┌─────────────────┐
│ PLAYING DESERT  │  score increases...
│ (2400-2899m)    │
└────────┬────────┘
         │
         │ score reaches 2900
         ▼
┌─────────────────┐
│ SPAWN LAUNCH    │  hasSpawnedLaunchPad = true
│ PAD (2900m)     │  launchPadY = 29000 (in pixels)
└────────┬────────┘  hasHitLaunchPad = false
         │
         ├─────────────┬─────────────┐
         │             │             │
         ▼             ▼             ▼
  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │  LANDS   │  │  ROCKET  │  │  MISSES  │
  │  ON PAD  │  │ FLY-OVER │  │   PAD    │
  └────┬─────┘  └────┬─────┘  └────┬─────┘
       │             │             │
       ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│hasHitLaunch │ │hasHitLaunch │ │ frog.pos.y  │
│Pad = true   │ │Pad = true   │ │ > launchPadY│
└──────┬──────┘ └──────┬──────┘ │   + 300     │
       │             │          └──────┬──────┘
       │             │                 │
       ├─────────────┤                 ▼
       │                        ┌─────────────┐
       ▼                        │ GAME OVER   │
┌─────────────┐                └─────────────┘
│isLaunching  │
│ToSpace=true │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ LAUNCH      │  Black screen fade
│ SEQUENCE    │  Frog spins upward
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ TRANSITION  │  hasSpawnedLaunchPad = false
│ TO SPACE    │  hasHitLaunchPad = false
│ (3000m+)    │  launchPadY = 0
└─────────────┘  isLaunchingToSpace = false
                 currentWeather = .space
```

## Key Coordinates Reference

| Event                    | Score (m) | Y Position (pixels) |
|--------------------------|-----------|---------------------|
| Desert begins            | 2400      | 24000               |
| Launch pad spawns        | 2900      | 29000               |
| Space begins             | 3000      | 30000               |
| Launch pad miss distance | +300      | +3000               |
| Rocket detection zone    | ±150      | ±1500 (from pad)    |

## Code Flow Through update()

```
update() called every frame
    │
    ├─> checkPendingDesertTransition()  // Handle desert cutscene
    │
    ├─> frog.update()                   // Update frog physics
    │
    ├─> collisionManager.check()        // Check all collisions
    │       └─> didLand() may be called
    │             └─> if launch pad: hasHitLaunchPad = true
    │
    ├─> checkWeatherChange()            // Handle weather transitions
    │
    ├─> checkLaunchPadInteraction() ◄── NEW!
    │       │
    │       ├─> Check rocket fly-over
    │       └─> Check if missed (300+ units past)
    │             └─> handleMissedLaunchPad()
    │                   └─> handleGameOver()
    │
    └─> updateCamera(), updateHUD(), etc.
```
