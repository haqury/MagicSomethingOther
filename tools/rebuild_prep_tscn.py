"""Regenerate scenes/prep/prep.tscn (compact layout, fits 1280x720)."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "scenes" / "prep" / "prep.tscn"

STAT_ROWS = [
	("HpRow", "prep.hp"),
	("SpeedRow", "prep.speed"),
	("StaminaRow", "prep.stamina"),
	("DashRow", "prep.dash"),
	("VisionRow", "prep.vision"),
]

SPELL_SLOTS = [
	("LmbSlot", "prep.spell_lmb"),
	("RmbSlot", "prep.spell_rmb"),
	("MmbSlot", "prep.spell_mmb"),
]

PARAM_ROWS = [
	("PowerRow", "prep.power"),
	("AreaRow", "prep.area"),
	("RangeRow", "prep.range"),
	("DurationRow", "prep.duration"),
	("ObjectHpRow", "prep.object_hp"),
]


def row_nodes(parent: str) -> str:
	return f"""
[node name="NameLabel" type="Label" parent="{parent}"]
custom_minimum_size = Vector2(72, 0)
layout_mode = 2
text = "STAT_PLACEHOLDER"
clip_text = true

[node name="ValueLabel" type="Label" parent="{parent}"]
custom_minimum_size = Vector2(28, 0)
layout_mode = 2
horizontal_alignment = 2

[node name="CostLabel" type="Label" parent="{parent}"]
custom_minimum_size = Vector2(24, 0)
layout_mode = 2
horizontal_alignment = 2

[node name="MinusButton" type="Button" parent="{parent}"]
custom_minimum_size = Vector2(28, 28)
layout_mode = 2
text = "-"

