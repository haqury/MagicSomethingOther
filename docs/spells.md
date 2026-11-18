# Магия и разрушаемость

Заклинание — это элемент плюс форма. Элемент решает, что произойдёт с целью. Форма решает, куда и как это доедет. Отдельных ресурсов «огненный снаряд» и «ледяная стена» нет: подготовка собирает `SpellData` из этих двух полей.

## SpellData

Класс: `SpellData` (`extends Resource`, `class_name SpellData`).

```gdscript
enum Element { FIRE, WATER, EARTH, AIR, ICE, LIGHT, LIGHTNING }
enum Form { PROJECTILE, AREA, WALL, BEAM, SELF, AROUND, MINE }

@export var element: Element = Element.FIRE
@export var form: Form = Form.PROJECTILE
@export var power: float = 10.0
@export var area: float = 1.0
@export var cast_range: float = 320.0
@export var duration: float = 1.5
@export var object_hp: float = 40.0
@export var scene: PackedScene
```

Порядок значений в обоих `enum` фиксирован: по сети едут эти индексы.

| Индекс | Element | Имя |
|---|---|---|
| 0 | `FIRE` | огонь |
| 1 | `WATER` | вода |
| 2 | `EARTH` | земля |
| 3 | `AIR` | воздух |
| 4 | `ICE` | лёд |
| 5 | `LIGHT` | свет |
| 6 | `LIGHTNING` | молния |

| Индекс | Form | Имя |
|---|---|---|
| 0 | `PROJECTILE` | снаряд |
| 1 | `AREA` | цель, область |
| 2 | `WALL` | стена |
| 3 | `BEAM` | луч |
| 4 | `SELF` | на себя |
| 5 | `AROUND` | вокруг себя |
| 6 | `MINE` | мина |

`scene` выбирает сервер по форме, не по элементу. Цвет заглушки — `modulate` корня:

| Элемент | Цвет |
|---|---|
| огонь | `#e85d04` |
| вода | `#219ebc` |
| земля | `#7a6a3a` |
| воздух | `#c5d5e4` |
| лёд | `#a9def9` |
| свет | `#ffe8a3` |
| молния | `#f0e14a` |

Один шаблон чисел: `res://data/spells/spell_base.tres`. При выборе формы сервер подставляет базу формы, затем накатывает ранги подготовки.

| Форма | `power` | `area` | `cast_range` | `duration` | `object_hp` | Сцена |
|---|---|---|---|---|---|---|
| снаряд | 10 | 1 | 480 | 1.5 | — | `projectile.tscn` |
| область | 10 | 1 | 280 | 2.0 | — | `area_zone.tscn` |
| стена | — | 1 | 280 | 8 | 60 | `destructible_wall.tscn` |
| луч | 10 | — | 400 | — | — | `beam_flash.tscn` |
| на себя | 10 | — | — | — | — | `self_flash.tscn` |
| вокруг себя | 10 | 1 | — | — | — | `nova_flash.tscn` |
| мина | 10 | 1 | 280 | 10 | 30 | `mine.tscn` |

Прочерк — поле у этой формы не читается. Ранг такого поля подготовка не продаёт.

`area` у зоны, вспышки вокруг и мины переводится в радиус: зона `36 * area` px, круг вокруг себя `56 * area`, взрыв мины `24 * area`. У снаряда и стены `area` — масштаб сцены.

## Полезная нагрузка

Сервер вызывает один раз на цель:

- `LIGHT` — `heal(power)` у узла из группы `players`, пока `current_hp > 0`. Свет с нуля не поднимает.
- остальные шесть элементов — `take_damage(power)` у узла из группы `destructibles` или `enemies`.

Элемент при этом уже записан в ресурсе. Горения, намокания, оглушения и цепной молнии на этом этапе нет: шесть боевых элементов бьют одинаково, различается только id.

Игрок в группы `destructibles` и `enemies` не входит, поэтому чужой боевой каст его не задевает. Исключение одно: форма `SELF` целится в кастера. Боевой элемент на себе снимает своё `current_hp`, свет на себе лечит.

`heal` живёт на `Player` рядом с `take_damage`: сервер, `amount > 0`, результат не выше `max_hp`.

## Куда встаёт каст

Точка прицела для области, стены и мины клампится окружностью `cast_range`. `cast_range <= 0` отменяет такой каст.

Снаряд и луч берут направление на курсор. Вектор короче 1 px заменяется на `Vector2.RIGHT.rotated(player.rotation)`.

`SELF` и `AROUND` прицел не читают. Точка — позиция игрока в кадр каста.

Спавн мира, только с сервера:

```gdscript
func spawn_spell_scene(data: SpellData, at: Vector2, rot: float) -> Node2D:
    var node := data.scene.instantiate() as Node2D
    node.global_position = at
    node.rotation = rot
    node.scale = Vector2(data.area, data.area)
    node.modulate = element_color(data.element)
    node.set_multiplayer_authority(1)
    entities.add_child(node)
    return node
```

## Формы

### Снаряд

Дерево `projectile.tscn`:

