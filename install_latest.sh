#!/bin/bash
# Shark Installer - Downloads and installs the latest Shark release from GitHub

set -e

REPO_OWNER="SSBun"
REPO_NAME="Shark"
APP_NAME="Shark"
TEMP_DIR=$(mktemp -d)

cleanup() {
    echo "Cleaning up..."
    # Detach any mounted Shark volumes
    for vol in /Volumes/Shark*; do
        if [ -d "$vol" ]; then
            hdiutil detach "$vol" 2>/dev/null || true
        fi
    done
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo "Fetching latest release from GitHub..."

# Get latest release info
RELEASE_JSON=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")

# Find the DMG file URL - look for browser_download_url containing .dmg but NOT .sha256
DMG_URL=$(echo "$RELEASE_JSON" | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*\.dmg"' | grep -v '\.sha256"' | sed 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$DMG_URL" ]; then
    echo "Error: Could not find DMG file in latest release"
    echo "Release JSON: $RELEASE_JSON"
    exit 1
fi

echo "Downloading: $DMG_URL"
DMG_PATH="$TEMP_DIR/$APP_NAME.dmg"
curl -sL "$DMG_URL" -o "$DMG_PATH"

echo "Mounting DMG..."
hdiutil attach "$DMG_PATH" -nobrowse -readonly

sleep 2

# Find the .app in the mounted volume (handle spaces in volume name)
APP_PATH=""
for vol in /Volumes/Shark*; do
    if [ -d "$vol" ]; then
        if [ -d "$vol/$APP_NAME.app" ]; then
            APP_PATH="$vol/$APP_NAME.app"
            break
        elif [ -d "$vol/"*.app ]; then
            APP_PATH=$(ls "$vol"/*.app | head -1)
            break
        fi
    fi
done

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: Could not find .app in DMG"
    exit 1
fi

echo "Installing $APP_NAME to /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP_PATH" "/Applications/"

echo "Unmounting DMG..."
# Get the mount point and detach it
MOUNT_POINT=$(df "$APP_PATH" | tail -1 | awk '{print $NF}')
hdiutil detach "$MOUNT_POINT"

echo "Running xattr to activate the application..."
xattr -rd com.apple.quarantine "/Applications/$APP_NAME.app"

echo "Installation complete! $APP_NAME has been installed to /Applications"
