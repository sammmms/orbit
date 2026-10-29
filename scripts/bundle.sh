#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$DIR/.build/release"
APP_BUNDLE="$DIR/Orbit.app"

echo "==> Building Orbit (Release)..."
cd "$DIR"
swift build -c release

echo "==> Packaging into Orbit.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/Orbit" "$APP_BUNDLE/Contents/MacOS/Orbit"

if [ ! -f "$DIR/Resources/AppIcon.icns" ]; then
    echo "==> Generating AppIcon.icns..."
    swift "$DIR/scripts/generate_icon.swift"
    mkdir -p "$DIR/Resources"
    cp "$DIR/AppIcon.icns" "$DIR/Resources/AppIcon.icns"
fi
cp "$DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Orbit</string>
    <key>CFBundleIdentifier</key>
    <string>id.bizapps.orbit</string>
    <key>CFBundleName</key>
    <string>Orbit</string>
    <key>CFBundleDisplayName</key>
    <string>Orbit</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Orbit uses automation to paste clipboard snippets into active apps.</string>
</dict>
</plist>
EOF

# Ad-hoc code signing for local execution
echo "==> Code-signing Orbit.app (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Successfully created $APP_BUNDLE!"

if [ "$1" == "run" ]; then
    echo "==> Launching Orbit.app..."
    open "$APP_BUNDLE"
fi
