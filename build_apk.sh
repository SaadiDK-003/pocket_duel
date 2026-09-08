#!/usr/bin/env bash
# Build a signed debug APK headless (mage4). Ensures Godot's editor Android
# settings point at the right SDK/JDK/keystore, then exports directly (no editor
# --import run, which tends to revert those settings).
set -e

ES="$HOME/.config/godot/editor_settings-4.7.tres"
if [ -f "$ES" ]; then
  sed -i 's|export/android/android_sdk_path = .*|export/android/android_sdk_path = "'"$HOME"'/Android"|' "$ES"
  sed -i 's|export/android/java_sdk_path = .*|export/android/java_sdk_path = "/usr/lib/jvm/java-17-openjdk-amd64"|' "$ES"
  sed -i 's|export/android/debug_keystore = .*|export/android/debug_keystore = "'"$HOME"'/.android/debug.keystore"|' "$ES"
fi

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME="$HOME/Android"
export ANDROID_SDK_ROOT="$HOME/Android"

cd "$(dirname "$0")"
mkdir -p build
godot --headless --path . --export-debug "Android" build/pocket-duel.apk
echo "Built: $(pwd)/build/pocket-duel.apk"
