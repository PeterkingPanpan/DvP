#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🔨 Building..."
swift build -c release 2>&1

echo "📦 Creating DvP.app..."
APP="$PWD/DvP.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/DvP "$APP/Contents/MacOS/DvP"
chmod +x "$APP/Contents/MacOS/DvP"

# Copy icon if exists
[ -f Assets/AppIcon.icns ] && cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DvP</string>
    <key>CFBundleIdentifier</key>
    <string>com.nuturn.dvp</string>
    <key>CFBundleName</key>
    <string>DvP</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo -n 'APPL????' > "$APP/Contents/PkgInfo"

echo "🔏 Signing with DvP Dev..."
codesign --force --deep --sign "DvP Dev" "$APP" 2>&1

echo "✅ Done: $APP"
