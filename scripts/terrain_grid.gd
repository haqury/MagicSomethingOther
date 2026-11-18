class_name TerrainGrid
extends Node2D

const CELL := 56.0
const LIFT := 16.0
const STEP_UP_SPEED := 0.85
const FLOOR := -2
const CEILING := 3
const FLAT := 0
const DITCH := -1
const WATER := -2

const _CARDINAL: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

@export var tile_scene: PackedScene

var _heights: Dictionary = {}
var _tiles: Dictionary = {}
var _bounds := Rect2(-100000, -100000, 200000, 200000)


func _ready() -> void:
	add_to_group("terrain")
	set_multiplayer_authority(1)


func bind(map: Node2D) -> void:
	var ground := map.get_node_or_null("Ground") as Polygon2D
	if ground == null:
		return
	var poly := ground.polygon
	if poly.is_empty():
		return
	var xform := ground.global_transform
	var min_point := xform * poly[0]
	var max_point := min_point
	for point in poly:
		var world: Vector2 = xform * point
		min_point = min_point.min(world)
		max_point = max_point.max(world)
	_bounds = Rect2(min_point, max_point - min_point).grow(1.0)


func height_at(world: Vector2) -> int:
	return _height(_cell_of(world))


func visual_lift(world: Vector2) -> float:
	return float(height_at(world)) * LIFT


## Вода имеет высоту −2. Отрицательный z_index уезжает под полигон карты.
func draw_order(world: Vector2) -> int:
	return height_at(world) - FLOOR


func speed_scale_at(world: Vector2) -> float:
	match height_at(world):
		DITCH:
			return 0.75
		WATER:
			return 0.5
		_:
			return 1.0


## Рельеф: поднять клетку на 1, не выше потолка. Стену не создаёт.
func raise(world: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var cell := _cell_of(world)
	if not _inside(cell):
		return
	var height := _height(cell)
	if height >= CEILING:
		return
	_publish(cell, height + 1)


## Земляная зона: опустить клетку на 1, не ниже воды.
func lower(world: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var cell := _cell_of(world)
	if not _inside(cell):
		return
	var height := _height(cell)
	if height <= FLOOR:
		return
	_publish(cell, height - 1)


## Обрыв гасит шаг поперёк кромки. Шаг вверх на 1 замедляется.
func clip_velocity(from: Vector2, velocity: Vector2, delta: float) -> Vector2:
	if velocity.length_squared() < 0.001 or delta <= 0.0:
		return velocity
	var origin := _cell_of(from)
	var ahead := from + velocity * delta
	var dest := _cell_of(ahead)
	if dest == origin or _can_step(origin, dest):
		return velocity * _climb_scale(origin, dest)
	var along_x := Vector2(velocity.x, 0.0)
	var along_y := Vector2(0.0, velocity.y)
	var x_cell := _cell_of(from + along_x * delta)
	var y_cell := _cell_of(from + along_y * delta)
	var allow_x := x_cell == origin or _can_step(origin, x_cell)
	var allow_y := y_cell == origin or _can_step(origin, y_cell)
	if allow_x and not allow_y:
		return along_x * _climb_scale(origin, x_cell)
	if allow_y and not allow_x:
		return along_y * _climb_scale(origin, y_cell)
	if allow_x and allow_y:
		if absf(velocity.x) >= absf(velocity.y):
			return along_x * _climb_scale(origin, x_cell)
		return along_y * _climb_scale(origin, y_cell)
	return Vector2.ZERO


## Следующая точка обхода по шагам в 1. Нет пути — Vector2.INF.
func find_step(from_world: Vector2, goal_world: Vector2) -> Vector2:
	var start := _cell_of(from_world)
	var goal := _cell_of(goal_world)
	if start == goal:
		return goal_world
	var queue: Array[Vector2i] = [start]
	var came: Dictionary = {}
	var seen := {start: true}
	var found := false
	var guard := 0
	while not queue.is_empty() and guard < 900:
		guard += 1
		var current: Vector2i = queue.pop_front()
		if current == goal:
			found = true
			break
		for dir in _CARDINAL:
			var nxt: Vector2i = current + dir
			if seen.has(nxt) or not _inside(nxt) or not _can_step(current, nxt):
				continue
			seen[nxt] = true
			came[nxt] = current
			queue.append(nxt)
	if not found or not came.has(goal):
		return Vector2.INF
	var step: Vector2i = goal
	while came.has(step) and came[step] != start:
		step = came[step]
	return _center(step)


func _can_step(a: Vector2i, b: Vector2i) -> bool:
	return absi(_height(a) - _height(b)) <= 1


func _climb_scale(a: Vector2i, b: Vector2i) -> float:
	if _height(b) - _height(a) == 1:
		return STEP_UP_SPEED
	return 1.0


func _publish(cell: Vector2i, height: int) -> void:
	_apply_cell.rpc(cell.x, cell.y, height)


@rpc("authority", "call_local", "reliable")
func _apply_cell(cx: int, cy: int, height: int) -> void:
	var cell := Vector2i(cx, cy)
	if height == FLAT:
		_heights.erase(cell)
	else:
		_heights[cell] = height
	_refresh_tile(cell)
	for dir in _CARDINAL:
		_refresh_tile(cell + dir)


func _refresh_tile(cell: Vector2i) -> void:
	if not _inside(cell):
		return
	var height := _height(cell)
	var drops := _drops(cell)
	var tile: Node2D = _tiles.get(cell) as Node2D
	if height == FLAT and not _has_drop(drops):
		if tile != null:
			tile.queue_free()
			_tiles.erase(cell)
		return
	if tile == null:
		if tile_scene == null:
			return
		tile = tile_scene.instantiate() as Node2D
		tile.name = "Cell_%d_%d" % [cell.x, cell.y]
		add_child(tile)
		_tiles[cell] = tile
	tile.position = _center(cell) + Vector2(0.0, -float(height) * LIFT)
	tile.z_index = height - FLOOR
	if tile.has_method("show_height"):
		tile.show_height(height)
	if tile.has_method("show_edges"):
		tile.show_edges(drops)


func _drops(cell: Vector2i) -> Array[int]:
	var height := _height(cell)
	var drops: Array[int] = []
	for dir in _CARDINAL:
		var neighbor := cell + dir
		if not _inside(neighbor):
			drops.append(0)
			continue
		drops.append(maxi(height - _height(neighbor), 0))
	return drops


func _has_drop(drops: Array[int]) -> bool:
	for drop in drops:
		if drop >= 1:
			return true
	return false


func _height(cell: Vector2i) -> int:
	return int(_heights.get(cell, FLAT))


func _cell_of(world: Vector2) -> Vector2i:
	return Vector2i(roundi(world.x / CELL), roundi(world.y / CELL))


func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL, cell.y * CELL)


func _inside(cell: Vector2i) -> bool:
	return _bounds.has_point(_center(cell))


func sync_to(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id == multiplayer.get_unique_id():
		return
	for cell in _heights:
		var key: Vector2i = cell
		_apply_cell.rpc_id(peer_id, key.x, key.y, int(_heights[cell]))
