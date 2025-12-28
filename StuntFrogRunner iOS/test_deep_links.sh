#!/bin/bash

# Deep Link Testing Script for StuntFrog
# Usage: ./test_deep_links.sh

echo "🐸 StuntFrog Deep Link Tester"
echo "=============================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get today's date in YYYY-MM-DD format
TODAY=$(date +%Y-%m-%d)

echo "Available test options:"
echo ""
echo "${GREEN}1. Test on Simulator (today's challenge)${NC}"
echo "2. Test on Simulator (specific date)"
echo "3. Test on Device"
echo "4. Show example share message"
echo "5. Validate Info.plist configuration"
echo ""
read -p "Choose an option (1-5): " choice

case $choice in
    1)
        echo ""
        echo "${YELLOW}Opening today's challenge on simulator...${NC}"
        xcrun simctl openurl booted "stuntfrog://challenge/$TODAY"
        echo "✅ Command sent! Check your simulator."
        ;;
    2)
        echo ""
        read -p "Enter date (YYYY-MM-DD): " custom_date
        echo "${YELLOW}Opening challenge for $custom_date on simulator...${NC}"
        xcrun simctl openurl booted "stuntfrog://challenge/$custom_date"
        echo "✅ Command sent! Check your simulator."
        ;;
    3)
        echo ""
        echo "Getting device list..."
        xcrun devicectl list devices
        echo ""
        read -p "Enter your device ID: " device_id
        echo "${YELLOW}Opening today's challenge on device...${NC}"
        xcrun devicectl device open url --device "$device_id" "stuntfrog://challenge/$TODAY"
        echo "✅ Command sent! Check your device."
        ;;
    4)
        echo ""
        echo "${GREEN}Example Share Message:${NC}"
        echo "─────────────────────────────────────"
        echo "I just crushed 'Sunny Bee Bonanza' in 2:05.43! Think you can beat me? 🐸"
        echo ""
        echo "Tap here to accept: stuntfrog://challenge/$TODAY"
        echo "─────────────────────────────────────"
        echo ""
        echo "This is what your friends will receive!"
        ;;
    5)
        echo ""
        echo "${YELLOW}Checking Info.plist configuration...${NC}"
        echo ""
        if [ -f "Info.plist" ]; then
            if grep -q "CFBundleURLTypes" Info.plist; then
                echo "✅ CFBundleURLTypes found in Info.plist"
                if grep -q "stuntfrog" Info.plist; then
                    echo "✅ 'stuntfrog' URL scheme configured"
                    echo ""
                    echo "${GREEN}Configuration looks good!${NC}"
                else
                    echo "❌ 'stuntfrog' URL scheme NOT found"
                    echo "Add 'stuntfrog' to CFBundleURLSchemes array"
                fi
            else
                echo "❌ CFBundleURLTypes NOT found in Info.plist"
                echo "You need to add URL types configuration"
                echo "See Info.plist.snippet for the required configuration"
            fi
        else
            echo "⚠️  Info.plist not found in current directory"
            echo "Run this script from your project root, or"
            echo "manually check your Info.plist file"
        fi
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "──────────────────────────────────────"
echo "Other useful test URLs:"
echo "  stuntfrog://challenge"
echo "  stuntfrog://challenge/2025-12-25"
echo "  stuntfrog://challenge/2025-01-01"
echo ""
echo "To test in Safari on device:"
echo "  1. Open Safari"
echo "  2. Type: stuntfrog://challenge/$TODAY"
echo "  3. Tap Go"
echo "  4. Tap 'Open' when prompted"
echo ""
echo "To test in Messages:"
echo "  1. Send yourself: stuntfrog://challenge/$TODAY"
echo "  2. Tap the link"
echo "  3. App should open"
echo "──────────────────────────────────────"
