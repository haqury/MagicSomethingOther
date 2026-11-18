# Игрок

Сцена: `res://scenes/player/player.tscn`. Скрипт корня: `player.gd` (`class_name Player`).

## Дерево сцены

```
Player (CharacterBody2D)  player.gd
├── CollisionShape2D          круг, радиус 12
├── Body (Polygon2D)          треугольник-заглушка, нос смотрит в +X
├── Camera2D                  zoom (1, 1), enabled = false
└── MultiplayerSynchronizer
```

Коллизия, заглушка тела и камера лежат в сцене. Скрипт их не создаёт.

Слои: `collision_layer = players (2)`, `collision_mask = world (1)`.

Авторитет узла — peer `1` (его выставляет спавн). Синхронизатор поэтому шлёт состояние с сервера. В конфиге репликации, с флагом spawn у полей, которые должны приехать вместе с узлом:

- `position`
- `rotation`
- `current_hp`
- `current_stamina`
- `essence`
- `max_hp`
- `move_speed`
- `max_stamina`
- `dash_multiplier`
- `vision_zoom`

Поля сборки сервер заполняет из принятого `PlayerStats` в момент спавна. По ходу боя из этого списка сами меняются `position`, `rotation`, `current_hp` и `current_stamina`. Корпус смотрит туда, куда целился владелец: сервер пишет `rotation`.

## Поля скрипта

```gdscript
@export var stats: PlayerStats
@export var spell_lmb: SpellData
@export var spell_rmb: SpellData
@export var spell_mmb: SpellData

var current_hp: float = 0.0
var current_stamina: float = 0.0
var sprint_locked: bool = false

var essence: int = 0
var max_hp: float = 100.0
var move_speed: float = 180.0
var max_stamina: float = 100.0
var dash_multiplier: float = 1.8
var vision_zoom: float = 1.0
```

Три слота — весь боевой набор.

Пустой слот (`null`) не кастуется.

Назначение в сцене игрока нужно редактору. В матч сервер подставляет сборку подготовки:

- `spell_lmb` в сцене — огонь, форма снаряд;
- `spell_rmb` в сцене — земля, форма стена;
- `spell_mmb` в сцене пустой.

`current_hp` и `current_stamina` сервер в момент спавна ставит в `stats.max_hp` и `stats.max_stamina`, затем копирует поля сборки на одноимённые поля узла. Дальше узел читает уже эти поля. Повторной покупки в бою нет.

Владелец на любом пире:

```gdscript
func is_local_owner() -> bool:
    return name.to_int() == multiplayer.get_unique_id()
```

## Ввод

Владелец в `_physics_process` собирает пакет:

| Поле | Смысл |
|---|---|
| `move: Vector2` | WASD, длина `0` или `1` |
| `sprint: bool` | Пробел зажат |
| `aim: Vector2` | курсор в мировых координатах |
| `cast_lmb` / `cast_rmb` / `cast_mmb` | фронт нажатия в этом кадре |

Имена действий: `move_left`, `move_right`, `move_up`, `move_down`, `sprint`, `cast_lmb`, `cast_rmb`, `cast_mmb`. Физические клавиши берутся из `InputMap`. По умолчанию это A/D/W/S, Space и три кнопки мыши. Игрок меняет их в настройках, см. [settings.md](settings.md). Сервер коды клавиш не получает.

Хост подставляет пакет в симуляцию сразу. Удалённый владелец шлёт движение отдельно от щелчка:

```gdscript
@rpc("any_peer", "unreliable_ordered")
func submit_input(move: Vector2, sprint: bool, aim: Vector2) -> void

@rpc("any_peer", "reliable")
func request_cast(slot: int, aim: Vector2) -> void
```

Оба RPC идут на пир `1` (`rpc_id(1, …)`). Сервер принимает пакет, если `get_remote_sender_id() == name.to_int()`. Чужой ввод отбрасывается. `move` сервер ещё раз нормализует и режет до длины 1.

Каст вынесен в надёжный канал, чтобы щелчок не потерялся между кадрами `unreliable_ordered`.

## Движение и рывок

Считает сервер. Скорость берётся из полей узла `move_speed` и `dash_multiplier` (они записаны из принятой сборки).

При `current_hp <= 0` сервер обнуляет `velocity` и этот пакет ввода в движение не подставляет. Узел игрока при этом остаётся в дереве: пир и камера локального владельца на месте, касты тоже не выпускаются.

Пока игрок жив, Пробел зажат, `current_stamina > 0` и `sprint_locked == false`:

- множитель скорости = `dash_multiplier`;
- стамина уменьшается на `30 * delta`.

Если во время рывка стамина дошла до `0`, ставится `sprint_locked = true`. Пока Пробел удерживают, множитель снова не включается.

Пробел отпущен:

- `sprint_locked = false`;
- стамина растёт на `20 * delta` и зажимается в `max_stamina`.

Зажатый Пробел регенерацию не запускает. Без рывка множитель равен `1`. Нулевой `move` обнуляет `velocity`.

```gdscript
velocity = move * move_speed * multiplier
move_and_slide()
```

Взгляд: если вектор от игрока к `aim` длиннее 1 px, `rotation = (aim - global_position).angle()`.

## Камера

В `_ready` локальный владелец включает свою камеру:

```gdscript
var local := is_local_owner()
$Camera2D.enabled = local
if local:
    $Camera2D.make_current()
```

У остальных игроков `Camera2D` остаётся выключенной.

Целевой зум. Больше `vision_zoom` — камера дальше, в кадре больше мира:

```gdscript
var z := 1.0 / maxf(vision_zoom, 0.5)
$Camera2D.zoom = $Camera2D.zoom.lerp(Vector2(z, z), 1.0 - exp(-6.0 * delta))
```

Лерп идёт у локального владельца от уже реплицированного `vision_zoom`. При `1.0` зум равен `(1, 1)`. При потолке `1.5` зум равен `(0.667, 0.667)`.

## Каст со слота

Сервер в `request_cast` выбирает ресурс:

| `slot` | Поле |
|---|---|
| `0` | `spell_lmb` |
| `1` | `spell_rmb` |
| `2` | `spell_mmb` |

Другой индекс, пустой ресурс и `current_hp <= 0` завершают вызов. Дальше ветка по `SpellData.kind` из [spells.md](spells.md).

В матче каст идёт по слотам, собранным на подготовке. `essence` в бою не списывается.

## Здоровье

```gdscript
signal died

func take_damage(amount: float) -> void:
    if not multiplayer.is_server():
        return
    if amount <= 0.0 or current_hp <= 0.0:
        return
    current_hp = maxf(current_hp - amount, 0.0)
    if current_hp <= 0.0:
        died.emit()

func heal(amount: float) -> void:
    if not multiplayer.is_server():
        return
    if amount <= 0.0 or current_hp <= 0.0:
        return
    current_hp = minf(current_hp + amount, max_hp)
```

`take_damage` совпадает по сигнатуре с `Destructible`, чтобы будущий враг бил игрока тем же вызовом. Свет вызывает `heal`. Боевой каст союзника здоровье не снимает: игрок не входит в `destructibles` и `enemies`. Форма «на себя» с боевым элементом бьёт кастера отдельно. С нуля `heal` не поднимает.

На нуле узел не удаляется. `queue_free()` здесь оборвал бы пира. Движение и каст на нуле уже отключены выше.

## Граница узла

Урон и уничтожение объектов выполняет сервер. Сборку `essence` сервер подтверждает до спавна. Камеру включает пир, чьё имя совпало с id узла.
