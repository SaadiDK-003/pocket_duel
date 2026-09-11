class_name BallPreview
extends Control

## Draws a single ball (via BallPainter) so the shop can preview a ball set's
## finish. Set `base` and `style`, then it paints itself centred.

var base: Color = Color(0.80, 0.09, 0.09)
var style: String = "classic"
var multi: bool = false                 # true = draw an "any colour" ball

# The six snooker colours, for the multi ("any colour") ball.
const MULTI_COLORS: Array[Color] = [
	Color(0.96, 0.82, 0.14), Color(0.16, 0.62, 0.24), Color(0.52, 0.32, 0.14),
	Color(0.20, 0.45, 0.90), Color(0.96, 0.52, 0.68), Color(0.12, 0.12, 0.14),
]


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.30
	var c := size * 0.5 + Vector2(0, -r * 0.14)
	if multi:
		_paint_multi(c, r)
	else:
		BallPainter.paint(self, c, r, 1.0, base, 1.0, style)


## A ball split into the six colours — clearly reads as "pot any colour".
func _paint_multi(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(r * 0.18, r * 0.28), r * 1.02, Color(0, 0, 0, 0.28))   # contact shadow
	var n := MULTI_COLORS.size()
	for i in n:
		var a0 := -PI * 0.5 + float(i) / n * TAU
		var a1 := -PI * 0.5 + float(i + 1) / n * TAU
		var pts := PackedVector2Array([c])
		for k in range(9):
			var a := lerpf(a0, a1, k / 8.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, MULTI_COLORS[i])
	# Highlight + specular + outline for a glossy finish.
	draw_circle(c + Vector2(-r * 0.30, -r * 0.30), r * 0.30, Color(1, 1, 1, 0.28))
	draw_circle(c + Vector2(-r * 0.34, -r * 0.34), r * 0.13, Color(1, 1, 1, 0.7))
	draw_arc(c, r, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 1.5, true)
