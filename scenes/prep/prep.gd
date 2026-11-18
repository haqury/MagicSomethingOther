extends Control

@onready var _essence: Label = %EssenceLabel
@onready var _status: Label = %StatusLabel
@onready var _confirm: Button = %ConfirmButton
@onready var _map_option: OptionButton = %MapOption
@onready var _icon_popup: PopupPanel = $IconSelectPopup
@onready var _icon_picker: SpellIconPicker = $IconSelectPopup/Margin/IconPicker

var stats: PlayerStats
var drafts: Array[PrepRules.SpellSlotDraft] = []

var _pick_slot: int = -1
var _pick_kind: StringName = &"element"

const STATS_COLUMN := "MarginContainer/MainVBox/BodyHBox/StatsColumn"

const STAT_ROWS := {
	"hp": {"upgrade": "try_upgrade_max_hp", "downgrade": "try_downgrade_max_hp", "value": "max_hp", "rank": "hp_rank", "cost_base": PlayerStats.HP_BASE_COST, "cost_growth": PlayerStats.HP_COST_GROWTH, "cap": PlayerStats.HP_CAP},
	"speed": {"upgrade": "try_upgrade_move_speed", "downgrade": "try_downgrade_move_speed", "value": "move_speed", "rank": "move_speed_rank", "cost_base": PlayerStats.SPEED_BASE_COST, "cost_growth": PlayerStats.SPEED_COST_GROWTH, "cap": PlayerStats.SPEED_CAP},
	"stamina": {"upgrade": "try_upgrade_max_stamina", "downgrade": "try_downgrade_max_stamina", "value": "max_stamina", "rank": "max_stamina_rank", "cost_base": PlayerStats.STAMINA_BASE_COST, "cost_growth": PlayerStats.STAMINA_COST_GROWTH, "cap": PlayerStats.STAMINA_CAP},
	"dash": {"upgrade": "try_upgrade_dash_multiplier", "downgrade": "try_downgrade_dash_multiplier", "value": "dash_multiplier", "rank": "dash_rank", "cost_base": PlayerStats.DASH_BASE_COST, "cost_growth": PlayerStats.DASH_COST_GROWTH, "cap": PlayerStats.DASH_CAP},
	"vision": {"upgrade": "try_upgrade_vision_zoom", "downgrade": "try_downgrade_vision_zoom", "value": "vision_zoom", "rank": "vision_rank", "cost_base": PlayerStats.VISION_BASE_COST, "cost_growth": PlayerStats.VISION_COST_GROWTH, "cap": PlayerStats.VISION_CAP},
}


func _ready() -> void:
	_localize_static_labels()
	Settings.locale_changed.connect(func(_loc: String) -> void:
		_localize_static_labels()
		_icon_picker.refresh_tooltips()
		_rebuild_map_options()
		_refresh_all()
	)
	stats = PrepRules.make_prep_stats()
	for _i in 3:
		drafts.append(PrepRules.SpellSlotDraft.new())
	_icon_picker.id_selected.connect(_on_popup_pick)
	_wire_stats()
	_wire_slots()
	_wire_map_picker()
	NetworkManager.map_changed.connect(func(_i: int) -> void: _refresh_map_ui())
	%SettingsButton.pressed.connect(_on_settings)
	_confirm.pressed.connect(_on_confirm)
	NetworkManager.loadout_accepted.connect(_on_loadout_accepted)
	NetworkManager.loadout_rejected.connect(_on_loadout_rejected)
	NetworkManager.match_preparation_changed.connect(_refresh_confirm)
	_refresh_all()


func _wire_map_picker() -> void:
	_rebuild_map_options()
	_map_option.item_selected.connect(_on_map_selected)
	_refresh_map_ui()


func _rebuild_map_options() -> void:
	var index := NetworkManager.get_selected_map()
	_map_option.clear()
	for i in MapCatalog.map_count():
		_map_option.add_item(tr(MapCatalog.name_key(i)), i)
	if _map_option.item_count > 0:
		_map_option.select(clampi(index, 0, _map_option.item_count - 1))


func _on_map_selected(index: int) -> void:
	if not multiplayer.is_server():
		return
	NetworkManager.set_selected_map(index)


