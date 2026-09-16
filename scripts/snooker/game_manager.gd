extends Node2D

## Milestone 1 game manager — owns the table, the balls, the cue, and the
## custom physics step.
##
## Physics model (all hand-written, deterministic):
##   - Each substep: move balls by velocity, apply rolling friction, then
##     resolve pocket capture, ball-to-ball collisions, and cushion bounces.
##   - Several substeps per frame keep fast balls from tunnelling through
##     thin pockets or each other.
##
## Everything here is tunable from the constants block. The roadmap's
## priority is "make it feel good first", so expect to nudge these.

# ------------------------------------------------------------------ Tunables
# The simulation runs once per RENDERED frame (see _process) so motion is smooth
# at the display's native refresh (60/90/120 Hz), not a fixed 60. Substeps are
# sized to a fixed target length so collision fidelity stays constant whatever
# the frame rate; the delta is clamped so a frame hitch can't tunnel balls.
const SIM_SUB_DT: float = 1.0 / 480.0     # Target physics substep length (s).
const SIM_MAX_SUBSTEPS: int = 16
const SIM_MAX_DELTA: float = 1.0 / 30.0   # Cap the frame delta after a hitch.
# Exponential coast: fraction of speed KEPT per second. This gives the natural
# pool "glide" — fast at first, easing to a gentle stop — instead of the
# abrupt halt a constant deceleration produces. Lower = more friction.
const FRICTION_PER_SEC: float = 0.34
const STOP_SPEED: float = 10.0           # px/s — below this a ball is stopped (snappy turn ends).
const RESTITUTION_CUSHION: float = 0.78  # Energy kept on a cushion bounce.
const RESTITUTION_BALL: float = 0.94     # Energy kept on a ball-to-ball hit.
const MAX_SHOT_SPEED: float = 3400.0     # px/s at 100% power.
var ball_radius: float = 18.0            # Scaled to the table in _layout().

# --- Spin ---
const FOLLOW_FACTOR: float = 0.65        # Follow/draw kick as a fraction of impact speed.
const SIDE_FACTOR: float = 0.35          # Side-spin throw off a cushion.
const SPIN_DECAY: float = 0.45           # Spin kept per second while travelling.

# ------------------------------------------------------------------ Ball colours
const COLOR_CUE: Color = Color(0.97, 0.97, 0.90)
const COLOR_RED: Color = Color(0.80, 0.08, 0.08)
const COLOR_YELLOW: Color = Color(0.95, 0.82, 0.12)
const COLOR_GREEN: Color = Color(0.10, 0.50, 0.16)
const COLOR_BROWN: Color = Color(0.42, 0.26, 0.10)
const COLOR_BLUE: Color = Color(0.13, 0.35, 0.80)
const COLOR_PINK: Color = Color(0.95, 0.45, 0.62)
const COLOR_BLACK: Color = Color(0.08, 0.08, 0.08)

# ------------------------------------------------------------------ Game modes
# Mode name -> number of reds. The menu (Phase 7) will pick one; for now keys
# 1 / 2 switch. Both are perfect triangles (6 = 3 rows, 15 = 5 rows).
const MODES: Dictionary = {"Classic": 15, "Quick": 6}
const DEFAULT_MODE: String = "Classic"

# ------------------------------------------------------------------ State
var table: Table
var cue: Cue
var hud: Hud
var overlay: OverlayMenu
var settings_panel: SettingsPanel
var toast: AchievementToast
var turn := TurnManager.new()
var rules := RulesManager.new()
var ai := AIPlayer.new()
var _ai_seq: int = 0              # Cancels stale scheduled AI shots.
var balls: Array[Ball] = []
var cue_ball: Ball
var mode_name: String = DEFAULT_MODE
var reds_count: int = MODES[DEFAULT_MODE]
var _balls_moving: bool = false
var _frame_over: bool = false
var _match_over: bool = false
var _frame_pots: int = 0          # Object balls potted in the current frame.
var _break_shot: bool = false     # Next shot is the opening break (scatter sound).
var _frame_starter: int = 0       # Who breaks the current frame (alternates).
var _paused: bool = false
var _ball_in_hand: bool = false          # Cue ball can be placed within the D.
var _potted_this_shot: Array[Ball] = []
var _first_contact: Ball = null
var _undo_stack: Array = []       # Snapshots for undo (current frame only).
var _frame_ball_impact: float = 0.0      # Loudest ball-ball hit this frame.
var _frame_cushion_impact: float = 0.0   # Loudest cushion hit this frame.


const MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"


var _last_vp: Vector2 = Vector2.ZERO
var _confetti: CanvasLayer = null
var _shake_amt: float = 0.0          # Current screen-shake magnitude (px).
var _base_pos: Vector2 = Vector2.ZERO
# --- LAN networking ---
var _net: bool = false               # networked match?
var _net_host: bool = false          # this instance is the host (authority)?
var _my: int = 0                     # my player index (0 host, 1 guest)
var _net_push_t: float = 0.0
var _snap_buf: Array = []            # guest: buffered snapshots {t, pos} for interpolation
var _latest_t: int = 0               # guest: newest snapshot host-time
var _hello_sent: bool = false        # guest sent its name to the host?
var _last_turn: int = -1             # for the "your turn" cue
var _aim_send_t: int = 0             # throttle for live aim streaming
var _place_send_t: int = 0           # throttle for ball-in-hand placement
var _last_hud_sig: String = ""       # guest: only refresh the HUD when it changes
var _ping_ms: int = 0                # measured round-trip time (LAN)
var _ping_send_t: float = 0.0
var _fps_t: float = 0.0
var _fps_shown: bool = false
const NET_HZ: float = 35.0           # state broadcasts per second while moving
const NET_SNAP: float = 220.0        # jump farther than this -> snap (re-rack/respot)
const NET_DELAY_MS: float = 90.0     # guest renders this far in the past (jitter buffer)
var _timer_active: bool = false
var _shot_time_left: float = 0.0
var _last_tick_sec: int = -1


