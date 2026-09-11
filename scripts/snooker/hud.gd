class_name Hud
extends CanvasLayer

## Scoreboard overlay: two player cards (active one highlighted) and a centre
## pill showing the ball "on" (as a coloured dot) and the current break. All
## elements are positioned by layout(vp) from the real viewport size, so on wide
## phones the UI sits in the side gutters instead of over the felt.

signal pause_requested
signal shoot_pressed

const ACCENT: Color = Color(0.98, 0.78, 0.28)
const TEXT_DIM: Color = Color(0.62, 0.67, 0.74)
const TEXT_BRIGHT: Color = Color(0.96, 0.97, 0.99)
const CARD_W: float = 320.0
const CARD_H: float = 84.0
const PILL_W: float = 360.0
const PILL_H: float = 62.0
const PWRV_W: float = 46.0        # Vertical power meter (8-ball-pool style).
const PWRV_H: float = 380.0
const PWR_INSET: float = 5.0

const ON_COLORS: Dictionary = {
	"RED": Color(0.82, 0.12, 0.12), "YELLOW": Color(0.96, 0.82, 0.14),
	"GREEN": Color(0.16, 0.62, 0.24), "BROWN": Color(0.52, 0.32, 0.14),
	"BLUE": Color(0.20, 0.45, 0.90), "PINK": Color(0.96, 0.52, 0.68),
	"BLACK": Color(0.15, 0.15, 0.17), "COLOUR": Color(0.85, 0.85, 0.88),
}

var spin: SpinSelector

var _cards := []
var _style_active: StyleBoxFlat
var _style_idle: StyleBoxFlat
var _pill: Panel
var _pause: Button
var _on_ball: BallPreview
var _on_text: Label
var _sep: Label
var _break: Label
var _mode: Label
var _hint: Label
var _flash: Label
var _timer: Label
var _power_track: Panel
var _power_clip: Control
var _power_grad: TextureRect
var _shoot_btn: Button


func setup() -> void:
	_build_styles()
	_cards = [_make_card(true), _make_card(false)]
	_make_center_pill()
	_make_pause_button()

	_mode = _make_label(920, HORIZONTAL_ALIGNMENT_RIGHT, 26)
	_mode.size.x = 420
	_mode.modulate = TEXT_DIM
	_hint = _make_label(0, HORIZONTAL_ALIGNMENT_CENTER, 22)
	_hint.size.x = 800
	_hint.modulate = TEXT_DIM
	_hint.text = "1 Classic   2 Quick   R Rematch   Esc Menu"
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_hint.hide()

	_flash = _make_label(0, HORIZONTAL_ALIGNMENT_CENTER, 46)
	_flash.size.x = 800
	_flash.modulate = Color(1, 1, 1, 0)

	_timer = _make_label(0, HORIZONTAL_ALIGNMENT_CENTER, 34)
	_timer.size.x = 160
	_timer.hide()

	_make_power_bar()

	_shoot_btn = Button.new()
	_shoot_btn.text = "SHOOT"
	_shoot_btn.custom_minimum_size = Vector2(240, 90)
	_shoot_btn.size = Vector2(240, 90)
	_shoot_btn.add_theme_font_size_override("font_size", 40)
	var ss := StyleBoxFlat.new()
	ss.bg_color = ACCENT
	ss.set_corner_radius_all(18)
	_shoot_btn.add_theme_stylebox_override("normal", ss)
	var ssh := ss.duplicate(); ssh.bg_color = ACCENT.lightened(0.1)
	_shoot_btn.add_theme_stylebox_override("hover", ssh)
	_shoot_btn.add_theme_stylebox_override("pressed", ssh)
	_shoot_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	_shoot_btn.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.12))
	_shoot_btn.pressed.connect(func(): Audio.play("ui_click"); shoot_pressed.emit())
	_shoot_btn.hide()
	add_child(_shoot_btn)

	spin = SpinSelector.new()
	add_child(spin)


func set_shoot_visible(v: bool) -> void:
	_shoot_btn.visible = v


