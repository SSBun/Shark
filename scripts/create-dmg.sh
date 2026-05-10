#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Shark...${NC}"

# Build the app
xcodebuild \
  -scheme Shark \
  -configuration Release \
  -derivedDataPath build \
  -destination 'platform=macOS' \
  clean build

# Find the built app
APP_PATH=$(find build -name "Shark.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo -e "${RED}Error: Could not find built app${NC}"
  exit 1
fi

echo -e "${GREEN}App built at: $APP_PATH${NC}"

# Get version from tag or use default
VERSION=${1:-"dev"}
DMG_NAME="Shark-${VERSION}.dmg"

echo -e "${GREEN}Creating DMG: $DMG_NAME${NC}"

# Create temporary directory
TMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DIR/"

# Create INSTALL.md with instructions
cat > "$TMP_DIR/INSTALL.md" << 'EOF'
# Shark Installation Guide

## Quick Install
1. Drag Shark.app to the Applications folder
2. Run the following command in Terminal to fix the app:
   ```
   xattr -cr /Applications/Shark.app
   ```
3. Launch Shark from Applications

## Why do I need to run xattr?
This command removes extended attributes that macOS adds when downloading DMG files. These attributes can prevent the app from launching properly.

EOF

echo -e "${GREEN}Created INSTALL.md${NC}"

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
  echo -e "${GREEN}Using create-dmg...${NC}"
  create-dmg \
    --volname "Shark" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "Shark.app" 175 190 \
    --hide-extension "Shark.app" \
    --app-drop-link 425 190 \
    --no-internet-enable \
    "$DMG_NAME" \
    "$TMP_DIR/"
else
  echo -e "${YELLOW}create-dmg not found, using hdiutil...${NC}"
  echo -e "${YELLOW}Install create-dmg with: brew install create-dmg${NC}"
  ln -s /Applications "$TMP_DIR/Applications"
  hdiutil create -volname "Shark" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_NAME"
fi

# Clean up
rm -rf "$TMP_DIR"
rm -f rw.*."$DMG_NAME"

# Calculate checksum
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"

echo -e "${GREEN}✓ DMG created: $DMG_NAME${NC}"
echo -e "${GREEN}✓ Checksum: ${NC}"
cat "${DMG_NAME}.sha256"

echo ""
echo -e "${GREEN}To test the DMG:${NC}"
echo -e "  1. Open $DMG_NAME"
echo -e "  2. Drag Shark to Applications"
echo -e "  3. Launch from Applications folder"

