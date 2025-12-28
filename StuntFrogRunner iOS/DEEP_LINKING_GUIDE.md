# Deep Linking Implementation Guide for StuntFrog

## Overview
This guide explains how to set up deep linking in StuntFrog so that when players share daily challenges with friends, those friends can tap a link and jump directly to the challenge in the app.

## What Was Implemented

### 1. URL Scheme Configuration
The app now supports custom URL schemes in the format:
```
stuntfrog://challenge/2025-12-28
```

### 2. Deep Link Handling
- **SceneDelegate.swift**: Added `scene(_:openURLContexts:)` and `scene(_:continue:)` methods
- **GameCenterChallengeManager.swift**: Added `createChallengeDeepLink()` method
- **UIViewController+DeepLinking.swift**: Helper extensions for navigation

### 3. User Experience Flow
1. Player A completes a daily challenge
2. Player A taps "Challenge Friend"
3. Player A shares via Messages/social media
4. Player B receives a message with a link like: `stuntfrog://challenge/2025-12-28`
5. Player B taps the link
6. StuntFrog opens directly to the daily challenge
7. Player B sees a friendly "Challenge Accepted!" alert

## Required Configuration

### Step 1: Configure Info.plist

Add the following to your `Info.plist` file:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.stuntfrog</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>stuntfrog</string>
        </array>
    </dict>
</array>
```

**How to add this in Xcode:**
1. Open your project in Xcode
2. Select your app target
3. Go to the "Info" tab
4. Find or add "URL Types"
5. Click "+" to add a new URL type
6. Set:
   - **Identifier**: `com.yourcompany.stuntfrog` (use your actual bundle ID)
   - **URL Schemes**: `stuntfrog`
   - **Role**: Editor

### Step 2: Optional - Universal Links (Advanced)

If you have a website (e.g., `stuntfrog.app`), you can set up universal links that work even when the app isn't installed.

#### In Xcode:
1. Select your target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Associated Domains"
5. Add domain: `applinks:stuntfrog.app`

#### On Your Website:
Create a file at `https://stuntfrog.app/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.yourcompany.stuntfrog",
        "paths": ["/challenge/*"]
      }
    ]
  }
}
```

Replace `TEAMID` with your Apple Team ID and `com.yourcompany.stuntfrog` with your bundle identifier.

## Testing Deep Links

### Test on Device

#### Method 1: Safari
1. Open Safari on your iOS device
2. Type in the address bar: `stuntfrog://challenge/2025-12-28`
3. Tap "Go"
4. You should see a prompt to open StuntFrog
5. Tap "Open" and verify the challenge screen appears

#### Method 2: Notes App
1. Open the Notes app
2. Create a new note
3. Type: `stuntfrog://challenge/2025-12-28`
4. iOS will automatically make it a tappable link
5. Tap the link
6. StuntFrog should open to the challenge

#### Method 3: Messages
1. Send yourself an iMessage with: `stuntfrog://challenge/2025-12-28`
2. Tap the link
3. Verify the app opens correctly

#### Method 4: Xcode Console
In Xcode, when the app is running on device, paste this in Terminal:

```bash
xcrun simctl openurl booted "stuntfrog://challenge/2025-12-28"
```

Or for a real device:
```bash
# First find your device ID
xcrun devicectl list devices

# Then open the URL
xcrun devicectl device open url --device <DEVICE_ID> "stuntfrog://challenge/2025-12-28"
```

### Test on Simulator

Open Terminal and run:
```bash
xcrun simctl openurl booted "stuntfrog://challenge/2025-12-28"
```

## URL Format Specifications

### Custom URL Scheme
```
stuntfrog://challenge/{date}
```

**Examples:**
- `stuntfrog://challenge/2025-12-28` - Opens specific date's challenge
- `stuntfrog://challenge` - Opens today's challenge

### Universal Links (if configured)
```
https://stuntfrog.app/challenge/{date}
```

**Examples:**
- `https://stuntfrog.app/challenge/2025-12-28`
- `https://stuntfrog.app/challenge`

## Code Flow

### When a Link is Tapped

1. **iOS receives the URL**
   - Custom scheme: `stuntfrog://challenge/2025-12-28`
   - Universal link: `https://stuntfrog.app/challenge/2025-12-28`

2. **SceneDelegate.scene(_:openURLContexts:) is called**
   ```swift
   func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
       guard let url = URLContexts.first?.url else { return }
       handleDeepLink(url)
   }
   ```

3. **URL is parsed**
   - Extract the host/path: `challenge`
   - Extract the date: `2025-12-28`

4. **Challenge manager records the event**
   ```swift
   GameCenterChallengeManager.shared.recordChallengeReceived()
   ```

5. **User sees confirmation alert**
   ```
   "Challenge Accepted! 🐸"
   "Ready to take on today's daily challenge?"
   ```

6. **User taps "Let's Go!"**
   - Coordinator navigates to menu (if not there)
   - Coordinator starts the daily challenge
   - User is playing within seconds!

## Debugging

### Enable Logging

