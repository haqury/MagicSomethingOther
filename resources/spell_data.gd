class_name SpellData
extends Resource

enum Element {FIRE, WATER, EARTH, AIR, ICE, LIGHT, LIGHTNING}
enum Form {PROJECTILE, AREA, WALL, BEAM, SELF, AROUND, MINE, RELIEF}

@export var element: Element = Element.FIRE
@export var form: Form = Form.PROJECTILE
@export var power: float = 10.0
@export var area: float = 1.0
@export var cast_range: float = 320.0
@export var duration: float = 1.5
@export var object_hp: float = 40.0
@export var scene: PackedScene