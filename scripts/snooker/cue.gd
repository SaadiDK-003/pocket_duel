class_name Cue
extends Node2D

## Aiming + shooting input and its on-table visuals.
##
## Mechanic (slingshot / pull-back): press anywhere and drag AWAY from the
## direction you want to shoot, then release. The further you pull, the more
## power. This maps naturally to both mouse and touch.
##
## Aim assist (8-ball-pool style): a projected line is cast from the cue ball
## along the aim direction to the first ball or cushion it would meet — with a
## ghost cue-ball at the contact point and a predicted travel line for the ball
## that gets hit.
##
## Because "emulate_mouse_from_touch" is on in project.godot, handling mouse
## events alone also covers Android touch.

# Set by the game manager after creation.
var game: Node = null
var cue_ball: Ball = null

var _aiming: bool = false
var _placing: bool = false             # Dragging the cue ball within the D.
var _ready: bool = false               # Aim locked, awaiting the SHOOT tap.
var _shot_dir: Vector2 = Vector2.ZERO
var _shot_power: float = 0.0
var _drag_start: Vector2 = Vector2.ZERO   # Where the aim drag began.
var _pointer: Vector2 = Vector2.ZERO      # Current pointer position (world space).

# Opponent's live aim (LAN) — drawn on our screen while they line up.
var _remote_active: bool = false
var _remote_dir: Vector2 = Vector2.ZERO
var _remote_power: float = 0.0

const AIM_RANGE: float = 300.0       # Distance from the ball for 100% power.
const DEAD_ZONE: float = 14.0        # Below this the aim/shot is ignored.
const MAX_RAY: float = 4000.0        # Fallback aim-line length if nothing hit.
const GRAB_RADIUS: float = 48.0      # How close a press must be to grab the ball.
const ACCENT: Color = Color(0.98, 0.78, 0.28)


var _cursor: int = Input.CURSOR_ARROW


func _process(_delta: float) -> void:
	# Show a hand cursor when the cue ball can be grabbed (ball-in-hand + hover),
	# and a grab cursor while actually dragging it.
	var want := Input.CURSOR_ARROW
	if game != null and game.is_ball_in_hand():
		if _placing:
			want = Input.CURSOR_DRAG
		elif get_global_mouse_position().distance_to(cue_ball.position) <= GRAB_RADIUS:
			want = Input.CURSOR_POINTING_HAND
		queue_redraw()   # Animate the ball-in-hand pulse.
	if want != _cursor:
		_cursor = want
		Input.set_default_cursor_shape(want)


func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.can_shoot() or not game.is_human_turn():
		if _aiming or _placing or _ready:
			_cancel()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var m := get_global_mouse_position()
			# Ball-in-hand: grabbing the cue ball moves it; anything else aims.
			if game.is_ball_in_hand() and m.distance_to(cue_ball.position) <= GRAB_RADIUS:
				_placing = true
				game.place_cue_ball(m)
			else:
				_aiming = true
				_ready = false
				game.hud.set_shoot_visible(false)
				_drag_start = m
				_pointer = m
				_update_power()
		else:
			if _placing:
				_placing = false
			elif _aiming:
				_aiming = false
				var a: Dictionary = _aim()
				if a["dist"] < DEAD_ZONE:
					_cancel()          # Just a tap — nothing aimed.
				elif GameState.tap_to_shoot:
					_shot_dir = a["dir"]
					_shot_power = a["power"]
					_ready = true       # Lock the aim; wait for SHOOT.
					game.hud.set_power(_shot_power)
					game.hud.set_shoot_visible(true)
					game.hud.set_cancel_visible(true)
					game.net_send_aim(a["dir"], a["power"])   # opponent sees the locked aim
				else:
					game.hud.clear_power()   # Release-to-fire mode.
					game.net_send_aim_off()
					game.player_shoot(a["dir"], a["power"])
		queue_redraw()
	elif event is InputEventMouseMotion:
		if _placing:
			game.place_cue_ball(get_global_mouse_position())
		elif _aiming:
			_pointer = get_global_mouse_position()
			_update_power()
			var a: Dictionary = _aim()
			if a["dist"] >= DEAD_ZONE:
				game.net_send_aim(a["dir"], a["power"])   # stream live aim to opponent
			queue_redraw()