```
Projectile (Area2D)  projectile.gd
├── CollisionShape2D           круг, радиус 4
├── Body (Polygon2D)           ромб, нос в +X
└── MultiplayerSynchronizer    position, rotation
```

Скорость `480` px/с. Сервер каждый кадр пускает луч на шаг движения. Маска луча: всегда `world` и `hazards`. Боевой элемент добавляет `enemies`, свет — `players`.

Первое тело съедает снаряд. Если тело принимает нагрузку этого элемента, сервер её применяет. Стена на слое `world` останавливает и свет, и урон; свет стену не лечит. Дистанция копится до `cast_range`, таймер — до `duration`. `duration <= 0` оставляет только дистанцию и попадание.

### Область

Дерево `area_zone.tscn`:

```
AreaZone (Area2D)  area_zone.gd
├── CollisionShape2D     круг, радиус 36
└── Body (Polygon2D)     тот же круг, заливка
```

Сервер ставит зону в точку прицела и задаёт радиус `36 * area`. Зона живёт `duration` секунд. Каждое подходящее тело получает нагрузку один раз: и то, что уже внутри в кадр спавна, и то, что вошло позже. Повторно то же тело не бьётся. Зона движение не блокирует.

### Стена

Стена — `Destructible`. Блокирует и принимает урон своими `object_hp`. Нагрузку элемента при постановке не выпускает: огненная стена и стена света одинаково стоят, пока их не собьют или не выйдет `duration`. `duration <= 0` оставляет стену, пока не кончится `hp`.

Дерево `destructible_wall.tscn`:

```
DestructibleWall (StaticBody2D)  destructible.gd
├── CollisionShape2D              RectangleShape2D, size (48, 16)
├── Body (Polygon2D)              тот же прямоугольник
└── MultiplayerSynchronizer       hp
```

`collision_layer = world (1)`, `collision_mask = 0`. После спавна сервер пишет `hp = object_hp` и цвет элемента.

### Луч

Мгновенный отрезок длины `cast_range` от игрока по прицелу. Маска та же, что у снаряда. Первое подходящее тело получает нагрузку. Тело слоя `world` или `hazards` обрывает луч, даже если нагрузку оно не принимает.

Сцена `beam_flash.tscn` — только рисунок на `0.12` с:

```
BeamFlash (Node2D)  flash.gd
└── Line2D
```

Сервер ставит точки линии от игрока до точки удара или до конца дальности и таймером удаляет узел.

### На себя

Сервер сразу вызывает нагрузку на кастере. Сцена `self_flash.tscn` стоит в точке игрока `0.2` с и в симуляции не участвует:

```
SelfFlash (Node2D)  flash.gd
└── Body (Polygon2D)     круг, радиус 18
```

### Вокруг себя

Мгновенный круг в точке игрока, радиус `56 * area`. Кастер в выборку не входит: для этого есть форма «на себя». Остальные тела в круге, которым подходит элемент, получают нагрузку один раз.

```
NovaFlash (Node2D)  flash.gd
└── Body (Polygon2D)     круг, радиус 56
```

Узел живёт `0.2` с. За игроком не едет.

### Мина

Мина ставится в точку прицела, лежит до `duration` или пока её не сломают, и срабатывает от пересечения.

```
Mine (StaticBody2D)  mine.gd
├── CollisionShape2D          круг, радиус 8, слой hazards
├── Trigger (Area2D)          круг, радиус 24
├── Body (Polygon2D)
└── MultiplayerSynchronizer   hp
```

Тело мины на слое `hazards` (бит 5). Игрок этот слой не маскирует и сквозь мину проходит. Снаряд и луч слой видят, поэтому мину можно сбить: `mine.gd` состоит в группе `destructibles`, держит `hp = object_hp` и тот же контракт `take_damage`, что стена. Класс `Destructible` она не наследует: тот сидит на стене и блокирует ход.

`Trigger` у боевой мины маскирует `enemies`, у света — `players`. Первое подходящее пересечение наносит нагрузку всем подходящим телам в радиусе `24 * area` и удаляет мину. Пока врагов нет, боевая мина просто лежит свой `duration`.

## Destructible

Скрипт: `res://scripts/destructible.gd`, `class_name Destructible`, `extends StaticBody2D`.

```gdscript
signal destroyed

@export var hp: float = 30.0

func _ready() -> void:
    add_to_group("destructibles")

func take_damage(amount: float) -> void:
    if not multiplayer.is_server():
        return
    if amount <= 0.0 or hp <= 0.0:
        return
    hp = maxf(hp - amount, 0.0)
    if hp <= 0.0:
        destroyed.emit()
        queue_free()
```

Урон и `queue_free` выполняет сервер. Спавнер разносит удаление. Промежуточное `hp` уходит синхронизатором.

## Спавн

В списке `MultiplayerSpawner`:

- `projectile.tscn`
- `area_zone.tscn`
- `destructible_wall.tscn`
- `beam_flash.tscn`
- `self_flash.tscn`
- `nova_flash.tscn`
- `mine.tscn`

Цены рангов и выбор в трёх слотах — в [prep.md](prep.md). В матче сервер читает уже собранные `element`, `form`, `power`, `area`, `cast_range`, `duration`, `object_hp`.
