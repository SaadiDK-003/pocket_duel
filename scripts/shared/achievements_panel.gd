class_name AchievementsPanel
extends CanvasLayer

## Achievements & lifetime stats. Read-only: achievements unlock during play.

signal closed

const ACCENT: Color = Color(0.98, 0.78, 0.28)
const TEXT: Color = Color(0.95, 0.96, 0.98)
const TEXT_DIM: Color = Color(0.62, 0.67, 0.74)
const PANEL: Color = Color(0.11, 0.14, 0.17)
const ROW: Color = Color(0.06, 0.08, 0.10)
const DONE: Color = Color(0.12, 0.30, 0.18)

var _root: Control


func _ready() -> void:
	layer = 15
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
	closed.emit()


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
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	pc.add_child(margin)

	# Fill most of the screen instead of a tiny centred box; 2 columns when wide.
	var vp := get_viewport().get_visible_rect().size
	var content_w := clampf(vp.x * 0.88, 640.0, 1600.0)
	var cols := 2 if content_w > 760.0 else 1

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(content_w, 0)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", TEXT)
	vb.add_child(title)

	# Lifetime stats strip.
	var stats := Label.new()
	stats.text = "Played %d   ·   Won %d   ·   Streak %d   ·   Best break %d   ·   Pots %d" % [
		GameState.stat_played, GameState.stat_won, GameState.stat_streak,
		GameState.stat_best_break, GameState.stat_pots]
	stats.add_theme_font_size_override("font_size", 26)
	stats.add_theme_color_override("font_color", TEXT_DIM)
	vb.add_child(stats)

	_spacer(vb, 4)
	# Scroll the (growing) list so the panel never overflows the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(content_w, clampf(vp.y * 0.52, 340.0, 660.0))
	vb.add_child(scroll)
	# A right margin keeps the rows clear of the scrollbar.
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", 26)
	pad.add_theme_constant_override("margin_left", 4)
	pad.mouse_filter = Control.MOUSE_FILTER_PASS    # don't block touch-drag scrolling
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS   # let touch-drag reach the scroller
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(grid)
	for id in Achievements.ORDER:
		_row(grid, id, Achievements.LIST[id])

	_spacer(vb, 8)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 78)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.add_theme_font_size_override("font_size", 32)
	back.add_theme_stylebox_override("normal", _bstyle(ACCENT))
	back.add_theme_stylebox_override("hover", _bstyle(ACCENT.lightened(0.1)))
	back.add_theme_stylebox_override("pressed", _bstyle(ACCENT.darkened(0.1)))
	back.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	back.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.12))
	back.pressed.connect(func(): Audio.play("ui_click"); close())
	vb.add_child(back)


func _row(parent: Node, id: String, data: Dictionary) -> void:
	var unlocked: bool = id in GameState.achieved
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = DONE if unlocked else ROW
	st.set_corner_radius_all(12)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	pc.add_theme_stylebox_override("panel", st)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # fill the grid column
	# Non-interactive rows: let touch-drag pass through so the list scrolls
	# smoothly no matter where the finger lands (was getting stuck on the rows).
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(pc)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)

	var icon := Label.new()
	icon.text = "🏅" if unlocked else "🔒"
	icon.add_theme_font_size_override("font_size", 40)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)

	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_theme_constant_override("separation", 2)
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(txt)
	var nm := Label.new()
	nm.text = str(data["name"])
	nm.add_theme_font_size_override("font_size", 32)
	nm.add_theme_color_override("font_color", TEXT if unlocked else TEXT_DIM)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(nm)
	var ds := Label.new()
	ds.text = str(data["desc"])
	ds.add_theme_font_size_override("font_size", 23)
	ds.add_theme_color_override("font_color", TEXT_DIM)
	ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(ds)

	var rw := Label.new()
	rw.text = ("✓" if unlocked else "🪙 %d" % int(data["reward"]))
	rw.add_theme_font_size_override("font_size", 30)
	rw.add_theme_color_override("font_color", ACCENT)
	rw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(rw)


func _spacer(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


func _bstyle(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s
