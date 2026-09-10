class_name AchievementToast
extends CanvasLayer

## An animated "Achievement Unlocked" banner that slides in from the top,
## holds, then slides out. Multiple unlocks are queued and shown one by one.

const ACCENT: Color = Color(0.98, 0.78, 0.28)
const TEXT: Color = Color(0.98, 0.98, 0.99)
const PANEL: Color = Color(0.13, 0.16, 0.20)

var _queue: Array = []           # Pending [name, reward] pairs.
var _busy: bool = false
var _wrap: Control               # Full-width row; we animate its Y.
var _sub: Label


func _ready() -> void:
	layer = 18
	# Full-width wrapper so the banner is horizontally centred without having
	# to measure the panel; only its Y is animated.
	_wrap = Control.new()
	_wrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wrap)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrap.add_child(row)

	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PANEL
	st.set_corner_radius_all(18)
	st.set_border_width_all(2)
	st.border_color = ACCENT
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 14
	st.content_margin_left = 30
	st.content_margin_right = 30
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", st)
	row.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "🏅 ACHIEVEMENT UNLOCKED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT)
	vb.add_child(title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 30)
	_sub.add_theme_color_override("font_color", TEXT)
	vb.add_child(_sub)

	_wrap.position.y = -220
	_wrap.visible = false


## Queue an achievement banner (by catalogue id).
func show_id(id: String) -> void:
	if not Achievements.LIST.has(id):
		return
	var d: Dictionary = Achievements.LIST[id]
	_queue.append([str(d["name"]), int(d["reward"])])
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		_wrap.visible = false
		return
	_busy = true
	var item: Array = _queue.pop_front()
	_sub.text = "%s   🪙 +%d" % [item[0], item[1]]
	_wrap.visible = true
	_wrap.position.y = -220

	Audio.play("achieve")
	var tw := create_tween()
	tw.tween_property(_wrap, "position:y", 24.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.9)
	tw.tween_property(_wrap, "position:y", -220.0, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_next)
