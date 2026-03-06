#!/bin/bash
# Shark Installer - Downloads the latest Shark DMG from GitHub

set -e

REPO_OWNER="SSBun"
REPO_NAME="Shark"
APP_NAME="Shark"

echo "Fetching latest release from GitHub..."

# Get the latest release tag by following the redirect
# This doesn't require API access - just github.com
LATEST_URL=$(curl -sL "https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest" -w "%{url_effective}" -o /dev/null)

# Extract tag from URL (e.g., https://github.com/SSBun/Shark/releases/tag/v1.1.4 -> v1.1.4)
TAG=$(echo "$LATEST_URL" | sed 's/.*\/tag\///')

# Remove 'v' prefix from tag for version number (v1.1.4 -> 1.1.4)
VERSION=$(echo "$TAG" | sed 's/^v//')

# Construct the download URL
DMG_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$TAG/$APP_NAME-$VERSION.dmg"

# Download to Downloads folder
DMG_VERSION="$APP_NAME-$VERSION.dmg"
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
