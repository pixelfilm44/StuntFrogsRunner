# Deep Link Testing Commands

## Quick Test Commands

### Simulator Testing

```bash
# Test basic challenge link
xcrun simctl openurl booted "stuntfrog://challenge/2025-12-28"

# Test challenge link without date (should use today)
xcrun simctl openurl booted "stuntfrog://challenge"

# Test with different dates
xcrun simctl openurl booted "stuntfrog://challenge/2025-12-29"
xcrun simctl openurl booted "stuntfrog://challenge/2025-12-30"
```

### Real Device Testing

First, find your device:
```bash
xcrun devicectl list devices
```

Then test (replace DEVICE_ID with your device's ID):
```bash
# Example device ID: 00008110-000123456789ABCD
xcrun devicectl device open url --device DEVICE_ID "stuntfrog://challenge/2025-12-28"
```

## Expected Behavior

### ✅ Success Indicators

1. **App launches or comes to foreground**
2. **Console logs appear:**
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

3. **Alert appears: "Challenge Accepted! 🐸"**
4. **User can tap "Let's Go!" to start challenge**

### ❌ Failure Indicators

1. **Nothing happens when running command**
   - Check Info.plist configuration
   - Try clean build (⌘ + Shift + K)

2. **Safari opens instead of app**
   - URL scheme not registered
   - App needs to be reinstalled

3. **App opens but no alert**
   - Check SceneDelegate implementation
   - Verify GameCoordinator has the extension

4. **Console shows error**
   - Check URL format
   - Verify date is correct format (YYYY-MM-DD)

## Manual Testing Steps

### Step 1: Share a Challenge

1. Launch StuntFrog
2. Go to Daily Challenges
3. Complete a challenge (or skip for testing)
4. Complete the challenge
5. On Game Over screen, tap "CHALLENGE FRIEND"
6. Choose "Copy Challenge Text"
7. Paste into Notes to verify format

**Expected clipboard content:**
```
I just crushed 'Sunny Bee Bonanza' in 2:05.43! Think you can beat me? 🐸

stuntfrog://challenge/2025-12-28
```

### Step 2: Test the Link

1. Paste the link into Notes
2. Tap the blue `stuntfrog://...` link
3. iOS prompts: "Open in StuntFrog?"
4. Tap "Open"
5. Verify alert appears

### Step 3: Test Via Messages

1. Send the copied text to yourself via Messages
2. On another device (or same device after force-quit)
3. Tap the link
4. Verify app opens correctly

## Debugging Commands

### Check if URL scheme is registered

```bash
# List all URL schemes for your app
# (This won't directly show custom schemes, but confirms app installation)
xcrun simctl listapps booted | grep -i stunt
```

### View app's Info.plist

```bash
# Find your app's data directory
xcrun simctl get_app_container booted com.yourcompany.stuntfrog

# Then navigate to that directory and view Info.plist
```

### Force reinstall

```bash
# Uninstall
xcrun simctl uninstall booted com.yourcompany.stuntfrog

# Then rebuild and run in Xcode
```

## Common Issues & Fixes

### Issue: "xcrun: error: unable to find utility"

**Solution**: Install Xcode Command Line Tools
```bash
xcode-select --install
```

### Issue: "No devices are booted"

**Solution**: Start a simulator first
```bash
# List available simulators
xcrun simctl list devices

# Boot a simulator (example)
xcrun simctl boot "iPhone 15 Pro"

# Or just launch Simulator.app and start a device
```

### Issue: Deep link opens Safari

**Solution**:
1. Delete app from device/simulator
2. Clean build folder in Xcode (⌘ + Shift + K)
3. Build and run again (⌘ + R)

### Issue: Link works in simulator but not on device

**Solution**: Check if device is registered
```bash
# List devices
xcrun devicectl list devices

# If not listed, reconnect device and trust computer
```

## Testing Checklist

- [ ] Info.plist has URL scheme `stuntfrog`
- [ ] App builds without errors
- [ ] Simulator test works: `xcrun simctl openurl booted "stuntfrog://challenge/2025-12-28"`
- [ ] Console shows deep link logs
- [ ] Alert appears: "Challenge Accepted! 🐸"
- [ ] Tapping "Let's Go!" starts challenge
- [ ] Link works from Notes app
- [ ] Link works from Messages app
- [ ] Link works from Safari
- [ ] Analytics tracking works (challenge received count increments)
- [ ] Real device test works (if applicable)

## Performance Testing

Test rapid link taps (should not crash):
```bash
# Send 5 links in quick succession
for i in {1..5}; do
  xcrun simctl openurl booted "stuntfrog://challenge/2025-12-28"
  sleep 1
done
```

Expected: App handles gracefully without crashing

## Edge Cases to Test

1. **Invalid date format:**
   ```bash
   xcrun simctl openurl booted "stuntfrog://challenge/2025-13-99"
   ```
   Expected: Falls back to today's challenge

2. **Missing date:**
   ```bash
   xcrun simctl openurl booted "stuntfrog://challenge"
   ```
   Expected: Uses today's challenge

3. **Old date:**
   ```bash
   xcrun simctl openurl booted "stuntfrog://challenge/2020-01-01"
   ```
   Expected: Shows appropriate message or today's challenge

4. **Future date:**
   ```bash
   xcrun simctl openurl booted "stuntfrog://challenge/2026-01-01"
   ```
   Expected: Shows appropriate message or today's challenge

5. **Wrong host:**
   ```bash
   xcrun simctl openurl booted "stuntfrog://invalid/test"
   ```
   Expected: Logs error, doesn't crash

## Success Criteria

✅ All simulator tests pass
✅ All manual tests pass
✅ Console logs show correct parsing
✅ No crashes with edge cases
✅ Real device testing works
✅ Share sheet includes tappable link
✅ Analytics tracking works

---

**Pro Tip**: Keep the Console open in Xcode while testing to see real-time logs!

**Last Updated**: December 28, 2025
