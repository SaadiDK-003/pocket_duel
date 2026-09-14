class_name PowerMeter
extends Control

## Vertical power meter (8-ball-pool style): a dark rounded capsule with a
## yellow→orange→red gradient that fills UP from the bottom. Drawn directly so
## the fill is clipped to the rounded shape (no square corners poking out).

const INSET: float = 5.0
var power: float = 0.0
var _grad: Gradient


func _ready() -> void:
	_grad = Gradient.new()
	_grad.set_offset(0, 0.0); _grad.set_color(0, Color(0.95, 0.20, 0.12))   # top = red
	_grad.set_offset(1, 1.0); _grad.set_color(1, Color(1.0, 0.85, 0.16))    # bottom = yellow
	_grad.add_point(0.5, Color(0.98, 0.55, 0.13))                           # orange


func set_value(p: float) -> void:
	power = clampf(p, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Dark capsule track.
	_capsule(Vector2.ZERO, size, Color(0.05, 0.06, 0.08, 0.90))

	# Gradient fill, clipped to the capsule, revealed from the bottom up.
	var iw := w - INSET * 2.0
	var ih := h - INSET * 2.0
	var frad := iw * 0.5
	var cx := w * 0.5
	var track_bottom := INSET + ih
	var fill_top := INSET + ih * (1.0 - power)
	var yy := int(ceil(fill_top))
	while yy <= int(track_bottom):
		var half := frad
		var db := track_bottom - float(yy)          # round the bottom cap
		if db < frad:
			half = sqrt(maxf(frad * frad - (frad - db) * (frad - db), 0.0))
		var dt := float(yy) - INSET                 # round the top cap when full
		if dt < frad:
			half = minf(half, sqrt(maxf(frad * frad - (frad - dt) * (frad - dt), 0.0)))
		var frac := (float(yy) - INSET) / ih
		draw_line(Vector2(cx - half, yy + 0.5), Vector2(cx + half, yy + 0.5), _grad.sample(clampf(frac, 0.0, 1.0)), 1.6)
		yy += 1

	# Thin light border.
	_capsule_outline(Vector2.ZERO, size, Color(1, 1, 1, 0.14))


func _capsule(pos: Vector2, sz: Vector2, col: Color) -> void:
	var rad := sz.x * 0.5
	draw_rect(Rect2(pos + Vector2(0, rad), Vector2(sz.x, sz.y - 2.0 * rad)), col)
	draw_circle(pos + Vector2(rad, rad), rad, col)
	draw_circle(pos + Vector2(rad, sz.y - rad), rad, col)


func _capsule_outline(pos: Vector2, sz: Vector2, col: Color) -> void:
	var rad := sz.x * 0.5
	draw_line(pos + Vector2(0, rad), pos + Vector2(0, sz.y - rad), col, 2.0)
	draw_line(pos + Vector2(sz.x, rad), pos + Vector2(sz.x, sz.y - rad), col, 2.0)
	draw_arc(pos + Vector2(rad, rad), rad, PI, TAU, 16, col, 2.0, true)
	draw_arc(pos + Vector2(rad, sz.y - rad), rad, 0.0, PI, 16, col, 2.0, true)
