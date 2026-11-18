# Настройки

Локальные настройки клиента: графика, назначение клавиш, язык. На сервер они не уходят. В пакете ввода уже готовые `move`, `sprint` и фронты каста, а не скан-коды, поэтому раскладка у каждого игрока своя.

Класс: `Settings` (`extends Node`), Autoload, файл `res://autoloads/settings.gd`. В списке автозагрузок он стоит выше `NetworkManager`, чтобы меню открылось уже с языком, окном и раскладкой.

Скрипт сцены `res://scenes/settings/settings.gd` только переключает вкладки и вызывает этот автозагруз. Второго класса `Settings` нет.

Файл: `user://settings.cfg` (`ConfigFile`). Нет файла — пишутся значения по умолчанию и сразу применяются.

## API

```gdscript
signal graphics_changed
signal bindings_changed
signal locale_changed(locale: String)

func apply_all() -> void
func set_window_mode(mode: String) -> void
func set_resolution(size: Vector2i) -> void
func set_vsync(mode: String) -> void
func set_max_fps(fps: int) -> void
func set_ui_scale(scale: float) -> void
func set_locale(locale: String) -> void
func start_rebind(action: StringName) -> void
func cancel_rebind() -> void
func reset_bindings() -> void
```

Каждый `set_*` пишет секцию на диск и применяет её в том же вызове. Отдельной кнопки «Применить» нет.

## Графика

| Параметр | Ключ в cfg | По умолчанию | Допустимые значения |
|---|---|---|---|
| Режим окна | `graphics/window_mode` | `windowed` | `windowed`, `borderless`, `fullscreen` |
| Разрешение | `graphics/resolution` | `1280x720` | `1280x720`, `1600x900`, `1920x1080`, `2560x1440` |
| VSync | `graphics/vsync` | `enabled` | `disabled`, `enabled`, `adaptive` |
| Предел кадров | `graphics/max_fps` | `0` | `0`, `60`, `120`, `144`, `240` |
| Масштаб интерфейса | `graphics/ui_scale` | `1.0` | `1.0`, `1.25`, `1.5` |

`max_fps = 0` означает `Engine.max_fps = 0` (предел снят).

| Режим | Окно | Разрешение из списка |
|---|---|---|
| `windowed` | `DisplayServer.WINDOW_MODE_WINDOWED` | размер окна, окно по центру текущего экрана |
| `borderless` | `DisplayServer.WINDOW_MODE_FULLSCREEN` | список разрешения выключен, размер берётся с экрана |
| `fullscreen` | `DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN` | выбранный размер передаётся в `window_set_size` до смены режима |

VSync пишется как `DisplayServer.VSYNC_DISABLED`, `VSYNC_ENABLED` или `VSYNC_ADAPTIVE`. Если драйвер не принимает adaptive, в cfg остаётся выбор игрока, а `VsyncStatus` показывает ключ `settings.vsync_fallback`.

Масштаб интерфейса меняет `default_font_size` базовой темы UI: `roundi(16 * ui_scale)`. Камера, мир и `Camera2D.zoom` этим множителем не пользуются.

Рендерер остаётся `gl_compatibility`, как в `project.godot`. Переключателя Forward+ / Mobile в меню нет: на 2D-кадр он не влияет.

## Управление

Действия заведены в карте ввода проекта. `Settings` меняет только события этих действий и новые имена не создаёт.

| Действие | По умолчанию | Что делает |
|---|---|---|
| `move_left` | A | вектор ввода, X− |
| `move_right` | D | вектор ввода, X+ |
| `move_up` | W | вектор ввода, Y− |
| `move_down` | S | вектор ввода, Y+ |
| `sprint` | Space | рывок, пока зажато |
| `cast_lmb` | левая кнопка мыши | слот 0, фронт нажатия |
| `cast_rmb` | правая кнопка мыши | слот 1 |
| `cast_mmb` | средняя кнопка мыши | слот 2 |
| `ui_cancel` | Escape | закрыть настройки или отменить прослушивание клавиши |