## Called when the SHOOT button is tapped (connected by the game manager).
func request_fire() -> void:
	if not _ready:
		return
	var d := _shot_dir
	var p := _shot_power
	_ready = false
	game.hud.set_shoot_visible(false)
	game.hud.set_cancel_visible(false)
	game.hud.clear_power()
	queue_redraw()
	game.net_send_aim_off()
	game.player_shoot(d, p)     # reads spin; routes to the host in a LAN match


func _cancel() -> void:
	_aiming = false
	_placing = false
	_ready = false
	if game != null:
		game.hud.clear_power()
		game.hud.set_shoot_visible(false)
		game.hud.set_cancel_visible(false)
		game.net_send_aim_off()
	queue_redraw()


func _update_power() -> void:
	var a: Dictionary = _aim()
	if a["dist"] < DEAD_ZONE:
		game.hud.clear_power()
	else:
		game.hud.set_power(a["power"])


func _aim() -> Dictionary:
	# Pull-back (8-ball-pool style): the shot fires OPPOSITE to your drag — pull
	# back to load power, release to fire forward. The aim is the drag VECTOR (not
	# the finger's position by the ball), so you can perform the pull-back anywhere
	# in the open table — it works even when the cue ball sits on a rail.
	var drag: Vector2 = _pointer - _drag_start
	var dist: float = drag.length()
	var power: float = clampf(dist / AIM_RANGE, 0.0, 1.0)
	var dir: Vector2 = (-drag).normalized() if dist > 0.0 else Vector2.ZERO
	return {"dir": dir, "power": power, "dist": dist}


# ------------------------------------------------------------------ Drawing
func set_remote_aim(dir: Vector2, power: float, active: bool) -> void:
	_remote_active = active
	_remote_dir = dir
	_remote_power = power
	queue_redraw()


func _draw() -> void:
	if cue_ball == null or cue_ball.is_potted or game == null:
		return
	# In a LAN match, on the opponent's turn draw THEIR live aim (streamed).
	if game._net and not game.is_human_turn():
		if _remote_active and game.can_shoot() and _remote_dir != Vector2.ZERO:
			_draw_prediction(cue_ball.position, _remote_dir)
			_draw_cue_stick(cue_ball.position, _remote_dir, _remote_power)
		return
	if not game.can_shoot() or not game.is_human_turn():
		return

	# Ball-in-hand affordance.
	if game.is_ball_in_hand() and not _aiming and not _ready:
		var c := cue_ball.position
		var r := cue_ball.radius
		if _placing:
			# "Held": a bright ring hugging the ball as it follows the finger.
			draw_arc(c, r + 4.0, 0.0, TAU, 36, Color(1, 1, 1, 0.95), 3.0)
			draw_arc(c, r + 4.0, 0.0, TAU, 36, ACCENT, 1.5)
			return
		# "Movable": a gently pulsing ring + four drag arrows.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 320.0)
		draw_arc(c, r + 8.0 + pulse * 4.0, 0.0, TAU, 36, Color(1, 1, 1, 0.30 + 0.35 * pulse), 2.0)
		_draw_move_arrows(c, r + 22.0)

	var dir: Vector2
	var power: float
	if _aiming:
		var a: Dictionary = _aim()
		if a["dist"] < DEAD_ZONE:
			return
		dir = a["dir"]
		power = a["power"]
	elif _ready:
		dir = _shot_dir
		power = _shot_power
	else:
		return

	var origin: Vector2 = cue_ball.position
	_draw_prediction(origin, dir)
	_draw_cue_stick(origin, dir, power)


