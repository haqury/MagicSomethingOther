extends Node2D

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene

@onready var map_container: Node2D = $MapContainer
@onready var entities: Node2D = $Entities

var _map: GameMap


func _ready() -> void:
	_load_map()
	var terrain := $TerrainGrid as TerrainGrid
	if _map != null and terrain != null:
		terrain.bind(_map)
	NetworkManager.player_left.connect(_on_player_left)
	if not multiplayer.is_server():
		return
	for peer_id in NetworkManager.consume_pending_peers():
		spawn_player(peer_id)
	NetworkManager.player_joined.connect(spawn_player)
	$WaveDirector.start(entities, enemy_scene)


func _load_map() -> void:
	for child in map_container.get_children():
		child.queue_free()
	var scene_path := MapCatalog.scene_path(NetworkManager.get_selected_map())
	var packed: PackedScene = load(scene_path) as PackedScene
	_map = packed.instantiate() as GameMap
	map_container.add_child(_map)


func _on_player_left(peer_id: int) -> void:
	var node := entities.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()


func spawn_player(peer_id: int) -> void:
	if entities.get_node_or_null(str(peer_id)):
		return
	var loadout := NetworkManager.take_loadout(peer_id)
	if loadout == null:
		return
	var player: Player = player_scene.instantiate() as Player
	player.name = str(peer_id)
	player.set_multiplayer_authority(1)
	player.stats = loadout.stats
	player.spell_lmb = loadout.spell_lmb
	player.spell_rmb = loadout.spell_rmb
	player.spell_mmb = loadout.spell_mmb
	if _map != null:
		player.global_position = _map.player_spawn_for(peer_id)
	else:
		player.global_position = Vector2((peer_id - 1) * 80, 0)
	entities.add_child(player)
	var terrain := $TerrainGrid as TerrainGrid
	if terrain != null:
		terrain.sync_to(peer_id)
	var waves := $WaveDirector
	if waves != null and waves.has_method("sync_to"):
		waves.sync_to(peer_id)