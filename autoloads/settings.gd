extends Node

signal graphics_changed
signal bindings_changed
signal locale_changed(locale: String)

const CFG_PATH := "user://settings.cfg"

var return_scene: String = "res://scenes/main_menu/main_menu.tscn"

var _rebind_action: StringName = &""
var _ui_theme: Theme

const DEFAULT_BINDINGS: Dictionary = {
	&"move_left": "key:65",
	&"move_right": "key:68",
	&"move_up": "key:87",
	&"move_down": "key:83",
	&"sprint": "key:32",
	&"cast_lmb": "mouse:1",
	&"cast_rmb": "mouse:2",
	&"cast_mmb": "mouse:4",
	&"ui_cancel": "key:4194305",
}

const WINDOW_MODES: PackedStringArray = ["windowed", "borderless", "fullscreen"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const VSYNC_MODES: PackedStringArray = ["disabled", "enabled", "adaptive"]
const MAX_FPS_OPTIONS: PackedInt32Array = [0, 60, 120, 144, 240]
const UI_SCALES: PackedFloat32Array = [1.0, 1.25, 1.5]


func _ready() -> void:
	_ui_theme = load("res://theme/ui_theme.tres") as Theme
	_load_or_defaults()
	apply_all()


func apply_all() -> void:
	_apply_graphics()
	_apply_bindings()
	_apply_locale()


func _load_or_defaults() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		_write_defaults(cfg)
		cfg.save(CFG_PATH)
	_load_bindings(cfg)


func _write_defaults(cfg: ConfigFile) -> void:
	cfg.set_value("graphics", "window_mode", "windowed")
	cfg.set_value("graphics", "resolution", "1280x720")
	cfg.set_value("graphics", "vsync", "enabled")
	cfg.set_value("graphics", "max_fps", 0)
	cfg.set_value("graphics", "ui_scale", 1.0)
	for action in DEFAULT_BINDINGS.keys():
		cfg.set_value("input", String(action), DEFAULT_BINDINGS[action])
	var loc := "en"
	if OS.get_locale_language() == "ru":
		loc = "ru"
	cfg.set_value("locale", "language", loc)


func _load_bindings(cfg: ConfigFile) -> void:
	for action in DEFAULT_BINDINGS.keys():
		if not cfg.has_section_key("input", String(action)):
			cfg.set_value("input", String(action), DEFAULT_BINDINGS[action])


func set_window_mode(mode: String) -> void:
	var cfg := _open_cfg()
	cfg.set_value("graphics", "window_mode", mode)
	cfg.save(CFG_PATH)
	_apply_graphics()
	graphics_changed.emit()


func set_resolution(size: Vector2i) -> void:
	var cfg := _open_cfg()
	cfg.set_value("graphics", "resolution", "%dx%d" % [size.x, size.y])
	cfg.save(CFG_PATH)
	_apply_graphics()
	graphics_changed.emit()


func set_vsync(mode: String) -> void:
	var cfg := _open_cfg()
	cfg.set_value("graphics", "vsync", mode)
	cfg.save(CFG_PATH)
	_apply_graphics()
	graphics_changed.emit()


func set_max_fps(fps: int) -> void:
	var cfg := _open_cfg()
	cfg.set_value("graphics", "max_fps", fps)
	cfg.save(CFG_PATH)
	_apply_graphics()
	graphics_changed.emit()


func set_ui_scale(scale: float) -> void:
	var cfg := _open_cfg()
	cfg.set_value("graphics", "ui_scale", scale)
	cfg.save(CFG_PATH)
	_apply_graphics()
	graphics_changed.emit()


func set_locale(locale: String) -> void:
	var cfg := _open_cfg()
	cfg.set_value("locale", "language", locale)
	cfg.save(CFG_PATH)
	_apply_locale()
	locale_changed.emit(locale)


func start_rebind(action: StringName) -> void:
	_rebind_action = action


func cancel_rebind() -> void:
	_rebind_action = &""


func reset_bindings() -> void:
	var cfg := _open_cfg()
	for action in DEFAULT_BINDINGS.keys():
		cfg.set_value("input", String(action), DEFAULT_BINDINGS[action])
	cfg.save(CFG_PATH)
	_apply_bindings()
	bindings_changed.emit()


func is_rebinding() -> bool:
	return not _rebind_action.is_empty()


func get_rebind_action() -> StringName:
	return _rebind_action


func get_cfg_value(section: String, key: String, default_value: Variant) -> Variant:
	var cfg := _open_cfg()
	return cfg.get_value(section, key, default_value)


func binding_display(action: StringName) -> String:
	var raw: String = get_cfg_value("input", String(action), "")
	if raw.is_empty():
		return "—"
	if raw.begins_with("key:"):
		var code := int(raw.substr(4))
		return OS.get_keycode_string(code)
	if raw.begins_with("mouse:"):
		var button := int(raw.substr(6))
		match button:
			1: return "LMB"
			2: return "RMB"
			3: return "MMB"
			4: return "MMB"
			_: return "Mouse %d" % button
	return raw


func _open_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	return cfg


func _apply_graphics() -> void:
	var cfg := _open_cfg()
	var mode: String = cfg.get_value("graphics", "window_mode", "windowed")
	var res_str: String = cfg.get_value("graphics", "resolution", "1280x720")
	var vsync: String = cfg.get_value("graphics", "vsync", "enabled")
	var max_fps: int = cfg.get_value("graphics", "max_fps", 0)
	var ui_scale: float = cfg.get_value("graphics", "ui_scale", 1.0)
	var parts := res_str.split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	match mode:
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(size)
			var screen := DisplayServer.window_get_current_screen()
			var screen_size := DisplayServer.screen_get_size(screen)
			DisplayServer.window_set_position(screen_size / 2 - size / 2)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"fullscreen":
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	match vsync:
		"disabled":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		"adaptive":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		_:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = max_fps
	if _ui_theme:
		_ui_theme.default_font_size = roundi(16 * ui_scale)
		get_tree().root.theme = _ui_theme


func _apply_bindings() -> void:
	var cfg := _open_cfg()
	for action in DEFAULT_BINDINGS.keys():
		var raw: String = cfg.get_value("input", String(action), DEFAULT_BINDINGS[action])
		InputMap.action_erase_events(action)
		var ev := _event_from_cfg(raw)
		if ev:
			InputMap.action_add_event(action, ev)


func _apply_locale() -> void:
	var cfg := _open_cfg()
	var locale: String = cfg.get_value("locale", "language", "en")
	TranslationServer.set_locale(locale)


func _event_from_cfg(raw: String) -> InputEvent:
	if raw.begins_with("key:"):
		var ev := InputEventKey.new()
		ev.keycode = int(raw.substr(4)) as Key
		ev.physical_keycode = ev.keycode
		return ev
	if raw.begins_with("mouse:"):
		var ev := InputEventMouseButton.new()
		ev.button_index = int(raw.substr(6)) as MouseButton
		return ev
	return null


func _cfg_from_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var key := ev as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		return "key:%d" % code
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		return "mouse:%d" % mb.button_index
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if _rebind_action.is_empty():
		return
	if event.is_echo():
		return
	if event is InputEventMouseMotion:
		return
	if event.is_action_pressed(&"ui_cancel"):
		cancel_rebind()
		return
	var raw := _cfg_from_event(event)
	if raw.is_empty():
		return
	var cfg := _open_cfg()
	# Снять ту же клавишу с другого действия
	for action in DEFAULT_BINDINGS.keys():
		if action == _rebind_action:
			continue
		if cfg.get_value("input", String(action), "") == raw:
			cfg.set_value("input", String(action), "")
	cfg.set_value("input", String(_rebind_action), raw)
	cfg.save(CFG_PATH)
	_rebind_action = &""
	_apply_bindings()
	bindings_changed.emit()
	get_viewport().set_input_as_handled()