The implementation includes debug logging. Look for these in your Xcode console:

```
🔗 Deep link received: stuntfrog://challenge/2025-12-28
📥 Challenge received (total: 5)
🎮 Opening daily challenge from deep link
```

### Common Issues

#### Link doesn't work
**Solution**: Verify Info.plist is configured correctly. Clean build folder (Cmd+Shift+K) and rebuild.

#### App opens but doesn't navigate
**Solution**: Check that GameCoordinator has the `showDailyChallengeFromDeepLink()` method and it's properly implemented.

#### Alert doesn't appear
**Solution**: Ensure `topMostViewController()` extension is working. Try adding debug print statements.

### Testing Checklist

- [ ] Info.plist has `CFBundleURLTypes` configured
- [ ] URL scheme is `stuntfrog` (lowercase, no spaces)
- [ ] Deep link opens app from Safari
- [ ] Deep link opens app from Messages
- [ ] Deep link opens app from Notes
- [ ] Alert appears when link is tapped
- [ ] Challenge starts when "Let's Go!" is tapped
- [ ] Analytics record challenge received

## Share Message Example

When a player shares a challenge, the message looks like:

```
I just crushed 'Sunny Bee Bonanza' in 2:05.43! Think you can beat me? 🐸

Tap here to accept: stuntfrog://challenge/2025-12-28
```

The recipient can tap the link, and StuntFrog opens directly to that challenge.

## Analytics

The system tracks:
- **Challenges sent**: Incremented when player shares
- **Challenges received**: Incremented when app opens via deep link

Access stats:
```swift
let stats = GameCenterChallengeManager.shared.getChallengeStats()
print("Sent: \(stats.sent), Received: \(stats.received)")
```

## Future Enhancements

### 1. Deep Link to Specific Challenge Dates
Currently implemented! The URL includes the date.

### 2. Deep Link Parameters
Add query parameters for additional context:
```
stuntfrog://challenge/2025-12-28?from=PlayerName&time=125.43
```

Parse them like:
```swift
if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
    let fromPlayer = components.queryItems?.first(where: { $0.name == "from" })?.value
    let theirTime = components.queryItems?.first(where: { $0.name == "time" })?.value
    
    // Show: "PlayerName challenged you! Their time: 2:05.43"
}
```

### 3. Preview Before Opening
Show the challenge details before starting:
```swift
"PlayerName got 2:05.43 on 'Sunny Bee Bonanza'"
[View Leaderboard] [Accept Challenge] [Decline]
```

### 4. Push Notifications
When a friend beats your time, send a push notification with a deep link:
```swift
let content = UNMutableNotificationContent()
content.title = "Challenge Update!"
content.body = "PlayerName beat your time on 'Sunny Bee Bonanza'!"
content.userInfo = ["deepLink": "stuntfrog://challenge/2025-12-28"]
```

### 5. QR Codes
Generate QR codes for challenges:
```swift
func generateQRCode(for link: String) -> UIImage? {
    let data = link.data(using: .ascii)
    let filter = CIFilter(name: "CIQRCodeGenerator")
    filter?.setValue(data, forKey: "inputMessage")
    // ... generate and return image
}
```

## Security Considerations

### Validate Date Format
```swift
func isValidChallengeDate(_ dateString: String) -> Bool {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dateString) != nil
}
```

### Rate Limiting
Prevent abuse by limiting how many deep links can be opened in a short time:
```swift
private var lastDeepLinkTime: Date?
private let minimumInterval: TimeInterval = 2.0

func shouldHandleDeepLink() -> Bool {
    guard let last = lastDeepLinkTime else {
        lastDeepLinkTime = Date()
        return true
    }
    
    if Date().timeIntervalSince(last) > minimumInterval {
        lastDeepLinkTime = Date()
        return true
    }
    
    return false
}
```

### Sanitize Input
Always validate and sanitize URL components before using them.

## App Store Review Considerations

When submitting your app:
1. **Explain the URL scheme** in your App Review notes
2. **Demonstrate the feature** in your demo video
3. **Ensure it doesn't bypass purchases** or required content
4. **Respect user privacy** - don't track users across apps via deep links

## Troubleshooting

### "App not installed" on Universal Links
- Verify the Apple App Site Association file is accessible
- Check that the domain is added to Associated Domains
- Test with a real domain (not localhost)

### Deep link works once then stops
- Check if you're calling `recordChallengeReceived()` correctly
- Verify no infinite loops in navigation code

### Alert appears but nothing happens
- Add logging to `showDailyChallengeFromDeepLink()`
- Verify GameCoordinator has `startDailyChallenge()` method
- Check that coordinator isn't nil

## Summary

With deep linking implemented:
✅ Friends can tap a link and jump directly to challenges
✅ Better viral growth potential
✅ Smoother user experience
✅ Enhanced social features
✅ Analytics tracking of shared challenges

---

**Implementation Status**: ✅ Complete
**Testing Status**: ⚠️ Requires Info.plist configuration
**iOS Version**: 13.0+
**Last Updated**: December 28, 2025
