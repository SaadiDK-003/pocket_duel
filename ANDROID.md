# Testing Pocket Duel on an Android phone

**There is no Expo Go equivalent for Godot** — no companion app + QR code. You
either **One-Click Deploy** over USB (the fast dev loop, closest to Expo Go) or
build an **APK** and install it. Both need a one-time toolchain setup on your
machine. After that, deploying is a single click.

> This machine (the server the project lives on) has **no** Java / Android SDK /
> Godot export templates, so an APK can't be built here. Do the steps below on
> the computer where you run the Godot editor.

---

## ✅ Already set up on this machine (mage4)

The toolchain is installed and a signed debug APK already builds here:
- JDK 17, Android SDK at `~/Android` (platform-tools/`adb`, build-tools 34, android-34)
- Godot 4.7.2 export templates installed
- Debug keystore at `~/.android/debug.keystore`, wired into Godot's editor settings
- Android export preset committed (`export_presets.cfg`); ETC2/ASTC enabled

**Rebuild the APK any time:**
```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=$HOME/Android
godot --headless --path /var/www/html/game --export-debug "Android" build/pocket-duel.apk
```

**Install it on a phone plugged into this machine (USB debugging on):**
```bash
~/Android/platform-tools/adb install -r /var/www/html/game/build/pocket-duel.apk
```
Or open the project in the Godot editor, plug in the phone, and use the
top-right **One-Click Deploy** icon.

The steps below are the from-scratch reference (e.g. for another machine).

---

## One-time setup (~20–30 min)

### 1. Java (JDK 17)
Godot's Android build needs JDK **17** (not newer).
```bash
# Ubuntu/Debian
sudo apt install openjdk-17-jdk
java -version   # should say 17.x
```
On Windows/macOS install Temurin/Adoptium JDK 17.

### 2. Android SDK + platform-tools (gives you `adb`)
Easiest: install **Android Studio**, open it once, and let it install the SDK.
Or command-line only:
```bash
# Linux example — adjust paths/versions as needed
mkdir -p ~/Android/cmdline-tools
# download "Command line tools" from https://developer.android.com/studio#command-tools
# unzip so you have ~/Android/cmdline-tools/latest/bin/sdkmanager
cd ~/Android/cmdline-tools/latest/bin
./sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"
```
Make sure `adb` works: `~/Android/platform-tools/adb version`.

### 3. Godot Android export templates
In the Godot editor (matching your version, 4.7.x):
**Editor → Manage Export Templates… → Download and Install.**

### 4. Point Godot at the SDK + a debug key
**Editor → Editor Settings → Export → Android:**
- **Android SDK Path** → your SDK folder (e.g. `~/Android`).
- **Debug Keystore** → Godot 4 can create one automatically; if the field is
  empty, click to generate, or make one:
  ```bash
  keytool -keyalg RSA -genkeypair -alias androiddebugkey \
    -keypass android -keystore debug.keystore -storepass android \
    -dname "CN=Android Debug,O=Android,C=US" -validity 9999
  ```
  Point the Debug Keystore field at that `debug.keystore` (user + password
  `androiddebugkey` / `android`).

### 5. Create the Android export preset
**Project → Export… → Add… → Android.** Defaults are fine for testing.
Set a **Unique Name** (package id) like `com.devteampro.pocketduel`.
(The generated `export_presets.cfg` is git-ignored on purpose — it can hold a
release keystore path/password. That's expected.)

### 6. Install the Android build template (needed for the gradle build)
**Project → Install Android Build Template…** (creates an `android/` folder).

---

## Put the phone in developer mode
1. **Settings → About phone → tap "Build number" 7 times** (enables Developer
   options).
2. **Settings → Developer options → enable "USB debugging".**
3. Plug the phone into the computer with a USB cable. On the phone, **Allow USB
   debugging** when prompted.
4. Confirm the computer sees it:
   ```bash
   adb devices    # your phone should be listed as "device"
   ```

---

## Run it — the fast loop (like Expo Go)
With the phone connected and detected, Godot shows a small **Android/phone icon
in the top-right toolbar**. Click it (or the ▶ deploy dropdown → your device) and
Godot builds, installs, and launches Pocket Duel on the phone. Each change =
click again to redeploy.

Remote debug output (prints, errors) streams back to the editor's Output panel.

## Run it — the APK way (share/sideload)
**Project → Export… → select the Android preset → Export Project…** → save
`pocket-duel.apk`. Then:
```bash
adb install -r pocket-duel.apk        # install over USB
```
or copy the `.apk` to the phone (Drive/USB/email) and tap it to install
(enable "install from unknown sources" for the installer app). This APK is what
you'd share with testers.

## Wireless (optional, no cable after pairing)
Android 11+:
```bash
adb pair <phone-ip>:<pair-port>       # from phone's Wireless debugging screen
adb connect <phone-ip>:<port>
```
Then One-Click Deploy works over Wi-Fi.

---

## Notes
- The game is **landscape** (sensor landscape) and scales to any screen via
  Godot's `canvas_items` stretch, so phones/tablets of different ratios are fine.
- If a build fails, the editor Output usually names the cause (wrong JDK, SDK
  path, missing build template). Fixing that field and redeploying is enough.
- Ads and the Remove Ads purchase are **not** in the build yet (later phases);
  this is the clean game for playtesting.
