# Pocket Duel — Snooker MVP Roadmap

## Project Goal

Build a polished, free Android snooker game focused first on **local two-player gameplay on one device**.

The first release should prioritize:

- Smooth and satisfying snooker physics
- Simple controls
- Proper scoring and core snooker rules
- Good mobile performance
- Clean UI
- Minimal, non-intrusive advertising
- One-time **Remove Ads** purchase
- Architecture that allows more two-player games to be added later

---

# Tech Stack

## Game Engine

- **Godot 4.x Stable**
- **GDScript**
- Android-first
- Landscape orientation

## Initial Target Resolution

- Design around `1920x1080`
- Responsive scaling for different Android screen sizes

## Backend

No backend is required for the first version.

Do **not** add yet:

- Laravel
- Node.js
- MySQL
- PostgreSQL
- WebSockets
- User accounts
- Cloud saves
- Online multiplayer

---

# Project Structure

```text
pocket-duel/
│
├── assets/
│   ├── audio/
│   ├── fonts/
│   ├── icons/
│   ├── shared/
│   └── snooker/
│       ├── balls/
│       ├── cues/
│       ├── tables/
│       └── ui/
│
├── scenes/
│   ├── main_menu/
│   │   └── main_menu.tscn
│   │
│   ├── snooker/
│   │   ├── snooker_game.tscn
│   │   ├── table.tscn
│   │   ├── ball.tscn
│   │   └── cue.tscn
│   │
│   └── shared/
│
├── scripts/
│   ├── snooker/
│   │   ├── ball.gd
│   │   ├── cue.gd
│   │   ├── game_manager.gd
│   │   ├── rules_manager.gd
│   │   └── turn_manager.gd
│   │
│   └── shared/
│       ├── settings_manager.gd
│       └── audio_manager.gd
│
├── ui/
│
└── project.godot
```

This structure should make it easy to add future games such as:

```text
scenes/
├── snooker/
├── air_hockey/
├── pong/
├── football/
└── tank_duel/
```

---

# Development Roadmap

## Phase 0 — Project Setup

### Tasks

- [ ] Create Godot project
- [ ] Configure Android export
- [ ] Set landscape orientation
- [ ] Configure responsive viewport
- [ ] Create project folder structure
- [ ] Initialize Git repository
- [ ] Create `.gitignore`
- [ ] Create first `snooker_game.tscn`
- [ ] Test project on a real Android device

### Goal

A blank Android build should install and launch successfully.

---

# Phase 1 — Core Physics Prototype

Do not build menus or monetization yet.

Start with only:

- White cue ball
- One red ball
- Table
- Six pockets

## Table

- [ ] Add snooker table background
- [ ] Add playable table surface
- [ ] Add six pockets
- [ ] Add cushion collisions
- [ ] Add correct table boundaries
- [ ] Prevent balls from leaving the table

## Ball Physics

- [ ] Create reusable ball scene
- [ ] Create circular collision shape
- [ ] Add ball velocity
- [ ] Add friction
- [ ] Add ball-to-ball collision
- [ ] Add ball-to-cushion collision
- [ ] Add minimum velocity threshold
- [ ] Stop balls cleanly when velocity becomes very low
- [ ] Prevent overlapping balls
- [ ] Detect pocket entry
- [ ] Remove or disable potted balls

## Shooting

- [ ] Select cue ball
- [ ] Show aiming direction
- [ ] Add aiming guide line
- [ ] Add cue graphic
- [ ] Add power control
- [ ] Shoot cue ball
- [ ] Disable controls while balls are moving
- [ ] Re-enable controls after all balls stop

### Phase 1 Success Test

```text
Aim
↓
Set power
↓
Shoot cue ball
↓
Cue ball hits red
↓
Balls move naturally
↓
Balls bounce correctly
↓
Friction slows balls
↓
Red enters pocket
↓
Pocket is detected
```

Do not proceed until this feels good.

---

# Phase 2 — Full Snooker Ball Setup

## Add All Balls

- [ ] 15 Red balls
- [ ] Yellow ball
- [ ] Green ball
- [ ] Brown ball
- [ ] Blue ball
- [ ] Pink ball
- [ ] Black ball
- [ ] White cue ball

## Ball Values

```text
Red    = 1
Yellow = 2
Green  = 3
Brown  = 4
Blue   = 5
Pink   = 6
Black  = 7
```

## Starting Positions

- [ ] Correct red triangle
- [ ] Yellow starting position
- [ ] Green starting position
- [ ] Brown starting position
- [ ] Blue starting position
- [ ] Pink starting position
- [ ] Black starting position
- [ ] Cue ball starting area

## Ball Data

Each ball should track:

```text
type
color
value
position
velocity
is_potted
starting_position
```

---

# Phase 3 — Local Two-Player System

The first public version should support two people sharing one Android device.

## Players

