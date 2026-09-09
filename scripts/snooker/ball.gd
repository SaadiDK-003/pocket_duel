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
var starting_position: Vector2 = Vector2.ZERO

# --- Pot animation (sink into the pocket) ---
const SINK_TIME: float = 0.24
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
		# Slide toward the pocket (accelerating), shrink, and fade.
		_paint(_sink_offset * (t * t), radius * (1.0 - 0.82 * t), 1.0 - t)
	else:
		_paint(Vector2.ZERO, radius, 1.0)


## Paint the ball centred at `c`, radius `r`, with overall opacity `a`.
func _paint(c: Vector2, r: float, a: float) -> void:
	# Contact shadow on the cloth (down-right of the ball).
	draw_circle(c + Vector2(r * 0.18, r * 0.28), r * 1.02, Color(0, 0, 0, 0.28 * a))
	# Shaded base (rim darker) then the lit face offset toward the light (top-left).
	draw_circle(c, r, _fade(color.darkened(0.30), a))
	draw_circle(c + Vector2(-r * 0.16, -r * 0.16), r * 0.82, _fade(color, a))
	# Highlight glow + tight specular dot.
	draw_circle(c + Vector2(-r * 0.30, -r * 0.30), r * 0.34, _fade(color.lightened(0.35), a))
	draw_circle(c + Vector2(-r * 0.34, -r * 0.34), r * 0.15, Color(1, 1, 1, 0.75 * a))
	# Thin dark outline so balls read against the felt.
	draw_arc(c, r, 0.0, TAU, 32, Color(0, 0, 0, 0.35 * a), 1.5, true)


func _fade(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * a)
