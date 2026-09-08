# Pocket Duel — Snooker

Local two-player snooker for Android (Godot 4.x, GDScript). See
[`roadmap.md`](roadmap.md) for the full plan.

**Current milestone:** Milestone 1 — Physics Prototype (Phase 0 + Phase 1).
Table, six pockets, cue ball, one red, custom physics, aim + power. No menus,
scoring, or full ball rack yet — that comes only once the physics *feels good*.

---

## 1. Install Godot

1. Download **Godot 4.x Stable — Standard** (not the .NET/Mono build; this
   project uses GDScript) from <https://godotengine.org/download>.
2. It's a single executable — no installer needed. Unzip and run it.

On Linux you can also do:

```bash
# Example — check the site for the current 4.x version and adjust the URL.
cd ~/Downloads
unzip Godot_v4.*_stable_linux.x86_64.zip
chmod +x Godot_v4.*_stable_linux.x86_64
./Godot_v4.*_stable_linux.x86_64
```

## 2. Open and run this project

1. Launch Godot → **Import**.
2. Select this folder's `project.godot` (`/var/www/html/game/project.godot`).
3. Once it opens, press **F5** (or the ▶ Play button, top-right).

The main scene is `scenes/snooker/snooker_game.tscn` and runs on launch.

## 3. How to play (prototype controls)

- **Press and drag away** from the cue ball, then **release** — slingshot aim.
  Pull further = more power (watch the power bar, bottom-left).
- The white aim line shows the shot direction; controls lock while balls roll
  and unlock when everything stops.
- **Restart / rematch** from the pause menu (the **II** button or **Esc**).
  (Desktop dev shortcut: **R**. Right-click does nothing — it must never reset a live frame.)

## 4. What to check (Phase 1 success test)

Aim → set power → shoot → cue hits red → natural motion → correct cushion
bounces → friction slows the balls → red drops into a pocket → pocket detected.

If anything feels off (too slippery, bounces too lively, stops too abruptly,
power too weak/strong), tell me which — every value lives in the **Tunables**
block at the top of [`scripts/snooker/game_manager.gd`](scripts/snooker/game_manager.gd)
and the cue's `MAX_DRAG` in [`scripts/snooker/cue.gd`](scripts/snooker/cue.gd).

## 5. Test on an Android phone

See [`ANDROID.md`](ANDROID.md) for the full setup. Short version: Godot has no
Expo-Go-style QR flow — you do a one-time toolchain setup (JDK 17, Android SDK,
export templates), then **One-Click Deploy** over USB runs it on your phone, or
you export an **APK** to sideload/share.

---

## Project layout

```
scenes/snooker/snooker_game.tscn   Main scene (loads on launch)
scripts/snooker/game_manager.gd    Physics step + owns table/balls/cue
scripts/snooker/ball.gd            Ball data + drawing (class_name Ball)
scripts/snooker/table.gd           Table geometry + pockets (class_name Table)
scripts/snooker/cue.gd             Aim/power input + visuals (class_name Cue)
```
# pocket_duel
# pocket_duel
