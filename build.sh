#!/bin/bash
set -e

echo "================================"
echo "Building Desktop Capture v0"
echo "================================"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This build script is for macOS only"
    exit 1
fi

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed"
    echo "Please install Xcode from the App Store"
    exit 1
fi

echo "Building native app..."
cd native-app

# Build in release mode
swift build -c release

echo ""
echo "Build successful!"
echo ""

# Copy binary to build folder
BUILD_DIR="../build"
mkdir -p "$BUILD_DIR"

BINARY_PATH=".build/release/DesktopCapture"

if [ -f "$BINARY_PATH" ]; then
    cp "$BINARY_PATH" "$BUILD_DIR/"
    echo "Binary copied to: $BUILD_DIR/DesktopCapture"
    echo ""
else
    echo "Error: Binary not found at $BINARY_PATH"
    exit 1
fi

# Create app bundle structure (optional but cleaner)
APP_BUNDLE="$BUILD_DIR/DesktopCapture.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/DesktopCapture"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DesktopCapture</string>
    <key>CFBundleIdentifier</key>
    <string>com.desktopcapture.app</string>
    <key>CFBundleName</key>
    <string>DesktopCapture</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "App bundle created: $APP_BUNDLE"
echo ""

cd ..

echo "================================"
echo "Build Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo "1. Run ./install-chrome-host.sh to set up Native Messaging"
echo "2. Load chrome-extension/ as unpacked extension in Chrome"
echo "3. Grant Accessibility and Screen Recording permissions"
echo "4. Run: $APP_BUNDLE/Contents/MacOS/DesktopCapture"
echo ""