Прицел — положение курсора. Отдельного действия «смотреть» нет.

В cfg секция `input`. На действие одна запись: тип `key` или `mouse` и код движка.

```
[input]
move_left="key:65"
cast_lmb="mouse:1"
```

На действие приходится ровно одно событие. Лишнее событие того же действия при загрузке cfg снимается.

Назначение:

1. Игрок жмёт кнопку действия. `start_rebind` запоминает имя и ставит на кнопке ключ `settings.press_key`.
2. Следующее нажатие клавиши или кнопки мыши становится событием. Движение мыши и echo игнорируются.
3. Та же физическая клавиша снимается с другого действия, чтобы одно нажатие не вело два слота. Освободившееся действие остаётся пустым, пока игрок не назначит новую клавишу.
4. `ui_cancel` во время прослушивания вызывает `cancel_rebind`: прежняя клавиша на месте, cfg не пишется.
5. Успех сразу попадает в `InputMap` и в cfg. Сигнал `bindings_changed`.

`reset_bindings()` возвращает таблицу выше и перезаписывает секцию `input`.

Пустое действие в матч пропускается: в пакете нет этой оси или этого каста. «Сброс» возвращает полный набор.

## Локализация

Языки первого этапа: `ru` и `en`.

Старт: если в cfg есть `locale/language`, берётся он. Файла ещё нет — при языке ОС на `ru` пишется `ru`, иначе `en`.

Смена языка вызывает `TranslationServer.set_locale(locale)` и сохраняет ключ. Подписи с автопереводом обновляются сами.

Строки лежат в `res://locale/ui.csv`. Колонки: `keys`, `en`, `ru`. В кнопках и в `tr()` стоит ключ (`menu.singleplayer`), а не готовая фраза.

Тема UI ссылается на один шрифт с латиницей и кириллицей. Файла шрифта в репозитории пока нет: на реализации в `res://theme/ui_font.ttf` кладётся OFL-шрифт (подходит Noto Sans) и назначается в `Theme.default_font`.

Подписи языка в списке написаны сами на себе и через перевод не прогоняются: `Русский`, `English`.

### Ключи