func _process(delta: float) -> void:
	_simulate(delta)
	_update_shake(delta)
	if _net and _net_host:
		_net_push_t -= delta
		if _net_push_t <= 0.0:
			# Stream fast while balls move (interpolation smooths it); idle is slow.
			_net_push_t = (1.0 / NET_HZ) if _balls_moving else (1.0 / 8.0)
			_net_broadcast_state()
	elif _net and _snap_buf.size() > 0:
		_net_interp_buffer()        # guest: interpolate between buffered snapshots
	if _net:
		_check_turn_cue()
		_ping_send_t -= delta
		if _ping_send_t <= 0.0:
			_ping_send_t = 1.0
			_net_ping.rpc(Time.get_ticks_msec())
	if GameState.show_fps:
		_fps_shown = true
		_fps_t -= delta
		if _fps_t <= 0.0:
			_fps_t = 0.25
			hud.set_debug(Engine.get_frames_per_second(), _ping_ms if _net else -1)
	elif _fps_shown:
		_fps_shown = false
		hud.set_debug(-1, -1)
	if _timer_active and not _paused:
		_shot_time_left -= delta
		if _shot_time_left <= 0.0:
			_on_shot_timeout()
		else:
			var secs := int(ceil(_shot_time_left))
			hud.set_timer(secs)
			if secs != _last_tick_sec and secs <= 5:   # Tick the last 5 seconds.
				_last_tick_sec = secs
				Audio.play("ui_click", -10.0, 0.0)
				_vibrate(15)


## Start the per-shot countdown for a human turn (no-op if disabled or bot turn).
func _start_shot_timer() -> void:
	if _net:
		return                       # shot timer is disabled in LAN matches
	if GameState.shot_timer > 0 and is_human_turn() and not _frame_over and not _match_over:
		_shot_time_left = float(GameState.shot_timer)
		_last_tick_sec = -1
		_timer_active = true
		hud.set_timer(GameState.shot_timer)
	else:
		_stop_shot_timer()


func _stop_shot_timer() -> void:
	_timer_active = false
	hud.hide_timer()


func _on_shot_timeout() -> void:
	_stop_shot_timer()
	cue._cancel()                 # Drop any locked aim.
	turn.switch_turn()
	hud.refresh(turn, rules.on_ball_text())
	hud.spin.visible = is_human_turn()
	hud.flash("TIME UP  —  %s's Turn" % str(turn.names[turn.current]), Color(1.0, 0.5, 0.4))
	_vibrate(60)
	if _is_ai_turn():
		_schedule_ai()
	else:
		_start_shot_timer()


func _ready() -> void:
	_net = Net.is_networked
	_net_host = Net.is_host
	_my = Net.my_index
	if _net:
		GameState.vs_ai = false
		Net.link_lost.connect(_on_net_link_lost)
	_build_background()
	table = Table.new()
	add_child(table)
	_build_cue()
	_build_hud()
	overlay = OverlayMenu.new()
	add_child(overlay)
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	toast = AchievementToast.new()
	add_child(toast)
	hud.pause_requested.connect(_toggle_pause)
	hud.shoot_pressed.connect(cue.request_fire)
	hud.cancel_pressed.connect(cue._cancel)
	hud.emoji_selected.connect(_on_emoji_selected)
	hud.enable_emojis(_net)
	get_viewport().size_changed.connect(_on_resize)
	_base_pos = position
	_layout()
	_start_mode(GameState.mode)


## Full-screen dark background so wide phones show no letterbox bars — the table
## is centred on it and UI sits in the side gutters.
func _build_background() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -100
	add_child(cl)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(bg)


## Recompute the table rectangle and HUD placement from the actual viewport size.
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_last_vp = vp
	table.setup(_compute_play_rect(vp))
	# Balls scale with the table so they're a consistent, readable size on any
	# screen (bigger than the old fixed 18px on wide phones). Bounded by table
	# WIDTH too, so the 15-red triangle always fits between the pink and black.
	ball_radius = clampf(minf(table.play_rect.size.y * 0.030, table.play_rect.size.x * 0.0138), 15.0, 26.0)
	# Pass the table's outer wood edges so side HUD widgets stay in the gutters.
	var margin := Table.CUSHION_W + Table.RAIL_W
	hud.layout(vp, table.play_rect.position.x - margin, table.play_rect.end.x + margin)


func _compute_play_rect(vp: Vector2) -> Rect2:
	var top := 210.0        # Clear the top score cards, pill, timer & pause.
	var bottom := 120.0     # Clear the bottom mode/hint text.
	var side := 96.0
	var avail_w := vp.x - side * 2.0
	var avail_h := vp.y - top - bottom
	var aspect := 1.95      # Snooker playfield ~ 2:1.
	var pw := avail_w
	var ph := pw / aspect
	if ph > avail_h:
		ph = avail_h
		pw = ph * aspect
	var px := (vp.x - pw) * 0.5
	var py := top + (avail_h - ph) * 0.5
	return Rect2(px, py, pw, ph)


func _on_resize() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == _last_vp:
		return
	_layout()
	_start_mode(mode_name)   # Rebuild the rack for the new geometry.


## Start (or restart) a frame in the given mode. Also serves as rematch.
func _start_mode(name: String) -> void:
	mode_name = name
	reds_count = MODES.get(name, MODES[DEFAULT_MODE])
	_clear_balls()
	_build_balls()
	cue.cue_ball = cue_ball
	turn.reset()                    # Full match reset (frames won -> 0).
	if GameState.names.size() >= 2:
		turn.names = [GameState.names[0], GameState.names[1]]
	_frame_starter = 0
	_match_over = false
	_begin_frame()


## Rack a fresh frame, keeping the match score. Alternates the breaker.
func _next_frame() -> void:
	_frame_starter = 1 - _frame_starter
	_clear_balls()
	_build_balls()
	cue.cue_ball = cue_ball
	turn.reset_frame(_frame_starter)
	_begin_frame()


## Shared per-frame setup used by both a new match and the next frame.
func _begin_frame() -> void:
	_cancel_ai()
	_stop_celebrate()
	ai.difficulty = GameState.ai_difficulty
	rules.reset(reds_count)
	_balls_moving = false
	_frame_over = false
	_paused = false
	_ball_in_hand = true            # Frame starts with the cue ball in hand.
	_frame_pots = 0
	_break_shot = true              # The first shot of the frame scatters the pack.
	_potted_this_shot.clear()
	_first_contact = null
	_undo_stack.clear()             # Undo is scoped to the current frame.
	overlay.hide_menu()
	hud.set_mode(mode_name)
	hud.refresh(turn, rules.on_ball_text())
	hud.spin.visible = is_human_turn()
	cue.queue_redraw()
	if is_human_turn():
		hud.flash("BALL IN HAND  —  DRAG THE CUE BALL", Color(0.6, 0.85, 1.0))
	if _is_ai_turn():
		_schedule_ai()
	else:
		_start_shot_timer()
	if _net_host:
		_net_begin.rpc()