- [ ] Player 1
- [ ] Player 2
- [ ] Current player indicator
- [ ] Player names
- [ ] Player score
- [ ] Turn switching

## Shot Lifecycle

```text
Player aims
↓
Player shoots
↓
Balls move
↓
All balls stop
↓
Shot is evaluated
↓
Score is calculated
↓
Foul is checked
↓
Turn continues or switches
```

## UI

- [ ] Player 1 score
- [ ] Player 2 score
- [ ] Current player's turn
- [ ] Target ball indicator
- [ ] Shot power indicator
- [ ] Pause button
- [ ] Settings button

---

# Phase 4 — Snooker Rules Engine

Start with standard core rules.

## Basic Sequence

```text
Red
↓
Color
↓
Red
↓
Color
↓
...
Last Red
↓
Yellow
↓
Green
↓
Brown
↓
Blue
↓
Pink
↓
Black
↓
Frame Complete
```

## Core Rule Tracking

- [ ] Ball required for current shot
- [ ] First ball contacted
- [ ] Balls potted during shot
- [ ] Cue ball potted
- [ ] Score earned
- [ ] Foul value
- [ ] Whether player keeps turn
- [ ] Whether color must be respotted
- [ ] Whether frame is complete

## Basic Fouls

- [ ] Cue ball potted
- [ ] No ball contacted
- [ ] Wrong ball contacted first
- [ ] Wrong ball potted
- [ ] Incorrect target ball
- [ ] Invalid shot

## Color Respotting

Before all reds are gone:

- [ ] Respotted Yellow
- [ ] Respotted Green
- [ ] Respotted Brown
- [ ] Respotted Blue
- [ ] Respotted Pink
- [ ] Respotted Black

After all reds are gone:

Colors should be permanently removed in order.

---

# Phase 5 — Game Modes

## Classic Snooker

- [ ] 15 reds
- [ ] Standard frame rules

## Quick Snooker

Recommended for mobile.

Possible setup:

- [ ] 6 reds
- [ ] Same color sequence
- [ ] Shorter match duration

Quick Snooker should be available from the main menu.

---

# Phase 6 — Better Controls

Once the basic game works well:

## Aiming

- [ ] Drag-to-aim
- [ ] Fine aim adjustment
- [ ] Sensitivity setting
- [ ] Aiming line
- [ ] Optional predicted cue-ball path

## Power

- [ ] Power slider
- [ ] Drag-back cue mechanic
- [ ] Power percentage
- [ ] Power animation

## Spin — Later

Do not make spin mandatory for the first prototype.

Later add:

- [ ] Top spin
- [ ] Back spin
- [ ] Left spin
- [ ] Right spin

---

# Phase 7 — Main Menu

Build the menu only after gameplay works.

## Main Screen

```text
POCKET DUEL

SNOOKER

[ 2 PLAYERS ]
[ QUICK SNOOKER ]

[ SETTINGS ]
[ REMOVE ADS ]
```

Future games can later appear in the same hub.

---

# Phase 8 — Game Flow

## Before Match

- [ ] Select Classic or Quick
- [ ] Enter Player 1 name
- [ ] Enter Player 2 name
- [ ] Start match

## During Match

- [ ] Scoreboard
- [ ] Turn indicator
- [ ] Pause
- [ ] Resume
- [ ] Restart
- [ ] Quit

## Match Complete

```text
PLAYER 1 WINS

48 - 31

[ REMATCH ]
[ MAIN MENU ]
```

---

# Phase 9 — Audio and Polish

## Audio

- [ ] Cue strike sound
- [ ] Ball collision sound
- [ ] Cushion collision sound
- [ ] Pocket sound
- [ ] UI click sound
- [ ] Win sound

## Feedback

- [ ] Optional vibration
- [ ] Pot animation
- [ ] Score animation
- [ ] Foul notification
- [ ] Turn transition
- [ ] Winner animation

## Settings

- [ ] Sound On/Off
- [ ] Music On/Off
- [ ] Vibration On/Off
- [ ] Aim sensitivity
- [ ] Reset settings

---

# Phase 10 — Android Optimization

Test on real devices.

## Performance

- [ ] Stable frame rate
- [ ] No physics jitter
- [ ] Low battery impact
- [ ] Fast startup
- [ ] Low memory usage
- [ ] No input delay

## Screen Testing

Test on:

- [ ] 16:9 screens
- [ ] 18:9 screens
- [ ] 19.5:9 screens
- [ ] 20:9 screens
- [ ] Small Android phones
- [ ] Large Android phones
- [ ] Tablets

---

# Phase 11 — Advertising

Do not add ads until the game itself is enjoyable.

## Recommended Ad Strategy

### Never Show Ads During Gameplay

No ads while:

- Aiming
- Shooting
- Balls are moving
- Player is taking a turn
- Frame is active

