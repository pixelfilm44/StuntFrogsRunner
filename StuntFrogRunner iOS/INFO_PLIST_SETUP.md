# Info.plist Configuration for Deep Linking

## Overview
This guide shows you **exactly** how to configure your Info.plist to enable deep linking for StuntFrog challenge sharing.

## Step-by-Step Instructions

### Option 1: Configure Using Xcode Interface (Recommended)

1. **Open your project in Xcode**
2. **Select your app target** (StuntFrogRunner iOS)
3. **Click the "Info" tab**
4. **Add URL Types:**
   - Look for "URL Types" section (you may need to scroll down)
   - If you don't see it, click the "+" button and select "URL Types"
   - Click the "+" at the bottom of the URL Types section to add a new type
   
5. **Configure the URL Type:**
   - **Identifier**: `$(PRODUCT_BUNDLE_IDENTIFIER)` or your full bundle ID like `com.yourcompany.stuntfrog`
   - **URL Schemes**: `stuntfrog` (lowercase, no spaces)
   - **Role**: Editor
   - **Icon**: (leave empty)

### Option 2: Edit Info.plist as Source Code

If you prefer to edit the raw XML:

1. **In Xcode, right-click on Info.plist**
2. **Select "Open As" → "Source Code"**
3. **Add this XML** inside the main `<dict>` tag:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>stuntfrog</string>
        </array>
    </dict>
</array>
```

4. **Save the file**

## Verify Configuration

After adding the URL type, your Info.plist should look like this when viewed as source code:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Other keys here -->
    
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLName</key>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>stuntfrog</string>
            </array>
        </dict>
    </array>
    
    <!-- Other keys here -->
</dict>
</plist>
```

## Testing the Configuration

### 1. Clean Build

After adding the URL scheme:
1. In Xcode, press **⌘ + Shift + K** (Product → Clean Build Folder)
2. Press **⌘ + B** (Product → Build)
3. Press **⌘ + R** (Product → Run)

### 2. Test on Simulator

Once your app is running, open Terminal and run:

```bash
xcrun simctl openurl booted "stuntfrog://challenge/2025-12-28"
```

**Expected behavior:**
- Your app should come to the foreground
- Console should show: `🔗 Deep link received: stuntfrog://challenge/2025-12-28`
- You should see the "Challenge Accepted!" alert

### 3. Test on Real Device

#### Method A: Safari
1. Open Safari on your device
2. Type in address bar: `stuntfrog://challenge/2025-12-28`
3. Tap "Go"
4. You should see: "Open in StuntFrog?"
5. Tap "Open"

#### Method B: Notes
1. Open Notes app
2. Type: `stuntfrog://challenge/2025-12-28`
3. iOS will auto-detect it as a link
4. Tap the blue link
5. App should open

#### Method C: Messages
1. Send yourself a message with: `stuntfrog://challenge/2025-12-28`
2. Tap the link
3. App should open

### 4. Test Challenge Sharing

1. Open StuntFrog
2. Complete a daily challenge
3. Tap "Challenge Friend"
4. Share via Messages to yourself
5. Open the message on another device or delete the app and reinstall
6. Tap the link in the message
7. StuntFrog should open to the challenge

## Troubleshooting

### "Link doesn't open my app"

**Solution 1: Check the URL scheme is lowercase**
- Must be `stuntfrog` not `StuntFrog` or `STUNTFROG`

**Solution 2: Clean build**
```bash
# In Xcode
Product → Clean Build Folder (⌘ + Shift + K)
Product → Build (⌘ + B)
```

**Solution 3: Delete app and reinstall**
Sometimes iOS caches URL schemes. Delete the app from your device and reinstall.

### "Link opens Safari instead"

This happens if the URL scheme isn't registered. Check:
1. Info.plist has `CFBundleURLTypes`
2. URL scheme is spelled exactly: `stuntfrog`
3. You've rebuilt the app after adding the configuration

### "Link works once then stops"

Check your `SceneDelegate.swift` for the deep link handling code. Make sure:
```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    handleDeepLink(url)
}
```

### "Console shows error parsing URL"

Check the URL format:
- ✅ `stuntfrog://challenge/2025-12-28`
- ❌ `stuntfrog:/challenge/2025-12-28` (missing second slash)
- ❌ `stuntfrog://challenge` (missing date is OK)
- ❌ `Stuntfrog://challenge/2025-12-28` (uppercase S)

## What Each Part Does

### CFBundleURLTypes
This is an array that can contain multiple URL schemes. Each app can respond to multiple schemes if needed.

### CFBundleTypeRole
- **Editor**: Your app can open and edit this URL type
- **Viewer**: Your app can only view this URL type
- Use "Editor" for most cases

### CFBundleURLName
A reverse-DNS identifier for this URL type. Typically matches your bundle identifier.

### CFBundleURLSchemes
An array of URL scheme strings. For StuntFrog, we use `["stuntfrog"]`.

## Advanced: Add Universal Links (Optional)

If you have a website (e.g., `stuntfrog.app`):

### 1. Add Associated Domains

In Xcode:
1. Select target → "Signing & Capabilities"
2. Click "+ Capability"
3. Add "Associated Domains"
4. Add domain: `applinks:stuntfrog.app`

### 2. Host AASA File

On your web server, create this file at:
`https://stuntfrog.app/.well-known/apple-app-site-association`

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

Replace:
- `TEAMID` with your Apple Team ID (find in Apple Developer account)
- `com.yourcompany.stuntfrog` with your bundle identifier

### 3. Test Universal Link

```bash
# Should open your app
https://stuntfrog.app/challenge/2025-12-28
```

## Debugging Checklist

- [ ] Info.plist contains `CFBundleURLTypes`
- [ ] URL scheme is `stuntfrog` (lowercase)
- [ ] Clean build performed (⌘ + Shift + K)
- [ ] App rebuilt and reinstalled
- [ ] Tested with simulator command: `xcrun simctl openurl booted "stuntfrog://challenge/2025-12-28"`
- [ ] Console shows: `🔗 Deep link received:`
- [ ] SceneDelegate has `scene(_:openURLContexts:)` method
- [ ] `handleDeepLink` method exists and is called
- [ ] URL parsing logs show correct host and path

## Expected Console Output

When everything is working, you should see:

```
🔗 Deep link received: stuntfrog://challenge/2025-12-28
🔗 URL scheme: stuntfrog
🔗 URL host: challenge
🔗 URL path: /2025-12-28
🔗 Path components: ["2025-12-28"]
🔗 Challenge date from path: 2025-12-28
📥 Challenge received (total: 1)
🎮 Opening daily challenge from deep link
```

## Summary

✅ **Required**: Add `CFBundleURLTypes` to Info.plist with URL scheme `stuntfrog`
✅ **Required**: Clean build and reinstall app
✅ **Optional**: Add universal links for better UX
✅ **Test**: Use `xcrun simctl openurl` command
✅ **Verify**: Check console logs for deep link messages

---

**Need help?** Check the console logs and compare them to the expected output above.

**Last Updated**: December 28, 2025
