class_name ShopPanel
extends CanvasLayer

## Cosmetics shop: spend coins to unlock table cloths and cue skins, and select
## which to use. Buying/selecting saves to GameState immediately.

signal closed

const ACCENT: Color = Color(0.98, 0.78, 0.28)
const TEXT: Color = Color(0.95, 0.96, 0.98)
const TEXT_DIM: Color = Color(0.62, 0.67, 0.74)
const BTN: Color = Color(0.16, 0.19, 0.23)
const PANEL: Color = Color(0.11, 0.14, 0.17)

var _root: Control
var _msg: Label


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

	# Use most of the screen width instead of a tiny centred box.
	var vp := get_viewport().get_visible_rect().size
	var content_w := clampf(vp.x * 0.86, 640.0, 1500.0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.custom_minimum_size = Vector2(content_w, 0)
	margin.add_child(vb)

	# Header: title + coin balance.
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "SHOP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", TEXT)
	header.add_child(title)
	var coins := Label.new()
	coins.text = "🪙 %d" % GameState.coins
	coins.add_theme_font_size_override("font_size", 40)
	coins.add_theme_color_override("font_color", ACCENT)
	header.add_child(coins)
	vb.add_child(header)

	_section(vb, "TABLE CLOTH", Cosmetics.CLOTH_ORDER, Cosmetics.CLOTHS, "cloth", GameState.selected_cloth)
	_section(vb, "CUE", Cosmetics.CUE_ORDER, Cosmetics.CUES, "cue", GameState.selected_cue)
	_section(vb, "BALL SET", Cosmetics.BALL_SET_ORDER, Cosmetics.BALL_SETS, "ball", GameState.selected_ball_set)

	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.custom_minimum_size = Vector2(0, 26)
	_msg.add_theme_font_size_override("font_size", 22)
	_msg.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	vb.add_child(_msg)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 72)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.add_theme_font_size_override("font_size", 32)
	back.add_theme_stylebox_override("normal", _bstyle(ACCENT))
	back.add_theme_stylebox_override("hover", _bstyle(ACCENT.lightened(0.1)))
	back.add_theme_stylebox_override("pressed", _bstyle(ACCENT.darkened(0.1)))
	back.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	back.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.12))
	back.pressed.connect(func(): Audio.play("ui_click"); close())
	vb.add_child(back)


func _section(parent: Node, heading: String, order: Array, catalogue: Dictionary, kind: String, selected: String) -> void:
	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 28)
	h.add_theme_color_override("font_color", TEXT_DIM)
	parent.add_child(h)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	for id in order:
		row.add_child(_swatch(kind, id, catalogue[id], id == selected))


func _swatch(kind: String, id: String, item: Dictionary, is_selected: bool) -> Control:
	var owned: bool = GameState.is_owned(id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # spread evenly across the row

	var b := Button.new()
	b.custom_minimum_size = Vector2(132, 112)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # keep the swatch centred in its cell
	var sb := StyleBoxFlat.new()
	# Ball sets show a ball preview on a dark bed; cloths/cues fill with the colour.
	sb.bg_color = Color(0.06, 0.08, 0.10) if kind == "ball" else item["color"]
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(4 if is_selected else 1)
	sb.border_color = ACCENT if is_selected else Color(1, 1, 1, 0.15)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(func(): _pick(kind, id, item["price"]))
	if kind == "ball":
		var prev := BallPreview.new()
		prev.base = item["color"]
		prev.style = item["style"]
		prev.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(prev)
	box.add_child(b)

	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	if is_selected:
		lbl.text = "✓ Using"
		lbl.add_theme_color_override("font_color", ACCENT)
	elif owned:
		lbl.text = "Owned"
		lbl.add_theme_color_override("font_color", TEXT_DIM)
	else:
		lbl.text = "🪙 %d" % item["price"]
		lbl.add_theme_color_override("font_color", TEXT)
	box.add_child(lbl)
	return box


func _pick(kind: String, id: String, price: int) -> void:
	Audio.play("ui_click")
	if GameState.is_owned(id):
		_select(kind, id)
	elif GameState.buy(id, price):
		_select(kind, id)
	else:
		if _msg:
			_msg.text = "Not enough coins"
		return
	_build()   # Refresh selection / balance / labels.


func _select(kind: String, id: String) -> void:
	match kind:
		"cloth": GameState.select_cloth(id)
		"cue": GameState.select_cue(id)
		"ball": GameState.select_ball_set(id)


func _bstyle(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s
