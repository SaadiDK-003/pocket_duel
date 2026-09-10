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
const SINK_TIME: float = 0.30
var _sinking: bool = false
var _sink_t: float = 0.0
var _sink_offset: Vector2 = Vector2.ZERO   # Local vector toward the pocket centre.


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
func pot_into(pocket_pos: Vector2) -> void:
	is_potted = true
	velocity = Vector2.ZERO
	_sinking = true
	_sink_t = 0.0
	_sink_offset = pocket_pos - position
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
		# 1) Continue into the pocket smoothly — ease OUT (fast at capture, easing
		#    into the hole) so there's no stall between rolling and dropping.
		var mp := minf(t / 0.5, 1.0)
		var move := 1.0 - (1.0 - mp) * (1.0 - mp)
		var c := _sink_offset * move
		# 2) Fall into the hole: shrink faster as it drops (t^2).
		var s := maxf(1.0 - t * t, 0.02)
		# 3) Darken into the pocket's shadow, and only fade right at the end.
		var dark := t * 0.75
		var a := 1.0 if t < 0.82 else (1.0 - (t - 0.82) / 0.18)
		# Highlight dims as it turns away from the light while dropping.
		BallPainter.paint(self, c, radius * s, a, color.lerp(Color(0.02, 0.02, 0.02), dark), 1.0 - dark, style)
	else:
		BallPainter.paint(self, Vector2.ZERO, radius, 1.0, color, 1.0, style)
