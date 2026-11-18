class_name GameMap
extends Node2D

@onready var _player_spawns: Node2D = $PlayerSpawns


func player_spawn_for(peer_id: int) -> Vector2:
	var marker := _player_spawns.get_node_or_null(str(peer_id))
	if marker is Node2D:
		return global_position + (marker as Node2D).position
	var fallback := _player_spawns.get_node_or_null("1")
	if fallback is Node2D:
		return global_position + (fallback as Node2D).position + Vector2((peer_id - 1) * 72, 0)
	return global_position + Vector2((peer_id - 1) * 72, 0)