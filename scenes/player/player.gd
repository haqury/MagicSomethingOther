class_name Player
extends CharacterBody2D

signal died

@export var stats: PlayerStats
@export var spell_lmb: SpellData
@export var spell_rmb: SpellData
@export var spell_mmb: SpellData

var current_hp: float = 0.0
var current_stamina: float = 100.0
var sprint_locked: bool = false

var essence: int = 0
var max_hp: float = 100.0
var move_speed: float = 180.0
var max_stamina: float = 100.0
var dash_multiplier: float = 1.8
var vision_zoom: float = 1.0

var _server_move := Vector2.ZERO
var _server_sprint := false
var _server_aim := Vector2.ZERO

@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("players")
	if multiplayer.is_server() and stats != null:
		apply_stats_from_resource()
	var local := is_local_owner()
	_camera.enabled = local
	if local:
		_camera.make_current()
	var body := $Body as Node2D
	if body:
		_body_rest = body.position


func apply_stats_from_resource() -> void:
	if stats == null:
		return
	current_hp = stats.max_hp
	current_stamina = stats.max_stamina
	essence = stats.essence
	max_hp = stats.max_hp
	move_speed = stats.move_speed
	max_stamina = stats.max_stamina
	dash_multiplier = stats.dash_multiplier
	vision_zoom = stats.vision_zoom
	_apply_solidity()


var _walk_origin := Vector2.ZERO
var _walk_ready := false
## Смещение спрайта над центром коллизии. Родитель крутится к мыши, спрайт держим на месте.
var _body_rest := Vector2.ZERO

const _OCTANTS: PackedStringArray = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const _WALL_SIDE := 56.0


func is_local_owner() -> bool:
	return name.to_int() == multiplayer.get_unique_id()


func _process(delta: float) -> void:
	var body := $Body as AnimatedSprite2D
	if body == null:
		return
	# Родитель крутится к прицелу. Спрайт остаётся вертикальным и не орбитирует вокруг ног.
	body.rotation = -rotation
	var lift := 0.0
	var grid := _terrain()
	if grid != null:
		lift = grid.visual_lift(global_position)
		z_index = grid.draw_order(global_position)
	body.position = (_body_rest + Vector2(0.0, -lift)).rotated(-rotation)
	if not _walk_ready:
		_walk_origin = global_position
		_walk_ready = true
		return
	var step := global_position - _walk_origin
	_walk_origin = global_position
	var moving := step.length() > 10.0 * delta
	var aim := step if moving else Vector2.RIGHT.rotated(rotation)
	if aim.length_squared() < 0.01:
		aim = Vector2.DOWN
	var facing := _octant(aim)
	var clip := "%s_%s" % ["walk" if moving else "idle", facing]
	if body.sprite_frames == null or not body.sprite_frames.has_animation(clip):
		clip = "walk_%s" % facing
		if body.sprite_frames == null or not body.sprite_frames.has_animation(clip):
			return
	if moving:
		if body.animation != clip or not body.is_playing():
			body.play(clip)
		body.speed_scale = clampf(step.length() / maxf(delta, 0.001) / 120.0, 0.75, 1.8)
	else:
		if body.animation != clip:
			body.animation = clip
		body.frame = 0
		body.pause()


func _octant(direction: Vector2) -> String:
	var sector := int(round(direction.angle() / (PI / 4.0)))
	return _OCTANTS[posmod(sector, 8)]


func _physics_process(delta: float) -> void:
	if is_local_owner():
		_gather_owner_input()
	if multiplayer.is_server():
		_server_physics(delta)
	if is_local_owner():
		var z := 1.0 / maxf(vision_zoom, 0.5)
		_camera.zoom = _camera.zoom.lerp(Vector2(z, z), 1.0 - exp(-6.0 * delta))


func _gather_owner_input() -> void:
	var move := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var sprint := Input.is_action_pressed(&"sprint")
	var aim := get_global_mouse_position()
	var cast_l := Input.is_action_just_pressed(&"cast_lmb")
	var cast_r := Input.is_action_just_pressed(&"cast_rmb")
	var cast_m := Input.is_action_just_pressed(&"cast_mmb")
	if multiplayer.is_server():
		_receive_input(move, sprint, aim)
		if cast_l:
			_server_cast(0, aim)
		if cast_r:
			_server_cast(1, aim)
		if cast_m:
			_server_cast(2, aim)
	else:
		submit_input.rpc_id(1, move, sprint, aim)
		if cast_l:
			request_cast.rpc_id(1, 0, aim)
		if cast_r:
			request_cast.rpc_id(1, 1, aim)
		if cast_m:
			request_cast.rpc_id(1, 2, aim)


