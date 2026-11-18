extends Destructible

const _DAMAGE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/fx/walls/damage_1.png"),
	preload("res://assets/sprites/fx/walls/damage_2.png"),
	preload("res://assets/sprites/fx/walls/damage_3.png"),
	preload("res://assets/sprites/fx/walls/damage_4.png"),
]
const _TICK := 0.5
const _WALL_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/fx/walls/fire.png"),
	preload("res://assets/sprites/fx/walls/water.png"),
	preload("res://assets/sprites/fx/walls/earth.png"),
	preload("res://assets/sprites/fx/walls/air.png"),
	preload("res://assets/sprites/fx/walls/ice.png"),
	preload("res://assets/sprites/fx/walls/light.png"),
	preload("res://assets/sprites/fx/walls/lightning.png"),
]

var _caster: Node2D
var _data: SpellData
var _solid := true
var _tick := 0.0
var _shimmer := 0.0
var _look_scale := Vector2.ONE
var _inside: Dictionary = {}
var max_hp: float = 60.0
var _damage_stage := -2


func setup(caster: Node2D, data: SpellData) -> void:
	_caster = caster
	_data = data
	hp = data.object_hp
	max_hp = hp
	_damage_stage = -2
	_apply_element_look()
	_apply_damage_stage()
	_solid = data.element == SpellData.Element.EARTH or data.element == SpellData.Element.ICE
	if _solid:
		add_to_group("solid_walls")
	if _solid:
		# Твёрдое тело на слое мира: враг и игрок упираются в коллизию.
		collision_layer = SpellUtil.layer_world()
		$Aura.monitoring = false
	else:
		# Слой ловушек видят снаряды, но не маска ходьбы. Сквозь стену проходят.
		collision_layer = SpellUtil.layer_hazards()
		var aura: Area2D = $Aura
		aura.monitoring = true
		aura.monitorable = false
		aura.collision_layer = 0
		if data.element == SpellData.Element.LIGHT:
			aura.collision_mask = SpellUtil.layer_players()
		else:
			aura.collision_mask = SpellUtil.layer_enemies()
		if not aura.body_entered.is_connected(_on_body_entered):
			aura.body_entered.connect(_on_body_entered)
		if not aura.body_exited.is_connected(_on_body_exited):
			aura.body_exited.connect(_on_body_exited)
		if multiplayer.is_server():
			call_deferred("_collect_overlap")
			# Область не замечает уже стоящий StaticBody2D. Камень и лёд бьём запросом формы.
			if data.element != SpellData.Element.LIGHT:
				_damage_solid_walls()
	# Земля стоит, пока её не разобьют. У остальных стен срок жизни из крафта.
	if data.element != SpellData.Element.EARTH and data.duration > 0.0 and multiplayer.is_server():
		get_tree().create_timer(data.duration).timeout.connect(queue_free)


func _apply_element_look() -> void:
	var body := $Body as Sprite2D
	if body == null or _data == null:
		return
	body.texture = _WALL_TEXTURES[_data.element]
	# Базовый блок 56px, примерно корпус мага. Ранг размера в крафте умножает всю стену.
	modulate = Color.WHITE
	_look_scale = Vector2.ONE
	body.scale = _look_scale
	body.position = Vector2.ZERO


## Четыре стадии по четвертям запаса прочности. Полная стена без слоя повреждений.
func _apply_damage_stage() -> void:
	var mark := $Body/Damage as Sprite2D
	if mark == null:
		return
	var cap := maxf(max_hp, 1.0)
	var ratio := clampf(hp / cap, 0.0, 1.0)
	var stage := -1
	if hp < cap:
		if ratio > 0.75:
			stage = 0
		elif ratio > 0.5:
			stage = 1
		elif ratio > 0.25:
			stage = 2
		else:
			stage = 3
	if stage == _damage_stage:
		return
	_damage_stage = stage
	mark.visible = stage >= 0
	if stage >= 0:
		mark.texture = _DAMAGE_TEXTURES[stage]


func _process(delta: float) -> void:
	_apply_damage_stage()
	_apply_relief_visual()
	# Земля и лёд — неподвижный блок. Живая пульсация только у проходимых стен.
	if _solid:
		return
	_shimmer += delta
	var body := $Body as Sprite2D
	if body == null:
		return
	var wave := 1.0 + sin(_shimmer * 4.5) * 0.04
	body.scale = _look_scale * wave


func _apply_relief_visual() -> void:
	var body := $Body as Sprite2D
	if body == null:
		return
	var lift := 0.0
	var grid := get_tree().get_first_node_in_group("terrain")
	if grid != null and grid.has_method("visual_lift"):
		lift = float(grid.visual_lift(global_position))
		z_index = int(grid.draw_order(global_position))
	body.position = Vector2(0.0, -lift)


func _physics_process(delta: float) -> void:
	if _solid or _data == null or not multiplayer.is_server():
		return
	_tick += delta
	if _tick < _TICK:
		return
	_tick = 0.0
	if _data.element != SpellData.Element.LIGHT:
		_damage_solid_walls()
	var stale: Array[int] = []
	for id in _inside.keys():
		var node := instance_from_id(id) as Object
		if node == null or not is_instance_valid(node) or not (node is Node):
			stale.append(id)
			continue
		_affect(node as Node)
	for id in stale:
		_inside.erase(id)


func _collect_overlap() -> void:
	var aura: Area2D = $Aura
	for body in aura.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server() or _solid:
		return
	if not _accepts(body):
		return
	_inside[body.get_instance_id()] = true
	_affect(body)


func _on_body_exited(body: Node) -> void:
	_inside.erase(body.get_instance_id())


func _accepts(body: Node) -> bool:
	if _data.element == SpellData.Element.LIGHT:
		return body.is_in_group("players")
	return body.is_in_group("enemies")


func _damage_solid_walls() -> void:
	var aura_shape := $Aura/CollisionShape2D.shape as RectangleShape2D
	var shape := RectangleShape2D.new()
	shape.size = aura_shape.size if aura_shape != null else Vector2(58, 58)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = $Aura.global_transform
	query.collision_mask = SpellUtil.layer_world()
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space := get_world_2d().direct_space_state
	for hit in space.intersect_shape(query, 16):
		var collider: Object = hit.get("collider")
		if collider == self or not (collider is Node):
			continue
		var node := collider as Node
		if node.is_in_group("solid_walls"):
			_affect(node)


func _affect(body: Node) -> void:
	if _data.element == SpellData.Element.LIGHT:
		if body.has_method("heal"):
			body.heal(_data.power)
		return
	if body.has_method("take_damage"):
		body.take_damage(_data.power)
	_apply_element(body)


func _apply_element(body: Node) -> void:
	match _data.element:
		SpellData.Element.FIRE:
			if body.has_method("apply_status"):
				body.apply_status(&"burn", 2.2, maxf(_data.power * 0.45, 1.0))
		SpellData.Element.WATER:
			if body.has_method("apply_status"):
				body.apply_status(&"slow", 1.8, 0.5)
		SpellData.Element.LIGHTNING:
			if body.has_method("apply_status"):
				body.apply_status(&"stun", 0.45, 0.0)
		SpellData.Element.AIR:
			if body.has_method("apply_push"):
				var side := signf(to_local(body.global_position).y)
				if side == 0.0:
					side = 1.0
				var push := global_transform.y.normalized() * side * 280.0
				body.apply_push(push, 0.28)
