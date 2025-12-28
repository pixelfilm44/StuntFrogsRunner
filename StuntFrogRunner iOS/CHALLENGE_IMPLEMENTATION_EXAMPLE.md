# Friend Challenge Implementation Example

## Quick Start

The friend challenge feature has been implemented in `GameOverViewController.swift` and is ready to use! Here's what was added:

### 1. Core Files Added

- **GameCenterChallengeManager.swift** - Singleton manager for all challenge operations
- **GAMECENTER_FRIEND_CHALLENGE_GUIDE.md** - Complete documentation

### 2. Updated Files

- **GameOverViewController.swift** - Added "Challenge Friend" button and functionality

## How It Works

### User Flow

1. Player completes a daily challenge (reaches 2000m)
2. Game Over screen shows "CHALLENGE COMPLETE!" 
3. A "CHALLENGE FRIEND" button appears below "TRY AGAIN"
4. Tapping the button:
   - Shows Game Center friends list (iOS 14+)
   - OR shows share sheet directly (iOS 13)
5. Player can:
   - Copy challenge message to clipboard
   - Share via Messages, social media, etc.
6. Challenge includes player's completion time

### Challenge Message Examples

The system randomly selects from friendly, competitive messages like:
- "I just crushed 'Sunny Bee Bonanza' in 2:05.43! Think you can beat me? 🐸"
- "Completed 'Rainy Sprint' in 1:58.22! Your turn! 💪"
- "Just set a time of 2:12.67 on 'Midnight Mayhem'! Can you do better? 🏆"

## Optional Enhancements

### Option A: Add Challenge Stats to Menu

Display how many challenges the player has sent and received:

```swift
// In MenuViewController.swift

private lazy var challengeStatsLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    label.textColor = .lightGray
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
}()

// In updateStats()
private func updateStats() {
    // ... existing code ...
    
    let stats = GameCenterChallengeManager.shared.getChallengeStats()
    if stats.sent > 0 || stats.received > 0 {
        challengeStatsLabel.text = "Challenges: \(stats.sent) sent • \(stats.received) received"
    }
}
```

### Option B: Quick Challenge from Menu

Add a button to quickly challenge friends on today's best time:

```swift
// In MenuViewController.swift

@objc private func handleQuickChallenge() {
    guard DailyChallenges.shared.hasCompletedToday() else {
        let alert = UIAlertController(
            title: "Not Yet!",
            message: "Complete today's daily challenge first!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        return
    }
    
    let challenge = DailyChallenges.shared.getTodaysChallenge()
    let bestTime = DailyChallenges.shared.getTodaysBestTime()
    let message = GameCenterChallengeManager.shared.createShareableText(
        challengeName: challenge.name,
        time: bestTime
    )
    
    let activityVC = UIActivityViewController(
        activityItems: [message],
        applicationActivities: nil
    )
    
    activityVC.completionWithItemsHandler = { activityType, completed, _, _ in
        if completed {
            GameCenterChallengeManager.shared.recordChallengeSent()
        }
    }
    
    present(activityVC, animated: true)
}
```

### Option C: Submit Scores to Leaderboards

Enable Game Center leaderboards for daily challenges:

```swift
// In DailyChallenges.swift, inside recordRun()

if completed && !wasAlreadyCompleted {
    // Existing coin reward code...
    
    // Submit to Game Center leaderboard
    GameCenterChallengeManager.shared.submitToLeaderboard(
        time: timeInSeconds,
        challengeDate: dateStr
    ) { success, error in
        if success {
            print("✅ Score submitted to Game Center")
        }
    }
}
```

**Note:** You'll need to configure leaderboards in App Store Connect first:
1. Go to App Store Connect → Your App → Services → Game Center
2. Create leaderboards with IDs like: `com.stuntfrog.daily.2025-12-26`
3. Set the score format to "Time (Elapsed)"
4. Set sort order to "Ascending" (lower times are better)

### Option D: Friend Leaderboard View

Show friends' times on the daily challenge:

```swift
// New file: DailyChallengeLeaderboardViewController.swift

import UIKit
import GameKit

class DailyChallengeLeaderboardViewController: UIViewController {
    
    func loadFriendScores() {
        guard #available(iOS 14.0, *) else { return }
        
        let challengeDate = DailyChallenges.shared.getCurrentDate()
        let leaderboardID = "com.stuntfrog.daily.\(challengeDate)"
        
        GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { leaderboards, error in
            guard let leaderboard = leaderboards?.first else { return }
            
            leaderboard.loadEntries(
                for: .friends,
                timeScope: .allTime,
                range: NSRange(location: 1, length: 100)
            ) { local, entries, totalCount, error in
                // Display entries in table view
                entries?.forEach { entry in
                    print("\(entry.player.displayName): \(entry.formattedScore)")
                }
            }
        }
    }
}
```

## Testing Checklist

- [ ] Complete a daily challenge
- [ ] Verify "Challenge Friend" button appears
- [ ] Tap button with Game Center signed in
- [ ] Verify Game Center UI or share sheet appears
- [ ] Copy message to clipboard - verify format is correct
- [ ] Share via Messages - verify friend receives message
- [ ] Test with Game Center signed out - verify error message
- [ ] Test on iOS 13 device - verify share sheet fallback works
- [ ] Verify challenge count increments after sending

## Troubleshooting

### "Challenge Friend" button doesn't appear
- Verify `dailyChallengeCompleted` is set to `true` in GameOverViewController
- Check that `isDailyChallenge` is also `true`

### Game Center UI doesn't show
- Verify player is authenticated: `GKLocalPlayer.local.isAuthenticated`
- Check iOS version (iOS 14+ for friends list)
- Ensure Game Center capability is enabled in Xcode

### Share sheet doesn't work
- Check that `challengeFriendButton` is properly set as source view
- Verify message is not empty
- Check console for any errors

### Friends can't see the challenge
This is expected! The feature shares text via normal messaging/social apps. For true Game Center challenges with automatic notifications:
- Implement leaderboard submission (Option C)
- Use GKScore.challenge() API (see guide for details)
- Requires additional backend infrastructure

## Next Steps

1. ✅ Basic implementation is complete
2. Consider adding leaderboard integration (Option C)
3. Consider adding quick challenge button to menu (Option B)
4. Test with real friends to verify user experience
5. Monitor analytics for challenge send/receive rates

## Customization

### Change Challenge Messages

Edit `GameCenterChallengeManager.swift`, find `createChallengeMessage()`:

```swift
let messages = [
    "Your custom message here! Time: \(timeString) 🐸",
    "Another variation! Beat my \(timeString)! 💪",
    // Add more variations...
]
```

### Adjust Button Styling

Edit `challengeFriendButton` in `GameOverViewController.swift`:

```swift
button.titleLabel?.font = UIFont(name: "YourFont", size: 18)
button.setTitleColor(.yourColor, for: .normal)
// etc...
```

### Add Animations

Make the button pulse when it appears:

```swift
// In configureData() when showing the button
UIView.animate(withDuration: 0.3, delay: 0.5, options: [.autoreverse, .repeat]) {
    self.challengeFriendButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
}
```

## Analytics Integration

Track challenge engagement:

```swift
// When challenge is sent
Analytics.logEvent("challenge_sent", parameters: [
    "challenge_name": challenge.name,
    "player_time": bestTime,
    "method": "game_center" // or "share_sheet"
])

// When challenge is opened (would need deep linking)
Analytics.logEvent("challenge_received", parameters: [
    "challenge_name": challenge.name,
    "sender_id": senderID
])
```

## Support

For questions or issues:
1. Check the console logs (prefixed with 🎮, 🏆, 📤, 📥)
2. Review `GAMECENTER_FRIEND_CHALLENGE_GUIDE.md`
3. Verify Game Center is enabled in device Settings → Game Center

---

**Status:** ✅ Ready to Use  
**Last Updated:** December 26, 2025  
**Minimum iOS:** 13.0  
**Recommended iOS:** 14.0+ (for full features)
