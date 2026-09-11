class_name Table
extends Node2D

## The snooker table: the playable felt rectangle, the cushion boundary, the six
## pockets, and the standard markings (baulk line, "D", and the six colour
## spots). Geometry is computed once here and read by both the drawing code and
## the game manager's ball placement, so markings and balls always line up.
##
## The table is landscape: X is the long axis, the baulk end is on the LEFT.
## Spot fractions follow real snooker proportions of the playing area.

var play_rect: Rect2                       # Playable felt (ball CENTRES bounce
                                           # at these edges, offset by radius).
var pockets: Array[Dictionary] = []        # Each: { "pos": Vector2, "radius": float }

# Computed geometry (single source of truth).
var baulk_x: float = 0.0
var d_radius: float = 0.0
var spots: Dictionary = {}                 # colour name -> Vector2

# --- Physics --- (all scaled to the table in _compute_geometry)
var pocket_radius: float = 42.0            # Capture radius.

# --- Look & feel (scaled to the table) ---
const CUSHION_W: float = 30.0              # Cushion band thickness.
const RAIL_W: float = 46.0                 # Wooden frame beyond the cushions.
const JAW: float = 16.0                    # How far cushion noses angle into pockets.
var corner_open: float = 44.0              # Cushion pullback near corner pockets.
var mid_open: float = 36.0                 # Cushion pullback near middle pockets.
var corner_hole: float = 34.0
var mid_hole: float = 30.0

var felt_color: Color = Color(0.055, 0.42, 0.22)
var felt_light: Color = Color(0.10, 0.50, 0.27)
var felt_dark: Color = Color(0.035, 0.30, 0.16)
var cushion_color: Color = Color(0.05, 0.36, 0.19)
var cushion_top: Color = Color(0.13, 0.55, 0.30)
# Rich mahogany rail (independent of the cloth colour), like 8-ball-pool.
var wood_dark: Color = Color(0.20, 0.08, 0.06)
var wood_color: Color = Color(0.44, 0.16, 0.12)
var wood_light: Color = Color(0.62, 0.27, 0.20)
var line_color: Color = Color(0.9, 0.9, 0.85, 0.20)
var pocket_color: Color = Color(0.02, 0.02, 0.02)
var pocket_rim: Color = Color(0.11, 0.09, 0.07)
# Chrome pocket fittings + rail sight dots.
var chrome_base: Color = Color(0.60, 0.64, 0.70)
var chrome_hi: Color = Color(0.93, 0.96, 1.0)
var chrome_lo: Color = Color(0.26, 0.29, 0.36)
var sight_color: Color = Color(0.92, 0.90, 0.82)

var _felt_grad: GradientTexture2D            # Radial spotlight over the bed.


func setup(rect: Rect2) -> void:
	play_rect = rect
	# Apply the selected table cloth. Cushions are LIGHTER than the bed (8-ball
	# style); the bed gets a bright centre fading to dark edges.
	felt_color = GameState.cloth_color()
	felt_light = felt_color.lightened(0.30)
	felt_dark = felt_color.darkened(0.32)
	cushion_color = felt_color.lightened(0.08)
	cushion_top = felt_color.lightened(0.32)
	_build_felt_gradient()
	_compute_geometry()
	_build_pockets()
	queue_redraw()


## A radial gradient texture (bright centre -> dark rim) drawn over the bed for
## the soft "spotlight" look. Stretched to the table, so it reads as an ellipse.
func _build_felt_gradient() -> void:
	var g := Gradient.new()
	g.set_offset(0, 0.0);  g.set_color(0, felt_light)
	g.set_offset(1, 1.0);  g.set_color(1, felt_dark)
	g.add_point(0.55, felt_color)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 256
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	_felt_grad = gt


func _compute_geometry() -> void:
	var L := play_rect.size.x
	var w := play_rect.size.y
	var x0 := play_rect.position.x
	var cy := play_rect.get_center().y
	baulk_x = x0 + 0.20 * L                 # Baulk line: 1/5 up from baulk end.
	d_radius = 0.16 * w                     # "D" radius ~ 0.16 of table width.
	# Pockets and cushion openings scale with the table so they stay in
	# proportion (and match the scaled ball size) on every screen.
	pocket_radius = w * 0.055
	corner_hole = pocket_radius * 0.82
	mid_hole = pocket_radius * 0.72
	corner_open = pocket_radius * 1.05
	mid_open = pocket_radius * 0.86
	spots = {
		"green": Vector2(baulk_x, cy - d_radius),        # Left corner of the D.
		"brown": Vector2(baulk_x, cy),                   # Middle of the baulk line.
		"yellow": Vector2(baulk_x, cy + d_radius),       # Right corner of the D.
		"blue": Vector2(x0 + 0.50 * L, cy),              # Centre spot.
		"pink": Vector2(x0 + 0.75 * L, cy),              # Between centre and top.
		"black": Vector2(x0 + (10.0 / 11.0) * L, cy),    # 1/11 from the top cushion.
	}


