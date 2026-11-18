class_name Destructible
extends StaticBody2D

signal destroyed

@export var hp: float = 30.0

func _ready() -> void:
	add_to_group("destructibles")


func take_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		destroyed.emit()
		queue_free()
		return
	# Короткий блик, чтобы попадание по стене было видно до разрушения.
	var base := modulate
	modulate = Color(1.65, 1.65, 1.65)
	var tween := create_tween()
	tween.tween_property(self, "modulate", base, 0.12)