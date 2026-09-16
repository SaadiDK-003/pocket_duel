class_name SettingsPanel
extends CanvasLayer

## A reusable, self-contained Settings modal (Sound / Music / Vibration /
## Tap to Shoot / Shot Timer / Reset). Used by both the main menu and the
## in-game pause menu. Changes save immediately to GameState.

const ACCENT: Color = Color(0.98, 0.78, 0.28)
const TEXT: Color = Color(0.95, 0.96, 0.98)
const BTN: Color = Color(0.16, 0.19, 0.23)
const BTN_HOVER: Color = Color(0.23, 0.27, 0.32)
const PANEL: Color = Color(0.11, 0.14, 0.17)

var _root: Control


func _ready() -> void:
	layer = 15                     # Above the pause overlay (layer 10).
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	visible = false


func open() -> void:
	_build()
	visible = true


func close() -> void:
	visible = false


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PANEL
	st.set_corner_radius_all(24)
	st.set_border_width_all(2)
	st.border_color = Color(1, 1, 1, 0.08)
	pc.add_theme_stylebox_override("panel", st)
	center.add_child(pc)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	pc.add_child(margin)

	# Responsive width/columns: wide screens get two columns of toggles so the
	# panel stays short; narrow screens fall back to a single column + scroll.
	var vp := get_viewport().get_visible_rect().size
	var content_w: float = clampf(vp.x * 0.86, 560.0, 1180.0)
	var cols: int = 2 if content_w >= 900.0 else 1

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(content_w, 0)
	margin.add_child(vb)

	_title(vb, "SETTINGS")
	_spacer(vb, 8)

	# Middle section scrolls if it doesn't fit, so the title stays pinned at the
	# top and Back stays pinned at the bottom no matter how many rows there are.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(content_w, clampf(vp.y * 0.50, 300.0, 620.0))
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	# A right margin keeps the toggles clear of the scrollbar (and a matching left
	# one keeps the two columns visually centred).
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", 26)
	pad.add_theme_constant_override("margin_left", 4)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(inner)

	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(grid)

	_toggle_row(grid, "Sound", GameState.sound_enabled,
		func(on): GameState.sound_enabled = on; GameState.save_settings())
	_toggle_row(grid, "Music", GameState.music_enabled,
		func(on): GameState.music_enabled = on; GameState.save_settings())
	_toggle_row(grid, "Vibration", GameState.vibration_enabled,
		func(on): GameState.vibration_enabled = on; GameState.save_settings())
	_toggle_row(grid, "Tap to Shoot", GameState.tap_to_shoot,
		func(on): GameState.tap_to_shoot = on; GameState.save_settings())
	_toggle_row(grid, "Screen Shake", GameState.shake_enabled,
		func(on): GameState.shake_enabled = on; GameState.save_settings())
	_toggle_row(grid, "Pot Sparkle", GameState.sparkle_enabled,
		func(on): GameState.sparkle_enabled = on; GameState.save_settings())
	_toggle_row(grid, "Low Graphics", GameState.low_graphics,
		func(on): GameState.low_graphics = on; GameState.save_settings())
	_toggle_row(grid, "Show FPS", GameState.show_fps,
		func(on): GameState.show_fps = on; GameState.save_settings())
	_toggle_row(grid, "Pro Rules", GameState.pro_rules,
		func(on): GameState.pro_rules = on; GameState.save_settings())

	_spacer(inner, 6)

	var timer_values := [0, 30, 20, 15]
	var st_btn := _button(inner, "", func(): pass, false)
	var st_label := func() -> String:
		return "Shot Timer: Off" if GameState.shot_timer == 0 else "Shot Timer: %ds" % GameState.shot_timer
	st_btn.text = st_label.call()
	st_btn.pressed.connect(func():
		var idx: int = timer_values.find(GameState.shot_timer)
		GameState.shot_timer = timer_values[(idx + 1) % timer_values.size()]
		GameState.save_settings()
		st_btn.text = st_label.call())

	_spacer(inner, 6)
	_button(inner, "Reset to defaults", func(): GameState.reset_settings(); _build(), false)

	_spacer(vb, 10)
	_button(vb, "Back", close, true)


# ------------------------------------------------------------------ Widgets
func _title(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 48)
	l.add_theme_color_override("font_color", TEXT)
	parent.add_child(l)


func _spacer(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


func _button(parent: Node, text: String, handler: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 32)
	var base := ACCENT if primary else BTN
	var hov := ACCENT.lightened(0.10) if primary else BTN_HOVER
	b.add_theme_stylebox_override("normal", _btn_style(base))
	b.add_theme_stylebox_override("hover", _btn_style(hov))
	b.add_theme_stylebox_override("pressed", _btn_style(hov))
	var fc := Color(0.1, 0.1, 0.12) if primary else TEXT
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.pressed.connect(func(): Audio.play("ui_click"); handler.call())
	parent.add_child(b)
	return b


func _toggle_row(parent: Node, label: String, initial: bool, cb: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.custom_minimum_size = Vector2(360, 0)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", TEXT)
	h.add_child(l)

	var t := Button.new()
	t.toggle_mode = true
	t.button_pressed = initial
	t.custom_minimum_size = Vector2(150, 62)
	t.add_theme_font_size_override("font_size", 30)
	var upd := func():
		t.text = "ON" if t.button_pressed else "OFF"
		var col: Color = Color(0.22, 0.72, 0.38) if t.button_pressed else Color(0.30, 0.33, 0.37)
		t.add_theme_stylebox_override("normal", _btn_style(col))
		t.add_theme_stylebox_override("hover", _btn_style(col.lightened(0.08)))
		t.add_theme_stylebox_override("pressed", _btn_style(col))
		t.add_theme_color_override("font_color", Color(1, 1, 1))
		t.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	upd.call()
	t.toggled.connect(func(_p): upd.call(); Audio.play("ui_click"); cb.call(t.button_pressed))
	h.add_child(t)
	parent.add_child(h)
