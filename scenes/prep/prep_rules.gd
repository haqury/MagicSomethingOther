class_name PrepRules
extends RefCounted

const START_ESSENCE := 100

const STAT_DEFAULT_PATH := "res://data/player_stats_default.tres"
const SPELL_BASE_PATH := "res://data/spells/spell_base.tres"

enum SpellChannel { POWER, AREA, CAST_RANGE, DURATION, OBJECT_HP }

class SpellSlotDraft:
	var element: int = -1
	var form: int = -1
	var power_rank: int = 0
	var area_rank: int = 0
	var cast_range_rank: int = 0
	var duration_rank: int = 0
	var object_hp_rank: int = 0

	func get_rank(channel: SpellChannel) -> int:
		match channel:
			SpellChannel.POWER:
				return power_rank
			SpellChannel.AREA:
				return area_rank
			SpellChannel.CAST_RANGE:
				return cast_range_rank
			SpellChannel.DURATION:
				return duration_rank
			SpellChannel.OBJECT_HP:
				return object_hp_rank
		return 0

	func set_rank(channel: SpellChannel, value: int) -> void:
		match channel:
			SpellChannel.POWER:
				power_rank = value
			SpellChannel.AREA:
				area_rank = value
			SpellChannel.CAST_RANGE:
				cast_range_rank = value
			SpellChannel.DURATION:
				duration_rank = value
			SpellChannel.OBJECT_HP:
				object_hp_rank = value

static var _channel_meta: Dictionary = {
	SpellChannel.POWER: {"step": 2.0, "base_cost": 8, "growth": 4, "max_rank": 5},
	SpellChannel.AREA: {"step": 0.25, "base_cost": 8, "growth": 4, "max_rank": 4},
	SpellChannel.CAST_RANGE: {"step": 40.0, "base_cost": 6, "growth": 3, "max_rank": 5},
	SpellChannel.DURATION: {"step": 0.5, "base_cost": 6, "growth": 3, "max_rank": 4},
	SpellChannel.OBJECT_HP: {"step": 20.0, "base_cost": 8, "growth": 4, "max_rank": 5},
}

static var _install_cost: Dictionary = {
	SpellData.Form.PROJECTILE: 0,
	SpellData.Form.SELF: 10,
	SpellData.Form.AREA: 15,
	SpellData.Form.BEAM: 15,
	SpellData.Form.AROUND: 15,
	SpellData.Form.WALL: 20,
	SpellData.Form.MINE: 20,
	SpellData.Form.RELIEF: 15,
}

static var _form_fields: Dictionary = {
	SpellData.Form.PROJECTILE: [SpellChannel.POWER, SpellChannel.AREA, SpellChannel.CAST_RANGE, SpellChannel.DURATION],
	SpellData.Form.AREA: [SpellChannel.POWER, SpellChannel.AREA, SpellChannel.CAST_RANGE, SpellChannel.DURATION],
	SpellData.Form.WALL: [SpellChannel.AREA, SpellChannel.CAST_RANGE, SpellChannel.DURATION, SpellChannel.OBJECT_HP],
	SpellData.Form.BEAM: [SpellChannel.POWER, SpellChannel.CAST_RANGE],
	SpellData.Form.SELF: [SpellChannel.POWER],
	SpellData.Form.AROUND: [SpellChannel.POWER, SpellChannel.AREA],
	SpellData.Form.MINE: [SpellChannel.POWER, SpellChannel.AREA, SpellChannel.CAST_RANGE, SpellChannel.DURATION, SpellChannel.OBJECT_HP],
	SpellData.Form.RELIEF: [SpellChannel.CAST_RANGE],
}

static var _form_bases: Dictionary = {
	SpellData.Form.PROJECTILE: {"power": 10.0, "area": 1.0, "cast_range": 480.0, "duration": 1.5},
	SpellData.Form.AREA: {"power": 10.0, "area": 1.0, "cast_range": 280.0, "duration": 2.0},
	SpellData.Form.WALL: {"area": 1.0, "cast_range": 280.0, "duration": 8.0, "object_hp": 60.0},
	SpellData.Form.BEAM: {"power": 10.0, "cast_range": 400.0},
	SpellData.Form.SELF: {"power": 10.0},
	SpellData.Form.AROUND: {"power": 10.0, "area": 1.0},
	SpellData.Form.MINE: {"power": 10.0, "area": 1.0, "cast_range": 280.0, "duration": 10.0, "object_hp": 30.0},
	SpellData.Form.RELIEF: {"cast_range": 280.0},
}

