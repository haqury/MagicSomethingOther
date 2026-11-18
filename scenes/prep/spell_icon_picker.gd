class_name SpellIconPicker
extends VBoxContainer

signal id_selected(id: int)

@export var picker_kind: StringName = &"element"

@onready var _grid: GridContainer = $Grid

var _selected_id: int = -1
var _buttons: Dictionary = {}


func _ready() -> void:
	_build_grid()


func _build_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_buttons.clear()
	var empty_tex: Texture2D
	var paths: PackedStringArray
	if picker_kind == &"form":
		empty_tex = load(SpellUiCatalog.EMPTY_FORM) as Texture2D
		paths = SpellUiCatalog.FORM_PATHS
	else:
		empty_tex = load(SpellUiCatalog.EMPTY_ELEMENT) as Texture2D
		paths = SpellUiCatalog.ELEMENT_PATHS
	_add_button(-1, empty_tex, tr("prep.empty"))
	for i in paths.size():
		var tex := load(paths[i]) as Texture2D
		var key := _label_key(i)
		_add_button(i, tex, tr(key) if not key.is_empty() else "")


func _label_key(id: int) -> String:
	if picker_kind == &"form":
		var keys := ["form.projectile", "form.area", "form.wall", "form.beam", "form.self", "form.around", "form.mine", "form.relief"]
		if id >= 0 and id < keys.size():
			return keys[id]
	else:
		var keys := ["element.fire", "element.water", "element.earth", "element.air", "element.ice", "element.light", "element.lightning"]
		if id >= 0 and id < keys.size():
			return keys[id]
	return ""


func _add_button(id: int, texture: Texture2D, tooltip_text: String) -> void:
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(44, 44)
	btn.texture_normal = texture
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.toggle_mode = true
	btn.tooltip_text = tooltip_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void: _select(id))
	_grid.add_child(btn)
	_buttons[id] = btn


func set_selected(id: int) -> void:
	_selected_id = id
	for key in _buttons.keys():
		var btn: TextureButton = _buttons[key]
		btn.button_pressed = key == id
		btn.modulate = Color(1.15, 1.15, 1.2) if key == id else Color.WHITE


func _select(id: int) -> void:
	if _selected_id == id:
		return
	set_selected(id)
	id_selected.emit(id)


func refresh_tooltips() -> void:
	_build_grid()
	set_selected(_selected_id)