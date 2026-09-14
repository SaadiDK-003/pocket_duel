extends Node

## Autoload singleton ("GameState") — state that must survive a scene change:
## the chosen mode, the player names, and the persisted settings.

const SETTINGS_PATH: String = "user://settings.cfg"

var mode: String = "Classic"     # "Classic" or "Quick".
var names: Array = ["Player 1", "Player 2"]   # Untyped so literal assignment is simple.
var best_of: int = 3             # Frames per match (first to best_of/2 + 1).
var vs_ai: bool = false          # Solo vs the bot (bot is player 2).
var ai_difficulty: int = 1       # 0 Easy, 1 Medium, 2 Hard.

# --- Settings (persisted) ---
var sound_enabled: bool = true
var music_enabled: bool = true
var vibration_enabled: bool = true
var tap_to_shoot: bool = true    # true = drag-aim then tap SHOOT; false = release to fire.
var shot_timer: int = 0          # Seconds per shot (0 = off).
var shake_enabled: bool = true   # Screen shake on break/hits/pots.
var sparkle_enabled: bool = true # Particle burst when a ball drops.

# --- Progression (persisted) ---
var coins: int = 0
var owned: Array = ["green", "classic", "set_classic"]   # Unlocked ids (defaults free).
var selected_cloth: String = "green"
var selected_cue: String = "classic"
var selected_ball_set: String = "set_classic"

# --- Lifetime stats (persisted) ---
var stat_played: int = 0         # Matches finished.
var stat_won: int = 0            # Matches won (by a human, not the bot).
var stat_pots: int = 0           # Total balls potted.
var stat_best_break: int = 0     # Highest break ever.
var stat_streak: int = 0         # Current human win streak.

# --- Achievements (persisted) ---
var achieved: Array = []         # Unlocked achievement ids.

# --- Daily reward (persisted) ---
var daily_last: String = ""      # Date (YYYY-MM-DD) the reward was last claimed.
var daily_streak: int = 0        # Consecutive days claimed.


func _ready() -> void:
	load_settings()


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "sound", sound_enabled)
	c.set_value("audio", "music", music_enabled)
	c.set_value("haptics", "vibration", vibration_enabled)
	c.set_value("gameplay", "tap_to_shoot", tap_to_shoot)
	c.set_value("gameplay", "shot_timer", shot_timer)
	c.set_value("gameplay", "shake", shake_enabled)
	c.set_value("gameplay", "sparkle", sparkle_enabled)
	c.set_value("profile", "coins", coins)
	c.set_value("profile", "owned", owned)
	c.set_value("profile", "selected_cloth", selected_cloth)
	c.set_value("profile", "selected_cue", selected_cue)
	c.set_value("profile", "selected_ball_set", selected_ball_set)
	c.set_value("stats", "played", stat_played)
	c.set_value("stats", "won", stat_won)
	c.set_value("stats", "pots", stat_pots)
	c.set_value("stats", "best_break", stat_best_break)
	c.set_value("stats", "streak", stat_streak)
	c.set_value("stats", "achieved", achieved)
	c.set_value("daily", "last", daily_last)
	c.set_value("daily", "streak", daily_streak)
	c.save(SETTINGS_PATH)


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) != OK:
		return
	sound_enabled = c.get_value("audio", "sound", true)
	music_enabled = c.get_value("audio", "music", true)
	vibration_enabled = c.get_value("haptics", "vibration", true)
	tap_to_shoot = c.get_value("gameplay", "tap_to_shoot", true)
	shot_timer = c.get_value("gameplay", "shot_timer", 0)
	shake_enabled = c.get_value("gameplay", "shake", true)
	sparkle_enabled = c.get_value("gameplay", "sparkle", true)
	coins = c.get_value("profile", "coins", 0)
	owned = c.get_value("profile", "owned", ["green", "classic", "set_classic"])
	selected_cloth = c.get_value("profile", "selected_cloth", "green")
	selected_cue = c.get_value("profile", "selected_cue", "classic")
	selected_ball_set = c.get_value("profile", "selected_ball_set", "set_classic")
	if "set_classic" not in owned:      # Ensure the free default is always owned.
		owned.append("set_classic")
	stat_played = c.get_value("stats", "played", 0)
	stat_won = c.get_value("stats", "won", 0)
	stat_pots = c.get_value("stats", "pots", 0)
	stat_best_break = c.get_value("stats", "best_break", 0)
	stat_streak = c.get_value("stats", "streak", 0)
	achieved = c.get_value("stats", "achieved", [])
	daily_last = c.get_value("daily", "last", "")
	daily_streak = c.get_value("daily", "streak", 0)