## A vertical power meter (8-ball-pool style): a dark track with a yellow→red
## gradient that fills UP from the bottom as power increases.
func _make_power_bar() -> void:
	_power_track = Panel.new()
	_power_track.size = Vector2(PWRV_W, PWRV_H)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.08, 0.88)
	st.set_corner_radius_all(int(PWRV_W * 0.5))
	st.set_border_width_all(2)
	st.border_color = Color(1, 1, 1, 0.12)
	_power_track.add_theme_stylebox_override("panel", st)
	add_child(_power_track)

	var iw := PWRV_W - PWR_INSET * 2.0
	var ih := PWRV_H - PWR_INSET * 2.0
	_power_clip = Control.new()
	_power_clip.clip_contents = true
	_power_clip.position = Vector2(PWR_INSET, PWR_INSET + ih)   # zero-height at the bottom
	_power_clip.size = Vector2(iw, 0)
	_power_track.add_child(_power_clip)

	_power_grad = TextureRect.new()
	_power_grad.texture = _build_power_gradient()
	_power_grad.size = Vector2(iw, ih)
	_power_grad.stretch_mode = TextureRect.STRETCH_SCALE
	_power_clip.add_child(_power_grad)

	_power_track.hide()


## Vertical gradient for the meter: red (top / full power) -> orange -> yellow.
func _build_power_gradient() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_offset(0, 0.0); g.set_color(0, Color(0.95, 0.20, 0.12))   # top = red
	g.set_offset(1, 1.0); g.set_color(1, Color(1.0, 0.85, 0.16))    # bottom = yellow
	g.add_point(0.5, Color(0.98, 0.55, 0.13))                       # orange
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 16
	gt.height = 256
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	return gt


func set_power(power: float) -> void:
	_power_track.show()
	var ih := PWRV_H - PWR_INSET * 2.0
	var fh := ih * clampf(power, 0.0, 1.0)
	# Reveal the gradient from the bottom up (top of the fill gets redder).
	_power_clip.position.y = PWR_INSET + (ih - fh)
	_power_clip.size.y = fh
	_power_grad.position.y = -(ih - fh)


func clear_power() -> void:
	_power_track.hide()


## Position everything from the actual viewport size.
func layout(vp: Vector2) -> void:
	var w := vp.x
	var h := vp.y
	_cards[0]["panel"].position = Vector2(40, 26)
	_cards[1]["panel"].position = Vector2(w - 40 - CARD_W, 26)
	_pill.position = Vector2(w * 0.5 - PILL_W * 0.5, 38)
	_pause.position = Vector2(w - 40 - _pause.size.x, 26 + CARD_H + 14)
	_mode.position = Vector2(w - 60 - _mode.size.x, h - 46)
	_hint.position = Vector2(w * 0.5 - _hint.size.x * 0.5, h - 46)
	_flash.position = Vector2(w * 0.5 - _flash.size.x * 0.5, 150)
	_timer.position = Vector2(w * 0.5 - _timer.size.x * 0.5, 112)
	_power_track.position = Vector2(26, h * 0.42 - PWRV_H * 0.5)
	_shoot_btn.position = Vector2(w - 44 - _shoot_btn.size.x, h - 44 - _shoot_btn.size.y)
	spin.position = Vector2(44, h - 44 - spin.size.y)


func _build_styles() -> void:
	_style_active = StyleBoxFlat.new()
	_style_active.bg_color = Color(0.11, 0.13, 0.17, 0.94)
	_style_active.set_corner_radius_all(20)
	_style_active.set_border_width_all(3)
	_style_active.border_color = ACCENT
	_style_active.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.30)   # gold glow
	_style_active.shadow_size = 12
	_style_idle = StyleBoxFlat.new()
	_style_idle.bg_color = Color(0.09, 0.10, 0.13, 0.78)
	_style_idle.set_corner_radius_all(20)