@rpc("any_peer", "unreliable_ordered")
func submit_input(move: Vector2, sprint: bool, aim: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != name.to_int():
		return
	_receive_input(move, sprint, aim)


@rpc("any_peer", "reliable")
func request_cast(slot: int, aim: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != name.to_int():
		return
	_server_cast(slot, aim)


func _receive_input(move: Vector2, sprint: bool, aim: Vector2) -> void:
	_server_move = move
	if _server_move.length() > 1.0:
		_server_move = _server_move.normalized()
	_server_sprint = sprint
	_server_aim = aim


func _server_physics(delta: float) -> void:
	if current_hp <= 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var multiplier := 1.0
	if _server_sprint and current_stamina > 0.0 and not sprint_locked:
		multiplier = dash_multiplier
		current_stamina = maxf(current_stamina - 30.0 * delta, 0.0)
		if current_stamina <= 0.0:
			sprint_locked = true
	elif not _server_sprint:
		sprint_locked = false
		if current_stamina < max_stamina:
			current_stamina = minf(current_stamina + 20.0 * delta, max_stamina)
	velocity = _server_move * move_speed * multiplier * _ground_speed()
	var grid := _terrain()
	if grid != null:
		velocity = grid.clip_velocity(global_position, velocity, delta)
	move_and_slide()
	var look_at_pos := _server_aim
	var to_aim := look_at_pos - global_position
	if to_aim.length() > 1.0:
		rotation = to_aim.angle()


func take_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if amount <= 0.0 or current_hp <= 0.0:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	if current_hp <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if amount <= 0.0 or current_hp <= 0.0:
		return
	current_hp = minf(current_hp + amount, max_hp)


func _server_cast(slot: int, aim: Vector2) -> void:
	if current_hp <= 0.0:
		return
	var data := _spell_for_slot(slot)
	if data == null:
		return
	match data.form:
		SpellData.Form.PROJECTILE:
			_cast_projectile(data, aim)
		SpellData.Form.BEAM:
			_cast_beam(data, aim)
		SpellData.Form.AREA:
			_cast_area(data, aim)
		SpellData.Form.WALL:
			_cast_wall(data, aim)
		SpellData.Form.MINE:
			_cast_mine(data, aim)
		SpellData.Form.SELF:
			_cast_self(data)
		SpellData.Form.AROUND:
			_cast_around(data)
		SpellData.Form.RELIEF:
			_cast_relief(data, aim)


func _spell_for_slot(slot: int) -> SpellData:
	match slot:
		0: return spell_lmb
		1: return spell_rmb
		2: return spell_mmb
	return null


func _entities() -> Node2D:
	var game := get_tree().current_scene as Node2D
	return game.get_node("Entities") as Node2D


func _spawn_spell_scene(data: SpellData, at: Vector2, rot: float, configure: Callable = Callable()) -> Node2D:
	if data.scene == null:
		return null
	var node := data.scene.instantiate() as Node2D
	node.global_position = at
	node.rotation = rot
	node.scale = Vector2(data.area, data.area)
	node.modulate = SpellUtil.element_color(data.element)
	node.set_multiplayer_authority(1)
	_entities().add_child(node)
	if configure.is_valid():
		configure.call(node)
	return node


func _cast_projectile(data: SpellData, aim: Vector2) -> void:
	var dir := SpellUtil.aim_direction(global_position, aim, rotation)
	_spawn_spell_scene(data, global_position, dir.angle(), func(n): n.setup(self, data, dir))


func _cast_beam(data: SpellData, aim: Vector2) -> void:
	var dir := SpellUtil.aim_direction(global_position, aim, rotation)
	var space := get_world_2d().direct_space_state
	var to := global_position + dir * data.cast_range
	var query := PhysicsRayQueryParameters2D.create(global_position, to)
	query.collision_mask = SpellUtil.combat_mask(data.element)
	var hit := space.intersect_ray(query)
	var end := to
	if hit:
		end = hit.position
		if hit.collider is Node:
			var collider := hit.collider as Node
			if _payload_applicable(collider, data):
				SpellUtil.apply_payload(self, collider, data)
	_spawn_spell_scene(data, global_position, dir.angle(), func(n): n.setup_line(global_position, end))


func _cast_area(data: SpellData, aim: Vector2) -> void:
	if data.cast_range <= 0.0:
		return
	var at := SpellUtil.clamp_aim(global_position, aim, data.cast_range)
	if data.element == SpellData.Element.EARTH:
		var grid := _terrain()
		if grid != null:
			grid.lower(at)
		return
	_spawn_spell_scene(data, at, 0.0, func(n): n.setup(self, data))


func _cast_relief(data: SpellData, aim: Vector2) -> void:
	if data.element != SpellData.Element.EARTH or data.cast_range <= 0.0:
		return
	var at := SpellUtil.clamp_aim(global_position, aim, data.cast_range)
	var grid := _terrain()
	if grid != null:
		grid.raise(at)


func _cast_wall(data: SpellData, aim: Vector2) -> void:
	if data.cast_range <= 0.0:
		return
	var at := SpellUtil.clamp_aim(global_position, aim, data.cast_range)
	var dir := SpellUtil.aim_direction(global_position, aim, rotation)
	var rot := dir.angle() + PI * 0.5
	var blocks := data.element == SpellData.Element.EARTH or data.element == SpellData.Element.ICE
	if blocks:
		# Квадрат на сетке: соседняя клетка встаёт впритык, та же клетка занята.
		var side := _WALL_SIDE * maxf(data.area, 0.01)
		at = _snap_wall_cell(at, side)
		if _solid_wall_overlaps(at, side / _WALL_SIDE):
			return
		rot = 0.0
	_spawn_spell_scene(data, at, rot, func(n): n.setup(self, data))


func _snap_wall_cell(aim: Vector2, side: float) -> Vector2:
	var cell := Vector2(snappedf(aim.x, side), snappedf(aim.y, side))
	var area := side / _WALL_SIDE
	if not _solid_wall_overlaps(cell, area):
		return cell
	var delta := aim - cell
	if absf(delta.x) >= absf(delta.y):
		cell.x += side if delta.x >= 0.0 else -side
	else:
		cell.y += side if delta.y >= 0.0 else -side
	return cell


func _solid_wall_overlaps(at: Vector2, area: float) -> bool:
	var shape := RectangleShape2D.new()
	# Уже клетки, чтобы стык соседних блоков не считался наложением.
	shape.size = Vector2(40, 40)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at).scaled_local(Vector2(area, area))
	query.collision_mask = SpellUtil.layer_world()
	query.collide_with_areas = false
	var space := get_world_2d().direct_space_state
	for hit in space.intersect_shape(query, 32):
		var collider: Object = hit.get("collider")
		if collider is Node and (collider as Node).is_in_group("solid_walls"):
			return true
	return false


func _terrain() -> TerrainGrid:
	var node := get_tree().get_first_node_in_group("terrain")
	return node as TerrainGrid


func _ground_speed() -> float:
	var grid := _terrain()
	if grid == null:
		return 1.0
	return grid.speed_scale_at(global_position)


func _apply_solidity() -> void:
	var hollow := stats != null and stats.body_hollow
	SpellUtil.apply_body_collision(self, SpellUtil.layer_players(), hollow)


func _cast_mine(data: SpellData, aim: Vector2) -> void:
	if data.cast_range <= 0.0:
		return
	var at := SpellUtil.clamp_aim(global_position, aim, data.cast_range)
	_spawn_spell_scene(data, at, 0.0, func(n): n.setup(self, data))


func _cast_self(data: SpellData) -> void:
	SpellUtil.apply_payload(self, self, data)
	_spawn_spell_scene(data, global_position, rotation, func(n): n.setup_flash(0.55))


func _cast_around(data: SpellData) -> void:
	var radius := 56.0 * data.area
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = SpellUtil.combat_mask(data.element)
	for hit in space.intersect_shape(query):
		if hit.collider is Node:
			var collider := hit.collider as Node
			if collider == self:
				continue
			if _payload_applicable(collider, data):
				SpellUtil.apply_payload(self, collider, data)
	_spawn_spell_scene(data, global_position, 0.0, func(n): n.setup_flash(0.5))


func _payload_applicable(target: Node, data: SpellData) -> bool:
	if data.element == SpellData.Element.LIGHT:
		return target.is_in_group("players")
	return target.is_in_group("destructibles") or target.is_in_group("enemies") or target.is_in_group("solid_walls")