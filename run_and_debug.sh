#!/bin/bash

# DevCam Debug Launch Script
# This script launches DevCam from Xcode and captures all debug output

echo "========================================="
echo "DevCam Debug Launch"
echo "========================================="
echo ""

# Kill existing instance
echo "1. Killing existing DevCam instances..."
killall DevCam 2>/dev/null && echo "   ✓ Existing instance terminated" || echo "   ℹ No existing instance"

echo ""
echo "2. Building DevCam with debug logging..."
cd "$(dirname "$0")"
xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(BUILD|error:|warning:)" | tail -10

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "   ✗ Build failed!"
    exit 1
fi

echo "   ✓ Build succeeded"

echo ""
echo "3. Launching DevCam..."
echo "   App location: Build/Products/Debug/DevCam.app"
echo ""
echo "========================================="
echo "DEBUG OUTPUT BELOW:"
echo "========================================="
echo ""

# Run and capture all output
/Users/dev/Library/Developer/Xcode/DerivedData/DevCam-ctedjoxnerhfsiheymhmgbroqwuq/Build/Products/Debug/DevCam.app/Contents/MacOS/DevCam 2>&1

