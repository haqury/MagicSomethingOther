class_name MobSpawnMarker
extends Node2D

@export var spawn_count: int = 3
@export var spawn_radius: float = 48.0


func _ready() -> void:
	add_to_group("mob_spawns")