func _draw_prediction(origin: Vector2, dir: Vector2) -> void:
	var hit: Dictionary = _cast(origin, dir, [cue_ball])
	var contact: Vector2 = hit["point"]
	var r: float = cue_ball.radius

	# Main aim line — solid white, to the first thing the cue ball meets.
	# antialiased so a near-horizontal thin line stays crisp (no stair-stepping).
	draw_line(origin, contact, Color(1, 1, 1, 0.8), 2.5, true)

	if hit["type"] == "ball":
		var target: Ball = hit["target"]
		draw_arc(contact, r, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 2.0, true)   # ghost cue ball
		# Object ball's direction (line of centres) — solid, constant colour.
		var n: Vector2 = (target.position - contact).normalized()
		draw_line(target.position, target.position + n * 100.0, Color(1.0, 0.82, 0.25, 0.9), 3.0, true)
		# Cue ball's deflection (tangent); tiny on a full-ball stun.
		var deflect: Vector2 = dir - dir.dot(n) * n
		if deflect.length() > 0.06:
			deflect = deflect.normalized()
			draw_line(contact, contact + deflect * 72.0, Color(0.45, 0.85, 1.0, 0.7), 2.5, true)
	elif hit["type"] == "cushion":
		var nrm: Vector2 = hit["normal"]
		var refl: Vector2 = dir - 2.0 * dir.dot(nrm) * nrm
		draw_line(contact, contact + refl * 120.0, Color(1, 1, 1, 0.4), 2.0, true)


## Manual dashed line (draw_dashed_line can intermittently drop the whole line).
func _dashed(from: Vector2, to: Vector2, col: Color, width: float, dash: float) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.5:
		return
	var dir := delta / length
	var step := dash * 2.0
	var t := 0.0
	while t < length:
		var seg_end := minf(t + dash, length)
		draw_line(from + dir * t, from + dir * seg_end, col, width)
		t += step


## Four small arrows pointing outward around the ball — a clear "drag me" hint.
func _draw_move_arrows(c: Vector2, dist: float) -> void:
	var col := Color(1, 1, 1, 0.8)
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for d in dirs:
		var tip := c + d * (dist + 8.0)
		var perp := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([
			tip, tip - d * 9.0 + perp * 6.0, tip - d * 9.0 - perp * 6.0,
		]), col)


## A realistic tapered snooker cue behind the ball, pulled back with power.
## Built from stacked tapered quads: leather tip, ferrule, wood shaft, a brass
## joint band, and a darker butt — plus a drop shadow and a top highlight. All
## dimensions scale with the ball so the cue stays in proportion on any screen.
func _draw_cue_stick(origin: Vector2, dir: Vector2, power: float) -> void:
	var r: float = cue_ball.radius
	var gap: float = r + 14.0 + power * 90.0
	var along: Vector2 = -dir                       # tip -> butt
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var total: float = clampf(r * 25.0, 400.0, 640.0)
	var tip_pt: Vector2 = origin - dir * gap        # striking end, near the ball
	var butt_pt: Vector2 = tip_pt + along * total

	var wood: Color = GameState.cue_color()
	var butt_col: Color = wood.darkened(0.40)
	var h_tip: float = maxf(r * 0.22, 3.2)          # half-width at the tip
	var h_butt: float = maxf(r * 0.50, 8.0)         # half-width at the butt

	# Stations along the length (fractions from the tip).
	var f_ferrule: float = 16.0 / total
	var f_shaft: float = 30.0 / total
	var f_joint: float = 0.52
	var h_at := func(f: float) -> float: return lerpf(h_tip, h_butt, f)

	var p := func(f: float) -> Vector2: return tip_pt + along * (total * f)

	# 1) Drop shadow beneath the cue.
	var sh := perp * (h_butt * 0.6) + along * 2.0
	draw_colored_polygon(_taper(tip_pt + sh, butt_pt + sh, h_tip, h_butt, perp), Color(0, 0, 0, 0.22))

	# 2) Darker butt (grip end) from the joint back.
	draw_colored_polygon(_taper(p.call(f_joint), butt_pt, h_at.call(f_joint), h_butt, perp), butt_col)
	# 3) Wood shaft from just past the ferrule to the joint.
	draw_colored_polygon(_taper(p.call(f_shaft), p.call(f_joint), h_at.call(f_shaft), h_at.call(f_joint), perp), wood)
	# 4) Cream ferrule.
	draw_colored_polygon(_taper(p.call(f_ferrule), p.call(f_shaft), h_at.call(f_ferrule), h_at.call(f_shaft), perp), Color(0.93, 0.92, 0.86))
	# 5) Blue leather tip, rounded at the striking end.
	draw_colored_polygon(_taper(tip_pt, p.call(f_ferrule), h_tip, h_at.call(f_ferrule), perp), Color(0.20, 0.34, 0.60))
	draw_circle(tip_pt, h_tip, Color(0.20, 0.34, 0.60))
	# 6) Brass joint band.
	draw_colored_polygon(_taper(p.call(f_joint - 0.02), p.call(f_joint + 0.01), h_at.call(f_joint - 0.02), h_at.call(f_joint + 0.01), perp), Color(0.82, 0.67, 0.33))

	# 7) Polish: a soft highlight down the top edge, a dark line down the bottom.
	draw_line(tip_pt + perp * (h_tip * 0.45), butt_pt + perp * (h_butt * 0.45), Color(1, 1, 1, 0.16), 2.0, true)
	draw_line(tip_pt - perp * h_tip, butt_pt - perp * h_butt, Color(0, 0, 0, 0.22), 1.5, true)


