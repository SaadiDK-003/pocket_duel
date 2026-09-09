class_name OverlayMenu
extends CanvasLayer

## A reusable modal (pause menu, match-complete). Opaque dark panel with a title
## and buttons, styled to match the main menu (gold primary + dark secondaries).

const ACCENT: Color = Color(0.98, 0.78, 0.28)
const TEXT: Color = Color(0.95, 0.96, 0.98)
const BTN: Color = Color(0.16, 0.19, 0.23)
const BTN_HOVER: Color = Color(0.23, 0.27, 0.32)
const PANEL: Color = Color(0.11, 0.14, 0.17)

var _root: Control


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	visible = false


## buttons: Array of { "text": String, "callable": Callable }. The first is the
## primary (gold) action. `subtitle` shows smaller text under the title.
func show_menu(title: String, buttons: Array, subtitle: String = "") -> void:
	for c in _root.get_children():
		_root.remove_child(c)
		c.free()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
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
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 16
	pc.add_theme_stylebox_override("panel", st)
	center.add_child(pc)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	pc.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(480, 0)
	margin.add_child(vb)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 52)
	t.add_theme_color_override("font_color", TEXT)
	vb.add_child(t)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 26)
		sub.add_theme_color_override("font_color", Color(0.75, 0.8, 0.86))
		vb.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacer)

	for i in range(buttons.size()):
		var b: Dictionary = buttons[i]
		vb.add_child(_make_button(b["text"], b["callable"], i == 0))

	visible = true


func _make_button(text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 32)
	if primary:
		b.add_theme_stylebox_override("normal", _btn_style(ACCENT))
		b.add_theme_stylebox_override("hover", _btn_style(ACCENT.lightened(0.10)))
		b.add_theme_stylebox_override("pressed", _btn_style(ACCENT.darkened(0.10)))
		b.add_theme_color_override("font_color", Color(0.10, 0.10, 0.12))
		b.add_theme_color_override("font_hover_color", Color(0.10, 0.10, 0.12))
	else:
		b.add_theme_stylebox_override("normal", _btn_style(BTN))
		b.add_theme_stylebox_override("hover", _btn_style(BTN_HOVER))
		b.add_theme_stylebox_override("pressed", _btn_style(BTN_HOVER))
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", TEXT)
	b.pressed.connect(func(): Audio.play("ui_click"); cb.call())
	return b


func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


func hide_menu() -> void:
	visible = false
