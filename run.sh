#!/bin/bash

# Exit on error
set -e

APP_NAME="FocusTick"
SCHEME="FocusTick"
BUILD_DIR="./build"

echo "🔨 Building $APP_NAME..."

# Check if xcodebuild is available
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: 'xcodebuild' not found. Please ensure Xcode is installed."
    echo "If you have Xcode installed, try running: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# Build the app into the local build directory
xcodebuild -project "$APP_NAME.xcodeproj" \
           -scheme "$SCHEME" \
           -configuration Debug \
           -derivedDataPath "$BUILD_DIR" \
           build

# Find the built .app file
APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find the built .app bundle."
    exit 1
fi

echo "🚀 Launching $APP_NAME..."
open "$APP_PATH"

echo "✅ $APP_NAME is now running in your menu bar!"