func _cancel_ai() -> void:
	_ai_seq += 1                    # Invalidate any pending scheduled shot.


func _clear_balls() -> void:
	for b in balls:
		b.queue_free()
	balls.clear()
	cue_ball = null


func _unhandled_input(event: InputEvent) -> void:
	# Esc toggles the pause menu at any time.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		return
	if _paused or _frame_over or _balls_moving:
		return
	# Quick keyboard dev controls (the pause menu covers these on-screen).
	# Note: no mouse-button shortcuts — right-click must never reset a live frame.
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_start_mode(mode_name)
			KEY_1:
				_start_mode("Classic")
			KEY_2:
				_start_mode("Quick")


# ------------------------------------------------------------------ Flow / menus
func _toggle_pause() -> void:
	if _frame_over:
		return                      # The match-complete menu is already showing.
	if _paused:
		_resume()
	else:
		_pause()


func _pause() -> void:
	_paused = true
	_cancel_ai()
	overlay.show_menu("PAUSED", [
		{"text": "Resume", "callable": _resume},
		{"text": "Settings", "callable": func(): settings_panel.open()},
		{"text": "Undo Shot", "callable": _undo},
		{"text": "Concede Frame", "callable": _concede},
		{"text": "Restart", "callable": _restart_frame},
		{"text": "Main Menu", "callable": _quit_to_menu},
	])


func _resume() -> void:
	_paused = false
	overlay.hide_menu()
	cue.queue_redraw()
	if _is_ai_turn():
		_schedule_ai()
	elif not _balls_moving:
		_start_shot_timer()   # Fresh shot clock after resuming.


func _restart_frame() -> void:
	_start_mode(mode_name)


func _quit_to_menu() -> void:
	_cancel_ai()
	_stop_celebrate()
	if _net:
		Net.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


## The current player concedes: the opponent takes the frame.
func _concede() -> void:
	_paused = false
	_cancel_ai()
	overlay.hide_menu()
	_balls_moving = false
	_frame_over = true
	_end_frame(1 - turn.current)


# ------------------------------------------------------------------ Undo
func _push_undo() -> void:
	var snap := {
		"balls": [],
		"scores": turn.scores.duplicate(),
		"current": turn.current,
		"break": turn.break_score,
		"frames": turn.frames_won.duplicate(),
		"reds": rules.reds_remaining,
		"on_red": rules.on_red,
		"phase": rules.phase,
		"next_colour": rules.next_colour,
		"starter": _frame_starter,
	}
	for b in balls:
		snap["balls"].append({"pos": b.position, "potted": b.is_potted})
	_undo_stack.push_back(snap)
	if _undo_stack.size() > 20:
		_undo_stack.pop_front()


func _undo() -> void:
	if _undo_stack.is_empty():
		_resume()
		return
	var snap: Dictionary = _undo_stack.pop_back()
	# In solo, step back past the bot's shots so control returns to the human.
	while GameState.vs_ai and int(snap["current"]) == 1 and not _undo_stack.is_empty():
		snap = _undo_stack.pop_back()
	_apply_snapshot(snap)


func _apply_snapshot(snap: Dictionary) -> void:
	_cancel_ai()
	var arr: Array = snap["balls"]
	for i in range(mini(arr.size(), balls.size())):
		var b := balls[i]
		var data: Dictionary = arr[i]
		b.is_potted = data["potted"]
		b.visible = not b.is_potted
		b.velocity = Vector2.ZERO
		b.position = data["pos"]
		b._clear_spin()
		b.queue_redraw()
	turn.scores[0] = snap["scores"][0]
	turn.scores[1] = snap["scores"][1]
	turn.current = snap["current"]
	turn.break_score = snap["break"]
	turn.frames_won[0] = snap["frames"][0]
	turn.frames_won[1] = snap["frames"][1]
	rules.reds_remaining = snap["reds"]
	rules.on_red = snap["on_red"]
	rules.phase = snap["phase"]
	rules.next_colour = snap["next_colour"]
	rules.frame_complete = false
	_frame_starter = snap["starter"]
	_balls_moving = false
	_frame_over = false
	_paused = false
	_ball_in_hand = false
	_first_contact = null
	_potted_this_shot.clear()
	overlay.hide_menu()
	hud.refresh(turn, rules.on_ball_text())
	hud.spin.visible = is_human_turn()
	cue.queue_redraw()
	if _is_ai_turn():
		_schedule_ai()
	else:
		_start_shot_timer()


# ------------------------------------------------------------------ Build
func _build_balls() -> void:
	# Full snooker rack (Phase 2): cue ball in the D, six colours on their spots,
	# and 15 reds packed in a triangle behind the pink.
	balls.clear()

	# Cue ball: placed inside the D, near the brown spot.
	var cue_pos := Vector2(table.baulk_x - table.d_radius * 0.45, table.play_rect.get_center().y)
	cue_ball = _spawn(Ball.BallType.CUE, 0, COLOR_CUE, cue_pos)

	# Six colours on their spots.
	_spawn(Ball.BallType.YELLOW, 2, COLOR_YELLOW, table.spots["yellow"])
	_spawn(Ball.BallType.GREEN, 3, COLOR_GREEN, table.spots["green"])
	_spawn(Ball.BallType.BROWN, 4, COLOR_BROWN, table.spots["brown"])
	_spawn(Ball.BallType.BLUE, 5, COLOR_BLUE, table.spots["blue"])
	_spawn(Ball.BallType.PINK, 6, COLOR_PINK, table.spots["pink"])
	_spawn(Ball.BallType.BLACK, 7, COLOR_BLACK, table.spots["black"])

	# Reds: triangle apex just behind the pink, widening toward the black.
	_build_reds(table.spots["pink"], reds_count)


