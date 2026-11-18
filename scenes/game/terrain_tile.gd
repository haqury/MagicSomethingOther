extends Node2D

const _EDGE_NAMES: PackedStringArray = ["EdgeN", "EdgeE", "EdgeS", "EdgeW"]


## Площадка клетки. Ноль прячет заливку: кромку рисует сосед выше.
func show_height(height: int) -> void:
	var body := $Body as Polygon2D
	if body == null:
		return
	match height:
		-2:
			body.color = Color(0.16, 0.4, 0.62, 0.92)
			body.visible = true
		-1:
			body.color = Color(0.34, 0.26, 0.14, 0.92)
			body.visible = true
		1:
			body.color = Color(0.46, 0.38, 0.24, 0.95)
			body.visible = true
		2:
			body.color = Color(0.56, 0.48, 0.32, 0.95)
			body.visible = true
		3:
			body.color = Color(0.68, 0.58, 0.4, 0.96)
			body.visible = true
		_:
			body.visible = false


## Четыре кромки: север, восток, юг, запад. 1 — скос, 2 и больше — обрыв.
func show_edges(drops: Array) -> void:
	for index in _EDGE_NAMES.size():
		var edge := get_node_or_null(_EDGE_NAMES[index]) as Polygon2D
		if edge == null:
			continue
		var drop := 0
		if index < drops.size():
			drop = int(drops[index])
		edge.visible = drop >= 1
		if drop < 1:
			continue
		var depth := float(drop) * 16.0
		edge.color = Color(0.74, 0.66, 0.48, 0.95) if drop == 1 else Color(0.15, 0.11, 0.08, 0.96)
		edge.polygon = _lip(index, depth)
	_show_corners(drops)


func _show_corners(drops: Array) -> void:
	var pairs := [
		["EdgeNE", 0, 1],
		["EdgeSE", 1, 2],
		["EdgeSW", 2, 3],
		["EdgeNW", 3, 0],
	]
	for pair in pairs:
		var corner := get_node_or_null(pair[0]) as Polygon2D
		if corner == null:
			continue
		var a := int(drops[pair[1]])
		var b := int(drops[pair[2]])
		var drop := mini(a, b)
		corner.visible = drop >= 1
		if drop < 1:
			continue
		var depth := float(drop) * 16.0
		corner.color = Color(0.74, 0.66, 0.48, 0.95) if drop == 1 else Color(0.15, 0.11, 0.08, 0.96)
		corner.polygon = _corner(pair[0], depth)


func _lip(side: int, depth: float) -> PackedVector2Array:
	var far := 28.0 + depth
	match side:
		0:
			return PackedVector2Array([Vector2(-28, -28), Vector2(28, -28), Vector2(28, -far), Vector2(-28, -far)])
		1:
			return PackedVector2Array([Vector2(28, -28), Vector2(28, 28), Vector2(far, 28), Vector2(far, -28)])
		2:
			return PackedVector2Array([Vector2(-28, 28), Vector2(28, 28), Vector2(28, far), Vector2(-28, far)])
		_:
			return PackedVector2Array([Vector2(-28, -28), Vector2(-28, 28), Vector2(-far, 28), Vector2(-far, -28)])


func _corner(name: String, depth: float) -> PackedVector2Array:
	var far := 28.0 + depth
	match name:
		"EdgeNE":
			return PackedVector2Array([Vector2(28, -28), Vector2(far, -28), Vector2(far, -far), Vector2(28, -far)])
		"EdgeSE":
			return PackedVector2Array([Vector2(28, 28), Vector2(far, 28), Vector2(far, far), Vector2(28, far)])
		"EdgeSW":
			return PackedVector2Array([Vector2(-28, 28), Vector2(-far, 28), Vector2(-far, far), Vector2(-28, far)])
		_:
			return PackedVector2Array([Vector2(-28, -28), Vector2(-far, -28), Vector2(-far, -far), Vector2(-28, -far)])
