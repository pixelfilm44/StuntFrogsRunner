# Google Analytics Quick Reference

This document provides a quick reference for all analytics events tracked in StuntFrogRunner.

## Priority Implementation Order

### 🔴 Critical (Implement First)
1. **App Launch** - Track app opens and sessions
2. **Game Start/End** - Core gameplay metrics
3. **Purchases** - All coin spending and upgrades
4. **Daily Challenge Completion** - Key engagement metric

### 🟡 Important (Implement Second)
5. **Distance Milestones** - Track player progression
6. **Challenge Completion** - Track achievement system
7. **Power-up Usage** - Understand item economy
8. **Shop Views** - Track monetization funnel

### 🟢 Nice to Have (Implement Last)
9. **Combo Tracking** - Advanced gameplay metrics
10. **Weather Changes** - Content engagement
11. **Special Events** - Space, desert, etc.

---

## Event Reference

### Session & Retention

| Event | When to Call | Priority |
|-------|-------------|----------|
| `app_launch` | AppDelegate.didFinishLaunching | 🔴 Critical |
| `screen_view` (menu) | MenuViewController.viewWillAppear | 🟡 Important |
| `screen_view` (shop) | ShopViewController.viewWillAppear | 🟡 Important |
| `tutorial_complete` | First time tutorial dismissed | 🔴 Critical |

### Game Events

| Event | When to Call | Priority |
|-------|-------------|----------|
| `game_start` | GameScene.resetGame() | 🔴 Critical |
| `game_end` | All game over sequences | 🔴 Critical |
| `distance_milestone` | Every 100m, 500m, 1000m | 🟡 Important |
| `combo_achieved` | Combo count ≥ 5 | 🟢 Nice to have |
| `combo_invincibility_activated` | Combo count ≥ 25 | 🟢 Nice to have |
| `crocodile_ride` | Ride completed/failed | 🟢 Nice to have |
| `weather_change` | setWeather() called | 🟢 Nice to have |
| `power_up_used` | Power-up collected/activated | 🟡 Important |

### Purchase Events

| Event | When to Call | Priority |
|-------|-------------|----------|
| `purchase` | Real money IAP completed | 🔴 Critical |
| `spend_virtual_currency` | Coins spent on anything | 🔴 Critical |
| `upgrade_purchase` | Upgrade bought in shop | 🔴 Critical |
| `consumable_purchase` | Consumable items bought | 🔴 Critical |

### Challenge Events

| Event | When to Call | Priority |
|-------|-------------|----------|
| `challenge_progress` | Progress milestones (25%, 50%, etc.) | 🟡 Important |
| `challenge_completed` | Challenge requirement met | 🔴 Critical |
| `challenge_reward_claimed` | Reward claimed by player | 🟡 Important |
| `unlock_achievement` | Same as challenge_completed | 🔴 Critical |
| `daily_challenge_start` | Daily challenge begins | 🔴 Critical |
| `daily_challenge_completed` | Daily challenge 2000m reached | 🔴 Critical |
| `daily_challenge_failed` | Daily challenge game over | 🔴 Critical |

### Special Events

| Event | When to Call | Priority |
|-------|-------------|----------|
| `space_launch` | Frog launches to space | 🟢 Nice to have |
| `warp_back` | Warp pad activated | 🟢 Nice to have |
| `desert_transition` | Desert cutscene plays | 🟢 Nice to have |
| `treasure_chest_opened` | Treasure chest collected | 🟡 Important |
| `coins_earned` | Coins awarded (any source) | 🟡 Important |

---

## Implementation Checklist

### Phase 1: Foundation (Day 1)
- [ ] Install Firebase SDK via Swift Package Manager
- [ ] Add GoogleService-Info.plist to project
- [ ] Initialize Firebase in AppDelegate
- [ ] Add `AnalyticsManager.swift` to project
- [ ] Test with `-FIRAnalyticsDebugEnabled` flag
- [ ] Verify events in Firebase DebugView

### Phase 2: Core Events (Day 2)
- [ ] Track app launch in AppDelegate
- [ ] Track game start in GameScene.resetGame()
- [ ] Track game end in all game over sequences
- [ ] Add gameStartTime property to GameScene
- [ ] Track daily challenge start/complete/fail
- [ ] Test all core events in DebugView

### Phase 3: Purchases (Day 3)
- [ ] Track all upgrade purchases in ShopViewController
- [ ] Track all consumable purchases
- [ ] Track virtual currency spending
- [ ] Add shop view tracking
- [ ] Test purchase flow with test coins

### Phase 4: Challenges (Day 4)
- [ ] Track challenge progress milestones
- [ ] Track challenge completion
- [ ] Track reward claims
- [ ] Add progress tracking to existing challenge updates
- [ ] Test with a few challenges

### Phase 5: Polish (Day 5)
- [ ] Add distance milestone tracking
- [ ] Add power-up usage tracking
- [ ] Add combo tracking (if ≥5)
- [ ] Add special event tracking
- [ ] Add user properties (player level, type)
- [ ] Final testing of all events