func _build_reds(pink: Vector2, count: int) -> void:
	var spacing := ball_radius * 2.0 + 1.0          # Touching, with a hair of gap.
	var row_dx := spacing * cos(deg_to_rad(30.0))   # Row-to-row spacing (~0.866).
	var apex_x := pink.x + spacing                  # Apex just behind the pink.
	var placed := 0
	var row := 0
	while placed < count:
		var in_row := mini(row + 1, count - placed)
		var x := apex_x + float(row) * row_dx
		var y0 := pink.y - float(row) * spacing * 0.5
		for i in range(in_row):
			_spawn(Ball.BallType.RED, 1, COLOR_RED, Vector2(x, y0 + float(i) * spacing))
			placed += 1
		row += 1


func _spawn(type: int, value: int, color: Color, pos: Vector2) -> Ball:
	var b := Ball.new()
	add_child(b)
	b.style = GameState.ball_style()
	b.setup(type, value, color, pos, ball_radius)
	b.sunk.connect(_on_ball_sunk)
	balls.append(b)
	return b


func _build_cue() -> void:
	cue = Cue.new()
	add_child(cue)                 # Added last -> draws on top of table/balls.
	cue.game = self
	cue.cue_ball = cue_ball


func _build_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.setup()
	hud.refresh(turn, rules.on_ball_text())


# ------------------------------------------------------------------ Shooting API
func can_shoot() -> bool:
	return not _balls_moving and not _frame_over and not _paused and cue_ball != null and not cue_ball.is_potted


func _is_ai_turn() -> bool:
	if _net:
		return false
	return GameState.vs_ai and turn.current == 1 and not _frame_over


## The human controls the cue only on their own turn (blocks aiming for the bot
## and, in a LAN match, for the opponent).
func is_human_turn() -> bool:
	if _net:
		return turn.current == _my
	return not _is_ai_turn()


## Schedule the bot's shot after a short "thinking" pause, guarding against
## state changes (pause, rematch, frame end) via a sequence token.
func _schedule_ai() -> void:
	if not (_is_ai_turn() and can_shoot()):
		return
	_ai_seq += 1
	var token := _ai_seq
	await get_tree().create_timer(0.8).timeout
	if token != _ai_seq or not (_is_ai_turn() and can_shoot()):
		return
	# The bot always plays it out — no auto-concede (it was abrupt/confusing).
	var shot: Dictionary = ai.choose_shot(self)
	shoot(shot["dir"], shot["power"], shot.get("side", 0.0), shot.get("follow", 0.0), false)


func shoot(dir: Vector2, power: float, spin_side: float = 0.0, spin_follow: float = 0.0, from_widget: bool = true) -> void:
	if not can_shoot():
		return
	_push_undo()
	_potted_this_shot.clear()
	_ball_in_hand = false           # Taking the shot ends placement.
	if from_widget:
		var s := hud.spin.get_spin()   # (side, follow) each -1..1
		spin_side = s.x
		spin_follow = s.y
		hud.spin.reset()
	cue_ball.spin_side = spin_side
	cue_ball.spin_follow = spin_follow
	cue_ball.spin_forward = dir
	cue_ball.velocity = dir * (power * MAX_SHOT_SPEED)
	_balls_moving = true
	_stop_shot_timer()
	Audio.play("cue_strike", -6.0 + 6.0 * power)


# ------------------------------------------------------------------ Ball-in-hand
func is_ball_in_hand() -> bool:
	return _ball_in_hand and can_shoot() and is_human_turn()


## Clamp a point to the legal "D" area (baulk side of the baulk line, inside the
## semicircle), keeping the whole ball on the table.
func clamp_to_d(pos: Vector2) -> Vector2:
	var c := Vector2(table.baulk_x, table.play_rect.get_center().y)
	var r := table.d_radius - ball_radius
	var off := pos - c
	if off.x > 0.0:
		off.x = 0.0                 # Only the baulk side of the line.
	if off.length() > r:
		off = off.normalized() * r
	return c + off


func place_cue_ball(pos: Vector2) -> void:
	if not is_ball_in_hand():
		return
	var p := clamp_to_d(pos)
	cue_ball.position = p
	cue_ball.queue_redraw()
	cue.queue_redraw()
	if _net and not _net_host:
		var now := Time.get_ticks_msec()
		if now - _place_send_t >= 40:   # throttle ~25Hz (unreliable)
			_place_send_t = now
			_net_place.rpc_id(1, p)     # tell the host where I placed it


# ------------------------------------------------------------------ LAN networking
## The cue calls this to take a shot. Host shoots locally; guest sends it to the
## host, which is the authority for the simulation.
func player_shoot(dir: Vector2, power: float) -> void:
	if not can_shoot() or not is_human_turn():
		return
	var s := hud.spin.get_spin()
	hud.spin.reset()
	if _net and not _net_host:
		_net_shoot.rpc_id(1, dir, power, s.x, s.y)
	else:
		shoot(dir, power, s.x, s.y, false)


## Host -> guest: full table + game state, ~30x/sec.
func _net_broadcast_state() -> void:
	var pos := PackedVector2Array()
	var pot := PackedByteArray()
	for b in balls:
		pos.append(b.position)
		pot.append(1 if b.is_potted else 0)
	_net_state.rpc({
		"t": Time.get_ticks_msec(),
		"pos": pos, "pot": pot,
		"cur": turn.current, "sc": [turn.scores[0], turn.scores[1]],
		"fr": [turn.frames_won[0], turn.frames_won[1]], "brk": turn.break_score,
		"on": rules.on_ball_text(), "bih": _ball_in_hand, "mov": _balls_moving,
		"nm": [str(turn.names[0]), str(turn.names[1])],
	})


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(p: Dictionary) -> void:
	if _net_host:
		return
	var pos = p["pos"]
	var pot = p["pot"]
	# Buffer this snapshot (by host time) for delayed interpolation.
	_latest_t = int(p.get("t", _latest_t + 16))
	_snap_buf.append({"t": _latest_t, "pos": pos})
	while _snap_buf.size() > 20:
		_snap_buf.pop_front()
	# Potted / visibility apply from the newest snapshot immediately.
	for i in range(mini(balls.size(), pot.size())):
		var b := balls[i]
		b.is_potted = pot[i] == 1
		b.visible = not b.is_potted
		if b.is_potted:
			b.position = pos[i]
		b.queue_redraw()
	turn.current = int(p["cur"])
	turn.scores[0] = int(p["sc"][0]); turn.scores[1] = int(p["sc"][1])
	turn.frames_won[0] = int(p["fr"][0]); turn.frames_won[1] = int(p["fr"][1])
	turn.break_score = int(p["brk"])
	turn.names = [str(p["nm"][0]), str(p["nm"][1])]
	_balls_moving = bool(p["mov"])
	_ball_in_hand = bool(p["bih"])
	# Only rebuild the HUD when something actually changed (not every packet).
	var sig := "%d|%d|%d|%d|%d|%d|%s|%s|%s" % [turn.current, turn.scores[0], turn.scores[1], turn.frames_won[0], turn.frames_won[1], turn.break_score, str(p["on"]), str(turn.names[0]), str(turn.names[1])]
	if sig != _last_hud_sig:
		_last_hud_sig = sig
		hud.refresh(turn, str(p["on"]))
	hud.spin.visible = is_human_turn() and not _balls_moving
	cue.queue_redraw()
	if not _hello_sent:                 # tell the host my name (host is ready now)
		_hello_sent = true
		_net_hello.rpc_id(1, Net.my_name)


