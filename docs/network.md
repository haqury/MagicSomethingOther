# Сеть и режимы

Класс: `NetworkManager` (`extends Node`), Autoload с именем `NetworkManager`.

Один вход в игру для всех трёх кнопок: поднять `MultiplayerPeer`, открыть `Game`, спавнить игроков с сервера. Синглплеер отличается типом пира: сокет не создаётся, проверки `multiplayer.is_server()` остаются теми же.

## Константы

| Имя | Значение | Смысл |
|---|---|---|
| `DEFAULT_PORT` | `7777` | Порт хоста и клиента |
| `MAX_PLAYERS` | `8` | Хост вместе с клиентами |
| `MAX_CLIENTS` | `7` | Аргумент `ENetMultiplayerPeer.create_server`. Хост в это число не входит |

## Состояние

```gdscript
enum SessionMode { MENU, SINGLEPLAYER, HOST, CLIENT }

var mode: SessionMode = SessionMode.MENU
var pending_peer_ids: Array[int] = []
```

`pending_peer_ids` копит id, пока сцена `Game` ещё не в дереве. После успешного старта пира сервер кладёт в очередь `1` — себя. Чужие id добавляет `peer_connected`.

## Сигналы

- `session_started(mode: SessionMode)` — пир назначен, сцена игры запрошена.
- `session_failed(reason: String)` — порт занят, пустой IP, ошибка создания пира.
- `connection_failed()` — клиент не достучался.
- `server_disconnected()` — клиент потерял хост.
- `player_joined(peer_id: int)` — серверу пора заспавнить этого игрока, либо положить id в очередь.
- `player_left(peer_id: int)` — сервер удаляет узел `Entities/<peer_id>`.

## API

```gdscript
func start_singleplayer() -> void
func host_game(port: int = DEFAULT_PORT) -> void
func join_game(address: String, port: int = DEFAULT_PORT) -> void
func leave_session() -> void
func consume_pending_peers() -> Array[int]
func start_match() -> void
func take_loadout(peer_id: int) -> Loadout
```

Повторный старт при `mode != MENU` игнорируется, пока не вызван `leave_session`.

### Одиночная игра

Кнопка «Одиночная игра».

1. `leave_session()` снимает хвост прошлой сессии.
2. `multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()`.
3. `mode = SINGLEPLAYER`.
4. В очередь спавна кладётся `1`.
5. `get_tree().change_scene_to_file("res://scenes/prep/prep.tscn")`.
6. Сигнал `session_started`.

Спавна на этом шаге нет. Очередь пиров копится до `start_match()`.

`OfflineMultiplayerPeer` даёт `multiplayer.is_server() == true` и `get_unique_id() == 1`. Порт 7777 не занимается.

### Создать сервер

Кнопка «Создать сервер».

1. `var peer := ENetMultiplayerPeer.new()`.
2. `peer.create_server(port, MAX_CLIENTS)`.
3. При ошибке пир не назначается, `mode` остаётся `MENU`, уходит `session_failed`.
4. При успехе: `multiplayer.multiplayer_peer = peer`, `mode = HOST`, в очередь кладётся `1`, сцена меняется на `Prep`, уходит `session_started`.
5. Менеджер подписывается на `multiplayer.peer_connected` и `peer_disconnected`.

ENet слушает все интерфейсы, чтобы к хосту подключались по локальной сети. Порт наружу открывает только эта кнопка.

Восьмой клиент (девятый участник) не входит: у `create_server` семь входящих слотов, вместе с хостом это восемь игроков.

### Подключиться

Кнопка «Подключиться». Адрес берётся из `LineEdit`. Пустая строка и строка из пробелов дают `session_failed`, пир не создаётся. Порт всегда `DEFAULT_PORT`: отдельного поля порта в MVP нет.

1. `peer.create_client(address.strip_edges(), port)`.
2. Ошибка создания — `session_failed`, меню остаётся открытым.
3. Успех вызова — `mode = CLIENT`, пир назначен. Сцена игры ждёт сигнал.
4. `connected_to_server` → сцена `Prep`, затем `session_started`. Спавн по-прежнему делает сервер, уже после `start_match()`.
5. `connection_failed` → `leave_session()` и сигнал `connection_failed`.
6. `server_disconnected` уже в игре → `leave_session()`, возврат в меню, сигнал `server_disconnected`.