static var _form_scenes: Dictionary = {
	SpellData.Form.PROJECTILE: "res://scenes/spells/projectile.tscn",
	SpellData.Form.AREA: "res://scenes/spells/area_zone.tscn",
	SpellData.Form.WALL: "res://scenes/spells/destructible_wall.tscn",
	SpellData.Form.BEAM: "res://scenes/spells/beam_flash.tscn",
	SpellData.Form.SELF: "res://scenes/spells/self_flash.tscn",
	SpellData.Form.AROUND: "res://scenes/spells/nova_flash.tscn",
	SpellData.Form.MINE: "res://scenes/spells/mine.tscn",
}


static func make_prep_stats() -> PlayerStats:
	var stats: PlayerStats = load(STAT_DEFAULT_PATH).duplicate(true) as PlayerStats
	stats.essence = START_ESSENCE
	return stats


static func form_uses_channel(form: int, channel: SpellChannel) -> bool:
	if form < 0 or form >= SpellData.Form.size():
		return false
	var channels: Array = _form_fields.get(form, [])
	return channel in channels


static func spell_upgrade_cost(form: int, channel: SpellChannel, rank: int) -> int:
	if not form_uses_channel(form, channel):
		return -1
	var meta: Dictionary = _channel_meta[channel]
	if rank >= meta["max_rank"]:
		return -1
	return meta["base_cost"] + rank * meta["growth"]


static func try_upgrade_spell(stats: PlayerStats, draft: SpellSlotDraft, channel: SpellChannel) -> bool:
	if draft.form < 0 or draft.element < 0:
		return false
	if not form_uses_channel(draft.form, channel):
		return false
	var rank := draft.get_rank(channel)
	var cost := spell_upgrade_cost(draft.form, channel, rank)
	if cost < 0:
		return false
	if not stats.try_spend(cost):
		return false
	draft.set_rank(channel, rank + 1)
	return true


static func try_downgrade_spell(stats: PlayerStats, draft: SpellSlotDraft, channel: SpellChannel) -> bool:
	if draft.form < 0 or draft.element < 0:
		return false
	if not form_uses_channel(draft.form, channel):
		return false
	var rank := draft.get_rank(channel)
	if rank <= 0:
		return false
	var refund := spell_upgrade_cost(draft.form, channel, rank - 1)
	if refund < 0:
		return false
	draft.set_rank(channel, rank - 1)
	stats.essence += refund
	return true


static func slot_total_cost(_stats: PlayerStats, draft: SpellSlotDraft) -> int:
	if draft.element < 0 and draft.form < 0:
		return 0
	if draft.element < 0 or draft.form < 0:
		return -1
	var total := _install_cost.get(draft.form, 0) as int
	for channel in _channel_meta.keys():
		if not form_uses_channel(draft.form, channel):
			continue
		var rank := draft.get_rank(channel)
		for r in range(rank):
			total += spell_upgrade_cost(draft.form, channel, r)
	return total


static func refund_slot(stats: PlayerStats, draft: SpellSlotDraft) -> void:
	var refund := slot_total_cost(stats, draft)
	if refund > 0:
		stats.essence += refund
	draft.element = -1
	draft.form = -1
	draft.power_rank = 0
	draft.area_rank = 0
	draft.cast_range_rank = 0
	draft.duration_rank = 0
	draft.object_hp_rank = 0


static func set_slot_form(stats: PlayerStats, draft: SpellSlotDraft, new_form: int) -> bool:
	if new_form < 0:
		refund_slot(stats, draft)
		return true
	if draft.element < 0:
		draft.form = -1
		return false
	if draft.form >= 0:
		var refund := slot_total_cost(stats, draft)
		if refund < 0:
			return false
		stats.essence += refund
		draft.power_rank = 0
		draft.area_rank = 0
		draft.cast_range_rank = 0
		draft.duration_rank = 0
		draft.object_hp_rank = 0
	draft.form = new_form
	var install: int = _install_cost.get(new_form, 0)
	if not stats.try_spend(install):
		draft.form = -1
		return false
	return true


static func set_slot_element(draft: SpellSlotDraft, new_element: int) -> void:
	draft.element = new_element


static func clear_slot_if_empty(stats: PlayerStats, draft: SpellSlotDraft) -> void:
	if draft.element < 0 and draft.form < 0:
		refund_slot(stats, draft)


