extends Control

@onready var _window_mode: OptionButton = %WindowModeOption
@onready var _resolution: OptionButton = %ResolutionOption
@onready var _vsync: OptionButton = %VsyncOption
@onready var _max_fps: OptionButton = %MaxFpsOption
@onready var _ui_scale: OptionButton = %UiScaleOption
@onready var _vsync_status: Label = %VsyncStatus
@onready var _binding_list: VBoxContainer = %BindingList
@onready var _language: OptionButton = %LanguageOption


func _ready() -> void:
	Settings.locale_changed.connect(func(_loc: String) -> void:
		_localize_static_labels()
		_refresh_bindings()
	)
	_populate_graphics()
	_populate_bindings()
	_populate_language()
	_window_mode.item_selected.connect(func(i): Settings.set_window_mode(Settings.WINDOW_MODES[i]))
	_resolution.item_selected.connect(func(i): Settings.set_resolution(Settings.RESOLUTIONS[i]))
	_vsync.item_selected.connect(func(i): Settings.set_vsync(Settings.VSYNC_MODES[i]))
	_max_fps.item_selected.connect(func(i): Settings.set_max_fps(Settings.MAX_FPS_OPTIONS[i]))
	_ui_scale.item_selected.connect(func(i): Settings.set_ui_scale(Settings.UI_SCALES[i]))
	_language.item_selected.connect(func(i): Settings.set_locale("ru" if i == 0 else "en"))
	%ResetButton.pressed.connect(func(): Settings.reset_bindings(); _refresh_bindings())
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file(Settings.return_scene))
	Settings.bindings_changed.connect(_refresh_bindings)
	_vsync_status.text = ""
	_localize_static_labels()


func _populate_graphics() -> void:
	for mode in Settings.WINDOW_MODES:
		_window_mode.add_item(tr("settings.%s" % mode))
	for res in Settings.RESOLUTIONS:
		_resolution.add_item("%dx%d" % [res.x, res.y])
	_vsync.add_item(tr("settings.vsync_off"))
	_vsync.add_item(tr("settings.vsync_on"))
	_vsync.add_item(tr("settings.vsync_adaptive"))
	_max_fps.add_item(tr("settings.fps_uncapped"))
	for fps in [60, 120, 144, 240]:
		_max_fps.add_item(str(fps))
	for scale in Settings.UI_SCALES:
		_ui_scale.add_item(str(scale))
	var cfg_mode: String = Settings.get_cfg_value("graphics", "window_mode", "windowed")
	_window_mode.select(Settings.WINDOW_MODES.find(cfg_mode))
	var res_str: String = Settings.get_cfg_value("graphics", "resolution", "1280x720")
	var parts := res_str.split("x")
	var res_vec := Vector2i(int(parts[0]), int(parts[1]))
	var ri := Settings.RESOLUTIONS.find(res_vec)
	if ri >= 0:
		_resolution.select(ri)
	var vs: String = Settings.get_cfg_value("graphics", "vsync", "enabled")
	_vsync.select(Settings.VSYNC_MODES.find(vs))
	var mf: int = Settings.get_cfg_value("graphics", "max_fps", 0)
	var fi := Settings.MAX_FPS_OPTIONS.find(mf)
	if fi >= 0:
		_max_fps.select(fi)
	var us: float = Settings.get_cfg_value("graphics", "ui_scale", 1.0)
	var ui := Settings.UI_SCALES.find(us)
	if ui >= 0:
		_ui_scale.select(ui)


func _populate_bindings() -> void:
	var actions := Settings.DEFAULT_BINDINGS.keys()
	var rows := _binding_list.get_children()
	for i in rows.size():
		if i >= actions.size():
			continue
		var action: StringName = actions[i]
		var row := rows[i]
		var button := row.get_node("BindButton") as Button
		if not button.pressed.is_connected(_on_bind_pressed):
			button.pressed.connect(_on_bind_pressed.bind(action))
	_refresh_bindings()


func _refresh_bindings() -> void:
	var actions := Settings.DEFAULT_BINDINGS.keys()
	var rows := _binding_list.get_children()
	for i in rows.size():
		if i >= actions.size():
			continue
		var action: StringName = actions[i]
		var row := rows[i]
		var label := row.get_node("ActionLabel") as Label
		var button := row.get_node("BindButton") as Button
		if action == &"ui_cancel":
			label.text = "Escape"
		else:
			label.text = tr("controls.%s" % action)
		if Settings.is_rebinding() and Settings.get_rebind_action() == action:
			button.text = tr("settings.press_key")
		else:
			button.text = Settings.binding_display(action)


func _populate_language() -> void:
	_language.add_item("Русский")
	_language.add_item("English")
	var loc: String = Settings.get_cfg_value("locale", "language", "en")
	_language.select(0 if loc == "ru" else 1)


func _on_bind_pressed(action: StringName) -> void:
	Settings.start_rebind(action)
	_refresh_bindings()


func _localize_static_labels() -> void:
	_localize_node(self)
	%Tabs.set_tab_title(0, tr("settings.graphics"))
	%Tabs.set_tab_title(1, tr("settings.controls"))
	%Tabs.set_tab_title(2, tr("settings.language"))
	%ResetButton.text = tr("settings.reset_bindings")
	%BackButton.text = tr("settings.back")


func _localize_node(node: Node) -> void:
	if node is Label:
		var text := (node as Label).text
		if text.contains(".") and text != "Escape":
			(node as Label).text = tr(text)
	elif node is Button and node != %ResetButton and node != %BackButton:
		var btext := (node as Button).text
		if btext.contains(".") and btext != "+":
			(node as Button).text = tr(btext)
	for child in node.get_children():
		_localize_node(child)