## --- Progression helpers ---
func cloth_color() -> Color:
	return Cosmetics.CLOTHS.get(selected_cloth, Cosmetics.CLOTHS["green"])["color"]


func cue_color() -> Color:
	return Cosmetics.CUES.get(selected_cue, Cosmetics.CUES["classic"])["color"]


func ball_style() -> String:
	return Cosmetics.BALL_SETS.get(selected_ball_set, Cosmetics.BALL_SETS["set_classic"])["style"]


func is_owned(id: String) -> bool:
	return id in owned


func add_coins(amount: int) -> void:
	coins += amount
	save_settings()


## Buy an item if affordable and not owned. Returns true on success.
func buy(id: String, price: int) -> bool:
	if is_owned(id) or coins < price:
		return false
	coins -= price
	owned.append(id)
	save_settings()
	return true


func select_cloth(id: String) -> void:
	selected_cloth = id
	save_settings()


func select_cue(id: String) -> void:
	selected_cue = id
	save_settings()


func select_ball_set(id: String) -> void:
	selected_ball_set = id
	save_settings()


## --- Stats & achievements ---
## Note the current running break mid-turn so a milestone break (30/50/100)
## unlocks the instant it's reached. Returns any newly unlocked ids.
func note_break(break_value: int) -> Array:
	if break_value <= stat_best_break:
		return []
	stat_best_break = break_value
	var unlocked := _check_achievements()
	if not unlocked.is_empty():
		save_settings()
	return unlocked


## Record a finished frame's figures (its top break and balls potted) so
## break/pot achievements unlock promptly, not only at match end. Returns the
## list of achievement ids newly unlocked (already rewarded with coins).
func record_frame(top_break: int, pots: int) -> Array:
	stat_pots += pots
	stat_best_break = maxi(stat_best_break, top_break)
	var unlocked := _check_achievements()
	save_settings()
	return unlocked


## Record a finished match. `human_won` is true only when a human player won
## (the bot winning does not count as a win or extend the streak). Returns any
## newly unlocked achievement ids. Frame figures are logged via record_frame.
func record_match(human_won: bool) -> Array:
	stat_played += 1
	if human_won:
		stat_won += 1
		stat_streak += 1
	else:
		stat_streak = 0
	var unlocked := _check_achievements()
	save_settings()
	return unlocked


## Evaluate every achievement against the current stats, unlocking and rewarding
## any newly met. Does not save (record_match / caller saves).
func _check_achievements() -> Array:
	var newly: Array = []
	for id in Achievements.ORDER:
		if id in achieved:
			continue
		if _achievement_met(id):
			achieved.append(id)
			coins += int(Achievements.LIST[id]["reward"])
			newly.append(id)
	return newly


func _achievement_met(id: String) -> bool:
	match id:
		"first_win": return stat_won >= 1
		"break30": return stat_best_break >= 30
		"fifty": return stat_best_break >= 50
		"century": return stat_best_break >= 100
		"pots100": return stat_pots >= 100
		"wins3": return stat_won >= 3
		"streak3": return stat_streak >= 3
		"play10": return stat_played >= 10
		"play20": return stat_played >= 20
	return false


## --- Daily reward ---
func daily_available() -> bool:
	return daily_last != _today()


## Claim today's reward. Returns the coins granted (0 if already claimed).
## The reward grows with the consecutive-day streak (capped), resetting if a
## day was missed.
func claim_daily() -> int:
	if not daily_available():
		return 0
	var yesterday := Time.get_date_string_from_unix_time(Time.get_unix_time_from_system() - 86400)
	daily_streak = daily_streak + 1 if daily_last == yesterday else 1
	daily_last = _today()
	var reward := 20 + mini(daily_streak - 1, 6) * 5   # 20,25,...,50 cap.
	coins += reward
	save_settings()
	return reward


func _today() -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()))


func reset_settings() -> void:
	sound_enabled = true
	music_enabled = true
	vibration_enabled = true
	tap_to_shoot = true
	shot_timer = 0
	shake_enabled = true
	sparkle_enabled = true
	save_settings()
