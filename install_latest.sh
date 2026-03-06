#!/bin/bash

set -e

REPO_OWNER="SSBun"
REPO_NAME="Shark"
APP_NAME="Shark"
TEMP_DIR=$(mktemp -d)

cleanup() {
    echo "Cleaning up..."
    if [ -d "/Volumes/$APP_NAME" ]; then
        hdiutil detach "/Volumes/$APP_NAME" -f 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo "Fetching latest release from GitHub..."

# Get latest release info
RELEASE_JSON=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")

# Find the DMG file URL
DMG_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*\.dmg"' | grep -v '\.sha256' | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')

if [ -z "$DMG_URL" ]; then
    echo "Error: Could not find DMG file in latest release"
    exit 1
fi

echo "Downloading: $DMG_URL"
DMG_PATH="$TEMP_DIR/$APP_NAME.dmg"
curl -sL "$DMG_URL" -o "$DMG_PATH"

echo "Mounting DMG..."
hdiutil attach "$DMG_PATH" -nobrowse -readonly

sleep 2

# Find the .app in the mounted volume
APP_PATH=""
if [ -d "/Volumes/$APP_NAME/$APP_NAME.app" ]; then
    APP_PATH="/Volumes/$APP_NAME/$APP_NAME.app"
elif [ -d "/Volumes/$APP_NAME/"*.app ]; then
    APP_PATH=$(ls /Volumes/$APP_NAME/*.app | head -1)
fi

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find .app in DMG"
    hdiutil detach "/Volumes/$APP_NAME" -f 2>/dev/null || true
    exit 1
fi

echo "Installing $APP_NAME to /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP_PATH" "/Applications/"

echo "Unmounting DMG..."
hdiutil detach "/Volumes/$APP_NAME" -f

echo "Running xattr to activate the application..."
xattr -rd com.apple.quarantine "/Applications/$APP_NAME.app"

echo "Installation complete! $APP_NAME has been installed to /Applications"
