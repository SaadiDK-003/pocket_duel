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

# --- Progression (persisted) ---
var coins: int = 0
var owned: Array = ["green", "classic"]   # Unlocked cosmetic ids (defaults free).
var selected_cloth: String = "green"
var selected_cue: String = "classic"


func _ready() -> void:
	load_settings()


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "sound", sound_enabled)
	c.set_value("audio", "music", music_enabled)
	c.set_value("haptics", "vibration", vibration_enabled)
	c.set_value("gameplay", "tap_to_shoot", tap_to_shoot)
	c.set_value("gameplay", "shot_timer", shot_timer)
	c.set_value("profile", "coins", coins)
	c.set_value("profile", "owned", owned)
	c.set_value("profile", "selected_cloth", selected_cloth)
	c.set_value("profile", "selected_cue", selected_cue)
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
	coins = c.get_value("profile", "coins", 0)
	owned = c.get_value("profile", "owned", ["green", "classic"])
	selected_cloth = c.get_value("profile", "selected_cloth", "green")
	selected_cue = c.get_value("profile", "selected_cue", "classic")


## --- Progression helpers ---
func cloth_color() -> Color:
	return Cosmetics.CLOTHS.get(selected_cloth, Cosmetics.CLOTHS["green"])["color"]


func cue_color() -> Color:
	return Cosmetics.CUES.get(selected_cue, Cosmetics.CUES["classic"])["color"]


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


func reset_settings() -> void:
	sound_enabled = true
	music_enabled = true
	vibration_enabled = true
	tap_to_shoot = true
	shot_timer = 0
	save_settings()
