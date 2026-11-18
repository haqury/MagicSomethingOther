class_name MapCatalog
extends RefCounted

const MAPS: Array[Dictionary] = [
	{
		"id": 0,
		"name_key": "map.meadow",
		"scene": "res://scenes/maps/meadow.tscn",
		"preview": "res://assets/ui/maps/meadow.png",
	},
	{
		"id": 1,
		"name_key": "map.ruins",
		"scene": "res://scenes/maps/ruins.tscn",
		"preview": "res://assets/ui/maps/ruins.png",
	},
	{
		"id": 2,
		"name_key": "map.arena",
		"scene": "res://scenes/maps/arena.tscn",
		"preview": "res://assets/ui/maps/arena.png",
	},
]


static func map_count() -> int:
	return MAPS.size()


static func scene_path(map_index: int) -> String:
	if map_index < 0 or map_index >= MAPS.size():
		return MAPS[0]["scene"]
	return MAPS[map_index]["scene"]


static func name_key(map_index: int) -> String:
	if map_index < 0 or map_index >= MAPS.size():
		return MAPS[0]["name_key"]
	return MAPS[map_index]["name_key"]


static func preview_path(map_index: int) -> String:
	if map_index < 0 or map_index >= MAPS.size():
		return MAPS[0]["preview"]
	return MAPS[map_index]["preview"]