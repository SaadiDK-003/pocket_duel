class_name LanLobby
extends CanvasLayer

## LAN lobby: host a game (auto-advertised on the WiFi) or tap a nearby game to
## join. Emits `start_match(is_host)` once both players are connected.

signal start_match(is_host)
signal closed

const ACCENT: Color = Color(0.98, 0.78, 0.28)
const TEXT: Color = Color(0.95, 0.96, 0.98)
const TEXT_DIM: Color = Color(0.62, 0.67, 0.74)
const BTN: Color = Color(0.16, 0.19, 0.23)
const GREEN: Color = Color(0.22, 0.72, 0.38)
const PANEL: Color = Color(0.11, 0.14, 0.17)

var _root: Control
var _state: String = "browse"        # browse | hosting | connecting | connected
var _status: String = ""


func _ready() -> void:
	layer = 16
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	visible = false
	Net.hosts_updated.connect(_on_hosts_updated)
	Net.server_connected.connect(_on_server_connected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.player_connected.connect(_on_player_connected)
	Net.link_lost.connect(_on_link_lost)


func open() -> void:
	_state = "browse"
	_status = ""
	Net.start_discovery()
	_build()
	visible = true


func close() -> void:
	Net.leave()
	visible = false
	closed.emit()


# ---------------------------------------------------------------- Net callbacks
func _on_hosts_updated(_hosts: Array) -> void:
	if _state == "browse":
		_build()


func _on_player_connected(_id: int) -> void:
	# Host: a guest joined -> begin the match as host.
	_state = "connected"
	start_match.emit(true)


func _on_server_connected() -> void:
	# Guest: connected -> begin the match as guest.
	_state = "connected"
	start_match.emit(false)


func _on_connection_failed() -> void:
	_state = "browse"
	_status = "Couldn't connect — try again."
	Net.start_discovery()
	_build()


func _on_link_lost() -> void:
	_state = "browse"
	_status = "The other player left."
	Net.start_discovery()
	_build()


# ---------------------------------------------------------------- UI
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
		margin.add_theme_constant_override("margin_" + side, 44)
	pc.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(620, 0)
	margin.add_child(vb)

	_label(vb, "PLAY OVER WIFI", 46, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(vb, "Both phones must be on the same WiFi.", 22, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_spacer(vb, 6)

	match _state:
		"hosting":
			_label(vb, "Hosting — waiting for a player to join…", 30, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
			var ips: Array = Net.local_ips()
			if not ips.is_empty():
				_label(vb, "Your IP: %s" % ", ".join(ips), 24, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
			_spacer(vb, 6)
			_button(vb, "Cancel", func(): Net.leave(); _state = "browse"; Net.start_discovery(); _build(), false)
		"connecting":
			_label(vb, "Connecting…", 30, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		"connected":
			_label(vb, "Connected! Starting…", 30, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		_:
			_button(vb, "HOST A GAME", _host, true)
			_spacer(vb, 8)
			_label(vb, "NEARBY GAMES", 24, TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
			var hosts: Array = Net._hosts.values()
			if hosts.is_empty():
				_label(vb, "Searching…  (the other device must be hosting)", 22, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
			for h in hosts:
				_host_row(vb, h)
			if _status != "":
				_spacer(vb, 4)
				_label(vb, _status, 22, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
			# Manual IP fallback (for tricky networks / debugging).
			_spacer(vb, 8)
			_label(vb, "OR ENTER HOST IP", 24, TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var ip_field := LineEdit.new()
			ip_field.placeholder_text = "192.168.x.x"
			ip_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ip_field.custom_minimum_size = Vector2(0, 66)
			ip_field.add_theme_font_size_override("font_size", 28)
			row.add_child(ip_field)
			var cbtn := _button(row, "Connect", func(): _manual_connect(ip_field.text), false)
			cbtn.size_flags_horizontal = Control.SIZE_SHRINK_END
			cbtn.custom_minimum_size = Vector2(180, 66)
			vb.add_child(row)

	_spacer(vb, 10)
	_button(vb, "Back", close, false)


func _host() -> void:
	Audio.play("ui_click")
	var pname: String = str(GameState.names[0]) if GameState.names.size() > 0 else "Player"
	if Net.host_game(pname):
		_state = "hosting"
	else:
		_status = "Couldn't host (port busy?)."
	_build()


func _manual_connect(ip: String) -> void:
	ip = ip.strip_edges()
	if ip == "":
		return
	Audio.play("ui_click")
	if Net.join(ip, Net.GAME_PORT):
		_state = "connecting"
		_start_connect_timeout()
	else:
		_status = "Couldn't start connection."
	_build()


## Don't spin on "Connecting…" forever — give up after 8s with a hint.
func _start_connect_timeout() -> void:
	await get_tree().create_timer(8.0).timeout
	if _state == "connecting":
		Net.leave()
		_state = "browse"
		_status = "Couldn't connect. Same WiFi? Try disabling the firewall / router 'AP isolation'."
		Net.start_discovery()
		_build()


func _host_row(parent: Node, h: Dictionary) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "  🎱  %s's Game        Join" % str(h["name"])
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_stylebox_override("normal", _bstyle(BTN))
	b.add_theme_stylebox_override("hover", _bstyle(BTN.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _bstyle(BTN.lightened(0.1)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.pressed.connect(func():
		Audio.play("ui_click")
		Net.opponent_name = str(h["name"])
		if Net.join(str(h["ip"]), int(h["port"])):
			_state = "connecting"
			_start_connect_timeout()
		else:
			_status = "Couldn't connect."
		_build())
	parent.add_child(b)


# ---------------------------------------------------------------- Widgets
func _label(parent: Node, text: String, size: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _spacer(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


func _bstyle(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(14)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _button(parent: Node, text: String, handler: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 32)
	var base := ACCENT if primary else BTN
	b.add_theme_stylebox_override("normal", _bstyle(base))
	b.add_theme_stylebox_override("hover", _bstyle(base.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _bstyle(base.lightened(0.1)))
	var fc := Color(0.1, 0.1, 0.12) if primary else TEXT
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.pressed.connect(func(): Audio.play("ui_click"); handler.call())
	parent.add_child(b)
	return b
