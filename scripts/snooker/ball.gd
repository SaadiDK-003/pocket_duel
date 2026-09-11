class_name Ball
extends Node2D

## A single snooker ball.
##
## This is a pure data + drawing node. It holds physics STATE (position,
## velocity, radius) but does NOT resolve its own motion or collisions —
## the game manager's custom physics step owns all of that so the whole
## table can be simulated deterministically together.

enum BallType { CUE, RED, YELLOW, GREEN, BROWN, BLUE, PINK, BLACK }

# --- Physics state ---
var velocity: Vector2 = Vector2.ZERO
var radius: float = 18.0
var is_potted: bool = false

# --- Spin (cue ball) ---
var spin_follow: float = 0.0     # +1 top spin (follow), -1 back spin (draw).
var spin_side: float = 0.0       # -1..+1 side spin (english), affects cushions.
var spin_forward: Vector2 = Vector2.ZERO   # Shot direction, "forward" for follow.

# --- Snooker data (see roadmap "Ball Data") ---
var type: int = BallType.RED
var value: int = 1
var color: Color = Color(0.8, 0.08, 0.08)
var style: String = "classic"    # Ball-set finish (see BallPainter / Cosmetics).
var starting_position: Vector2 = Vector2.ZERO

# --- Pot animation (sink into the pocket) ---
const SINK_TIME: float = 0.34
var _sinking: bool = false
var _sink_t: float = 0.0
var _sink_target: Vector2 = Vector2.ZERO   # Local vector to the pocket centre.
var _sink_dir: Vector2 = Vector2.ZERO      # Ball's travel direction at capture.
var _sink_speed: float = 0.0               # Ball's speed at capture.


func setup(p_type: int, p_value: int, p_color: Color, p_pos: Vector2, p_radius: float) -> void:
	type = p_type
	value = p_value
	color = p_color
	radius = p_radius
	position = p_pos
	starting_position = p_pos
	is_potted = false
	visible = true
	velocity = Vector2.ZERO
	_end_sink()
	_clear_spin()
	queue_redraw()


func is_moving() -> bool:
	return velocity.length() > 0.0


## Pot the ball: remove it from play (is_potted) and play the sink animation.
## The drop keeps the ball's momentum and curves into the hole (no sideways yank).
func pot_into(pocket_pos: Vector2) -> void:
	is_potted = true
	_sink_target = pocket_pos - position
	_sink_speed = velocity.length()
	_sink_dir = velocity / _sink_speed if _sink_speed > 1.0 else _sink_target.normalized()
	velocity = Vector2.ZERO
	_sinking = true
	_sink_t = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _sinking:
		return
	_sink_t += delta / SINK_TIME
	if _sink_t >= 1.0:
		_end_sink()
		visible = false
	queue_redraw()


func _end_sink() -> void:
	_sinking = false
	_sink_t = 0.0
	set_process(false)


## Put a potted ball back on the table at pos, WITHOUT changing its home spot
## (starting_position), so a full reset still uses the true spot.
func respot_to(pos: Vector2) -> void:
	is_potted = false
	visible = true
	velocity = Vector2.ZERO
	_end_sink()
	_clear_spin()
	position = pos
	queue_redraw()


func _clear_spin() -> void:
	spin_follow = 0.0
	spin_side = 0.0
	spin_forward = Vector2.ZERO


func _draw() -> void:
	if is_potted and not _sinking:
		return
	if _sinking:
		var t := clampf(_sink_t, 0.0, 1.0)
		# 1) Path: a quadratic Bézier that leaves in the ball's TRAVEL direction and
		#    curves into the pocket, so momentum is preserved (no sideways snap).
		var dist := _sink_target.length()
		var ctrl_len := clampf(_sink_speed * SINK_TIME * 0.5, dist * 0.3, dist * 0.9)
		var p1 := _sink_dir * ctrl_len                       # control point offset
		var c := 2.0 * (1.0 - t) * t * p1 + t * t * _sink_target   # P0 = 0
		# 2) Roll to the hole first, THEN drop in: hold size until ~30%, then shrink.
		var sink := clampf((t - 0.30) / 0.70, 0.0, 1.0)
		var s := maxf(1.0 - sink * sink, 0.05)
		# 3) Darken into the pocket's shadow as it drops, fading right at the end.
		var dark := sink * 0.8
		var a := 1.0 if sink < 0.75 else (1.0 - (sink - 0.75) / 0.25)
		BallPainter.paint(self, c, radius * s, a, color.lerp(Color(0.02, 0.02, 0.02), dark), 1.0 - dark, style)
	else:
		BallPainter.paint(self, Vector2.ZERO, radius, 1.0, color, 1.0, style)
