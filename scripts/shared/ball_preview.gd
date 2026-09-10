class_name BallPreview
extends Control

## Draws a single ball (via BallPainter) so the shop can preview a ball set's
## finish. Set `base` and `style`, then it paints itself centred.

var base: Color = Color(0.80, 0.09, 0.09)
var style: String = "classic"


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.30
	BallPainter.paint(self, size * 0.5 + Vector2(0, -r * 0.14), r, 1.0, base, 1.0, style)