static func apply_rank_value(base: float, channel: SpellChannel, rank: int) -> float:
	var meta: Dictionary = _channel_meta[channel]
	return base + meta["step"] * float(rank)


static func build_spell_data(element: int, form: int, draft: SpellSlotDraft) -> SpellData:
	var spell: SpellData = load(SPELL_BASE_PATH).duplicate(true) as SpellData
	spell.element = element as SpellData.Element
	spell.form = form as SpellData.Form
	var bases: Dictionary = _form_bases.get(form, {})
	if bases.has("power"):
		spell.power = apply_rank_value(bases["power"], SpellChannel.POWER, draft.power_rank)
	if bases.has("area"):
		spell.area = apply_rank_value(bases["area"], SpellChannel.AREA, draft.area_rank)
	if bases.has("cast_range"):
		spell.cast_range = apply_rank_value(bases["cast_range"], SpellChannel.CAST_RANGE, draft.cast_range_rank)
	if bases.has("duration"):
		spell.duration = apply_rank_value(bases["duration"], SpellChannel.DURATION, draft.duration_rank)
	if bases.has("object_hp"):
		spell.object_hp = apply_rank_value(bases["object_hp"], SpellChannel.OBJECT_HP, draft.object_hp_rank)
	var scene_path: String = _form_scenes.get(form, "")
	if not scene_path.is_empty():
		spell.scene = load(scene_path) as PackedScene
	return spell


static func build_loadout_from_ranks(
	stat_ranks: PackedInt32Array,
	elements: PackedInt32Array,
	forms: PackedInt32Array,
	spell_ranks: PackedInt32Array
) -> Loadout:
	if stat_ranks.size() != 6 or elements.size() != 3 or forms.size() != 3 or spell_ranks.size() != 15:
		return null
	var stats := make_prep_stats()
	var stat_counts: Array[int] = [
		stat_ranks[0], stat_ranks[1], stat_ranks[2], stat_ranks[3], stat_ranks[4]
	]
	for count in stat_counts:
		if count < 0:
			return null
	for _j in stat_counts[0]:
		if not stats.try_upgrade_move_speed():
			return null
	for _j in stat_counts[1]:
		if not stats.try_upgrade_max_stamina():
			return null
	for _j in stat_counts[2]:
		if not stats.try_upgrade_dash_multiplier():
			return null
	for _j in stat_counts[3]:
		if not stats.try_upgrade_vision_zoom():
			return null
	for _j in stat_counts[4]:
		if not stats.try_upgrade_max_hp():
			return null
	if stat_ranks[5] == 1:
		if not stats.try_purchase_hollow():
			return null
	elif stat_ranks[5] != 0:
		return null
	var spells: Array[SpellData] = []
	for slot in 3:
		var el: int = elements[slot]
		var fo: int = forms[slot]
		if el < 0 and fo < 0:
			spells.append(null)
			continue
		if (el < 0) != (fo < 0):
			return null
		if el < 0 or el >= SpellData.Element.size() or fo < 0 or fo >= SpellData.Form.size():
			return null
		var draft := SpellSlotDraft.new()
		draft.element = el
		draft.form = fo
		var base_idx := slot * 5
		draft.power_rank = spell_ranks[base_idx]
		draft.area_rank = spell_ranks[base_idx + 1]
		draft.cast_range_rank = spell_ranks[base_idx + 2]
		draft.duration_rank = spell_ranks[base_idx + 3]
		draft.object_hp_rank = spell_ranks[base_idx + 4]
		for channel in _channel_meta.keys():
			if not form_uses_channel(fo, channel):
				if draft.get_rank(channel) != 0:
					return null
				continue
			var mr: int = _channel_meta[channel]["max_rank"]
			if draft.get_rank(channel) < 0 or draft.get_rank(channel) > mr:
				return null
		var install: int = _install_cost.get(fo, 0)
		if not stats.try_spend(install):
			return null
		for channel in _channel_meta.keys():
			if not form_uses_channel(fo, channel):
				continue
			for r in draft.get_rank(channel):
				var cost := spell_upgrade_cost(fo, channel, r)
				if cost < 0 or not stats.try_spend(cost):
					return null
		spells.append(build_spell_data(el, fo, draft))
	var loadout := Loadout.new()
	loadout.stats = stats
	loadout.spell_lmb = spells[0]
	loadout.spell_rmb = spells[1]
	loadout.spell_mmb = spells[2]
	return loadout