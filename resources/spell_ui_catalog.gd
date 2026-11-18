class_name SpellUiCatalog
extends RefCounted

const ELEMENT_PATHS: PackedStringArray = [
	"res://assets/ui/elements/fire.png",
	"res://assets/ui/elements/water.png",
	"res://assets/ui/elements/earth.png",
	"res://assets/ui/elements/air.png",
	"res://assets/ui/elements/ice.png",
	"res://assets/ui/elements/light.png",
	"res://assets/ui/elements/lightning.png",
]

const FORM_PATHS: PackedStringArray = [
	"res://assets/ui/forms/projectile.png",
	"res://assets/ui/forms/area.png",
	"res://assets/ui/forms/wall.png",
	"res://assets/ui/forms/beam.png",
	"res://assets/ui/forms/self.png",
	"res://assets/ui/forms/around.png",
	"res://assets/ui/forms/mine.png",
	"res://assets/ui/forms/relief.png",
]

const EMPTY_ELEMENT := "res://assets/ui/elements/empty.png"
const EMPTY_FORM := "res://assets/ui/forms/empty.png"


static func element_texture(element_id: int) -> Texture2D:
	if element_id < 0 or element_id >= ELEMENT_PATHS.size():
		return load(EMPTY_ELEMENT) as Texture2D
	return load(ELEMENT_PATHS[element_id]) as Texture2D


static func form_texture(form_id: int) -> Texture2D:
	if form_id < 0 or form_id >= FORM_PATHS.size():
		return load(EMPTY_FORM) as Texture2D
	return load(FORM_PATHS[form_id]) as Texture2D