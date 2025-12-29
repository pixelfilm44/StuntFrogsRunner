# Minimal Google Analytics Integration (30-Minute Setup)

If you want to get analytics running **quickly** with the most important events, follow this minimal guide.

## Step 1: Install Firebase (10 minutes)

1. **Create Firebase Project**
   - Go to console.firebase.google.com
   - Click "Add project"
   - Name it "StuntFrogRunner"
   - Click through setup

2. **Add iOS App**
   - Click "Add app" → iOS
   - Enter your bundle ID (from Xcode)
   - Download `GoogleService-Info.plist`
   - Drag it into your Xcode project (check "Copy items")

3. **Install SDK**
   - In Xcode: File → Add Package Dependencies
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Add `FirebaseAnalytics` only

## Step 2: Add Minimal Code (15 minutes)

### 1. Update AppDelegate.swift

Add these two lines:

```swift
import UIKit
import FirebaseCore  // ← ADD THIS

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        FirebaseApp.configure()  // ← ADD THIS
        AnalyticsManager.shared.trackAppLaunch()  // ← ADD THIS
        
        // ... your existing code
        return true
    }
}
```

### 2. Add AnalyticsManager.swift

Copy the `AnalyticsManager.swift` file that was created into your project.

### 3. Add GameScene tracking

Find your `resetGame()` method and add at the top:

```swift
private var gameStartTime: TimeInterval = 0  // Add this property at top of class

func resetGame() {
    // ADD THESE TWO LINES at the start:
    gameStartTime = Date().timeIntervalSince1970
    AnalyticsManager.shared.trackGameStart(mode: gameMode, difficulty: difficultyLevel)
    
    // ... rest of your existing code
}
```

Find your game over code (wherever you call `coordinator?.gameDidEnd()`) and add before it:

```swift
private func endGame() {
    // ADD THIS before coordinator?.gameDidEnd():
    let duration = Date().timeIntervalSince1970 - gameStartTime
    AnalyticsManager.shared.trackGameEnd(
        mode: gameMode,
        score: score,
        coins: coinsCollectedThisRun,
        duration: duration,
        padsLanded: padsLandedThisRun,
        enemiesDefeated: 0,  // Add proper tracking later
        maxCombo: maxComboThisRun,
        raceResult: raceResult
    )
    
    // ... your existing game over code
    coordinator?.gameDidEnd(...)
}
```

### 4. Add Shop tracking

In `ShopViewController.swift`, add at top:

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    AnalyticsManager.shared.trackShopView()  // ← ADD THIS
}
```

Find your upgrade purchase code and add:

```swift
func purchaseUpgrade() {
    // ... your existing purchase code ...
    
    // ADD THIS after successful purchase:
    AnalyticsManager.shared.trackUpgradePurchase(
        upgradeName: "jump_power",  // or whatever upgrade
        level: newLevel,
        cost: cost
    )
}
```

## Step 3: Test (5 minutes)

1. **Enable Debug Mode**
   - In Xcode: Product → Scheme → Edit Scheme
   - Run → Arguments tab
   - Add: `-FIRAnalyticsDebugEnabled`

2. **Run the App**
   - Launch app in simulator
   - Play a quick game
   - Visit shop

3. **Check Firebase DebugView**
   - Go to Firebase Console
   - Analytics → DebugView
   - You should see events in real-time!

Look for these events:
- ✅ `app_launch` (when you open app)
- ✅ `game_start` (when you start playing)
- ✅ `game_end` (when you die/finish)
- ✅ `screen_view` (when you open shop)

## Done! 🎉

You now have basic analytics tracking:
- App opens and sessions
- Game starts and ends with stats
- Shop visits
- Basic retention data

## What to Track Next

After you have the basics working, add these in order:

### Priority 2: Purchase Events
```swift
// When buying items in shop:
AnalyticsManager.shared.trackVirtualCurrencySpent(
    itemName: "rocket_pack",
    amount: 100,
    itemCategory: "consumable"
)
```

### Priority 3: Daily Challenge Events
```swift
// When daily challenge completes:
AnalyticsManager.shared.trackDailyChallengeCompleted(
    challengeId: challenge.id,
    timeSeconds: challengeElapsedTime,
    seed: challenge.seed
)
```

### Priority 4: Milestones
```swift
// In your score update code:
if score % 100 == 0 && score > 0 {
    AnalyticsManager.shared.trackDistanceMilestone(
        distance: score,
        mode: gameMode
    )
}
```

## Viewing Your Data

### Real-Time (DebugView)
- Firebase Console → Analytics → DebugView
- Shows events as they happen
- Great for testing

### Historical Data (Dashboard)
- Firebase Console → Analytics → Dashboard
- Wait 24 hours for data processing
- Shows trends and insights

### Key Metrics to Watch
- **Active Users**: Daily/Weekly/Monthly active users
- **Retention**: Day 1, 7, 30 retention rates
- **Session Duration**: How long people play
- **Game Completions**: How many finish games

## Troubleshooting

**No events showing?**
- Wait 24 hours for dashboard
- Use DebugView for real-time
- Check Firebase is configured in AppDelegate

**Crash on launch?**
- Verify GoogleService-Info.plist is in project
- Check Firebase SDK version is 10.20.0+
- Clean build folder

**DebugView not working?**
- Verify scheme argument is added
- Try physical device instead of simulator
- Check bundle ID matches Firebase project

## Next Steps

1. ✅ Get basic tracking working (this guide)
2. 📖 Read `GOOGLE_ANALYTICS_SETUP.md` for full setup
3. 📊 Review `ANALYTICS_QUICK_REFERENCE.md` for all events
4. 🎮 Use extension files for detailed integrations

## Helpful Resources

- **Setup Guide**: `GOOGLE_ANALYTICS_SETUP.md`
- **Quick Reference**: `ANALYTICS_QUICK_REFERENCE.md`
- **GameScene Extensions**: `GameScene+Analytics.swift`
- **Shop Extensions**: `ShopViewController+Analytics.swift`
- **Challenge Extensions**: `ChallengeManager+Analytics.swift`

---

**That's it!** You now have basic Google Analytics running in under 30 minutes. 🚀