func _make_card(is_left: bool) -> Dictionary:
	var info_align := HORIZONTAL_ALIGNMENT_LEFT if is_left else HORIZONTAL_ALIGNMENT_RIGHT
	var panel := Panel.new()
	panel.size = Vector2(CARD_W, CARD_H)
	panel.add_theme_stylebox_override("panel", _style_idle)
	add_child(panel)

	# MarginContainer guarantees internal padding, so text never touches edges.
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 20)
	mc.add_theme_constant_override("margin_right", 20)
	mc.add_theme_constant_override("margin_top", 10)
	mc.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(mc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	mc.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = info_align
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", TEXT_DIM)
	info.add_child(name_lbl)

	var pips := Label.new()
	pips.horizontal_alignment = info_align
	pips.add_theme_font_size_override("font_size", 15)
	pips.add_theme_color_override("font_color", ACCENT)
	info.add_child(pips)

	var score_lbl := Label.new()
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 46)
	score_lbl.add_theme_color_override("font_color", TEXT_BRIGHT)

	# Name/pips on the outer side, big score toward the table centre.
	if is_left:
		row.add_child(info)
		row.add_child(score_lbl)
	else:
		row.add_child(score_lbl)
		row.add_child(info)

	return {"panel": panel, "name": name_lbl, "score": score_lbl, "pips": pips}


func _make_center_pill() -> void:
	_pill = Panel.new()
	_pill.size = Vector2(PILL_W, PILL_H)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.10, 0.13, 0.90)
	st.set_corner_radius_all(31)
	_pill.add_theme_stylebox_override("panel", st)
	add_child(_pill)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pill.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_on_ball = BallPreview.new()
	_on_ball.custom_minimum_size = Vector2(42, 42)
	_on_ball.style = "classic"
	_on_ball.base = ON_COLORS["RED"]
	row.add_child(_on_ball)
	_on_text = _mini_label(row, "RED", 26, TEXT_BRIGHT)
	_sep = _mini_label(row, "•", 24, TEXT_DIM)
	_break = _mini_label(row, "", 24, ACCENT)


func _mini_label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _make_pause_button() -> void:
	_pause = Button.new()
	_pause.text = "II"
	_pause.custom_minimum_size = Vector2(96, 80)
	_pause.size = Vector2(96, 80)
	_pause.add_theme_font_size_override("font_size", 46)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.13, 0.17, 0.92)
	st.set_corner_radius_all(18)
	st.set_border_width_all(2)
	st.border_color = Color(1, 1, 1, 0.12)
	_pause.add_theme_stylebox_override("normal", st)
	var sh := st.duplicate(); sh.bg_color = Color(0.18, 0.21, 0.26, 0.95)
	_pause.add_theme_stylebox_override("hover", sh)
	_pause.add_theme_stylebox_override("pressed", sh)
	_pause.add_theme_color_override("font_color", ACCENT)
	_pause.add_theme_color_override("font_hover_color", ACCENT)
	_pause.pressed.connect(func(): Audio.play("ui_click"); pause_requested.emit())
	add_child(_pause)


func _make_label(width: float, align: int, size: int) -> Label:
	var l := Label.new()
	l.size = Vector2(width, 40)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


# ------------------------------------------------------------------ Update
func refresh(turn: TurnManager, on_ball: String = "") -> void:
	for i in range(2):
		var c: Dictionary = _cards[i]
		c["name"].text = str(turn.names[i]).to_upper()
		c["score"].text = str(turn.scores[i])
		c["pips"].text = "●".repeat(turn.frames_won[i])
		var active := turn.current == i
		c["panel"].add_theme_stylebox_override("panel", _style_active if active else _style_idle)
		c["name"].add_theme_color_override("font_color", TEXT_BRIGHT if active else TEXT_DIM)
		c["panel"].modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.85)

	if on_ball == "":
		_pill.hide()
		return
	_pill.show()
	_on_ball.base = ON_COLORS.get(on_ball, Color(1, 1, 1))
	_on_ball.queue_redraw()
	_on_text.text = on_ball
	if turn.break_score > 0:
		_sep.show()
		_break.show()
		_break.text = "BREAK %d" % turn.break_score
	else:
		_sep.hide()
		_break.hide()


func set_timer(seconds: int) -> void:
	_timer.text = "⏱ %d" % seconds
	_timer.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if seconds <= 5 else TEXT_BRIGHT)
	_timer.show()


func hide_timer() -> void:
	_timer.hide()


func set_mode(mode_name: String) -> void:
	_mode.text = "%s Snooker" % mode_name


func flash(text: String, color: Color = Color(1, 1, 1)) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", color)
	_flash.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_flash, "modulate:a", 0.0, 1.1)
