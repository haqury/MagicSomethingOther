extends CharacterBody2D

const KIND_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/enemy_orc.png"),
	preload("res://assets/sprites/enemy_slime.png"),
	preload("res://assets/sprites/enemy_skeleton.png"),
]

@export var max_hp: float = 40.0
var hp: float = 40.0
@export var move_speed: float = 70.0
## 0 орк, 1 слизь, 2 скелет. Сервер задаёт до спавна, клиенты получают через синхронизатор.
var kind: int = 0:
	set(value):
		kind = clampi(value, 0, 2)
		if is_inside_tree():
			_apply_kind()

## Полый моб не занимает место: сквозь него проходят игроки и другие мобы.
var hollow: bool = false

var _target: Node2D
var _burn_time := 0.0
var _burn_dps := 0.0
var _slow_time := 0.0
var _slow_factor := 1.0
var _stun_time := 0.0
var _push := Vector2.ZERO
var _push_time := 0.0
var _body_rest := Vector2(0, -8)
var _detour := Vector2.INF
var _detour_wait := 0.0
## Битовая маска для клиентов: 1 горение, 2 замедление, 4 стан, 8 толчок.
var status_flags: int = 0:
	set(value):
		status_flags = value
		if is_inside_tree():
			_apply_status_tint()


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	var body := $Body as Sprite2D
	if body != null:
		_body_rest = body.position
	_apply_kind()
	_apply_status_tint()


func _apply_kind() -> void:
	# Слизь полая, орк и скелет твёрдые и не проходят друг сквозь друга.
	hollow = kind == 1
	_apply_solidity()
	var body := $Body as Sprite2D
	if body == null:
		return
	var index := clampi(kind, 0, KIND_TEXTURES.size() - 1)
	body.texture = KIND_TEXTURES[index]


func _apply_solidity() -> void:
	SpellUtil.apply_body_collision(self, SpellUtil.layer_enemies(), hollow)


func _ground_speed() -> float:
	var grid := get_tree().get_first_node_in_group("terrain")
	if grid != null and grid.has_method("speed_scale_at"):
		return float(grid.speed_scale_at(global_position))
	return 1.0


func _process(_delta: float) -> void:
	var body := $Body as Sprite2D
	if body == null:
		return
	var lift := 0.0
	var grid := get_tree().get_first_node_in_group("terrain")
	if grid != null and grid.has_method("visual_lift"):
		lift = float(grid.visual_lift(global_position))
		z_index = int(grid.draw_order(global_position))
	body.position = _body_rest + Vector2(0.0, -lift)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	_tick_statuses(delta)
	_acquire_target()
	if _push_time > 0.0:
		velocity = _clip_move(_push, delta)
	elif _stun_time > 0.0 or _target == null:
		velocity = Vector2.ZERO
	else:
		var dir := (_target.global_position - global_position).normalized()
		var speed := move_speed
		if _slow_time > 0.0:
			speed *= _slow_factor
		speed *= _ground_speed()
		velocity = _chase_velocity(dir * speed, delta)
		var body := $Body as Sprite2D
		if body:
			body.flip_h = dir.x < 0.0
	move_and_slide()


func _clip_move(desired: Vector2, delta: float) -> Vector2:
	var grid := get_tree().get_first_node_in_group("terrain")
	if grid != null and grid.has_method("clip_velocity"):
		return grid.clip_velocity(global_position, desired, delta)
	return desired


func _chase_velocity(desired: Vector2, delta: float) -> Vector2:
	var grid := get_tree().get_first_node_in_group("terrain")
	if grid == null or not grid.has_method("clip_velocity"):
		return desired
	var clipped: Vector2 = grid.clip_velocity(global_position, desired, delta)
	var blocked := clipped.length() < desired.length() * 0.6
	if not blocked:
		_detour = Vector2.INF
		return clipped
	_detour_wait -= delta
	if _detour_wait <= 0.0:
		_detour_wait = 0.4
		_detour = grid.find_step(global_position, _target.global_position)
	if not _detour.is_finite():
		return clipped
	var to_step := _detour - global_position
	if to_step.length() <= 8.0:
		_detour_wait = 0.0
		_detour = grid.find_step(global_position, _target.global_position)
		if not _detour.is_finite():
			return clipped
		to_step = _detour - global_position
		if to_step.length() <= 8.0:
			return clipped
	return grid.clip_velocity(global_position, to_step.normalized() * desired.length(), delta)


func apply_status(kind: StringName, duration: float, magnitude: float) -> void:
	if not multiplayer.is_server():
		return
	match kind:
		&"burn":
			_burn_time = maxf(_burn_time, duration)
			_burn_dps = maxf(_burn_dps, magnitude)
		&"slow":
			_slow_time = maxf(_slow_time, duration)
			_slow_factor = minf(_slow_factor if _slow_time > 0.0 else 1.0, magnitude)
		&"stun":
			_stun_time = maxf(_stun_time, duration)
	_publish_status()


func apply_push(impulse: Vector2, duration: float) -> void:
	if not multiplayer.is_server():
		return
	_push = impulse
	_push_time = maxf(_push_time, duration)
	_publish_status()


func _tick_statuses(delta: float) -> void:
	if _burn_time > 0.0:
		_burn_time = maxf(_burn_time - delta, 0.0)
		take_damage(_burn_dps * delta)
		if _burn_time <= 0.0:
			_burn_dps = 0.0
	if _slow_time > 0.0:
		_slow_time = maxf(_slow_time - delta, 0.0)
		if _slow_time <= 0.0:
			_slow_factor = 1.0
	if _stun_time > 0.0:
		_stun_time = maxf(_stun_time - delta, 0.0)
	if _push_time > 0.0:
		_push_time = maxf(_push_time - delta, 0.0)
		if _push_time <= 0.0:
			_push = Vector2.ZERO
	_publish_status()


func _publish_status() -> void:
	var flags := 0
	if _burn_time > 0.0:
		flags |= 1
	if _slow_time > 0.0:
		flags |= 2
	if _stun_time > 0.0:
		flags |= 4
	if _push_time > 0.0:
		flags |= 8
	status_flags = flags


func _apply_status_tint() -> void:
	var body := $Body as Sprite2D
	if body == null:
		return
	if status_flags & 4:
		body.modulate = Color(1.0, 0.95, 0.45)
	elif status_flags & 1:
		body.modulate = Color(1.0, 0.55, 0.32)
	elif status_flags & 2:
		body.modulate = Color(0.62, 0.84, 1.0)
	elif status_flags & 8:
		body.modulate = Color(0.82, 0.95, 1.0)
	else:
		body.modulate = Color.WHITE


func _acquire_target() -> void:
	if _target != null and is_instance_valid(_target):
		return
	var best_dist := INF
	_target = null
	for node in get_tree().get_nodes_in_group("players"):
		if node is Node2D:
			var dist := global_position.distance_squared_to(node.global_position)
			if dist < best_dist:
				best_dist = dist
				_target = node as Node2D


func take_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		queue_free()