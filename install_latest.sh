#!/bin/bash
# Shark Installer - Downloads the latest Shark DMG from GitHub

set -e

REPO_OWNER="SSBun"
REPO_NAME="Shark"
APP_NAME="Shark"

echo "Fetching latest release from GitHub..."

# Get latest release info
RELEASE_JSON=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")

# Use Python to parse JSON and extract DMG URL
DMG_URL=$(python3 -c "
import json
import sys

data = json.loads('$RELEASE_JSON')
assets = data.get('assets', [])

for asset in assets:
    name = asset.get('name', '')
    url = asset.get('browser_download_url', '')
    if name.endswith('.dmg') and not name.endswith('.sha256'):
        print(url)
        break
" 2>/dev/null)

if [ -z "$DMG_URL" ]; then
    echo "Error: Could not find DMG file in latest release"
    echo "Debug: $RELEASE_JSON"
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