## A tapered quad from s (half-width hs) to e (half-width he) about `perp`.
func _taper(s: Vector2, e: Vector2, hs: float, he: float, perp: Vector2) -> PackedVector2Array:
	return PackedVector2Array([s + perp * hs, e + perp * he, e - perp * he, s - perp * hs])




# ------------------------------------------------------------------ Ray casting
## Cast a ray along `dir`; return the first ball, pocket, or cushion it meets.
## `ignore` lists balls to skip (e.g. the ball being cast from).
## Result: { "type": "ball"|"pocket"|"cushion"|"none", "point": Vector2,
##           "target": Ball|null, "normal": Vector2 }
func _cast(origin: Vector2, dir: Vector2, ignore: Array = []) -> Dictionary:
	var r: float = cue_ball.radius
	var best_t: float = MAX_RAY
	var res: Dictionary = {
		"type": "none", "point": origin + dir * MAX_RAY,
		"target": null, "normal": Vector2.ZERO,
	}

	# Balls.
	for b in game.balls:
		if b in ignore or b.is_potted:
			continue
		var t: float = _ray_circle(origin, dir, b.position, r + b.radius)
		if t > 0.0 and t < best_t:
			best_t = t
			res = {"type": "ball", "point": origin + dir * t, "target": b, "normal": Vector2.ZERO}

	# Cushions: ray exit through the ball-centre bounds (play rect inset by r).
	var rect: Rect2 = game.table.play_rect
	var left: float = rect.position.x + r
	var right: float = rect.end.x - r
	var top: float = rect.position.y + r
	var bottom: float = rect.end.y - r
	var wt: float = best_t
	var wn: Vector2 = Vector2.ZERO
	var t2: float = 0.0
	if dir.x > 0.0:
		t2 = (right - origin.x) / dir.x
		if t2 > 0.0 and t2 < wt:
			wt = t2; wn = Vector2(-1, 0)
	elif dir.x < 0.0:
		t2 = (left - origin.x) / dir.x
		if t2 > 0.0 and t2 < wt:
			wt = t2; wn = Vector2(1, 0)
	if dir.y > 0.0:
		t2 = (bottom - origin.y) / dir.y
		if t2 > 0.0 and t2 < wt:
			wt = t2; wn = Vector2(0, -1)
	elif dir.y < 0.0:
		t2 = (top - origin.y) / dir.y
		if t2 > 0.0 and t2 < wt:
			wt = t2; wn = Vector2(0, 1)
	if wn != Vector2.ZERO and wt < best_t:
		best_t = wt
		var cush_pt: Vector2 = origin + dir * wt
		# The cushion is broken at the pockets: if the ball reaches the rail inside
		# a pocket mouth, it drops instead of bouncing.
		var dropped := false
		for p in game.table.pockets:
			if cush_pt.distance_to(p["pos"]) <= p["radius"]:
				res = {"type": "pocket", "point": p["pos"], "target": null, "normal": Vector2.ZERO}
				dropped = true
				break
		if not dropped:
			res = {"type": "cushion", "point": cush_pt, "target": null, "normal": wn}

	return res


## Smallest positive ray parameter where the unit ray hits a circle, else -1.
func _ray_circle(o: Vector2, d: Vector2, c: Vector2, radius: float) -> float:
	var oc: Vector2 = o - c
	var b: float = oc.dot(d)
	var cc: float = oc.dot(oc) - radius * radius
	var disc: float = b * b - cc
	if disc < 0.0:
		return -1.0
	var sq: float = sqrt(disc)
	var t1: float = -b - sq
	if t1 > 0.0:
		return t1
	var t2: float = -b + sq
	if t2 > 0.0:
		return t2
	return -1.0