| Ключ | en | ru |
|---|---|---|
| `menu.title` | Magic Something Other | Magic Something Other |
| `menu.singleplayer` | Singleplayer | Одиночная игра |
| `menu.host` | Host game | Создать сервер |
| `menu.join` | Join | Подключиться |
| `menu.ip` | IP | IP |
| `menu.settings` | Settings | Настройки |
| `menu.status.port_busy` | Port 7777 is busy | Порт 7777 занят |
| `menu.status.bad_address` | Enter an IP address | Введите IP-адрес |
| `menu.status.connection_failed` | Could not connect | Не удалось подключиться |
| `menu.status.server_lost` | Host disconnected | Хост отключился |
| `settings.title` | Settings | Настройки |
| `settings.graphics` | Graphics | Графика |
| `settings.controls` | Controls | Управление |
| `settings.language` | Language | Язык |
| `settings.back` | Back | Назад |
| `settings.window_mode` | Window mode | Режим окна |
| `settings.windowed` | Windowed | В окне |
| `settings.borderless` | Borderless | Без рамки |
| `settings.fullscreen` | Fullscreen | Полный экран |
| `settings.resolution` | Resolution | Разрешение |
| `settings.vsync` | VSync | Вертикальная синхронизация |
| `settings.vsync_off` | Off | Выкл. |
| `settings.vsync_on` | On | Вкл. |
| `settings.vsync_adaptive` | Adaptive | Адаптивная |
| `settings.max_fps` | Frame limit | Предел кадров |
| `settings.fps_uncapped` | Uncapped | Без предела |
| `settings.ui_scale` | UI scale | Масштаб интерфейса |
| `settings.reset_bindings` | Reset to defaults | Сбросить клавиши |
| `settings.press_key` | Press a key… | Нажмите клавишу… |
| `settings.vsync_fallback` | Adaptive VSync is unavailable | Адаптивная синхронизация недоступна |
| `controls.move_left` | Move left | Влево |
| `controls.move_right` | Move right | Вправо |
| `controls.move_up` | Move up | Вверх |
| `controls.move_down` | Move down | Вниз |
| `controls.sprint` | Dash | Рывок |
| `controls.cast_lmb` | Spell 1 | Заклинание 1 |
| `controls.cast_rmb` | Spell 2 | Заклинание 2 |
| `controls.cast_mmb` | Spell 3 | Заклинание 3 |
| `prep.title` | Preparation | Подготовка |
| `prep.essence` | Essence | Эссенция |
| `prep.ready` | Ready | Готово |
| `prep.start` | Start match | Начать матч |
| `prep.waiting` | Waiting for players | Ожидание игроков |
| `prep.hp` | Health | Здоровье |
| `prep.speed` | Speed | Скорость |
| `prep.stamina` | Stamina | Выносливость |
| `prep.dash` | Dash power | Сила рывка |
| `prep.vision` | Vision | Обзор |
| `prep.spell_lmb` | Left slot | Левый слот |
| `prep.spell_rmb` | Right slot | Правый слот |
| `prep.spell_mmb` | Middle slot | Средний слот |
| `prep.empty` | Empty | Пусто |
| `prep.element` | Element | Элемент |
| `prep.form` | Form | Форма |
| `element.fire` | Fire | Огонь |
| `element.water` | Water | Вода |
| `element.earth` | Earth | Земля |
| `element.air` | Air | Воздух |
| `element.ice` | Ice | Лёд |
| `element.light` | Light | Свет |
| `element.lightning` | Lightning | Молния |
| `form.projectile` | Projectile | Снаряд |
| `form.area` | Area | Область |
| `form.wall` | Wall | Стена |
| `form.beam` | Beam | Луч |
| `form.self` | Self | На себя |
| `form.around` | Around | Вокруг себя |
| `form.mine` | Mine | Мина |
| `prep.power` | Power | Сила |
| `prep.area` | Size | Размер |
| `prep.area` | Size | Размер |
| `prep.range` | Range | Дальность |
| `prep.duration` | Duration | Длительность |
| `prep.object_hp` | Durability | Прочность |
| `prep.rejected` | Loadout rejected | Сборка отклонена |

## Дерево сцены `Settings.tscn`

```
Settings (Control)  settings.gd
└── CenterContainer
    └── PanelContainer
        └── VBoxContainer
            ├── Title (Label)                    ключ settings.title
            ├── Tabs (TabContainer)
            │   ├── Graphics (VBoxContainer)
            │   │   ├── WindowModeOption (OptionButton)
            │   │   ├── ResolutionOption (OptionButton)
            │   │   ├── VsyncOption (OptionButton)
            │   │   ├── MaxFpsOption (OptionButton)
            │   │   ├── UiScaleOption (OptionButton)
            │   │   └── VsyncStatus (Label)
            │   ├── Controls (VBoxContainer)
            │   │   ├── BindingList (VBoxContainer)   девять готовых рядов
            │   │   └── ResetButton (Button)
            │   └── Language (VBoxContainer)
            │       └── LanguageOption (OptionButton)  Русский / English
            └── BackButton (Button)
```

Ряд клавиши — `HBox` из `Label` и `Button`, уже лежащий в сцене, по одному на действие. Скрипт подставляет перевод и текущую клавишу и ряды в `_ready` не создаёт.

`Back` возвращает на сцену, которая открыла настройки (меню или подготовка). Путь вызывающей сцены меню записывает в `Settings` перед сменой сцены.

Окно настроек открывается до симуляции матча: из главного меню и с экрана подготовки. Боевую паузу этот этап не описывает.
