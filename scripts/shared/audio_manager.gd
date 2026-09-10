extends Node

## Autoload singleton ("Audio"). Plays short sound effects through a small pool
## of players so overlapping sounds (a break scattering the pack) don't cut each
## other off. Respects the GameState sound setting. Missing files are ignored,
## so dropping in real recordings later is just a matter of matching filenames.

const SFX: Dictionary = {
	"ui_click": "res://assets/audio/ui_click.wav",
	"cue_strike": "res://assets/audio/cue_strike.mp3",   # real recording
	"ball_hit": "res://assets/audio/ball_hit.mp3",       # real recording
	"cushion": "res://assets/audio/cushion.mp3",         # real recording
	"break": "res://assets/audio/break_shot.mp3",        # real recording (opening break)
	"pocket": "res://assets/audio/pocket.mp3",       # real recording (ball drop)
	"win": "res://assets/audio/win.wav",
	"achieve": "res://assets/audio/achieve.wav",
}
const POOL_SIZE: int = 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	for key in SFX:
		if ResourceLoader.exists(SFX[key]):
			_streams[key] = load(SFX[key])
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(name: String, volume_db: float = 0.0, pitch_variation: float = 0.0) -> void:
	if not GameState.sound_enabled:
		return
	if not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()
