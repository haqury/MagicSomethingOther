extends Node

enum Kind { SPIN, PULSE, BURST }

@export var kind: Kind = Kind.PULSE
@export var target_path: NodePath = ^"../Body"
@export var spin_speed: float = 1.6
@export var pulse_speed: float = 5.0
@export var pulse_amount: float = 0.08
@export var burst_time: float = 0.45

var _time := 0.0
var _base_scale := Vector2.ONE
var _sprite: CanvasItem


func _ready() -> void:
	_sprite = get_node_or_null(target_path) as CanvasItem
	if _sprite:
		_base_scale = _sprite.scale


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_time += delta
	match kind:
		Kind.SPIN:
			_sprite.rotation = _time * spin_speed
			_sprite.scale = _base_scale * (1.0 + sin(_time * pulse_speed) * pulse_amount)
		Kind.PULSE:
			var wave := 1.0 + sin(_time * pulse_speed) * pulse_amount
			_sprite.scale = _base_scale * wave
			var color := _sprite.modulate
			color.a = clampf(0.72 + sin(_time * pulse_speed) * 0.28, 0.35, 1.0)
			_sprite.modulate = color
		Kind.BURST:
			var u := clampf(_time / burst_time, 0.0, 1.0)
			var grow := lerpf(0.35, 1.25, 1.0 - pow(1.0 - u, 2.0))
			_sprite.scale = _base_scale * grow
			var color := _sprite.modulate
			color.a = 1.0 - u
			_sprite.modulate = color
