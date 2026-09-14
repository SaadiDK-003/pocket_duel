extends Node

## Autoload ("Net"). LAN multiplayer for two players on the same WiFi.
##
## Host: opens an ENet server AND broadcasts a small UDP "here I am" packet so
##       nearby phones can discover it without typing an IP.
## Guest: listens for those broadcasts (a live list of nearby games) and connects
##        to the chosen host by IP.
##
## The host is the authority: it runs the physics/rules and streams state to the
## guest; the guest sends its shots to the host (wired in the game scene).

signal hosts_updated(hosts)          # Array of {name, ip, port} (guest side).
signal server_connected()            # Guest: connected to a host.
signal connection_failed()           # Guest: could not connect.
signal player_connected(id)          # Host: a guest joined.
signal link_lost()                   # Either side: the other left / dropped.

const GAME_PORT: int = 7654
const DISCOVERY_PORT: int = 7655
const MAGIC: String = "PD1"

var is_host: bool = false
var is_networked: bool = false
var peer: ENetMultiplayerPeer = null
var host_name: String = "Player"
var my_index: int = 0                # 0 = host (player 1), 1 = guest (player 2).
var opponent_name: String = "Opponent"

var _bcast: PacketPeerUDP = null     # host: outgoing broadcast socket
var _listen: PacketPeerUDP = null    # guest: incoming discovery socket
var _bcast_t: float = 0.0
var _hosts: Dictionary = {}          # ip -> {name, ip, port, seen}
var _uid: int = 0


func _ready() -> void:
	_uid = randi()
	set_process(false)


# ---------------------------------------------------------------- Hosting
func host_game(pname: String) -> bool:
	leave()
	host_name = pname if pname.strip_edges() != "" else "Player"
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(GAME_PORT, 3) != OK:
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	is_host = true
	is_networked = true
	my_index = 0
	_bcast = PacketPeerUDP.new()
	_bcast.set_broadcast_enabled(true)
	_bcast.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_bcast_t = 0.0
	set_process(true)
	return true


func _on_peer_connected(id: int) -> void:
	# A guest joined — stop advertising (only one opponent).
	if _bcast:
		_bcast.close()
		_bcast = null
	player_connected.emit(id)


func _on_peer_disconnected(_id: int) -> void:
	link_lost.emit()


# ---------------------------------------------------------------- Discovery / joining
func start_discovery() -> bool:
	_hosts.clear()
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null
		return false
	set_process(true)
	return true


func stop_discovery() -> void:
	if _listen:
		_listen.close()
		_listen = null


func join(ip: String, port: int) -> bool:
	stop_discovery()
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, port) != OK:
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	is_host = false
	is_networked = true
	my_index = 1
	return true


func _on_connected_to_server() -> void:
	server_connected.emit()


func _on_connection_failed() -> void:
	connection_failed.emit()
	_reset_peer()


func _on_server_disconnected() -> void:
	link_lost.emit()
	_reset_peer()


# ---------------------------------------------------------------- Process
func _process(delta: float) -> void:
	if is_host and _bcast:
		_bcast_t -= delta
		if _bcast_t <= 0.0:
			_bcast_t = 1.0
			var pkt := JSON.stringify({"m": MAGIC, "n": host_name, "p": GAME_PORT, "u": _uid})
			_bcast.put_packet(pkt.to_utf8_buffer())
	if _listen:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var data := _listen.get_packet()
			var ip := _listen.get_packet_ip()
			var msg = JSON.parse_string(data.get_string_from_utf8())
			if typeof(msg) == TYPE_DICTIONARY and msg.get("m") == MAGIC and int(msg.get("u", 0)) != _uid:
				_hosts[ip] = {"name": str(msg.get("n", "Game")), "ip": ip, "port": int(msg.get("p", GAME_PORT)), "seen": Time.get_ticks_msec()}
				changed = true
		var now := Time.get_ticks_msec()
		for ip in _hosts.keys():
			if now - int(_hosts[ip]["seen"]) > 3000:
				_hosts.erase(ip)
				changed = true
		if changed:
			hosts_updated.emit(_hosts.values())


# ---------------------------------------------------------------- Teardown
func leave() -> void:
	_reset_peer()
	stop_discovery()
	if _bcast:
		_bcast.close()
		_bcast = null
	is_host = false
	is_networked = false
	set_process(false)


func _reset_peer() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
