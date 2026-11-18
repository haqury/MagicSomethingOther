class_name SpellUtil
extends RefCounted

const COLORS: PackedColorArray = [
	Color("#e85d04"), Color("#219ebc"), Color("#7a6a3a"), Color("#c5d5e4"),
	Color("#a9def9"), Color("#ffe8a3"), Color("#f0e14a"),
]


static func element_color(element: SpellData.Element) -> Color:
	return COLORS[element]


static func layer_world() -> int:
	return 1


static func layer_players() -> int:
	return 2


static func layer_projectiles() -> int:
	return 4


static func layer_enemies() -> int:
	return 8


static func layer_hazards() -> int:
	return 16


static func layer_solids() -> int:
	return 32


## Полый объект сталкивается только с миром. Твёрдый ещё и с другими твёрдыми.
static func apply_body_collision(body: CollisionObject2D, identity_layer: int, hollow: bool) -> void:
	if hollow:
		body.collision_layer = identity_layer
		body.collision_mask = layer_world()
	else:
		body.collision_layer = identity_layer | layer_solids()
		body.collision_mask = layer_world() | layer_solids()


static func combat_mask(element: SpellData.Element) -> int:
	var mask := layer_world() | layer_hazards()
	if element == SpellData.Element.LIGHT:
		mask |= layer_players()
	else:
		mask |= layer_enemies()
	return mask


static func apply_payload(_caster: Node2D, target: Node, data: SpellData) -> void:
	if data.element == SpellData.Element.LIGHT:
		if target.is_in_group("players") and target.has_method("heal"):
			target.heal(data.power)
	elif is_harm_target(target):
		if target.has_method("take_damage"):
			target.take_damage(data.power)


## Урон получают мобы и всё разрушаемое: каменные и ледяные стены тоже.
static func is_harm_target(target: Node) -> bool:
	return target.is_in_group("enemies") or target.is_in_group("destructibles") or target.is_in_group("solid_walls")


static func clamp_aim(origin: Vector2, aim: Vector2, cast_range: float) -> Vector2:
	var delta := aim - origin
	if cast_range <= 0.0:
		return origin
	if delta.length() > cast_range:
		return origin + delta.normalized() * cast_range
	return aim


static func aim_direction(origin: Vector2, aim: Vector2, fallback_rot: float) -> Vector2:
	var d := aim - origin
	if d.length() < 1.0:
		return Vector2.RIGHT.rotated(fallback_rot)
	return d.normalized()