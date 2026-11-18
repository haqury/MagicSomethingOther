extends Node2D

@onready var _line: Line2D = get_node_or_null("Line2D") as Line2D
@onready var _glow: Sprite2D = get_node_or_null("Glow") as Sprite2D
@onready var _impact: Sprite2D = get_node_or_null("Impact") as Sprite2D

var _time := 0.0
var _life := 0.45


func setup_line(from: Vector2, to: Vector2) -> void:
	var local_from := to_local(from)
	var local_to := to_local(to)
	if _line:
		_line.points = PackedVector2Array([local_from, local_to])
	var span := local_to - local_from
	if _glow and _glow.texture:
		_glow.position = (local_from + local_to) * 0.5
		_glow.rotation = span.angle()
		var length := maxf(span.length(), 8.0)
		_glow.scale = Vector2(length / float(_glow.texture.get_width()), 1.15)
	if _impact:
		_impact.position = local_to
		_impact.rotation = -rotation
	_life = 0.42
	if multiplayer.is_server():
		get_tree().create_timer(_life).timeout.connect(queue_free)


func setup_flash(lifetime: float) -> void:
	_life = lifetime
	if multiplayer.is_server():
		get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_time += delta
	var fade := clampf(1.0 - _time / maxf(_life, 0.05), 0.0, 1.0)
	if _line:
		_line.width = 7.0 + sin(_time * 32.0) * 3.0
		var line_color := _line.default_color
		line_color.a = fade
		_line.default_color = line_color
	if _glow:
		var glow_color := _glow.modulate
		glow_color.a = fade
		_glow.modulate = glow_color
	if _impact:
		var grow := lerpf(0.45, 1.2, clampf(_time / _life, 0.0, 1.0))
		_impact.scale = Vector2(0.4, 0.4) * grow
		var impact_color := _impact.modulate
		impact_color.a = fade
		_impact.modulate = impact_color
