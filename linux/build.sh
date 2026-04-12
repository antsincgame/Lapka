#!/bin/bash
# Build Lapka for Linux
# Dependencies: gcc libx11-dev libcairo2-dev libasound2-dev
#               libxfixes-dev libxtst-dev libxext-dev libxi-dev
set -e

echo "Building Lapka..."

# Find WAV file
WAV=""
for f in cute-purr.wav purr.wav ../cute-purr.wav; do
    [ -f "$f" ] && WAV="$f" && break
done

if [ -n "$WAV" ]; then
    echo "Sound: $WAV"
else
    echo "Warning: No WAV file found. Building without sound."
    echo "Place cute-purr.wav next to the binary for purring."
fi

gcc -O2 -std=c11 -Wall -Wextra -Wno-unused-parameter \
    -o lapka lapka.c \
    -lX11 -lcairo -lXfixes -lXext -lXi -lXtst -lasound -lpthread -lm

echo ""
echo "Built ./lapka successfully! ($(du -h lapka | cut -f1))"
echo "Run: ./lapka"
echo ""
echo "Note: Place cute-purr.wav next to lapka for purring sound."
echo ""
echo "Install dependencies (Debian/Ubuntu):"
echo "  sudo apt install gcc libx11-dev libcairo2-dev libasound2-dev \\"
echo "    libxfixes-dev libxtst-dev libxext-dev libxi-dev"
echo ""
echo "Install dependencies (Fedora):"
echo "  sudo dnf install gcc libX11-devel cairo-devel alsa-lib-devel \\"
echo "    libXfixes-devel libXtst-devel libXext-devel libXi-devel"
echo ""
echo "Install dependencies (Arch):"
echo "  sudo pacman -S gcc libx11 cairo alsa-lib libxfixes libxtst libxext libxi"
