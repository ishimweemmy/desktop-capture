#!/bin/bash
set -e

echo "================================"
echo "Installing Native Messaging Host"
echo "================================"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script is for macOS only"
    exit 1
fi

# Get absolute path to binary
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BINARY_PATH="$SCRIPT_DIR/build/DesktopCapture.app/Contents/MacOS/DesktopCapture"

if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: Binary not found at $BINARY_PATH"
    echo "Please run ./build.sh first"
    exit 1
fi

echo "Binary path: $BINARY_PATH"
echo ""

# Prompt for Chrome extension ID
echo "To get your Chrome extension ID:"
echo "1. Open Chrome and go to chrome://extensions/"
echo "2. Enable 'Developer mode' (toggle in top-right)"
echo "3. Click 'Load unpacked' and select the chrome-extension folder"
echo "4. Copy the Extension ID shown in the extension card"
echo ""

read -p "Enter Chrome Extension ID: " EXTENSION_ID

if [ -z "$EXTENSION_ID" ]; then
    echo "Error: Extension ID is required"
    exit 1
fi

echo ""
echo "Extension ID: $EXTENSION_ID"

# Create Native Messaging host manifest
MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
mkdir -p "$MANIFEST_DIR"

MANIFEST_PATH="$MANIFEST_DIR/com.desktopcapture.host.json"

cat > "$MANIFEST_PATH" << EOF
{
  "name": "com.desktopcapture.host",
  "description": "Desktop Capture Native Messaging Host",
  "path": "$BINARY_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXTENSION_ID/"
  ]
}
EOF

echo ""
echo "Native Messaging host manifest created:"
echo "$MANIFEST_PATH"
echo ""
echo "================================"
echo "Installation Complete!"
echo "================================"
echo ""
echo "The Chrome extension can now communicate with the native app."
echo ""
echo "Next steps:"
echo "1. Make sure the extension is loaded in Chrome"
echo "2. Grant permissions (Accessibility, Screen Recording)"
echo "3. Start the app: $BINARY_PATH"
echo ""
