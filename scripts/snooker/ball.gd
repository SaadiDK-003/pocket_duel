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
	_clear_spin()
	queue_redraw()


func is_moving() -> bool:
	return velocity.length() > 0.0


## Put a potted ball back on the table at pos, WITHOUT changing its home spot
## (starting_position), so a full reset still uses the true spot.
func respot_to(pos: Vector2) -> void:
	is_potted = false
	visible = true
	velocity = Vector2.ZERO
	_clear_spin()
	position = pos
	queue_redraw()


func _clear_spin() -> void:
	spin_follow = 0.0
	spin_side = 0.0
	spin_forward = Vector2.ZERO


func _draw() -> void:
	if is_potted:
		return
	# Contact shadow on the cloth (down-right of the ball).
	draw_circle(Vector2(radius * 0.18, radius * 0.28), radius * 1.02, Color(0, 0, 0, 0.28))
	# Shaded base (rim darker) then the lit face offset toward the light (top-left).
	draw_circle(Vector2.ZERO, radius, color.darkened(0.30))
	draw_circle(Vector2(-radius * 0.16, -radius * 0.16), radius * 0.82, color)
	# Highlight glow + tight specular dot.
	draw_circle(Vector2(-radius * 0.30, -radius * 0.30), radius * 0.34, color.lightened(0.35))
	draw_circle(Vector2(-radius * 0.34, -radius * 0.34), radius * 0.15, Color(1, 1, 1, 0.75))
	# Thin dark outline so balls read against the felt.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 1.5, true)