func _refresh_map_ui() -> void:
	var index := NetworkManager.get_selected_map()
	index = clampi(index, 0, maxi(_map_option.item_count - 1, 0))
	var can_pick := multiplayer.is_server()
	_map_option.disabled = not can_pick
	if _map_option.item_count > 0 and _map_option.selected != index:
		_map_option.set_block_signals(true)
		_map_option.select(index)
		_map_option.set_block_signals(false)


func _wire_stats() -> void:
	for key in STAT_ROWS.keys():
		var row := get_node("%s/%sRow" % [STATS_COLUMN, _row_name(key)])
		row.get_node("PlusButton").pressed.connect(_on_stat_plus.bind(key))
		row.get_node("MinusButton").pressed.connect(_on_stat_minus.bind(key))
	var hollow := get_node("%s/HollowRow" % STATS_COLUMN)
	hollow.get_node("PlusButton").pressed.connect(_on_hollow_plus)
	hollow.get_node("MinusButton").pressed.connect(_on_hollow_minus)


func _row_name(key: String) -> String:
	match key:
		"hp": return "Hp"
		"speed": return "Speed"
		"stamina": return "Stamina"
		"dash": return "Dash"
		"vision": return "Vision"
		_: return key


func _wire_slots() -> void:
	for i in 3:
		var slot := _slot_root(i)
		var cells: HBoxContainer = slot.get_node("SlotCells")
		var slot_idx := i
		cells.get_node("ElementCell").pressed.connect(
			func() -> void: _open_cell_picker(slot_idx, &"element", cells.get_node("ElementCell"))
		)
		cells.get_node("FormCell").pressed.connect(
			func() -> void: _open_cell_picker(slot_idx, &"form", cells.get_node("FormCell"))
		)
		for ch in PrepRules.SpellChannel.values():
			var row := slot.get_node("ParamRows/%sRow" % _channel_row_name(ch))
			row.get_node("PlusButton").pressed.connect(_on_spell_plus.bind(i, ch))
			row.get_node("MinusButton").pressed.connect(_on_spell_minus.bind(i, ch))


func _slot_root(index: int) -> VBoxContainer:
	match index:
		0: return %LmbSlot
		1: return %RmbSlot
		2: return %MmbSlot
	return null


func _channel_row_name(ch: PrepRules.SpellChannel) -> String:
	match ch:
		PrepRules.SpellChannel.POWER: return "Power"
		PrepRules.SpellChannel.AREA: return "Area"
		PrepRules.SpellChannel.CAST_RANGE: return "Range"
		PrepRules.SpellChannel.DURATION: return "Duration"
		PrepRules.SpellChannel.OBJECT_HP: return "ObjectHp"
	return ""


func _slot_configured(slot: int) -> bool:
	var draft := drafts[slot]
	return draft.element >= 0 and draft.form >= 0


func _open_cell_picker(slot: int, kind: StringName, anchor: Control) -> void:
	if kind == &"form" and drafts[slot].element < 0:
		_status.text = "%s → %s" % [tr("prep.element"), tr("prep.form")]
		return
	_status.text = ""
	_pick_slot = slot
	_pick_kind = kind
	_icon_picker.picker_kind = kind
	_icon_picker.refresh_tooltips()
	var draft := drafts[slot]
	var current_id := draft.element if kind == &"element" else draft.form
	_icon_picker.set_selected(current_id)
	var rect := anchor.get_global_rect()
	var popup_pos := Vector2i(int(rect.position.x), int(rect.position.y + rect.size.y + 4))
	var popup_size := Vector2i(_icon_popup.size)
	if popup_size.x < 16:
		popup_size = Vector2i(220, 260)
	_icon_popup.popup(Rect2i(popup_pos, popup_size))


func _on_popup_pick(id: int) -> void:
	_icon_popup.hide()
	if _pick_slot < 0:
		return
	if _pick_kind == &"element":
		_on_element_changed(_pick_slot, id)
	else:
		_on_form_changed(_pick_slot, id)
	_pick_slot = -1