func _build_pockets() -> void:
	var r := play_rect
	var mid_x := r.position.x + r.size.x * 0.5
	pockets = [
		{"pos": r.position, "radius": pocket_radius},                         # top-left
		{"pos": Vector2(mid_x, r.position.y), "radius": pocket_radius},        # top-middle
		{"pos": Vector2(r.end.x, r.position.y), "radius": pocket_radius},      # top-right
		{"pos": Vector2(r.position.x, r.end.y), "radius": pocket_radius},      # bottom-left
		{"pos": Vector2(mid_x, r.end.y), "radius": pocket_radius},             # bottom-middle
		{"pos": r.end, "radius": pocket_radius},                              # bottom-right
	]


func _draw() -> void:
	var felt_rect := play_rect.grow(CUSHION_W)          # Felt runs under cushions.
	var outer := felt_rect.grow(RAIL_W)                 # Outer edge of the wood.

	# Drop shadow beneath the table.
	_round_rect(Rect2(outer.position + Vector2(0, 10), outer.size), 40.0, Color(0, 0, 0, 0.30))

	# Wooden frame: dark base, main wood, light top bevel.
	_round_rect(outer, 40.0, wood_dark)
	_round_rect(outer.grow(-4.0), 36.0, wood_color)
	_round_rect(outer.grow(-4.0), 36.0, wood_light)     # bevel...
	_round_rect(outer.grow(-9.0), 31.0, wood_color)     # ...leaving a thin highlight.

	# Rail sight dots on the wood (between the cushions and the outer edge).
	_draw_sight_dots(felt_rect)

	# Felt bed: dark base, then the radial "spotlight" gradient over it.
	_round_rect(felt_rect, 14.0, felt_dark)
	if _felt_grad != null:
		draw_texture_rect(_felt_grad, felt_rect, false)
	_round_rect_outline(felt_rect, 14.0, felt_dark.darkened(0.2), 3.0)

	# Baulk line + "D".
	draw_line(Vector2(baulk_x, play_rect.position.y), Vector2(baulk_x, play_rect.end.y), line_color, 2.0)
	draw_arc(Vector2(baulk_x, play_rect.get_center().y), d_radius, PI * 0.5, PI * 1.5, 32, line_color, 2.0)
	for name in spots:
		draw_circle(spots[name], 3.0, line_color)

	# Cushions (with angled jaws) then the pockets on top.
	_draw_cushions()
	_draw_pockets()


func _draw_cushions() -> void:
	var l := play_rect.position.x
	var t := play_rect.position.y
	var r := play_rect.end.x
	var b := play_rect.end.y
	var mx := play_rect.get_center().x
	# Top / bottom rails are split by the middle pocket; sides are single.
	_cushion(Vector2(l + corner_open, t), Vector2(mx - mid_open, t), Vector2(0, -1))
	_cushion(Vector2(mx + mid_open, t), Vector2(r - corner_open, t), Vector2(0, -1))
	_cushion(Vector2(l + corner_open, b), Vector2(mx - mid_open, b), Vector2(0, 1))
	_cushion(Vector2(mx + mid_open, b), Vector2(r - corner_open, b), Vector2(0, 1))
	_cushion(Vector2(l, t + corner_open), Vector2(l, b - corner_open), Vector2(-1, 0))
	_cushion(Vector2(r, t + corner_open), Vector2(r, b - corner_open), Vector2(1, 0))


## One cushion segment: a from/to along the nose line, `out` points to the frame.
func _cushion(a: Vector2, b: Vector2, out: Vector2) -> void:
	var along := (b - a).normalized()
	var back := out * CUSHION_W
	var bevel := out * (CUSHION_W * 0.5)
	var nose_a := a + along * JAW
	var nose_b := b - along * JAW
	# Sloped face (nose -> mid) in the base colour...
	draw_colored_polygon(PackedVector2Array([a + bevel, b + bevel, nose_b, nose_a]), cushion_color.darkened(0.10))
	# ...and the flat top surface (mid -> back) in the lighter bevel colour.
	draw_colored_polygon(PackedVector2Array([a + back, b + back, b + bevel, a + bevel]), cushion_top)
	# Bright nose edge along the playing line, plus a soft shadow it casts on the bed.
	draw_line(nose_a, nose_b, cushion_top.lightened(0.12), 2.5, true)
	draw_line(nose_a - out * 3.0, nose_b - out * 3.0, Color(0, 0, 0, 0.14), 5.0)


