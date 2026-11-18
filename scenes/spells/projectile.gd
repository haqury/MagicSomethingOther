extends Area2D

const SPEED := 480.0
const IMPACT_SCENE := preload("res://scenes/spells/impact_flash.tscn")

var _caster: Node2D
var _data: SpellData
var _dir := Vector2.RIGHT
var _traveled := 0.0
var _alive := 0.0


func setup(caster: Node2D, data: SpellData, dir: Vector2) -> void:
	_caster = caster
	_data = data
	_dir = dir.normalized()
	collision_layer = SpellUtil.layer_projectiles()
	collision_mask = 0


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var step := _dir * SPEED * delta
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step)
	query.collision_mask = SpellUtil.combat_mask(_data.element)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.collider
		if collider is Node and _accepts_payload(collider as Node):
			SpellUtil.apply_payload(_caster, collider as Node, _data)
		_spawn_impact()
		queue_free()
		return
	global_position += step
	_traveled += step.length()
	_alive += delta
	if _traveled >= _data.cast_range:
		_spawn_impact()
		queue_free()
		return
	if _data.duration > 0.0 and _alive >= _data.duration:
		_spawn_impact()
		queue_free()


func _accepts_payload(target: Node) -> bool:
	if _data.element == SpellData.Element.LIGHT:
		return target.is_in_group("players")
	return target.is_in_group("destructibles") or target.is_in_group("enemies") or target.is_in_group("solid_walls")


func _spawn_impact() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := IMPACT_SCENE.instantiate() as Node2D
	fx.global_position = global_position
	fx.modulate = modulate
	parent.add_child(fx)
	if fx.has_method("setup_flash"):
		fx.setup_flash(0.4)