func _on_stat_plus(key: String) -> void:
	var info: Dictionary = STAT_ROWS[key]
	var method: Callable = Callable(stats, info["upgrade"])
	if method.call():
		_refresh_all()
		_invalidate_accepted_loadout()


func _on_stat_minus(key: String) -> void:
	var info: Dictionary = STAT_ROWS[key]
	var method: Callable = Callable(stats, info["downgrade"])
	if method.call():
		_refresh_all()
		_invalidate_accepted_loadout()


func _on_hollow_plus() -> void:
	if stats.try_purchase_hollow():
		_refresh_all()
		_invalidate_accepted_loadout()


func _on_hollow_minus() -> void:
	if stats.try_refund_hollow():
		_refresh_all()
		_invalidate_accepted_loadout()


func _on_element_changed(slot: int, el: int) -> void:
	var draft := drafts[slot]
	if el < 0:
		if draft.form < 0:
			PrepRules.refund_slot(stats, draft)
		else:
			draft.element = -1
	else:
		draft.element = el
	_refresh_slot(slot)
	_refresh_essence()
	_invalidate_accepted_loadout()


func _on_form_changed(slot: int, fo: int) -> void:
	var draft := drafts[slot]
	if fo < 0:
		PrepRules.refund_slot(stats, draft)
	else:
		if draft.element < 0:
			return
		PrepRules.set_slot_form(stats, draft, fo)
	_refresh_slot(slot)
	_refresh_essence()
	_invalidate_accepted_loadout()


func _on_spell_plus(slot: int, channel: PrepRules.SpellChannel) -> void:
	if PrepRules.try_upgrade_spell(stats, drafts[slot], channel):
		_refresh_slot(slot)
		_refresh_essence()
		_invalidate_accepted_loadout()


func _on_spell_minus(slot: int, channel: PrepRules.SpellChannel) -> void:
	if PrepRules.try_downgrade_spell(stats, drafts[slot], channel):
		_refresh_slot(slot)
		_refresh_essence()
		_invalidate_accepted_loadout()


func _invalidate_accepted_loadout() -> void:
	NetworkManager.revoke_local_loadout_acceptance()
	_refresh_confirm()


func _refresh_all() -> void:
	_refresh_essence()
	for key in STAT_ROWS.keys():
		_refresh_stat_row(key)
	_refresh_hollow()
	for i in 3:
		_refresh_slot(i)
	_refresh_confirm()


func _refresh_essence() -> void:
	_essence.text = "%s: %d" % [tr("prep.essence"), stats.essence]


func _refresh_stat_row(key: String) -> void:
	var info: Dictionary = STAT_ROWS[key]
	var row := get_node("%s/%sRow" % [STATS_COLUMN, _row_name(key)])
	var rank: int = stats.get(info["rank"])
	var value = stats.get(info["value"])
	row.get_node("ValueLabel").text = str(snappedf(float(value), 0.01))
	var cap: float = info["cap"]
	row.get_node("MinusButton").disabled = rank <= 0
	if float(value) >= cap:
		row.get_node("CostLabel").text = "—"
		row.get_node("PlusButton").disabled = true
	else:
		var cost: int = info["cost_base"] + rank * info["cost_growth"]
		row.get_node("CostLabel").text = str(cost)
		row.get_node("PlusButton").disabled = stats.essence < cost


func _refresh_hollow() -> void:
	var row := get_node("%s/HollowRow" % STATS_COLUMN)
	var bought := stats.body_hollow
	row.get_node("ValueLabel").text = tr("prep.hollow_on") if bought else tr("prep.solid")
	row.get_node("MinusButton").disabled = not bought
	if bought:
		row.get_node("CostLabel").text = "—"
		row.get_node("PlusButton").disabled = true
	else:
		row.get_node("CostLabel").text = str(PlayerStats.HOLLOW_COST)
		row.get_node("PlusButton").disabled = stats.essence < PlayerStats.HOLLOW_COST


