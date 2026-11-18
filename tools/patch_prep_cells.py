from pathlib import Path

path = Path(r"c:\Users\haqury\Documents\magic-something-other\scenes\prep\prep.tscn")
text = path.read_text(encoding="utf-8")

cell_block = """[node name="SlotCells" type="HBoxContainer" parent="{parent}"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="ElementCell" type="TextureButton" parent="{parent}/SlotCells"]
custom_minimum_size = Vector2(52, 52)
ignore_texture_size = true
stretch_mode = 5

[node name="FormCell" type="TextureButton" parent="{parent}/SlotCells"]
custom_minimum_size = Vector2(52, 52)
ignore_texture_size = true
stretch_mode = 5

"""

for slot in ("LmbSlot", "RmbSlot", "MmbSlot"):
    parent = f"MarginContainer/HBoxContainer/SpellsColumn/{slot}"
    old = (
        f'[node name="ElementPicker" parent="{parent}" instance=ExtResource("2")]\n'
        f"layout_mode = 2\n"
        f'picker_kind = &"element"\n\n'
        f'[node name="FormPicker" parent="{parent}" instance=ExtResource("2")]\n'
        f"layout_mode = 2\n"
        f'picker_kind = &"form"\n\n'
    )
    if old in text:
        text = text.replace(old, cell_block.format(parent=parent))

if "IconSelectPopup" not in text:
    popup = """
[node name="IconSelectPopup" type="PopupPanel" parent="."]
size = Vector2i(220, 260)

[node name="Margin" type="MarginContainer" parent="IconSelectPopup"]
layout_mode = 2
theme_override_constants/margin_left = 8
theme_override_constants/margin_top = 8
theme_override_constants/margin_right = 8
theme_override_constants/margin_bottom = 8

[node name="IconPicker" parent="IconSelectPopup/Margin" instance=ExtResource("2")]
layout_mode = 2
picker_kind = &"element"
"""
    text = text.replace(
        '[node name="MarginContainer" type="MarginContainer" parent="."]',
        '[node name="IconSelectPopup" type="PopupPanel" parent="."]\nsize = Vector2i(220, 260)\n\n[node name="Margin" type="MarginContainer" parent="IconSelectPopup"]\nlayout_mode = 2\ntheme_override_constants/margin_left = 8\ntheme_override_constants/margin_top = 8\ntheme_override_constants/margin_right = 8\ntheme_override_constants/margin_bottom = 8\n\n[node name="IconPicker" parent="IconSelectPopup/Margin" instance=ExtResource("2")]\nlayout_mode = 2\npicker_kind = &"element"\n\n[node name="MarginContainer" type="MarginContainer" parent="."]',
    )

path.write_text(text, encoding="utf-8")
print("patched cells")