## Interstitial Ads

Suggested starting rule:

```text
Match 1 → No ad
Match 2 → No ad
Match 3 → Possible ad
```

Then enforce a cooldown.

Recommended:

- Minimum 2–3 completed matches between interstitials
- Minimum 5–8 minutes between interstitials
- Only show on natural transitions

Good locations:

- After completed frame
- Before returning to main menu
- Occasionally before a rematch

Bad locations:

- After each shot
- After a foul
- During gameplay
- When changing aim
- When opening pause menu

---

# Phase 12 — Rewarded Ads

Rewarded ads should always be optional.

Possible future rewards:

- Temporary premium cue
- Temporary table design
- Cosmetic unlock
- Bonus customization

Never require rewarded ads to play standard snooker.

---

# Phase 13 — Remove Ads Purchase

Add a one-time purchase.

Recommended concept:

```text
REMOVE ADS
One-time purchase
```

Possible pricing:

- Around `$1.99 – $2.99`
- Use Google Play localized pricing

After purchase:

```text
Interstitial Ads → Disabled
Banner Ads       → Disabled
Rewarded Ads     → Optional
```

Do not make Remove Ads a subscription.

---

# Phase 14 — Privacy and Play Store Requirements

Before publishing:

- [ ] Privacy Policy
- [ ] Ad consent handling
- [ ] Google Play Data Safety form
- [ ] Content rating
- [ ] App icon
- [ ] Feature graphic
- [ ] Screenshots
- [ ] Store description
- [ ] Test release
- [ ] Internal testing
- [ ] Closed testing if required
- [ ] Production release

---

# Phase 15 — Release V1

## Minimum V1 Features

The initial public release should contain:

- [ ] Local 2-player snooker
- [ ] Classic Snooker
- [ ] Quick Snooker
- [ ] Full ball setup
- [ ] Core snooker rules
- [ ] Fouls
- [ ] Scoring
- [ ] Smooth physics
- [ ] Aim controls
- [ ] Power controls
- [ ] Sound
- [ ] Vibration
- [ ] Rematch
- [ ] Settings
- [ ] Minimal interstitial ads
- [ ] Remove Ads purchase

---

# Do Not Add to V1

Avoid scope creep.

Do not add yet:

- [ ] Online multiplayer
- [ ] Login/signup
- [ ] User accounts
- [ ] Server/backend
- [ ] AI opponent
- [ ] Leaderboards
- [ ] Social system
- [ ] Friends
- [ ] Chat
- [ ] Tournaments
- [ ] Cue marketplace
- [ ] Daily rewards
- [ ] Battle pass
- [ ] Complex achievements

---

# Post-Launch Roadmap

## Version 1.1

Focus on improvements based on player feedback.

Possible additions:

- Better aiming controls
- Better sound
- More table themes
- More cue designs
- Statistics
- Improved tutorials

## Version 1.2

Possible major addition:

- AI opponent
- Easy difficulty
- Medium difficulty
- Hard difficulty

## Version 1.3

Possible progression:

- Player statistics
- Win/loss history
- Achievements
- Unlockable cosmetics

## Version 2.0

Possible online features:

- Online 1v1 snooker
- Matchmaking
- Private room code
- Player profiles
- Leaderboards

A backend would likely be required at this stage.

---

# Future Multi-Game Expansion

Once Snooker is stable, Pocket Duel can become a collection of two-player games.

Possible future games:

1. Air Hockey
2. Pong
3. Tank Duel
4. Football
5. Basketball
6. Reaction Duel
7. Sumo Battle
8. Stickman Fight
9. Connect Four
10. Racing

Potential hub:

```text
POCKET DUEL

🎱 Snooker
🏓 Pong
⚽ Football
💣 Tanks
🏒 Air Hockey
⚔️ Stickman Duel
```

---

# Development Priority

Always follow this priority:

```text
Physics
↓
Controls
↓
Gameplay
↓
Rules
↓
Two-player experience
↓
UI
↓
Polish
↓
Performance
↓
Ads
↓
Purchases
↓
Release
```

The game should be fun **before monetization is added**.

---

# First Development Target

The immediate target is:

```text
Table
+
6 Pockets
+
1 White Ball
+
1 Red Ball
+
Cue
+
Aim
+
Power
+
Ball Collision
+
Cushion Collision
+
Pocket Detection
```

Once this prototype feels good, move to the full 22-ball setup.

---

# Definition of MVP Success

The MVP is successful when two people can:

1. Open the game.
2. Start a match immediately.
3. Aim naturally.
4. Control shot power.
5. Pot balls reliably.
6. Receive correct scores.
7. Alternate turns correctly.
8. Complete a frame.
9. Rematch without restarting the app.
10. Play without being interrupted by aggressive advertising.

The key principle throughout development:

> **Make the snooker feel good first. Everything else comes later.**
