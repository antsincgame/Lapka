#!/bin/bash
# Build Lapka.app for macOS
set -e

APP="Lapka.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo "Compiling Lapka.swift..."
swiftc -O -o "$MACOS_DIR/Lapka" Lapka.swift \
    -framework Cocoa \
    -framework AVFoundation \
    -framework CoreGraphics

cp Info.plist "$CONTENTS/"

if [ -f cute-purr.mp3 ]; then
    cp cute-purr.mp3 "$RES_DIR/"
    echo "Sound embedded."
elif [ -f ../cute-purr.mp3 ]; then
    cp ../cute-purr.mp3 "$RES_DIR/"
    echo "Sound embedded from parent dir."
else
    echo "Warning: cute-purr.mp3 not found. App will work without sound."
fi

echo ""
echo "Built $APP successfully!"
echo "Run: open $APP"
echo ""
echo "Note: macOS will ask for Accessibility permission on first launch."
echo "Go to System Settings → Privacy & Security → Accessibility → enable Lapka."
