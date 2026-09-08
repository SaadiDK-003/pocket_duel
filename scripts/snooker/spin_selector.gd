class_name SpinSelector
extends Control

## A small cue-ball widget: drag the marker to choose where the tip strikes the
## ball. Up = top spin (follow), down = back spin (draw), left/right = side.
## Exposes the chosen spin as a Vector2(side, follow), each in -1..1.

const R: float = 40.0                 # Ball radius in the widget.
const PAD: float = 10.0

var _offset: Vector2 = Vector2.ZERO   # Marker offset from centre, length <= 1.


func _ready() -> void:
	custom_minimum_size = Vector2((R + PAD) * 2.0, (R + PAD) * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP   # Swallow drags so aiming ignores them.


func get_spin() -> Vector2:
	# Screen Y is down, so up (negative y) means top spin (positive follow).
	return Vector2(_offset.x, -_offset.y)


func reset() -> void:
	_offset = Vector2.ZERO
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var active := false
	var local := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		active = true
		local = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		active = true
		local = event.position
	if not active:
		return
	var centre := size * 0.5
	_offset = (local - centre) / R
	if _offset.length() > 1.0:
		_offset = _offset.normalized()
	queue_redraw()
	accept_event()


func _draw() -> void:
	var c := size * 0.5
	# Dark rounded backing so it reads as a control, not a stray ball on the felt.
	draw_circle(c, R + PAD - 2.0, Color(0, 0, 0, 0.45))
	# Ball.
	draw_circle(c, R, Color(0.95, 0.95, 0.88))
	draw_arc(c, R, 0.0, TAU, 40, Color(0, 0, 0, 0.4), 2.0)
	# Cross-hairs.
	draw_line(c - Vector2(R, 0), c + Vector2(R, 0), Color(0, 0, 0, 0.12), 1.0)
	draw_line(c - Vector2(0, R), c + Vector2(0, R), Color(0, 0, 0, 0.12), 1.0)
	# Chosen contact point.
	var marker := c + _offset * R
	draw_circle(marker, 8.0, Color(0.85, 0.15, 0.15))
	draw_arc(marker, 8.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)
