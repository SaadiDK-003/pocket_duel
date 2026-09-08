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
				else:
					game.hud.clear_power()   # Release-to-fire mode.
					game.shoot(a["dir"], a["power"])
		queue_redraw()
	elif event is InputEventMouseMotion:
		if _placing:
			game.place_cue_ball(get_global_mouse_position())
		elif _aiming:
			_pointer = get_global_mouse_position()
			_update_power()
			queue_redraw()


## Called when the SHOOT button is tapped (connected by the game manager).
func request_fire() -> void:
	if not _ready:
		return
	var d := _shot_dir
	var p := _shot_power
	_ready = false
	game.hud.set_shoot_visible(false)
	game.hud.clear_power()
	queue_redraw()
	game.shoot(d, p)     # reads spin from the widget


func _cancel() -> void:
	_aiming = false
	_placing = false
	_ready = false
	if game != null:
		game.hud.clear_power()
		game.hud.set_shoot_visible(false)
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
func _draw() -> void:
	if cue_ball == null or cue_ball.is_potted:
		return
	if game == null or not game.can_shoot() or not game.is_human_turn():
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
	var hit: Dictionary = _cast(origin, dir)
	var contact: Vector2 = hit["point"]
	var r: float = cue_ball.radius

	# Main aim line — dashed guide from the cue ball to the first contact.
	_dashed(origin, contact, Color(1, 1, 1, 0.7), 2.0, 13.0)

	if hit["type"] == "ball":
		var target: Ball = hit["target"]
		# Ghost cue-ball outline where the cue ball would make contact.
		draw_arc(contact, r, 0.0, TAU, 28, Color(1, 1, 1, 0.4), 1.5)
		# Yellow: the struck ball's travel direction (line of centres).
		var n: Vector2 = (target.position - contact).normalized()
		draw_line(target.position, target.position + n * 80.0, Color(1.0, 0.82, 0.25, 0.8), 2.0)
		# Cyan: where the CUE ball deflects (tangent line, perpendicular to n).
		# Near-zero on a full-ball hit (cue stuns) — only drawn when meaningful.
		var deflect: Vector2 = dir - dir.dot(n) * n
		if deflect.length() > 0.06:
			deflect = deflect.normalized()
			draw_line(contact, contact + deflect * 80.0, Color(0.45, 0.85, 1.0, 0.8), 2.0)
	elif hit["type"] == "cushion":
		# Short preview of one bounce off the rail.
		var nrm: Vector2 = hit["normal"]
		var refl: Vector2 = dir - 2.0 * dir.dot(nrm) * nrm
		_dashed(contact, contact + refl * 110.0, Color(1, 1, 1, 0.4), 2.0, 12.0)


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


func _draw_cue_stick(origin: Vector2, dir: Vector2, power: float) -> void:
	# Cue stick behind the ball, pulled back proportional to power.
	var pull_back: float = cue_ball.radius + 14.0 + power * 90.0
	var tip: Vector2 = origin - dir * pull_back
	var butt: Vector2 = tip - dir * 230.0
	draw_line(tip, butt, Color(0.86, 0.66, 0.36), 6.0)
	draw_line(tip, tip - dir * 26.0, Color(0.2, 0.5, 0.7), 6.0)  # blue ferrule




# ------------------------------------------------------------------ Ray casting
## Cast a ray from the cue ball along `dir`; return the first ball or cushion.
## Result: { "type": "ball"|"cushion"|"none", "point": Vector2,
##           "target": Ball|null, "normal": Vector2 }
func _cast(origin: Vector2, dir: Vector2) -> Dictionary:
	var r: float = cue_ball.radius
	var best_t: float = MAX_RAY
	var res: Dictionary = {
		"type": "none", "point": origin + dir * MAX_RAY,
		"target": null, "normal": Vector2.ZERO,
	}

	# Balls (skip the cue ball itself and potted balls).
	for b in game.balls:
		if b == cue_ball or b.is_potted:
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
		res = {"type": "cushion", "point": origin + dir * wt, "target": null, "normal": wn}

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
