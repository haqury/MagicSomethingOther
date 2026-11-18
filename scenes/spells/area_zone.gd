extends Area2D

var _caster: Node2D
var _data: SpellData
var _hit: Dictionary = {}
var _scanned := false
var _wall_tick := 0.0


func setup(caster: Node2D, data: SpellData) -> void:
	_caster = caster
	_data = data
	scale = Vector2.ONE
	var shape := $CollisionShape2D.shape as CircleShape2D
	shape.radius = 36.0 * data.area
	monitoring = true
	monitorable = false
	collision_mask = SpellUtil.layer_world() | SpellUtil.layer_hazards()
	if data.element == SpellData.Element.LIGHT:
		collision_mask |= SpellUtil.layer_players()
	else:
		collision_mask |= SpellUtil.layer_enemies()
	body_entered.connect(_on_body_entered)
	if multiplayer.is_server():
		_hit_solid_walls()
		call_deferred("_initial_overlap")
		if data.duration > 0.0:
			get_tree().create_timer(data.duration).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _data == null or _data.element == SpellData.Element.LIGHT:
		return
	if not _scanned:
		_scanned = true
		return
	# Стену могли поставить уже внутрь зоны: область сама её не замечает.
	_wall_tick += delta
	if _wall_tick < 0.5:
		return
	_wall_tick = 0.0
	_hit_solid_walls()


func _initial_overlap() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	for node in get_overlapping_bodies():
		_on_body_entered(node)
	_hit_solid_walls()


func _hit_solid_walls() -> void:
	if _data == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = 36.0 * _data.area
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = SpellUtil.layer_world()
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space := get_world_2d().direct_space_state
	for hit in space.intersect_shape(query, 32):
		var collider: Object = hit.get("collider")
		if collider is Node:
			_on_body_entered(collider as Node)


func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if _hit.has(body.get_instance_id()):
		return
	if not _accepts(body):
		return
	_hit[body.get_instance_id()] = true
	SpellUtil.apply_payload(_caster, body, _data)


func _accepts(target: Node) -> bool:
	if _data.element == SpellData.Element.LIGHT:
		return target.is_in_group("players")
	return target.is_in_group("destructibles") or target.is_in_group("enemies") or target.is_in_group("solid_walls")
