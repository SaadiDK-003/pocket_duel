#!/usr/bin/env bash
# Build the Linux desktop executable (single self-contained file).
set -e
cd "$(dirname "$0")"
mkdir -p build
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Linux" build/pocket-duel.x86_64
chmod +x build/pocket-duel.x86_64
echo "Built: $(pwd)/build/pocket-duel.x86_64"