func _draw_pockets() -> void:
	for p in pockets:
		var pos: Vector2 = p["pos"]
		var is_mid: bool = absf(pos.y - play_rect.position.y) > 1.0 and absf(pos.y - play_rect.end.y) > 1.0
		var hole: float = mid_hole if is_mid else corner_hole
		_chrome_pocket(pos, hole)


## A shiny chrome pocket fitting with the black hole in it (8-ball-pool style).
func _chrome_pocket(pos: Vector2, hole: float) -> void:
	var collar := hole * 1.40
	draw_circle(pos + Vector2(0, collar * 0.10), collar * 1.05, Color(0, 0, 0, 0.22))  # shadow on wood
	draw_circle(pos, collar, chrome_base)                                              # metal base
	draw_circle(pos - Vector2(collar * 0.30, collar * 0.30), collar * 0.82, chrome_hi) # top-left sheen
	draw_circle(pos + Vector2(collar * 0.30, collar * 0.30), collar * 0.80, chrome_lo) # bottom-right shade
	draw_arc(pos, collar, 0.0, TAU, 48, chrome_lo.darkened(0.1), 2.0, true)            # rim definition
	draw_circle(pos, hole, pocket_color)                                              # the hole
	draw_circle(pos - Vector2(hole * 0.22, hole * 0.22), hole * 0.55, Color(0.06, 0.06, 0.07))  # depth
	draw_arc(pos, hole, 0.0, TAU, 40, Color(0, 0, 0, 0.7), 2.0, true)                  # inner rim


## Sight dots (diamonds) evenly spaced along the wooden rails.
func _draw_sight_dots(felt_rect: Rect2) -> void:
	var half := RAIL_W * 0.5
	var top_y := felt_rect.position.y - half
	var bot_y := felt_rect.end.y + half
	var left_x := felt_rect.position.x - half
	var right_x := felt_rect.end.x + half
	var r := maxf(pocket_radius * 0.10, 3.0)
	var px := play_rect.position.x
	var py := play_rect.position.y
	var pw := play_rect.size.x
	var ph := play_rect.size.y
	for f in [0.125, 0.25, 0.375, 0.625, 0.75, 0.875]:      # long rails
		_dot(Vector2(px + f * pw, top_y), r)
		_dot(Vector2(px + f * pw, bot_y), r)
	for f in [0.25, 0.5, 0.75]:                             # short rails
		_dot(Vector2(left_x, py + f * ph), r)
		_dot(Vector2(right_x, py + f * ph), r)


func _dot(p: Vector2, r: float) -> void:
	draw_circle(p, r * 1.25, wood_dark)          # recessed shadow
	draw_circle(p, r, sight_color)
	draw_circle(p - Vector2(r * 0.3, r * 0.3), r * 0.4, sight_color.lightened(0.3))  # tiny sheen


# ------------------------------------------------------------------ Draw helpers
func _round_rect(rect: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position + Vector2(rad, 0), Vector2(rect.size.x - 2 * rad, rect.size.y)), col)
	draw_rect(Rect2(rect.position + Vector2(0, rad), Vector2(rect.size.x, rect.size.y - 2 * rad)), col)
	draw_circle(rect.position + Vector2(rad, rad), rad, col)
	draw_circle(rect.position + Vector2(rect.size.x - rad, rad), rad, col)
	draw_circle(rect.position + Vector2(rad, rect.size.y - rad), rad, col)
	draw_circle(rect.position + Vector2(rect.size.x - rad, rect.size.y - rad), rad, col)


func _round_rect_outline(rect: Rect2, rad: float, col: Color, width: float) -> void:
	rad = minf(rad, minf(rect.size.x, rect.size.y) * 0.5)
	draw_line(rect.position + Vector2(rad, 0), rect.position + Vector2(rect.size.x - rad, 0), col, width)
	draw_line(rect.position + Vector2(rad, rect.size.y), rect.position + Vector2(rect.size.x - rad, rect.size.y), col, width)
	draw_line(rect.position + Vector2(0, rad), rect.position + Vector2(0, rect.size.y - rad), col, width)
	draw_line(rect.position + Vector2(rect.size.x, rad), rect.position + Vector2(rect.size.x, rect.size.y - rad), col, width)
	draw_arc(rect.position + Vector2(rad, rad), rad, PI, PI * 1.5, 8, col, width)
	draw_arc(rect.position + Vector2(rect.size.x - rad, rad), rad, PI * 1.5, TAU, 8, col, width)
	draw_arc(rect.position + Vector2(rad, rect.size.y - rad), rad, PI * 0.5, PI, 8, col, width)
	draw_arc(rect.position + Vector2(rect.size.x - rad, rect.size.y - rad), rad, 0, PI * 0.5, 8, col, width)
