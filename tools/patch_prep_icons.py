from pathlib import Path

path = Path(r"c:\Users\haqury\Documents\magic-something-other\scenes\prep\prep.tscn")
text = path.read_text(encoding="utf-8")
if "spell_icon_picker.tscn" not in text:
    text = text.replace(
        '[ext_resource type="Script" path="res://scenes/prep/prep.gd" id="1"]\n',
        '[ext_resource type="Script" path="res://scenes/prep/prep.gd" id="1"]\n'
        '[ext_resource type="PackedScene" uid="uid://spelliconpicker" path="res://scenes/prep/spell_icon_picker.tscn" id="2"]\n',
    )
    text = text.replace("load_steps=2", "load_steps=3")

repls = [
    (
        '[node name="ElementOption" type="OptionButton" parent="MarginContainer/HBoxContainer/SpellsColumn/LmbSlot"]\nlayout_mode = 2\n\n[node name="FormOption" type="OptionButton" parent="MarginContainer/HBoxContainer/SpellsColumn/LmbSlot"]\nlayout_mode = 2\n',
        '[node name="ElementPicker" parent="MarginContainer/HBoxContainer/SpellsColumn/LmbSlot" instance=ExtResource("2")]\nlayout_mode = 2\npicker_kind = &"element"\n\n[node name="FormPicker" parent="MarginContainer/HBoxContainer/SpellsColumn/LmbSlot" instance=ExtResource("2")]\nlayout_mode = 2\npicker_kind = &"form"\n',
    ),
    (
        '[node name="ElementOption" type="OptionButton" parent="MarginContainer/HBoxContainer/SpellsColumn/RmbSlot"]\nlayout_mode = 2\n\n[node name="FormOption" type="OptionButton" parent="MarginContainer/HBoxContainer/SpellsColumn/RmbSlot"]\nlayout_mode = 2\n',
        '[node name="ElementPicker" parent="MarginContainer/HBoxContainer/SpellsColumn/RmbSlot" instance=ExtResource("2")]\nlayout_mode = 2\npicker_kind = &"element"\n\n[node name="FormPicker" parent="MarginContainer/HBoxContainer/SpellsColumn/RmbSlot" instance=ExtResource("2")]\nlayout_mode = 2\npicker_kind = &"form"\n',
    ),
    (
        '[node name="ElementOption" type="OptionButton" parent="MarginContainer/HBoxContainer/SpellsColumn/MmbSlot"]\nlayout_mode = 2\n\n[node name="FormOption" type="OptionButton" parent="MarginContainer/HBoxContainer/SpellsColumn/MmbSlot"]\nlayout_mode = 2\n',
        '[node name="ElementPicker" parent="MarginContainer/HBoxContainer/SpellsColumn/MmbSlot" instance=ExtResource("2")]\nlayout_mode = 2\npicker_kind = &"element"\n\n[node name="FormPicker" parent="MarginContainer/HBoxContainer/SpellsColumn/MmbSlot" instance=ExtResource("2")]\nlayout_mode = 2\npicker_kind = &"form"\n',
    ),
]
for a, b in repls:
    if a in text:
        text = text.replace(a, b)
path.write_text(text, encoding="utf-8")
print("prep.tscn patched")