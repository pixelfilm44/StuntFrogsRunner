# Google Analytics Integration Guide

This guide walks you through setting up Google Analytics (Firebase Analytics) in your StuntFrogRunner game.

## Prerequisites

1. A Google account
2. Access to Firebase Console (console.firebase.google.com)
3. Xcode 15.0 or later

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project" or select existing project
3. Enter project name: `StuntFrogRunner` (or your preferred name)
4. **Disable Google Analytics if prompted** (we'll enable it in next step)
5. Click "Create project"

## Step 2: Enable Google Analytics

1. In your Firebase project, click the ⚙️ gear icon → Project settings
2. Navigate to "Integrations" tab
3. Find "Google Analytics" and click "Enable"
4. Choose existing Google Analytics account or create new one
5. Select or create a GA4 property
6. Click "Enable Google Analytics"

## Step 3: Add iOS App to Firebase

1. In Firebase Console, click "Add app" and select iOS
2. Enter your iOS bundle ID (found in Xcode: Target → General → Bundle Identifier)
   - Example: `com.yourcompany.StuntFrogRunner`
3. Enter App nickname: `StuntFrogRunner iOS`
4. **Download GoogleService-Info.plist** - you'll need this!
5. Click "Next" through the remaining steps

## Step 4: Add GoogleService-Info.plist to Xcode

1. Open your Xcode project
2. Drag `GoogleService-Info.plist` into the Xcode project navigator
3. **Important:** Make sure "Copy items if needed" is checked
4. Ensure the file is added to your target
5. The file should appear at the root level of your project

## Step 5: Install Firebase SDK

### Option A: Swift Package Manager (Recommended)

1. In Xcode, go to **File → Add Package Dependencies...**
2. Enter package URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: `10.20.0` or later
4. Click "Add Package"
5. Select **only** these products:
   - ✅ `FirebaseAnalytics`
   - ✅ `FirebaseAnalyticsSwift` (for Swift-specific features)
6. Click "Add Package"

### Option B: CocoaPods (Alternative)

Add to your `Podfile`:
```ruby
platform :ios, '15.0'

target 'StuntFrogRunner iOS' do
  use_frameworks!
  
  # Firebase Analytics
  pod 'Firebase/Analytics'
end
```

Then run:
```bash
pod install
```

## Step 6: Initialize Firebase in AppDelegate

Update your `AppDelegate.swift`:

```swift
import UIKit
import FirebaseCore  // Add this import

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var gameCoordinator: GameCoordinator?

    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 AppDelegate: didFinishLaunchingWithOptions called")
        
        // Configure Firebase - ADD THIS LINE
        FirebaseApp.configure()
        print("✅ Firebase configured")
        
        // Track app launch
        AnalyticsManager.shared.trackAppLaunch()
        
        // ... rest of your existing code
        
        for family in UIFont.familyNames {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }

        SoundManager.shared.preloadSounds()
        print("✅ AppDelegate: Sounds preloaded")
        
        DailyChallenges.shared.refreshIfNeeded { success in
            if success {
                print("✅ AppDelegate: Daily challenges ready")
            } else {
                print("⚠️ AppDelegate: Using cached/fallback challenges")
            }
        }
        
        return true
    }
    
    // ... rest of your code
}
```

## Step 7: Add Analytics to GameScene

The `AnalyticsManager.swift` file has already been created. Now integrate it into your game events:

### Example integrations in GameScene.swift:

```swift
// When game starts (in resetGame() or similar):
AnalyticsManager.shared.trackGameStart(mode: gameMode, difficulty: difficultyLevel)

// When game ends (in your game over logic):
AnalyticsManager.shared.trackGameEnd(
    mode: gameMode,
    score: score,
    coins: coinsCollectedThisRun,
    duration: Date().timeIntervalSince1970 - gameStartTime,
    padsLanded: padsLandedThisRun,
    enemiesDefeated: enemiesDefeatedThisRun,
    maxCombo: maxComboThisRun,
    raceResult: raceResult
)

// Track milestones (add this where you track score):
if score % 100 == 0 && score > 0 {
    AnalyticsManager.shared.trackDistanceMilestone(distance: score, mode: gameMode)
}

// Track power-up usage (when power-ups are consumed):
AnalyticsManager.shared.trackPowerUpUsed(type: "ROCKET", context: "gameplay")

// Track combos (in your combo logic):
AnalyticsManager.shared.trackComboAchieved(comboCount: comboCount, score: score)
```

## Step 8: Add Analytics to Shop & Purchases

### In ShopViewController or purchase handling:

```swift
// When purchasing upgrades:
AnalyticsManager.shared.trackUpgradePurchase(
    upgradeName: "jump_power",
    level: currentLevel + 1,
    cost: upgradeCost
)

// When purchasing consumables:
AnalyticsManager.shared.trackConsumablePurchase(
    itemType: "ROCKET",
    quantity: 4,
    cost: 100
)

// For real money IAP (if applicable):
AnalyticsManager.shared.trackPurchase(
    productId: "com.yourapp.coin_pack_100",
    price: 0.99,
    currency: "USD",
    itemName: "100 Coin Pack"
)
```

## Step 9: Add Analytics to Challenges

### In ChallengeManager or when challenges update:

```swift
// When challenge completes:
AnalyticsManager.shared.trackChallengeCompleted(
    challengeId: challenge.id,
    challengeTitle: challenge.title,
    reward: challenge.reward.displayText
)

// Track progress (can be called periodically):
AnalyticsManager.shared.trackChallengeProgress(
    challengeId: challenge.id,
    progress: challenge.progress,
    requirement: challenge.requirement
)

// Daily challenge completion:
AnalyticsManager.shared.trackDailyChallengeCompleted(
    challengeId: dailyChallenge.id,
    timeSeconds: completionTime,
    seed: dailyChallenge.seed
)
```

## Step 10: Test Your Integration

### Enable Debug Logging

Add this to your scheme arguments:
1. In Xcode, select **Product → Scheme → Edit Scheme...**
2. Select **Run** → **Arguments** tab
3. Add under "Arguments Passed On Launch":
   ```
   -FIRAnalyticsDebugEnabled
   ```

### View Real-Time Events

1. In Firebase Console, go to **Analytics → DebugView**
2. Run your app in simulator or device
3. You should see events appearing in real-time!

### Common Events to Test:
- Launch app → see `app_launch`
- Start game → see `game_start`
- Play game → see `game_end` with stats
- Purchase item → see `spend_virtual_currency`
- Complete challenge → see `challenge_completed`

## Step 11: Monitor Analytics in Google Analytics

1. Go to Firebase Console → Analytics → Dashboard
2. Wait 24-48 hours for data processing (not instant!)
3. View:
   - **Events:** See all tracked events
   - **User Properties:** See player segments
   - **Retention:** Track returning players
   - **Revenue:** Track IAP revenue
   - **Funnel Analysis:** See where players drop off

## Recommended Events to Track

Based on your game, here are the key events already implemented:

### Game Events
- ✅ `game_start` - Track game mode and difficulty
- ✅ `game_end` - Track score, coins, duration, stats
- ✅ `distance_milestone` - Track every 100m, 500m, etc.
- ✅ `combo_achieved` - Track combo streaks
- ✅ `crocodile_ride` - Track special gameplay moments
- ✅ `weather_change` - Track weather transitions

### Purchase Events
- ✅ `purchase` - Real money IAP
- ✅ `spend_virtual_currency` - Coin spending
- ✅ `upgrade_purchase` - Upgrade purchases
- ✅ `consumable_purchase` - Consumable item purchases

### Challenge Events
- ✅ `challenge_progress` - Track progress
- ✅ `challenge_completed` - Track completions
- ✅ `daily_challenge_completed` - Track daily challenge success
- ✅ `daily_challenge_failed` - Track daily challenge failures

### Retention Events
- ✅ `app_launch` - Track app opens
- ✅ `tutorial_complete` - Track onboarding completion

## Privacy & Compliance

### Update Privacy Manifest (PrivacyInfo.xcprivacy)

If you don't have one, create it:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeProductInteraction</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePurchaseHistory</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

### App Store Privacy Details

When submitting to App Store, declare:
- ✅ Analytics data collected
- ✅ Not used for tracking
- ✅ Not linked to user identity
- ✅ Used to improve app experience

## Troubleshooting

### Events not showing in Firebase
- Wait 24 hours for data processing
- Check DebugView for real-time events
- Verify `GoogleService-Info.plist` is added correctly
- Check Firebase is configured in AppDelegate

### Build errors
- Verify Firebase SDK version is 10.20.0+
- Clean build folder: **Product → Clean Build Folder**
- Check that `import FirebaseAnalytics` is present

### GoogleService-Info.plist errors
- File must be in project root
- Check "Copy items if needed" was selected
- Verify file is added to your target

## Best Practices

1. **Don't over-track**: Track meaningful events, not every frame
2. **Use parameters**: Add context to events with parameters
3. **Test thoroughly**: Use DebugView before releasing
4. **Respect privacy**: Don't track personal information
5. **Monitor regularly**: Review dashboard weekly

## Key Metrics to Monitor

### Retention
- Day 1, Day 7, Day 30 retention rates
- Session length and frequency

### Engagement
- Games played per user
- Average session duration
- Completion rates for challenges

### Monetization
- Virtual currency spending patterns
- IAP conversion rates
- Average revenue per user

### Gameplay
- Average distance traveled
- Most used power-ups
- Weather preference patterns
- Combo achievement rates

## Next Steps

1. ✅ Set up Firebase project
2. ✅ Add GoogleService-Info.plist
3. ✅ Install Firebase SDK
4. ✅ Initialize in AppDelegate
5. ✅ Add tracking code to game events
6. ✅ Test with DebugView
7. 🔄 Monitor analytics dashboard
8. 🔄 Iterate based on data

## Resources

- [Firebase Analytics Documentation](https://firebase.google.com/docs/analytics)
- [Google Analytics 4 Documentation](https://support.google.com/analytics/answer/9304153)
- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk)

---

**Questions or issues?** Check the Firebase Console support or review the troubleshooting section above.
