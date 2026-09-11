extends Control

## Title screen and pre-match / settings modals. Styled to match the in-game HUD
## (dark panels, gold accent). Modals are opaque so the menu never shows through.

const GAME_SCENE: String = "res://scenes/snooker/snooker_game.tscn"

const ACCENT: Color = Color(0.98, 0.78, 0.28)
const TEXT: Color = Color(0.95, 0.96, 0.98)
const TEXT_DIM: Color = Color(0.60, 0.66, 0.72)
const BTN: Color = Color(0.16, 0.19, 0.23)
const BTN_HOVER: Color = Color(0.23, 0.27, 0.32)
const PANEL: Color = Color(0.11, 0.14, 0.17)
const FIELD: Color = Color(0.06, 0.08, 0.10)

var _toast: Label
var _modal: Control
var _settings: SettingsPanel
var _shop: ShopPanel
var _achievements: AchievementsPanel
var _coins: Label


func _ready() -> void:
	_build()


func _build() -> void:
	# Background: the snooker photo, darkened + blurred, cover-scaled to fill.
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/menu_bg.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Dark scrim so the title and buttons stay legible over the photo.
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.06, 0.10, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	# Wider on a landscape phone so the menu fills more of the screen.
	var vpw := get_viewport().get_visible_rect().size.x
	vb.custom_minimum_size = Vector2(clampf(vpw * 0.5, 600.0, 900.0), 0)
	center.add_child(vb)

	_title(vb, "POCKET DUEL", 96, TEXT)
	_title(vb, "SNOOKER", 36, ACCENT)
	_spacer(vb, 22)
	_button(vb, "PLAY WITH HUMAN", func(): _show_prematch(false), true)
	_button(vb, "PLAY WITH BOT", func(): _show_prematch(true), false)
	_spacer(vb, 6)
	# Secondary actions in a compact 2-column grid so the menu stays short.
	var r1 := _row(vb)
	_small(_button(r1, "SHOP", _show_shop, false))
	_small(_button(r1, "ACHIEVEMENTS", _show_achievements, false))
	var r2 := _row(vb)
	_small(_button(r2, "SETTINGS", _show_settings, false))
	_small(_button(r2, "REMOVE ADS", func(): _toast_show("Remove Ads — coming in a later phase"), false))
	_spacer(vb, 6)
	_small(_button(vb, "EXIT", func(): get_tree().quit(), false))

	# Coin balance, top-right.
	_coins = Label.new()
	_coins.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_coins.position += Vector2(-260, 30)
	_coins.size = Vector2(220, 40)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins.add_theme_font_size_override("font_size", 34)
	_coins.add_theme_color_override("font_color", ACCENT)
	add_child(_coins)
	_update_coins()

	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position += Vector2(-300, -28)
	_toast.size = Vector2(600, 40)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", ACCENT)
	_toast.hide()
	add_child(_toast)

	# Offer the daily reward once per day, on entering the menu.
	if GameState.daily_available():
		call_deferred("_show_daily")


# ------------------------------------------------------------------ Widgets
func _title(parent: Node, text: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# Drop shadow so titles read clearly over the photo background.
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", 2)
	parent.add_child(l)


func _spacer(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


## A horizontal row for a 2-column grid of buttons.
func _row(parent: Node) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hb)
	return hb


## Shrink a secondary button so the grid stays compact.
func _small(b: Button) -> Button:
	b.custom_minimum_size = Vector2(0, 66)
	b.add_theme_font_size_override("font_size", 27)
	return b


func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s


func _button(parent: Node, text: String, handler: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 82)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 34)
	if primary:
		b.add_theme_stylebox_override("normal", _btn_style(ACCENT))
		b.add_theme_stylebox_override("hover", _btn_style(ACCENT.lightened(0.10)))
		b.add_theme_stylebox_override("pressed", _btn_style(ACCENT.darkened(0.10)))
		b.add_theme_color_override("font_color", Color(0.10, 0.10, 0.12))
		b.add_theme_color_override("font_hover_color", Color(0.10, 0.10, 0.12))
		b.add_theme_color_override("font_pressed_color", Color(0.10, 0.10, 0.12))
	else:
		b.add_theme_stylebox_override("normal", _btn_style(BTN))
		b.add_theme_stylebox_override("hover", _btn_style(BTN_HOVER))
		b.add_theme_stylebox_override("pressed", _btn_style(BTN_HOVER))
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", TEXT)
	b.pressed.connect(func(): Audio.play("ui_click"); handler.call())
	parent.add_child(b)
	return b


## Opaque modal: dim backdrop + solid centred panel. Returns the content VBox.
func _open_modal() -> VBoxContainer:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)

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
	vb.add_theme_constant_override("separation", 18)
	# Wider on a landscape screen instead of a tiny centred box.
	var vp := get_viewport().get_visible_rect().size
	vb.custom_minimum_size = Vector2(clampf(vp.x * 0.6, 560.0, 1000.0), 0)
	margin.add_child(vb)
	return vb


func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()