Клиент игроков не создаёт. Его узел создаёт сервер в обработчике `peer_connected`.

### Выход

`leave_session()`:

1. Отписывается от сигналов мультиплеера.
2. Ставит `multiplayer.multiplayer_peer = null`. Для ENet это закрывает сокет.
3. `mode = MENU`, очередь пиров пустая.
4. Если текущая сцена — не меню, грузит главное меню.

Хост таким выходом обрывает клиентов. Они уходят по `server_disconnected`.

## Старт матча

`start_match()` вызывает сервер с экрана подготовки, когда у каждого подключённого пира есть принятая сборка. Авторитет автозагрузки — peer `1`, поэтому рассылка такая:

```gdscript
@rpc("authority", "call_local", "reliable")
func begin_match() -> void:
    get_tree().change_scene_to_file("res://scenes/game/game.tscn")
```

Сервер вызывает `begin_match.rpc()`. Клиенты и хост грузят `Game` вместе. До этого вызова сцена игры не открывается. Правила сборки — в [prep.md](prep.md).

## Спавн игрока

`Game._ready` на сервере вызывает `consume_pending_peers()` и спавнит каждый id. Дальше сцена подписана на `player_joined`.

```gdscript
func spawn_player(peer_id: int) -> void:
    var player := player_scene.instantiate()
    player.name = str(peer_id)
    player.set_multiplayer_authority(1)
    var loadout := NetworkManager.take_loadout(peer_id)
    player.stats = loadout.stats
    player.spell_lmb = loadout.spell_lmb
    player.spell_rmb = loadout.spell_rmb
    player.spell_mmb = loadout.spell_mmb
    entities.add_child(player)
```

`entities` — это `spawn_path` спавнера, сцена игрока входит в его список. Узел, добавленный здесь на сервере, появляется и у клиентов. Повторный спавн того же имени пропускается.

Слоты и числа сборки сервер записывает в узел до `add_child` и дальше читает их только у себя. Клиентская копия игрока приезжает из packed scene; для кадра ей хватает полей синхронизатора (`current_hp`, скорость, обзор, стамина). Каст на клиенте слоты не открывает.

`peer_disconnected` на сервере делает `Entities.get_node_or_null(str(id)).queue_free()`.

Имя узла — источник владельца на всех пирах, включая момент `_ready` у клиента: спавнер переносит имя вместе с узлом. Отдельное свойство `owner_id` не требуется. Локальный игрок — тот, у кого `name.to_int() == multiplayer.get_unique_id()`.

## Главное меню

### Дерево сцены `MainMenu.tscn`

```
MainMenu (Control)  main_menu.gd
└── CenterContainer
    └── PanelContainer
        └── VBoxContainer
            ├── Title (Label)                  menu.title
            ├── SingleplayerButton (Button)    menu.singleplayer
            ├── HostButton (Button)            menu.host
            ├── AddressLabel (Label)           menu.ip
            ├── AddressEdit (LineEdit)         текст "127.0.0.1"
            ├── JoinButton (Button)            menu.join
            ├── SettingsButton (Button)        menu.settings
            └── StatusLabel (Label)            пустой, autowrap
```

Корень `Control` растянут на весь экран. Кнопки и поле лежат в `.tscn`. Скрипт узлы не собирает. Надписи — ключи из [settings.md](settings.md), автоперевод включён.

`main_menu.gd` связывает кнопки с `NetworkManager` и пишет в `StatusLabel` ключ статуса:

- на время смены сцены кнопки `disabled = true`;
- `session_failed` и `connection_failed` возвращают кнопки и ставят `menu.status.port_busy`, `menu.status.bad_address` или `menu.status.connection_failed`;
- `server_disconnected` ставит `menu.status.server_lost`;
- «Создать сервер» вызывает `host_game(NetworkManager.DEFAULT_PORT)`;
- «Подключиться» вызывает `join_game(AddressEdit.text)`;
- «Настройки» запоминает в `Settings` путь меню и открывает `res://scenes/settings/settings.tscn`. Пир при этом не создаётся.

Меню запускает сессию и открывает настройки. Трата `essence` происходит на подготовке, не здесь.
