extends CanvasLayer

@onready var _hp: ProgressBar = %HpBar
@onready var _stamina: ProgressBar = %StaminaBar
@onready var _essence: Label = %EssenceLabel
@onready var _hp_text: Label = %HpText
@onready var _stamina_text: Label = %StaminaText
@onready var _wave: Label = %WaveLabel


func _ready() -> void:
	var vbox := $Panel/VBox
	vbox.get_node("HpLabel").text = tr("prep.hp")
	vbox.get_node("StaminaLabel").text = tr("prep.stamina")


func _process(_delta: float) -> void:
	var player := _local_player()
	visible = player != null
	if player == null:
		return
	_hp.max_value = player.max_hp
	_hp.value = player.current_hp
	_stamina.max_value = player.max_stamina
	_stamina.value = player.current_stamina
	_hp_text.text = "%d / %d" % [int(player.current_hp), int(player.max_hp)]
	_stamina_text.text = "%d / %d" % [int(player.current_stamina), int(player.max_stamina)]
	_essence.text = "%s: %d" % [tr("prep.essence"), player.essence]


func show_wave(index: int, enemies: int, pause_left: float, building: bool, defeat: bool) -> void:
	if defeat:
		_wave.text = tr("wave.defeat")
		return
	if building:
		_wave.text = "%s\n%s" % [tr("wave.title") % (index + 1), tr("wave.build") % int(ceil(pause_left))]
		return
	_wave.text = "%s\n%s" % [tr("wave.title") % index, tr("wave.enemies") % enemies]


func _local_player() -> Player:
	var entities := get_parent().get_node_or_null("Entities")
	if entities == null:
		return null
	var node := entities.get_node_or_null(str(multiplayer.get_unique_id()))
	return node as Player