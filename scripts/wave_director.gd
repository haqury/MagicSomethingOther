extends Node

const BUILD_SECONDS := 15.0

var _entities: Node2D
var _enemy_scene: PackedScene
var _wave := 0
var _pause := 0.0
var _building := true
var _defeat := false
var _sync_wait := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_multiplayer_authority(1)
	_rng.randomize()


func start(entities: Node2D, enemy_scene: PackedScene) -> void:
	if not multiplayer.is_server():
		return
	_entities = entities
	_enemy_scene = enemy_scene
	_wave = 0
	_pause = BUILD_SECONDS
	_building = true
	_defeat = false
	_publish()


func _process(delta: float) -> void:
	if not multiplayer.is_server() or _entities == null:
		return
	if _defeat:
		return
	if _all_players_down():
		_defeat = true
		_building = false
		_publish()
		return
	if _building:
		_pause = maxf(_pause - delta, 0.0)
		if _pause <= 0.0:
			_begin_wave()
	elif _living_enemies() == 0:
		_building = true
		_pause = BUILD_SECONDS
	_sync_wait += delta
	if _sync_wait >= 0.25:
		_sync_wait = 0.0
		_publish()


func _begin_wave() -> void:
	_wave += 1
	_building = false
	_pause = 0.0
	if _enemy_scene == null:
		_publish()
		return
	# Число растёт с номером волны и с числом живых игроков, не больше 16 с маркера.
	var players := maxi(_living_players(), 1)
	for marker in get_tree().get_nodes_in_group("mob_spawns"):
		if marker is MobSpawnMarker:
			var spawn: MobSpawnMarker = marker as MobSpawnMarker
			var count := spawn.spawn_count + (_wave - 1) + maxi(players - 1, 0)
			count = mini(count, 16)
			for _i in count:
				var enemy := _enemy_scene.instantiate() as Node2D
				var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * spawn.spawn_radius
				enemy.global_position = spawn.global_position + offset
				enemy.set_multiplayer_authority(1)
				enemy.set("kind", _rng.randi_range(0, 2))
				_entities.add_child(enemy)
	_publish()


func _living_enemies() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if float(node.get("hp")) > 0.0:
			count += 1
	return count


func _living_players() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("players"):
		if float(node.get("current_hp")) > 0.0:
			count += 1
	return count


func _all_players_down() -> bool:
	var any := false
	for node in get_tree().get_nodes_in_group("players"):
		any = true
		if float(node.get("current_hp")) > 0.0:
			return false
	return any


func _publish() -> void:
	var enemies := 0 if _building or _defeat else _living_enemies()
	_sync_wave.rpc(_wave, enemies, _pause, _building, _defeat)


func sync_to(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id == multiplayer.get_unique_id():
		return
	var enemies := 0 if _building or _defeat else _living_enemies()
	_sync_wave.rpc_id(peer_id, _wave, enemies, _pause, _building, _defeat)


@rpc("authority", "call_local", "reliable")
func _sync_wave(index: int, enemies: int, pause_left: float, building: bool, defeat: bool) -> void:
	var hud := get_parent().get_node_or_null("Hud")
	if hud != null and hud.has_method("show_wave"):
		hud.show_wave(index, enemies, pause_left, building, defeat)