---

## Code Snippets

### Quick Copy-Paste Integrations

#### GameScene.swift - resetGame()
```swift
func resetGame() {
    // ADD THIS at the start
    gameStartTime = Date().timeIntervalSince1970
    AnalyticsManager.shared.trackGameStart(mode: gameMode, difficulty: difficultyLevel)
    
    // ... rest of your code
}
```

#### GameScene.swift - Game Over
```swift
private func endGame() {
    let duration = Date().timeIntervalSince1970 - gameStartTime
    
    AnalyticsManager.shared.trackGameEnd(
        mode: gameMode,
        score: score,
        coins: coinsCollectedThisRun,
        duration: duration,
        padsLanded: padsLandedThisRun,
        enemiesDefeated: totalEnemiesDefeated,
        maxCombo: maxComboThisRun,
        raceResult: raceResult
    )
    
    // ... show game over screen
}
```

#### GameScene.swift - Score Update
```swift
let currentScore = Int(frog.position.y / 10)
if currentScore > score {
    score = currentScore
    scoreLabel.text = "\(score)m"
    
    // Track milestones
    let milestones = [100, 200, 500, 1000, 1500, 2000]
    if milestones.contains(currentScore) {
        AnalyticsManager.shared.trackDistanceMilestone(distance: currentScore, mode: gameMode)
    }
    
    // Existing code...
    ChallengeManager.shared.recordScoreUpdate(currentScore: score)
}
```

#### ShopViewController.swift - Upgrade Purchase
```swift
@objc func didTapUpgrade() {
    let cost = calculateCost()
    guard canAfford(cost) else { return }
    
    // Deduct coins and apply upgrade
    PersistenceManager.shared.totalCoins -= cost
    applyUpgrade()
    
    // Track analytics
    AnalyticsManager.shared.trackUpgradePurchase(
        upgradeName: upgradeName,
        level: newLevel,
        cost: cost
    )
    
    updateUI()
}
```

#### AppDelegate.swift - Launch
```swift
import FirebaseCore

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Configure Firebase FIRST
    FirebaseApp.configure()
    
    // Track launch
    AnalyticsManager.shared.trackAppLaunch()
    
    // ... rest of your code
    return true
}
```

---

## Dashboard Setup (Firebase Console)

### Key Reports to Configure

1. **Retention Report**
   - Go to Analytics → Retention
   - Shows Day 1, 7, 30 retention
   - Goal: >40% Day 1, >20% Day 7

2. **Events Report**
   - Go to Analytics → Events
   - Monitor: `game_start`, `game_end`, `purchase`
   - Set up conversions for key events

3. **User Properties**
   - Go to Analytics → Custom Definitions → User Properties
   - Add: `player_type`, `player_level`, `total_games_played`

4. **Funnels**
   - Go to Analytics → Analysis → Funnel Analysis
   - Create funnel: App Launch → Game Start → Game End → Shop View → Purchase

5. **Revenue**
   - Go to Analytics → Monetization
   - Track: Total revenue, ARPU, purchases per user

---

## Testing Checklist

### Before Release
- [ ] Remove `-FIRAnalyticsDebugEnabled` from scheme
- [ ] Test on physical device
- [ ] Verify no PII (personally identifiable info) is tracked
- [ ] Check Privacy Manifest is updated
- [ ] Test with TestFlight before App Store release

### After Release
- [ ] Monitor Firebase Console daily for first week
- [ ] Check for spike in errors
- [ ] Verify event counts match expectations
- [ ] Review retention after 7 days
- [ ] Analyze purchase funnel

---

## Common Issues & Solutions

### Events not showing
**Problem:** Events tracked but not appearing in console  
**Solution:** Wait 24 hours; check DebugView for real-time; verify GoogleService-Info.plist

### Too many events
**Problem:** Hitting Firebase event limits  
**Solution:** Remove non-essential tracking; batch similar events; use parameters instead of unique events

### Crash on launch
**Problem:** App crashes after Firebase integration  
**Solution:** Verify Firebase SDK version; check GoogleService-Info.plist is in target; clean build

### DebugView not working
**Problem:** Can't see real-time events  
**Solution:** Add `-FIRAnalyticsDebugEnabled` to scheme; use device not simulator; check bundle ID matches

---

## Contact & Support

- Firebase Documentation: https://firebase.google.com/docs/analytics
- Firebase Console: https://console.firebase.google.com
- Support: https://firebase.google.com/support

---

## Metrics Targets

Set these goals in your Firebase dashboard:

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Day 1 Retention | >40% | - | - |
| Day 7 Retention | >20% | - | - |
| Average Session Duration | >3 min | - | - |
| Daily Active Users | Growing | - | - |
| Purchase Conversion | >5% | - | - |
| Average Score | >500m | - | - |
| Challenge Completion | >30% | - | - |

Update this table weekly to track progress!
