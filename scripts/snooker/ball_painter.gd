class_name BallPainter
extends RefCounted

## Shared ball rendering so the table balls and the shop preview look identical.
## `paint()` draws onto any CanvasItem (a Ball or a preview Control), honouring
## the selected ball-set finish `style`.

## Draw a ball centred at `c`, radius `r`, opacity `a`, base colour `base`,
## highlight strength `hl` (dimmed while a ball sinks), in the given `style`.
static func paint(ci: CanvasItem, c: Vector2, r: float, a: float, base: Color, hl: float, style: String) -> void:
	# Contact shadow on the cloth (down-right of the ball).
	ci.draw_circle(c + Vector2(r * 0.18, r * 0.28), r * 1.02, Color(0, 0, 0, 0.28 * a))

	match style:
		"matte":
			# Even, soft finish: low rim contrast, broad diffuse light, no specular.
			ci.draw_circle(c, r, _fade(base.darkened(0.20), a))
			ci.draw_circle(c + Vector2(-r * 0.10, -r * 0.10), r * 0.86, _fade(base, a))
			ci.draw_circle(c + Vector2(-r * 0.26, -r * 0.26), r * 0.40, _fade(base.lightened(0.16), a * 0.5 * hl))
		"marble":
			# Classic body with a few lighter veins/blotches.
			ci.draw_circle(c, r, _fade(base.darkened(0.30), a))
			ci.draw_circle(c + Vector2(-r * 0.16, -r * 0.16), r * 0.82, _fade(base, a))
			ci.draw_circle(c + Vector2(r * 0.22, r * 0.10), r * 0.26, _fade(base.lightened(0.28), a * 0.7))
			ci.draw_circle(c + Vector2(-r * 0.10, r * 0.30), r * 0.18, _fade(base.lightened(0.22), a * 0.6))
			ci.draw_circle(c + Vector2(r * 0.05, -r * 0.28), r * 0.14, _fade(base.darkened(0.18), a * 0.6))
			ci.draw_circle(c + Vector2(-r * 0.30, -r * 0.30), r * 0.30, _fade(base.lightened(0.32), a * hl))
			ci.draw_circle(c + Vector2(-r * 0.34, -r * 0.34), r * 0.13, Color(1, 1, 1, 0.65 * a * hl))
		"neon":
			# Glowing coloured halo ring, punchy specular.
			var glow := base.lightened(0.55)
			ci.draw_arc(c, r * 1.14, 0.0, TAU, 40, Color(glow.r, glow.g, glow.b, 0.18 * a), 6.0, true)
			ci.draw_arc(c, r * 1.05, 0.0, TAU, 40, Color(glow.r, glow.g, glow.b, 0.45 * a), 3.0, true)
			ci.draw_circle(c, r, _fade(base.darkened(0.34), a))
			ci.draw_circle(c + Vector2(-r * 0.16, -r * 0.16), r * 0.80, _fade(base, a))
			ci.draw_circle(c + Vector2(-r * 0.30, -r * 0.30), r * 0.32, _fade(base.lightened(0.45), a * hl))
			ci.draw_circle(c + Vector2(-r * 0.34, -r * 0.34), r * 0.15, Color(1, 1, 1, 0.85 * a * hl))
		_:
			# "classic": standard glossy snooker ball.
			ci.draw_circle(c, r, _fade(base.darkened(0.30), a))
			ci.draw_circle(c + Vector2(-r * 0.16, -r * 0.16), r * 0.82, _fade(base, a))
			ci.draw_circle(c + Vector2(-r * 0.30, -r * 0.30), r * 0.34, _fade(base.lightened(0.35), a * hl))
			ci.draw_circle(c + Vector2(-r * 0.34, -r * 0.34), r * 0.15, Color(1, 1, 1, 0.75 * a * hl))

	# Thin dark outline so balls read against the felt.
	ci.draw_arc(c, r, 0.0, TAU, 32, Color(0, 0, 0, 0.35 * a), 1.5, true)


static func _fade(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * a)