## Guest: render ~NET_DELAY_MS in the past, interpolating between the two buffered
## snapshots that bracket that time. Absorbs network jitter -> smooth motion.
func _net_interp_buffer() -> void:
	var render_t := float(_latest_t) - NET_DELAY_MS
	var a: Dictionary = _snap_buf[0]
	var b: Dictionary = _snap_buf[_snap_buf.size() - 1]
	for s in _snap_buf:
		if float(s["t"]) <= render_t:
			a = s
		if float(s["t"]) >= render_t:
			b = s
			break
	var apos = a["pos"]
	var bpos = b["pos"]
	var denom := float(b["t"]) - float(a["t"])
	var f := 0.0 if denom <= 0.0 else clampf((render_t - float(a["t"])) / denom, 0.0, 1.0)
	var n := mini(balls.size(), mini(apos.size(), bpos.size()))
	for i in range(n):
		var ball := balls[i]
		if ball.is_potted:
			continue
		var pa: Vector2 = apos[i]
		var pb: Vector2 = bpos[i]
		if pa.distance_to(pb) > NET_SNAP:
			ball.position = pb          # teleport (re-rack/respot) — don't slide
		else:
			ball.position = pa.lerp(pb, f)
		ball.queue_redraw()


@rpc("any_peer", "call_remote", "reliable")
func _net_shoot(dir: Vector2, power: float, side: float, follow: float) -> void:
	if not _net_host or turn.current != 1 or not can_shoot():
		return
	shoot(dir, power, side, follow, false)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_place(pos: Vector2) -> void:
	if not _net_host or turn.current != 1 or not _ball_in_hand:
		return
	cue_ball.position = clamp_to_d(pos)


## Host -> guest: the frame/match result overlay.
@rpc("authority", "call_remote", "reliable")
func _net_result(title: String, subtitle: String, is_match: bool) -> void:
	if _net_host:
		return
	var buttons: Array = []
	if is_match:
		buttons = [{"text": "New Match", "callable": _net_ask_restart}, {"text": "Main Menu", "callable": _quit_to_menu}]
	else:
		buttons = [{"text": "Next Frame", "callable": _net_ask_next}, {"text": "Main Menu", "callable": _quit_to_menu}]
	overlay.show_menu(title, buttons, subtitle)


func _net_ask_next() -> void:
	_net_next.rpc_id(1)


func _net_ask_restart() -> void:
	_net_restart.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _net_next() -> void:
	if _net_host:
		_next_frame()


@rpc("any_peer", "call_remote", "reliable")
func _net_restart() -> void:
	if _net_host:
		_restart_frame()


## Host -> guest: a new frame started; drop the overlay (state sync fills the rest).
@rpc("authority", "call_remote", "reliable")
func _net_begin() -> void:
	if not _net_host:
		overlay.hide_menu()


func _on_net_link_lost() -> void:
	Net.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


## Guest -> host: my player name.
@rpc("any_peer", "call_remote", "reliable")
func _net_hello(name: String) -> void:
	if _net_host:
		turn.names[1] = name if name.strip_edges() != "" else "Guest"


## Flash "YOUR TURN" / "OPPONENT'S TURN" with a cue when the turn flips.
func _check_turn_cue() -> void:
	if _frame_over or _match_over or _balls_moving:
		return
	if turn.current == _last_turn:
		return
	_last_turn = turn.current
	if turn.current == _my:
		hud.flash("YOUR TURN", Color(0.4, 0.9, 0.5))
		Audio.play("ui_click", 2.0)
	else:
		hud.flash("%s's turn…" % str(turn.names[turn.current]), Color(0.7, 0.85, 1.0))


# --- Live opponent aim ---
func net_send_aim(dir: Vector2, power: float) -> void:
	if not _net:
		return
	var now := Time.get_ticks_msec()
	if now - _aim_send_t < 40:       # ~25 Hz
		return
	_aim_send_t = now
	_net_aim.rpc(dir, power, true)


func net_send_aim_off() -> void:
	if _net:
		_net_aim.rpc(Vector2.ZERO, 0.0, false)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_aim(dir: Vector2, power: float, active: bool) -> void:
	cue.set_remote_aim(dir, power, active)


# --- Emojis / reactions ---
func _on_emoji_selected(idx: int) -> void:
	hud.show_emoji(idx, _my)
	if _net:
		_net_emoji.rpc(idx, _my)


@rpc("any_peer", "call_remote", "reliable")
func _net_emoji(idx: int, sender: int) -> void:
	hud.show_emoji(idx, sender)


# --- Ping (round-trip time) ---
@rpc("any_peer", "call_remote", "unreliable")
func _net_ping(t: int) -> void:
	_net_pong.rpc_id(multiplayer.get_remote_sender_id(), t)


@rpc("any_peer", "call_remote", "unreliable")
func _net_pong(t: int) -> void:
	_ping_ms = Time.get_ticks_msec() - t


