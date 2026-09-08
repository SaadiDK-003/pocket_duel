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


func _ready() -> void:
	load_settings()


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "sound", sound_enabled)
	c.set_value("audio", "music", music_enabled)
	c.set_value("haptics", "vibration", vibration_enabled)
	c.set_value("gameplay", "tap_to_shoot", tap_to_shoot)
	c.set_value("gameplay", "shot_timer", shot_timer)
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


func reset_settings() -> void:
	sound_enabled = true
	music_enabled = true
	vibration_enabled = true
	tap_to_shoot = true
	shot_timer = 0
	save_settings()
