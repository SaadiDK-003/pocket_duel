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

# --- Physics ---
var pocket_radius: float = 42.0            # Capture radius (unchanged; gameplay).

# --- Look & feel ---
const CUSHION_W: float = 30.0              # Cushion band thickness.
const RAIL_W: float = 46.0                 # Wooden frame beyond the cushions.
const JAW: float = 16.0                    # How far cushion noses angle into pockets.
const CORNER_OPEN: float = 44.0            # Cushion pullback near corner pockets.
const MID_OPEN: float = 36.0               # Cushion pullback near middle pockets.
const CORNER_HOLE: float = 34.0
const MID_HOLE: float = 30.0

var felt_color: Color = Color(0.055, 0.42, 0.22)
var felt_light: Color = Color(0.10, 0.50, 0.27)
var felt_dark: Color = Color(0.035, 0.30, 0.16)
var cushion_color: Color = Color(0.05, 0.36, 0.19)
var cushion_top: Color = Color(0.13, 0.55, 0.30)
var wood_dark: Color = Color(0.24, 0.14, 0.05)
var wood_color: Color = Color(0.40, 0.25, 0.11)
var wood_light: Color = Color(0.56, 0.38, 0.19)
var line_color: Color = Color(0.9, 0.9, 0.85, 0.20)
var pocket_color: Color = Color(0.02, 0.02, 0.02)
var pocket_rim: Color = Color(0.11, 0.09, 0.07)


func setup(rect: Rect2) -> void:
	play_rect = rect
	_compute_geometry()
	_build_pockets()
	queue_redraw()


func _compute_geometry() -> void:
	var L := play_rect.size.x
	var w := play_rect.size.y
	var x0 := play_rect.position.x
	var cy := play_rect.get_center().y
	baulk_x = x0 + 0.20 * L                 # Baulk line: 1/5 up from baulk end.
	d_radius = 0.16 * w                     # "D" radius ~ 0.16 of table width.
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

	# Felt bed with a soft central light pool for depth.
	_round_rect(felt_rect, 14.0, felt_color)
	draw_circle(play_rect.get_center(), minf(play_rect.size.x, play_rect.size.y) * 0.62, Color(felt_light.r, felt_light.g, felt_light.b, 0.10))
	_round_rect_outline(felt_rect, 14.0, felt_dark, 3.0)

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
	_cushion(Vector2(l + CORNER_OPEN, t), Vector2(mx - MID_OPEN, t), Vector2(0, -1))
	_cushion(Vector2(mx + MID_OPEN, t), Vector2(r - CORNER_OPEN, t), Vector2(0, -1))
	_cushion(Vector2(l + CORNER_OPEN, b), Vector2(mx - MID_OPEN, b), Vector2(0, 1))
	_cushion(Vector2(mx + MID_OPEN, b), Vector2(r - CORNER_OPEN, b), Vector2(0, 1))
	_cushion(Vector2(l, t + CORNER_OPEN), Vector2(l, b - CORNER_OPEN), Vector2(-1, 0))
	_cushion(Vector2(r, t + CORNER_OPEN), Vector2(r, b - CORNER_OPEN), Vector2(1, 0))


## One cushion segment: a from/to along the nose line, `out` points to the frame.
func _cushion(a: Vector2, b: Vector2, out: Vector2) -> void:
	var along := (b - a).normalized()
	var back := out * CUSHION_W
	var nose_a := a + along * JAW
	var nose_b := b - along * JAW
	# Body trapezoid: full-width at the back, pulled in at the nose (the jaws).
	draw_colored_polygon(PackedVector2Array([a + back, b + back, nose_b, nose_a]), cushion_color)
	# Bright nose highlight along the playing edge.
	draw_line(nose_a, nose_b, cushion_top, 3.0)


func _draw_pockets() -> void:
	for p in pockets:
		var pos: Vector2 = p["pos"]
		var is_mid: bool = absf(pos.y - play_rect.position.y) > 1.0 and absf(pos.y - play_rect.end.y) > 1.0
		var hole: float = MID_HOLE if is_mid else CORNER_HOLE
		draw_circle(pos, hole + 5.0, pocket_rim)          # leather rim
		draw_circle(pos, hole, pocket_color)              # hole
		draw_circle(pos - Vector2(hole * 0.28, hole * 0.28), hole * 0.5, Color(0.05, 0.05, 0.05))  # subtle depth


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