# ------------------------------------------------------------------ Simulation
## Advance the table once per rendered frame so motion tracks the display's
## refresh rate. Framerate-independent: the integrator is dt-based and the
## substep count adapts to keep each substep near SIM_SUB_DT.
func _simulate(delta: float) -> void:
	if _net and not _net_host:
		return                       # the guest renders host state; it never simulates
	if _paused or not _balls_moving:
		return

	var d := minf(delta, SIM_MAX_DELTA)   # Clamp so a hitch can't tunnel balls.
	var steps := clampi(int(ceil(d / SIM_SUB_DT)), 1, SIM_MAX_SUBSTEPS)
	var sub := d / float(steps)
	_frame_ball_impact = 0.0
	_frame_cushion_impact = 0.0
	for _i in steps:
		_step(sub)
	_play_impact_sounds()

	# Redraw moved balls and re-check whether anything is still rolling.
	var any_moving := false
	for b in balls:
		if b.is_potted:
			continue
		b.queue_redraw()
		if b.velocity.length() > 0.0:
			any_moving = true

	if not any_moving:
		_balls_moving = false
		_shake_amt = 0.0            # never leave the table offset when control returns
		position = _base_pos
		_evaluate_shot()
		# In-off: bring the cue ball back into the D, in hand.
		if cue_ball.is_potted:
			cue_ball.setup(cue_ball.type, cue_ball.value, cue_ball.color,
				cue_ball.starting_position, cue_ball.radius)
			_ball_in_hand = true
		if _frame_over:
			_end_frame()
		else:
			hud.refresh(turn, rules.on_ball_text())
			hud.spin.visible = is_human_turn()
			if _ball_in_hand and is_human_turn():
				hud.flash("BALL IN HAND  —  DRAG THE CUE BALL", Color(0.6, 0.85, 1.0))
			if _is_ai_turn():
				_schedule_ai()
			else:
				_start_shot_timer()
		cue.queue_redraw()   # Re-show the aim guide now that control returns.


## Play at most one ball-hit and one cushion sound per frame, scaled by how hard
## the loudest such collision was — so a break sounds busy without machine-gunning.
func _play_impact_sounds() -> void:
	if _frame_ball_impact > 60.0:
		if _break_shot:
			# First real contact with the pack: play the scatter, once.
			_break_shot = false
			Audio.play("break", -2.0)
			_add_shake(6.5)
			_vibrate(55)
		else:
			Audio.play("ball_hit", _impact_db(_frame_ball_impact), 0.12)
			_add_shake(clampf(_frame_ball_impact / 320.0, 0.0, 3.5))   # harder hit, bigger shake
	if _frame_cushion_impact > 80.0:
		Audio.play("cushion", _impact_db(_frame_cushion_impact), 0.10)


func _impact_db(impact: float) -> float:
	return lerpf(-22.0, 0.0, clampf(impact / 1600.0, 0.0, 1.0))


func _vibrate(ms: int) -> void:
	if GameState.vibration_enabled:
		Input.vibrate_handheld(ms)   # No-op on desktop.


## Feed the finished shot to the rules engine and apply the outcome.
func _evaluate_shot() -> void:
	var cue_potted := cue_ball in _potted_this_shot
	var potted_non_cue: Array = []
	for b in _potted_this_shot:
		if b != cue_ball:
			potted_non_cue.append(b)

	var res: Dictionary = rules.evaluate(_first_contact, potted_non_cue, cue_potted)
	_frame_pots += potted_non_cue.size()

	if res["foul"]:
		turn.add_score_to(turn.other(), res["foul_value"])
		turn.switch_turn()
		hud.flash("FOUL  +%d" % res["foul_value"], Color(1.0, 0.5, 0.4))
		_vibrate(60)
	else:
		if res["score"] > 0:
			var before_break := turn.break_score
			turn.add_score(res["score"])
			hud.flash("+%d" % res["score"], Color(1.0, 0.9, 0.4))
			# Milestone breaks unlock the instant they're reached.
			for id in GameState.note_break(turn.break_score):
				toast.show_id(id)
			# Big-break flourish when the break crosses 50 / 100 this shot.
			for m in [100, 50]:
				if before_break < m and turn.break_score >= m:
					_break_flourish(m)
					break
		if not res["keep_turn"]:
			turn.switch_turn()
			if res["score"] == 0:      # Clean miss/safety — announce the turn.
				hud.flash("%s's Turn" % str(turn.names[turn.current]), Color(0.7, 0.85, 1.0))

	# Put any respotted colours back on the table (on the next free spot).
	for b in res["respot"]:
		_respot_colour(b)

	if res["frame_complete"]:
		# Re-spotted black: if the final black leaves the scores level, snooker
		# respots the black and plays on instead of ending in a tie.
		if turn.scores[0] == turn.scores[1]:
			rules.frame_complete = false
			rules.next_colour = 7
			_respot_value(7)
			hud.flash("RE-SPOTTED BLACK")
		else:
			_frame_over = true

	_potted_this_shot.clear()
	_first_contact = null


# ------------------------------------------------------------------ Respotting
const VALUE_SPOT: Dictionary = {
	2: "yellow", 3: "green", 4: "brown", 5: "blue", 6: "pink", 7: "black",
}


func _respot_colour(b: Ball) -> void:
	b.respot_to(_free_spot_for(b))


## Official-ish placement: the ball's own spot; else the highest free colour
## spot; else the nearest free point up/down the centre line from its own spot.
func _free_spot_for(b: Ball) -> Vector2:
	var own: Vector2 = table.spots[VALUE_SPOT[b.value]]
	if _spot_free(own, b):
		return own
	for v in [7, 6, 5, 4, 3, 2]:
		var s: Vector2 = table.spots[VALUE_SPOT[v]]
		if _spot_free(s, b):
			return s
	var step := ball_radius * 2.0
	for i in range(1, 40):
		var up := own + Vector2(step * i, 0.0)
		if table.play_rect.has_point(up) and _spot_free(up, b):
			return up
		var down := own - Vector2(step * i, 0.0)
		if table.play_rect.has_point(down) and _spot_free(down, b):
			return down
	return own


func _spot_free(pos: Vector2, exclude: Ball) -> bool:
	for o in balls:
		if o == exclude or o.is_potted:
			continue
		if o.position.distance_to(pos) < ball_radius * 2.0 - 0.5:
			return false
	return true


func _respot_value(v: int) -> void:
	for b in balls:
		if b.value == v and b.type != Ball.BallType.CUE:
			_respot_colour(b)
			return


