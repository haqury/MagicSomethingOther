extends Node

enum SessionMode { MENU, SINGLEPLAYER, HOST, CLIENT }

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
const MAX_CLIENTS := 7

const PREP_SCENE := "res://scenes/prep/prep.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"
const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

signal session_started(mode: SessionMode)
signal session_failed(reason: String)
signal connection_failed()
signal server_disconnected()
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal loadout_accepted(peer_id: int)
signal loadout_rejected()
signal match_preparation_changed()
signal map_changed(map_index: int)

var mode: SessionMode = SessionMode.MENU
var pending_peer_ids: Array[int] = []
var selected_map_index: int = 0
var _accepted_loadouts: Dictionary = {}
var _match_started: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_singleplayer() -> void:
	if mode != SessionMode.MENU:
		return
	_reset_session_state()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = SessionMode.SINGLEPLAYER
	pending_peer_ids = [1]
	_accepted_loadouts.clear()
	_match_started = false
	get_tree().change_scene_to_file(PREP_SCENE)
	session_started.emit(mode)


func host_game(port: int = DEFAULT_PORT) -> void:
	if mode != SessionMode.MENU:
		return
	_reset_session_state()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		mode = SessionMode.MENU
		session_failed.emit("port_busy")
		return
	multiplayer.multiplayer_peer = peer
	mode = SessionMode.HOST
	pending_peer_ids = [1]
	_accepted_loadouts.clear()
	_match_started = false
	get_tree().change_scene_to_file(PREP_SCENE)
	session_started.emit(mode)


func join_game(address: String, port: int = DEFAULT_PORT) -> void:
	if mode != SessionMode.MENU:
		return
	var addr := address.strip_edges()
	if addr.is_empty():
		session_failed.emit("bad_address")
		return
	_reset_session_state()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, port)
	if err != OK:
		mode = SessionMode.MENU
		session_failed.emit("bad_address")
		return
	multiplayer.multiplayer_peer = peer
	mode = SessionMode.CLIENT
	_accepted_loadouts.clear()
	_match_started = false


func leave_session() -> void:
	_reset_session_state()
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != MENU_SCENE:
		get_tree().change_scene_to_file(MENU_SCENE)


func get_selected_map() -> int:
	return selected_map_index


func set_selected_map(map_index: int) -> void:
	if not multiplayer.is_server():
		return
	map_index = clampi(map_index, 0, MapCatalog.map_count() - 1)
	if selected_map_index == map_index:
		return
	selected_map_index = map_index
	if not _accepted_loadouts.is_empty():
		_accepted_loadouts.clear()
		match_preparation_changed.emit()
	map_changed.emit(map_index)
	_sync_map.rpc(map_index)


@rpc("authority", "call_local", "reliable")
func _sync_map(map_index: int) -> void:
	selected_map_index = clampi(map_index, 0, MapCatalog.map_count() - 1)
	map_changed.emit(selected_map_index)


func _reset_session_state() -> void:
	_accepted_loadouts.clear()
	_match_started = false
	selected_map_index = 0
	pending_peer_ids.clear()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = SessionMode.MENU


func consume_pending_peers() -> Array[int]:
	var out := pending_peer_ids.duplicate()
	pending_peer_ids.clear()
	return out


func take_loadout(peer_id: int) -> Loadout:
	return _accepted_loadouts.get(peer_id) as Loadout


func is_prep_phase() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == PREP_SCENE


func has_accepted_loadout(peer_id: int) -> bool:
	return _accepted_loadouts.has(peer_id)


func clear_accepted_loadout(peer_id: int) -> void:
	if not _accepted_loadouts.erase(peer_id):
		return
	match_preparation_changed.emit()


## Сброс «готовности» после правки черновика (сервер хранит accepted).
func revoke_local_loadout_acceptance() -> void:
	if mode == SessionMode.MENU:
		return
	if not has_accepted_loadout(multiplayer.get_unique_id()):
		return
	if multiplayer.is_server():
		clear_accepted_loadout(multiplayer.get_unique_id())
	else:
		_revoke_loadout_acceptance.rpc_id(1)


@rpc("any_peer", "reliable")
func _revoke_loadout_acceptance() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	clear_accepted_loadout(peer_id)


func all_peers_ready() -> bool:
	if not multiplayer.is_server():
		return false
	var ids: Array[int] = [1]
	for id in multiplayer.get_peers():
		ids.append(id)
	for id in ids:
		if not _accepted_loadouts.has(id):
			return false
	return true


func start_match() -> void:
	if not multiplayer.is_server() or _match_started:
		return
	if not all_peers_ready():
		return
	_match_started = true
	begin_match.rpc()


func submit_loadout_from_local(
	stat_ranks: PackedInt32Array,
	elements: PackedInt32Array,
	forms: PackedInt32Array,
	spell_ranks: PackedInt32Array
) -> void:
	if multiplayer.is_server():
		_validate_and_store(multiplayer.get_unique_id(), stat_ranks, elements, forms, spell_ranks)
	else:
		submit_loadout.rpc_id(1, stat_ranks, elements, forms, spell_ranks)


@rpc("any_peer", "call_local", "reliable")
func submit_loadout(
	stat_ranks: PackedInt32Array,
	elements: PackedInt32Array,
	forms: PackedInt32Array,
	spell_ranks: PackedInt32Array
) -> void:
	if not multiplayer.is_server() or _match_started:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if _accepted_loadouts.has(sender):
		return
	_validate_and_store(sender, stat_ranks, elements, forms, spell_ranks)


func _validate_and_store(
	peer_id: int,
	stat_ranks: PackedInt32Array,
	elements: PackedInt32Array,
	forms: PackedInt32Array,
	spell_ranks: PackedInt32Array
) -> void:
	var loadout := PrepRules.build_loadout_from_ranks(stat_ranks, elements, forms, spell_ranks)
	if loadout == null:
		if peer_id == multiplayer.get_unique_id():
			loadout_rejected.emit()
		else:
			_notify_rejected.rpc_id(peer_id)
		return
	_accepted_loadouts[peer_id] = loadout
	loadout_accepted.emit(peer_id)
	match_preparation_changed.emit()
	if peer_id != multiplayer.get_unique_id():
		_notify_accepted.rpc_id(peer_id)


@rpc("authority", "reliable")
func _notify_accepted() -> void:
	loadout_accepted.emit(multiplayer.get_unique_id())
	match_preparation_changed.emit()


@rpc("authority", "reliable")
func _notify_rejected() -> void:
	loadout_rejected.emit()


@rpc("authority", "call_local", "reliable")
func begin_match() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if not is_prep_phase():
		multiplayer.multiplayer_peer.disconnect_peer(id, false)
		return
	pending_peer_ids.append(id)
	_sync_map.rpc_id(id, selected_map_index)
	player_joined.emit(id)
	match_preparation_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		_accepted_loadouts.erase(id)
		player_left.emit(id)
		match_preparation_changed.emit()


func _on_connected_to_server() -> void:
	get_tree().change_scene_to_file(PREP_SCENE)
	session_started.emit(SessionMode.CLIENT)


func _on_connection_failed() -> void:
	leave_session()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave_session()
	server_disconnected.emit()