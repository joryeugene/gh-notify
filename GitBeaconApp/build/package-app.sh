#!/usr/bin/env bash
# package-app.sh: Assemble GitBeacon.app bundle from SPM build output.
# Usage: ./build/package-app.sh [debug|release]
set -euo pipefail

MODE="${1:-debug}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${REPO_ROOT}/.build/GitBeacon.app"

if [[ "$MODE" == "release" ]]; then
    BIN="${REPO_ROOT}/.build/apple/Products/Release/GitBeaconApp"
else
    BIN="${REPO_ROOT}/.build/debug/GitBeaconApp"
fi

[[ -f "$BIN" ]] || { echo "Binary not found: $BIN"; echo "Run: swift build first"; exit 1; }

echo "Assembling GitBeacon.app ($MODE)..."

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/bin"

cp "$BIN" "$APP_DIR/Contents/MacOS/GitBeaconApp"
chmod +x "$APP_DIR/Contents/MacOS/GitBeaconApp"

# Build .icns from icon.svg
ICON_SVG="${REPO_ROOT}/../assets/icon.svg"
if [[ -f "$ICON_SVG" ]] && command -v rsvg-convert &>/dev/null; then
    echo "Building app icon..."
    ICON_BUILD="${REPO_ROOT}/.build/icon-build"
    mkdir -p "$ICON_BUILD"
    rsvg-convert -w 1024 -h 1024 "$ICON_SVG" -o "${ICON_BUILD}/icon-1024.png"
    ICONSET="${ICON_BUILD}/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512 1024; do
        sips -z "$size" "$size" "${ICON_BUILD}/icon-1024.png" \
            --out "${ICONSET}/icon_${size}x${size}.png" &>/dev/null
    done
    cp "${ICONSET}/icon_32x32.png"     "${ICONSET}/icon_16x16@2x.png"
    cp "${ICONSET}/icon_64x64.png"     "${ICONSET}/icon_32x32@2x.png"
    cp "${ICONSET}/icon_256x256.png"   "${ICONSET}/icon_128x128@2x.png"
    cp "${ICONSET}/icon_512x512.png"   "${ICONSET}/icon_256x256@2x.png"
    cp "${ICONSET}/icon_1024x1024.png" "${ICONSET}/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET" --output "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf "$ICON_BUILD"
fi

# Copy daemon script into Resources
SCRIPTS_DIR="$(cd "$REPO_ROOT/.." && pwd)/scripts"
if [[ -f "$SCRIPTS_DIR/gitbeacon-daemon.sh" ]]; then
    cp "$SCRIPTS_DIR/gitbeacon-daemon.sh" "$APP_DIR/Contents/Resources/"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.joryeugene.gitbeacon-app</string>
    <key>CFBundleName</key>
    <string>GitBeacon</string>
    <key>CFBundleDisplayName</key>
    <string>GitBeacon</string>
    <key>CFBundleExecutable</key>
    <string>GitBeaconApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "Built: $APP_DIR"
echo "Run:   open $APP_DIR"