func _refresh_slot(slot: int) -> void:
	var draft := drafts[slot]
	var root := _slot_root(slot)
	var configured := _slot_configured(slot)
	var params: VBoxContainer = root.get_node("ParamRows")
	params.visible = configured
	_update_cells(slot)
	if not configured:
		return
	var form: int = draft.form
	for ch in PrepRules.SpellChannel.values():
		var row := root.get_node("ParamRows/%sRow" % _channel_row_name(ch))
		var uses := PrepRules.form_uses_channel(form, ch)
		row.visible = uses
		if not uses:
			continue
		var rank := draft.get_rank(ch)
		row.get_node("ValueLabel").text = str(rank)
		var cost := PrepRules.spell_upgrade_cost(form, ch, rank)
		row.get_node("MinusButton").disabled = rank <= 0
		if cost < 0:
			row.get_node("CostLabel").text = "—"
			row.get_node("PlusButton").disabled = true
		else:
			row.get_node("CostLabel").text = str(cost)
			row.get_node("PlusButton").disabled = stats.essence < cost


func _update_cells(slot: int) -> void:
	var root := _slot_root(slot)
	var el_btn: TextureButton = root.get_node("SlotCells/ElementCell")
	var fo_btn: TextureButton = root.get_node("SlotCells/FormCell")
	var draft := drafts[slot]
	el_btn.texture_normal = SpellUiCatalog.element_texture(draft.element)
	fo_btn.texture_normal = SpellUiCatalog.form_texture(draft.form)
	el_btn.modulate = Color.WHITE if draft.element >= 0 else Color(0.75, 0.78, 0.85)
	fo_btn.modulate = Color.WHITE if draft.form >= 0 else Color(0.75, 0.78, 0.85)


func _build_stat_ranks() -> PackedInt32Array:
	return PackedInt32Array([
		stats.move_speed_rank,
		stats.max_stamina_rank,
		stats.dash_rank,
		stats.vision_rank,
		stats.hp_rank,
		1 if stats.body_hollow else 0,
	])


func _build_spell_arrays() -> Dictionary:
	var elements := PackedInt32Array()
	var forms := PackedInt32Array()
	var ranks := PackedInt32Array()
	for draft in drafts:
		elements.append(draft.element)
		forms.append(draft.form)
		ranks.append(draft.power_rank)
		ranks.append(draft.area_rank)
		ranks.append(draft.cast_range_rank)
		ranks.append(draft.duration_rank)
		ranks.append(draft.object_hp_rank)
	return {"elements": elements, "forms": forms, "spell_ranks": ranks}


func _submit_draft() -> void:
	var packed := _build_spell_arrays()
	NetworkManager.submit_loadout_from_local(
		_build_stat_ranks(),
		packed["elements"],
		packed["forms"],
		packed["spell_ranks"]
	)


func _on_confirm() -> void:
	var my_id := multiplayer.get_unique_id()
	if not NetworkManager.has_accepted_loadout(my_id):
		_submit_draft()
		return
	if multiplayer.is_server() and NetworkManager.all_peers_ready():
		NetworkManager.start_match()


func _refresh_confirm() -> void:
	var my_id := multiplayer.get_unique_id()
	var accepted := NetworkManager.has_accepted_loadout(my_id)
	if NetworkManager.mode == NetworkManager.SessionMode.CLIENT:
		_confirm.text = tr("prep.ready")
		_confirm.disabled = false
		return
	if NetworkManager.all_peers_ready():
		_confirm.text = tr("prep.start")
		_confirm.disabled = false
	elif accepted:
		_confirm.text = tr("prep.waiting")
		_confirm.disabled = true
	else:
		_confirm.text = tr("prep.ready")
		_confirm.disabled = false


func _on_loadout_accepted(_peer_id: int) -> void:
	_status.text = ""
	_refresh_confirm()


func _on_loadout_rejected() -> void:
	_status.text = tr("prep.rejected")
	_refresh_confirm()


func _on_settings() -> void:
	Settings.return_scene = scene_file_path
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _localize_static_labels() -> void:
	_localize_node(self)


func _localize_node(node: Node) -> void:
	if node is Label:
		var text := (node as Label).text
		if text.contains(".") and text != "+":
			(node as Label).text = tr(text)
	elif node is Button:
		var btext := (node as Button).text
		if btext.contains(".") and btext != "+":
			(node as Button).text = tr(btext)
	for child in node.get_children():
		_localize_node(child)