## A frame just concluded: award it, then show either the next-frame screen or,
## if the match is decided, the match-complete screen.
func _end_frame(forced_winner: int = -1) -> void:
	_stop_shot_timer()
	var winner := forced_winner
	if winner < 0:
		winner = 0 if turn.scores[0] > turn.scores[1] else 1
	turn.frames_won[winner] += 1
	Audio.play("win")
	hud.refresh(turn, "")

	var top_break := maxi(turn.highest_break[0], turn.highest_break[1])
	var needed := GameState.best_of / 2 + 1
	# Log the frame's figures first so break/pot achievements can unlock now.
	var unlocked: Array = GameState.record_frame(top_break, _frame_pots)
	if turn.frames_won[winner] >= needed:
		_match_over = true
		var reward := 50 + top_break        # Coins for winning the match.
		GameState.add_coins(reward)
		# Record the match (played/won/streak) & collect any further unlocks.
		# A human wins unless the bot (player 2 in vs-AI) took it.
		var human_won := not (GameState.vs_ai and winner == 1)
		for id in GameState.record_match(human_won):
			if id not in unlocked:
				unlocked.append(id)
		_celebrate()
		var subtitle := "%d – %d frames   ·   Top break %d   ·   +%d coins" % [
			turn.frames_won[winner], turn.frames_won[1 - winner], top_break, reward]
		if not unlocked.is_empty():
			var names: Array = []
			for id in unlocked:
				names.append(str(Achievements.LIST[id]["name"]))
			subtitle += "\n🏅 Unlocked: %s" % ", ".join(names)
		overlay.show_menu(
			"🏆  %s WINS!" % turn.names[winner],
			[
				{"text": "New Match", "callable": _restart_frame},
				{"text": "Main Menu", "callable": _quit_to_menu},
			],
			subtitle)
		if _net_host:
			_net_result.rpc("🏆  %s WINS!" % turn.names[winner], subtitle, true)
	else:
		GameState.add_coins(10)             # Coins for winning a frame.
		var vp := get_viewport().get_visible_rect().size
		_confetti_burst(Vector2(vp.x * 0.5, vp.y * 0.62), 110)   # frame-win pop
		var subtitle := "%d – %d   ·   match %d–%d   ·   +10 coins" % [
			turn.scores[winner], turn.scores[1 - winner],
			turn.frames_won[0], turn.frames_won[1]]
		if not unlocked.is_empty():
			var names: Array = []
			for id in unlocked:
				names.append(str(Achievements.LIST[id]["name"]))
			subtitle += "\n🏅 Unlocked: %s" % ", ".join(names)
		overlay.show_menu(
			"%s wins the frame" % turn.names[winner],
			[
				{"text": "Next Frame", "callable": _next_frame},
				{"text": "Main Menu", "callable": _quit_to_menu},
			],
			subtitle)
		if _net_host:
			_net_result.rpc("%s wins the frame" % turn.names[winner], subtitle, false)


## Confetti burst over the whole screen for a match win.
## Confetti colour ramp + a small rectangle texture, shared by all celebrations.
func _confetti_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.25, 0.28))
	ramp.add_point(0.25, Color(0.98, 0.78, 0.28))
	ramp.add_point(0.5, Color(0.30, 0.80, 0.40))
	ramp.add_point(0.75, Color(0.25, 0.55, 0.95))
	ramp.set_color(1, Color(0.85, 0.40, 0.85))
	return ramp


func _confetti_tex() -> ImageTexture:
	var img := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


## Full-screen confetti rain — for a match win.
func _celebrate() -> void:
	if GameState.low_graphics:
		return
	_stop_celebrate()
	_confetti = CanvasLayer.new()
	_confetti.layer = 20                 # Above the match-complete overlay.
	add_child(_confetti)

	var vp := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.texture = _confetti_tex()
	p.position = Vector2(vp.x * 0.5, -20.0)
	p.amount = 240
	p.lifetime = 4.5
	p.preprocess = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x * 0.5, 8.0)
	p.direction = Vector2(0, 1)
	p.spread = 30.0
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 340.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color_initial_ramp = _confetti_ramp()
	_confetti.add_child(p)


## A one-shot party-popper burst from `center` — for a frame win or a big break.
func _confetti_burst(center: Vector2, amount: int) -> void:
	if GameState.low_graphics:
		return
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var p := CPUParticles2D.new()
	p.texture = _confetti_tex()
	p.position = center
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = 2.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, 660)
	p.initial_velocity_min = 320.0
	p.initial_velocity_max = 680.0
	p.angular_velocity_min = -520.0
	p.angular_velocity_max = 520.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color_initial_ramp = _confetti_ramp()
	cl.add_child(p)
	p.emitting = true
	p.finished.connect(cl.queue_free)


func _stop_celebrate() -> void:
	if is_instance_valid(_confetti):
		_confetti.queue_free()
	_confetti = null


