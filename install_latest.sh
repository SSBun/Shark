#!/bin/bash
# Shark Installer - Downloads the latest Shark DMG from GitHub

set -e

REPO_OWNER="SSBun"
REPO_NAME="Shark"
APP_NAME="Shark"

echo "Fetching latest release from GitHub..."

# Method 1: Try GitHub API (works if user can access api.github.com)
RELEASE_JSON=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" 2>/dev/null)

if [ -n "$RELEASE_JSON" ] && echo "$RELEASE_JSON" | grep -q "browser_download_url"; then
    # API worked - extract DMG URL
    DMG_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url" *: *"[^"]*\.dmg"' | grep -v sha256 | head -1 | sed 's/.*"browser_download_url" *: *"\([^"]*\)".*/\1/')
else
    # Method 2: API failed - scrape the releases page HTML
    echo "API not accessible, trying alternative method..."
    RELEASE_HTML=$(curl -sL "https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest")
    DMG_URL=$(echo "$RELEASE_HTML" | grep -o 'https://github.com/SSBun/Shark/releases/download/[^"]*\.dmg' | grep -v sha256 | head -1)
fi

if [ -z "$DMG_URL" ]; then
    echo "Error: Could not find DMG file"
    echo "Please download manually from: https://github.com/$REPO_OWNER/$REPO_NAME/releases"
    exit 1
fi

# Extract version from URL
DMG_VERSION=$(echo "$DMG_URL" | sed 's/.*\(Shark-[0-9.]*\.dmg\).*/\1/')

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
