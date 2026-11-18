extends Control

@onready var _singleplayer: Button = %SingleplayerButton
@onready var _host: Button = %HostButton
@onready var _join: Button = %JoinButton
@onready var _settings: Button = %SettingsButton
@onready var _address: LineEdit = %AddressEdit
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_apply_localized_text()
	if not Settings.locale_changed.is_connected(_on_locale_changed):
		Settings.locale_changed.connect(_on_locale_changed)
	_singleplayer.pressed.connect(_on_singleplayer)
	_host.pressed.connect(_on_host)
	_join.pressed.connect(_on_join)
	_settings.pressed.connect(_on_settings)
	NetworkManager.session_failed.connect(_on_session_failed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.session_started.connect(_on_session_started)


func _set_buttons_enabled(enabled: bool) -> void:
	_singleplayer.disabled = not enabled
	_host.disabled = not enabled
	_join.disabled = not enabled
	_settings.disabled = not enabled


func _on_singleplayer() -> void:
	_set_buttons_enabled(false)
	_status.text = ""
	NetworkManager.start_singleplayer()


func _on_host() -> void:
	_set_buttons_enabled(false)
	_status.text = ""
	NetworkManager.host_game(NetworkManager.DEFAULT_PORT)


func _on_join() -> void:
	_set_buttons_enabled(false)
	_status.text = ""
	NetworkManager.join_game(_address.text, NetworkManager.DEFAULT_PORT)


func _on_settings() -> void:
	Settings.return_scene = scene_file_path
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _on_session_started(_mode: NetworkManager.SessionMode) -> void:
	pass


func _on_session_failed(reason: String) -> void:
	_set_buttons_enabled(true)
	match reason:
		"port_busy":
			_status.text = tr("menu.status.port_busy")
		_:
			_status.text = tr("menu.status.bad_address")


func _on_connection_failed() -> void:
	_set_buttons_enabled(true)
	_status.text = tr("menu.status.connection_failed")


func _on_server_disconnected() -> void:
	_set_buttons_enabled(true)
	_status.text = tr("menu.status.server_lost")


func _apply_localized_text() -> void:
	$CenterContainer/PanelContainer/VBoxContainer/Title.text = tr("menu.title")
	_singleplayer.text = tr("menu.singleplayer")
	_host.text = tr("menu.host")
	$CenterContainer/PanelContainer/VBoxContainer/AddressLabel.text = tr("menu.ip")
	_join.text = tr("menu.join")
	_settings.text = tr("menu.settings")


func _on_locale_changed(_locale: String) -> void:
	_apply_localized_text()