[node name="PlusButton" type="Button" parent="{parent}"]
custom_minimum_size = Vector2(28, 28)
layout_mode = 2
text = "+"
"""


def build() -> str:
	lines: list[str] = []
	append = lines.append
	root = "MarginContainer/MainVBox"

	append('[gd_scene load_steps=3 format=3 uid="uid://c26vwj8ng34x"]')
	append("")
	append('[ext_resource type="Script" uid="uid://dx5lmdd0tivsa" path="res://scenes/prep/prep.gd" id="1"]')
	append('[ext_resource type="PackedScene" path="res://scenes/prep/spell_icon_picker.tscn" id="2"]')
	append("")
	append('[node name="Prep" type="Control"]')
	append("layout_mode = 3")
	append("anchors_preset = 15")
	append("anchor_right = 1.0")
	append("anchor_bottom = 1.0")
	append("grow_horizontal = 2")
	append("grow_vertical = 2")
	append('script = ExtResource("1")')
	append("")

	append('[node name="IconSelectPopup" type="PopupPanel" parent="."]')
	append("size = Vector2i(220, 260)")
	append("")
	append('[node name="Margin" type="MarginContainer" parent="IconSelectPopup"]')
	append("offset_left = 4.0")
	append("offset_top = 4.0")
	append("offset_right = 216.0")
	append("offset_bottom = 256.0")
	append("theme_override_constants/margin_left = 8")
	append("theme_override_constants/margin_top = 8")
	append("theme_override_constants/margin_right = 8")
	append("theme_override_constants/margin_bottom = 8")
	append("")
	append('[node name="IconPicker" parent="IconSelectPopup/Margin" instance=ExtResource("2")]')
	append("layout_mode = 2")
	append("")

	append('[node name="MarginContainer" type="MarginContainer" parent="."]')
	append("layout_mode = 1")
	append("anchors_preset = 15")
	append("anchor_right = 1.0")
	append("anchor_bottom = 1.0")
	append("grow_horizontal = 2")
	append("grow_vertical = 2")
	append("theme_override_constants/margin_left = 12")
	append("theme_override_constants/margin_top = 12")
	append("theme_override_constants/margin_right = 12")
	append("theme_override_constants/margin_bottom = 12")
	append("")

	append(f'[node name="MainVBox" type="VBoxContainer" parent="MarginContainer"]')
	append("layout_mode = 2")
	append("theme_override_constants/separation = 8")
	append("")

	top = f"{root}/TopBar"
	append(f'[node name="TopBar" type="HBoxContainer" parent="{root}"]')
	append("layout_mode = 2")
	append("theme_override_constants/separation = 10")
	append("")
	append(f'[node name="EssenceLabel" type="Label" parent="{top}"]')
	append("unique_name_in_owner = true")
	append("layout_mode = 2")
	append('text = "prep.essence"')
	append("")
	append(f'[node name="MapLabel" type="Label" parent="{top}"]')
	append("layout_mode = 2")
	append('text = "prep.map"')
	append("")
	append(f'[node name="MapOption" type="OptionButton" parent="{top}"]')
	append("unique_name_in_owner = true")
	append("custom_minimum_size = Vector2(140, 0)")
	append("layout_mode = 2")
	append("size_flags_horizontal = 3")
	append("clip_text = true")
	append("")
	append(f'[node name="TopSpacer" type="Control" parent="{top}"]')
	append("layout_mode = 2")
	append("size_flags_horizontal = 3")
	append("")
	append(f'[node name="ConfirmButton" type="Button" parent="{top}"]')
	append("unique_name_in_owner = true")
	append("layout_mode = 2")
	append('text = "prep.ready"')
	append("")
	append(f'[node name="SettingsButton" type="Button" parent="{top}"]')
	append("unique_name_in_owner = true")
	append("layout_mode = 2")
	append('text = "menu.settings"')
	append("")

	append(f'[node name="StatusLabel" type="Label" parent="{root}"]')
	append("unique_name_in_owner = true")
	append("layout_mode = 2")
	append("autowrap_mode = 3")
	append("")

	body = f"{root}/BodyHBox"
	append(f'[node name="BodyHBox" type="HBoxContainer" parent="{root}"]')
	append("layout_mode = 2")
	append("size_flags_vertical = 3")
	append("theme_override_constants/separation = 12")
	append("")

	stats = f"{body}/StatsColumn"
	append(f'[node name="StatsColumn" type="VBoxContainer" parent="{body}"]')
	append("layout_mode = 2")
	append("size_flags_horizontal = 0")
	append("theme_override_constants/separation = 4")
	append("")

	append(f'[node name="StatsTitle" type="Label" parent="{stats}"]')
	append("layout_mode = 2")
	append('text = "prep.title"')
	append("")

	for row_name, locale_key in STAT_ROWS:
		parent = f"{stats}/{row_name}"
		append(f'[node name="{row_name}" type="HBoxContainer" parent="{stats}"]')
		append("layout_mode = 2")
		append("theme_override_constants/separation = 4")
		block = row_nodes(parent).replace("STAT_PLACEHOLDER", locale_key)
		append(block.strip())
		append("")

	scroll = f"{body}/SpellsScroll"
	append(f'[node name="SpellsScroll" type="ScrollContainer" parent="{body}"]')
	append("layout_mode = 2")
	append("size_flags_horizontal = 3")
	append("size_flags_vertical = 3")
	append("horizontal_scroll_mode = 1")
	append("vertical_scroll_mode = 0")
	append("")

	spells = f"{scroll}/SpellsColumn"
	append(f'[node name="SpellsColumn" type="HBoxContainer" parent="{scroll}"]')
	append("layout_mode = 2")
	append("theme_override_constants/separation = 12")
	append("")

	for slot_name, title_key in SPELL_SLOTS:
		slot_parent = f"{spells}/{slot_name}"
		append(f'[node name="{slot_name}" type="VBoxContainer" parent="{spells}"]')
		append("unique_name_in_owner = true")
		append("layout_mode = 2")
		append("size_flags_horizontal = 0")
		append("theme_override_constants/separation = 6")
		append("")
		append(f'[node name="Title" type="Label" parent="{slot_parent}"]')
		append("layout_mode = 2")
		append(f'text = "{title_key}"')
		append("")
		append(f'[node name="SlotCells" type="HBoxContainer" parent="{slot_parent}"]')
		append("layout_mode = 2")
		append("theme_override_constants/separation = 6")
		append("")
		for cell in ("ElementCell", "FormCell"):
			append(f'[node name="{cell}" type="TextureButton" parent="{slot_parent}/SlotCells"]')
			append("custom_minimum_size = Vector2(44, 44)")
			append("layout_mode = 2")
			append("ignore_texture_size = true")
			append("stretch_mode = 5")
			append("")
		append(f'[node name="ParamRows" type="VBoxContainer" parent="{slot_parent}"]')
		append("visible = false")
		append("layout_mode = 2")
		append("theme_override_constants/separation = 2")
		append("")
		for prow_name, plocale in PARAM_ROWS:
			row_parent = f"{slot_parent}/ParamRows/{prow_name}"
			append(f'[node name="{prow_name}" type="HBoxContainer" parent="{slot_parent}/ParamRows"]')
			append("layout_mode = 2")
			append("theme_override_constants/separation = 4")
			block = row_nodes(row_parent).replace("STAT_PLACEHOLDER", plocale)
			append(block.strip())
			append("")

	text = "\n".join(lines)
	OUT.write_text(text, encoding="utf-8")
	print(f"wrote {OUT} ({text.count('[node name=')} nodes)")


if __name__ == "__main__":
	build()