## A celebratory flash + confetti burst for a milestone break (50 / 100).
func _break_flourish(value: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	_confetti_burst(Vector2(vp.x * 0.5, vp.y * 0.44), 80)
	Audio.play("achieve")
	if value >= 100:
		hud.flash("CENTURY BREAK!  %d" % value, Color(1.0, 0.85, 0.30))
	else:
		hud.flash("GREAT BREAK!  %d" % value, Color(0.55, 0.90, 1.0))


func _step(dt: float) -> void:
	_integrate(dt)
	_resolve_pockets()
	_resolve_ball_collisions()
	_resolve_cushions()


func _integrate(dt: float) -> void:
	var damp := pow(FRICTION_PER_SEC, dt)   # Time-consistent across substeps.
	var spin_damp := pow(SPIN_DECAY, dt)    # Spin bleeds off as the ball travels.
	cue_ball.spin_follow *= spin_damp
	cue_ball.spin_side *= spin_damp
	for b in balls:
		if b.is_potted:
			continue
		if b.velocity.length() <= STOP_SPEED:
			b.velocity = Vector2.ZERO
			continue
		b.position += b.velocity * dt
		b.velocity *= damp
		if b.velocity.length() <= STOP_SPEED:
			b.velocity = Vector2.ZERO


func _resolve_pockets() -> void:
	for b in balls:
		if b.is_potted:
			continue
		for p in table.pockets:
			if b.position.distance_to(p.get("capture", p["pos"])) <= p.get("cap_r", p["radius"]):
				# Sink toward the VISIBLE hole centre so the drop lands in the hole.
				_pot_ball(b, p.get("visual", p["pos"]))
				break


func _pot_ball(b: Ball, pocket_pos: Vector2) -> void:
	b.pot_into(pocket_pos)          # is_potted = true + sink animation.
	if b not in _potted_this_shot:
		_potted_this_shot.append(b)
		Audio.play("pocket")
		_vibrate(35)
		if GameState.shake_enabled:
			_add_shake(2.5)
		# The sparkle fires when the ball FINISHES sinking (b.sunk), so you see
		# the drop first, then the splash.


## Screen shake: nudge the table root (background & HUD are separate layers, so
## they don't move). Only ever runs while balls are in motion.
func _add_shake(amount: float) -> void:
	if not GameState.shake_enabled or GameState.low_graphics:
		return
	_shake_amt = maxf(_shake_amt, amount)


## A ball finished its sink animation — pop the sparkle now (after the drop).
func _on_ball_sunk(pos: Vector2, col: Color) -> void:
	if GameState.sparkle_enabled:
		_pot_sparkle(pos, col)


func _update_shake(delta: float) -> void:
	if _shake_amt > 0.05:
		position = _base_pos + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amt
		_shake_amt = maxf(_shake_amt - 42.0 * delta, 0.0)
	elif position != _base_pos:
		position = _base_pos


## A quick particle burst in the ball's colour when it drops — pot "juice".
func _pot_sparkle(pos: Vector2, col: Color) -> void:
	if GameState.low_graphics:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 60
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 20
	p.lifetime = 0.55
	p.emitting = true
	p.spread = 180.0
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 360.0
	p.gravity = Vector2.ZERO
	p.damping_min = 200.0
	p.damping_max = 340.0
	p.scale_amount_min = maxf(ball_radius * 0.20, 3.5)
	p.scale_amount_max = maxf(ball_radius * 0.38, 6.0)
	p.color = col.lightened(0.35)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = ramp
	add_child(p)
	p.finished.connect(p.queue_free)


func _resolve_ball_collisions() -> void:
	var n := balls.size()
	for i in range(n):
		var a := balls[i]
		if a.is_potted:
			continue
		for j in range(i + 1, n):
			var b := balls[j]
			if b.is_potted:
				continue
			_collide_pair(a, b)


func _collide_pair(a: Ball, b: Ball) -> void:
	var d := b.position - a.position
	var dist := d.length()
	var min_dist := a.radius + b.radius
	if dist == 0.0:
		b.position += Vector2(0.01, 0.0)   # Break perfect overlap.
		return
	if dist >= min_dist:
		return

	# Record the first ball the cue ball touches this shot (for foul checks).
	if _first_contact == null:
		if a == cue_ball:
			_first_contact = b
		elif b == cue_ball:
			_first_contact = a

	# Capture the cue ball's pre-impact travel so follow/draw can act after it.
	var cue: Ball = null
	if a == cue_ball:
		cue = a
	elif b == cue_ball:
		cue = b
	var cue_pre_dir := Vector2.ZERO
	var cue_pre_speed := 0.0
	if cue != null:
		cue_pre_speed = cue.velocity.length()
		cue_pre_dir = cue.velocity / cue_pre_speed if cue_pre_speed > 0.0 else cue.spin_forward

	var n := d / dist
	# Push the pair apart so they no longer overlap (half each, equal mass).
	var overlap := min_dist - dist
	a.position -= n * (overlap * 0.5)
	b.position += n * (overlap * 0.5)

	# Impulse along the contact normal (equal mass, restitution e).
	var rel_vel := b.velocity - a.velocity
	var vel_along := rel_vel.dot(n)
	if vel_along < 0.0:   # Only if they are closing.
		_frame_ball_impact = maxf(_frame_ball_impact, -vel_along)
		var jimp := -(1.0 + RESTITUTION_BALL) * vel_along / 2.0
		var impulse := n * jimp
		a.velocity -= impulse
		b.velocity += impulse

		# Follow / draw: the cue ball's stored spin converts to travel along its
		# incoming line after contact (+ follows through, - screws back). Spent.
		if cue != null and absf(cue.spin_follow) > 0.01 and cue_pre_speed > 0.0:
			cue.velocity += cue_pre_dir * (cue.spin_follow * FOLLOW_FACTOR * cue_pre_speed)
			cue.spin_follow = 0.0


func _resolve_cushions() -> void:
	var r := table.play_rect
	for b in balls:
		if b.is_potted:
			continue
		var left := r.position.x + b.radius
		var right := r.end.x - b.radius
		var top := r.position.y + b.radius
		var bottom := r.end.y - b.radius
		var is_cue := b == cue_ball
		# Open a gap in the top/bottom cushion at the middle pocket so a ball
		# aimed into it can cross the rail line and drop (a rail-hugging ball
		# outside this narrow mouth still bounces normally).
		var in_mid_mouth := absf(b.position.x - r.get_center().x) < table.pocket_radius * 0.95
		if b.position.x < left:
			b.position.x = left
			_frame_cushion_impact = maxf(_frame_cushion_impact, absf(b.velocity.x))
			if is_cue:
				b.velocity.y += b.spin_side * SIDE_FACTOR * absf(b.velocity.x)
				b.spin_side *= 0.6
			b.velocity.x = -b.velocity.x * RESTITUTION_CUSHION
		elif b.position.x > right:
			b.position.x = right
			_frame_cushion_impact = maxf(_frame_cushion_impact, absf(b.velocity.x))
			if is_cue:
				b.velocity.y += b.spin_side * SIDE_FACTOR * absf(b.velocity.x)
				b.spin_side *= 0.6
			b.velocity.x = -b.velocity.x * RESTITUTION_CUSHION
		if b.position.y < top and not in_mid_mouth:
			b.position.y = top
			_frame_cushion_impact = maxf(_frame_cushion_impact, absf(b.velocity.y))
			if is_cue:
				b.velocity.x += b.spin_side * SIDE_FACTOR * absf(b.velocity.y)
				b.spin_side *= 0.6
			b.velocity.y = -b.velocity.y * RESTITUTION_CUSHION
		elif b.position.y > bottom and not in_mid_mouth:
			b.position.y = bottom
			_frame_cushion_impact = maxf(_frame_cushion_impact, absf(b.velocity.y))
			if is_cue:
				b.velocity.x += b.spin_side * SIDE_FACTOR * absf(b.velocity.y)
				b.spin_side *= 0.6
			b.velocity.y = -b.velocity.y * RESTITUTION_CUSHION
