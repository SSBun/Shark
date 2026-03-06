#!/bin/bash
# Shark Installer - Downloads the latest Shark DMG from GitHub

set -e

REPO_OWNER="SSBun"
REPO_NAME="Shark"
APP_NAME="Shark"

echo "Fetching latest release from GitHub..."

# Get latest release info
RELEASE_JSON=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")

# Find the DMG file URL - look for browser_download_url containing .dmg but NOT .sha256
DMG_URL=$(echo "$RELEASE_JSON" | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*\.dmg"' | grep -v '\.sha256"' | sed 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$DMG_URL" ]; then
    echo "Error: Could not find DMG file in latest release"
    exit 1
fi

# Extract version from URL
DMG_VERSION=$(echo "$DMG_URL" | grep -oE 'Shark-[0-9]+\.[0-9]+\.[0-9]+\.dmg')

# Download to Downloads folder
DOWNLOADS_DIR="$HOME/Downloads"
DMG_PATH="$DOWNLOADS_DIR/$DMG_VERSION"

echo "Downloading: $DMG_URL"
curl -sL "$DMG_URL" -o "$DMG_PATH"

echo "Opening DMG file..."
open "$DMG_PATH"

echo ""
echo "Installation Steps:"
echo "1. Drag Shark.app to your Applications folder"
echo "2. If macOS shows 'Shark is damaged' error, run:"
echo "   xattr -rd com.apple.quarantine /Applications/Shark.app"
echo ""
echo "Download complete: $DMG_PATH"
