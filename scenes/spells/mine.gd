extends StaticBody2D

@export var hp: float = 30.0

var _caster: Node2D
var _data: SpellData
var _armed := true


func _ready() -> void:
	add_to_group("destructibles")


func setup(caster: Node2D, data: SpellData) -> void:
	_caster = caster
	_data = data
	hp = data.object_hp
	collision_layer = SpellUtil.layer_hazards()
	collision_mask = 0
	var trigger: Area2D = $Trigger
	trigger.monitoring = true
	if data.element == SpellData.Element.LIGHT:
		trigger.collision_mask = SpellUtil.layer_players()
	else:
		trigger.collision_mask = SpellUtil.layer_enemies()
	if not trigger.body_entered.is_connected(_on_trigger):
		trigger.body_entered.connect(_on_trigger)
	if multiplayer.is_server() and data.duration > 0.0:
		get_tree().create_timer(data.duration).timeout.connect(queue_free)


func take_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		queue_free()


func _on_trigger(body: Node) -> void:
	if not multiplayer.is_server() or not _armed:
		return
	if not _accepts(body):
		return
	_explode()


func _explode() -> void:
	_armed = false
	var radius := 24.0 * _data.area
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = SpellUtil.combat_mask(_data.element)
	var space := get_world_2d().direct_space_state
	for hit in space.intersect_shape(query):
		if hit.collider is Node:
			var node := hit.collider as Node
			if _accepts(node):
				SpellUtil.apply_payload(_caster, node, _data)
	_spawn_impact()
	queue_free()


func _accepts(target: Node) -> bool:
	if _data.element == SpellData.Element.LIGHT:
		return target.is_in_group("players")
	return target.is_in_group("destructibles") or target.is_in_group("enemies") or target.is_in_group("solid_walls")


func _spawn_impact() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := preload("res://scenes/spells/impact_flash.tscn").instantiate() as Node2D
	fx.global_position = global_position
	fx.modulate = modulate
	fx.scale = Vector2.ONE * maxf(_data.area, 0.6)
	parent.add_child(fx)
	if fx.has_method("setup_flash"):
		fx.setup_flash(0.45)