func _field(parent: Node, placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, 74)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.max_length = 16
	le.add_theme_font_size_override("font_size", 32)
	var st := StyleBoxFlat.new()
	st.bg_color = FIELD
	st.set_corner_radius_all(12)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	le.add_theme_stylebox_override("normal", st)
	var stf := st.duplicate()
	stf.border_color = ACCENT
	stf.set_border_width_all(2)
	le.add_theme_stylebox_override("focus", stf)
	parent.add_child(le)
	return le


# ------------------------------------------------------------------ Pre-match
## Opponent is already chosen on the main menu (is_bot). Here we pick the mode,
## names, difficulty (bot only), and best-of.
func _show_prematch(is_bot: bool) -> void:
	GameState.vs_ai = is_bot
	if GameState.mode != "Classic" and GameState.mode != "Quick":
		GameState.mode = "Classic"

	var vb := _open_modal()
	_title(vb, "Vs Bot" if is_bot else "Two Players", 46, TEXT)
	_spacer(vb, 6)

	# Mode selector (Classic / Quick).
	var mode_btn := _button(vb, "", func(): pass, false)
	var mode_label := func() -> String:
		return "Classic Snooker (15 reds)" if GameState.mode == "Classic" else "Quick Snooker (6 reds)"
	mode_btn.text = mode_label.call()
	mode_btn.pressed.connect(func():
		GameState.mode = "Quick" if GameState.mode == "Classic" else "Classic"
		mode_btn.text = mode_label.call())

	var le1 := _field(vb, "Player 1")
	var le2: LineEdit = null
	if is_bot:
		# Difficulty selector.
		var diff_names := ["Easy", "Medium", "Hard"]
		var diff_btn := _button(vb, "", func(): pass, false)
		var diff_label := func() -> String:
			return "Difficulty: %s" % diff_names[clampi(GameState.ai_difficulty, 0, 2)]
		diff_btn.text = diff_label.call()
		diff_btn.pressed.connect(func():
			GameState.ai_difficulty = (GameState.ai_difficulty + 1) % 3
			diff_btn.text = diff_label.call())
	else:
		le2 = _field(vb, "Player 2")

	# Best-of selector.
	var bo_values := [1, 3, 5]
	var bo_btn := _button(vb, "Best of %d" % GameState.best_of, func(): pass, false)
	bo_btn.pressed.connect(func():
		var idx: int = bo_values.find(GameState.best_of)
		GameState.best_of = bo_values[(idx + 1) % bo_values.size()]
		bo_btn.text = "Best of %d" % GameState.best_of)

	_spacer(vb, 10)
	_button(vb, "START", func(): _begin_match(le1.text, "" if le2 == null else le2.text), true)
	_button(vb, "Back", _close_modal, false)


func _begin_match(n1: String, n2: String) -> void:
	var name1 := n1.strip_edges()
	var name2 := n2.strip_edges()
	GameState.names = [
		name1 if name1 != "" else "Player 1",
		"Bot" if GameState.vs_ai else (name2 if name2 != "" else "Player 2"),
	]
	get_tree().change_scene_to_file(GAME_SCENE)


# ------------------------------------------------------------------ Settings
func _show_settings() -> void:
	if not is_instance_valid(_settings):
		_settings = SettingsPanel.new()
		add_child(_settings)
	_settings.open()


func _show_achievements() -> void:
	if not is_instance_valid(_achievements):
		_achievements = AchievementsPanel.new()
		add_child(_achievements)
	_achievements.open()


## Daily reward: a claim modal showing the streak and the coins on offer.
func _show_daily() -> void:
	if not GameState.daily_available():
		return
	var next_reward := 20 + mini(GameState.daily_streak, 6) * 5
	var vb := _open_modal()
	_title(vb, "DAILY REWARD", 46, ACCENT)
	_spacer(vb, 4)
	var info := Label.new()
	info.text = "Come back every day for more coins!\nDay streak: %d" % (GameState.daily_streak)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 26)
	info.add_theme_color_override("font_color", TEXT)
	vb.add_child(info)
	var amt := Label.new()
	amt.text = "🪙 +%d" % next_reward
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amt.add_theme_font_size_override("font_size", 60)
	amt.add_theme_color_override("font_color", ACCENT)
	vb.add_child(amt)
	_spacer(vb, 10)
	_button(vb, "CLAIM", func():
		var got := GameState.claim_daily()
		_update_coins()
		_close_modal()
		if got > 0:
			_toast_show("Daily reward claimed: +%d coins" % got), true)
	_button(vb, "Later", _close_modal, false)


func _show_shop() -> void:
	if not is_instance_valid(_shop):
		_shop = ShopPanel.new()
		add_child(_shop)
		_shop.closed.connect(_update_coins)
	_shop.open()


func _update_coins() -> void:
	_coins.text = "🪙 %d" % GameState.coins


func _toast_show(text: String) -> void:
	_toast.text = text
	_toast.show()
	await get_tree().create_timer(1.8).timeout
	if is_instance_valid(_toast):
		_toast.hide()
