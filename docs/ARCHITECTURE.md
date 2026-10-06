# ODRAVETH — Архитектура

Документ описывает техническое устройство проекта. Продуктовые правила — только в [`PRODUCT_BASELINE.md`](PRODUCT_BASELINE.md); обоснования решений — в [`DECISIONS.md`](DECISIONS.md).

Текущее состояние: **Stage 1** — технический фундамент (Stage 0) и типизированная база 40 утверждённых карт с декларативными данными эффектов. Игровой логики (MatchEngine, исполнение эффектов, ИИ) ещё нет.

## 1. Принципы

1. **Офлайн.** Никакого сетевого кода, backend и сторонних SDK.
2. **Android landscape first.** Дизайн 1920×1080, `canvas_items` + `expand`, только альбомная ориентация, safe area.
3. **Однонаправленные зависимости.** Нет циклов; нижние слои не знают о верхних (граф — раздел 4).
4. **Нет God-object.** Каждый autoload решает одну задачу. Autoload — только там, где нужен глобальный экземпляр, переживающий смену сцен.
5. **Состояние матча — не в глобальных синглтонах.** Матч принадлежит экрану боя (будущий экземпляр MatchEngine); между экранами передаются параметры маршрута.
6. **Данные отдельно от кода.** Карты, герои, колоды, баланс — файлы в `res://data/`, а не константы в скриптах.
7. **Проверяемость.** Логика без зависимости от дерева сцен (RefCounted / static), headless smoke-тест.

## 2. Структура каталогов

| Путь | Назначение |
|---|---|
| `project.godot` | Настройки проекта: main scene, autoload, экран, рендерер, строгие предупреждения GDScript |
| `scenes/boot/` | Boot-экран (инициализация сервисов) |
| `scenes/menu/` | Главное меню |
| `scenes/common/` | Общие сцены экранов (сейчас — базовый placeholder-экран) |
| `scenes/heroes/` · `collection/` · `deck_builder/` · `prebattle/` · `battle/` · `result/` | Утверждённые экраны UI flow (пока placeholder) |
| `scenes/progress/` · `settings/` | Экраны пунктов меню «Прогресс» и «Настройки» (пока placeholder) |
| `scripts/core/` | Сервисы приложения (EventBus, SceneRouter, AppState), таблица маршрутов, правила и фракции baseline, boot |
| `scripts/cards/` | База карт: `CardDatabase` (реестр), `CardSchema` (валидация JSON), `CardDefinition` и `CardEffectSpec` (модель), `EffectVocabulary` (словарь эффектов), `CardEnums` (таксономия) |
| `scripts/battle/` | Боевой домен: сейчас только состояния результата; позже MatchEngine |
| `scripts/save/` | Локальные сохранения (SaveManager) |
| `scripts/ui/` | Скрипты экранов и переиспользуемых UI-контейнеров |
| `scripts/heroes/` · `decks/` · `ai/` | Зарезервировано: герои, валидация колод, ИИ (следующие этапы) |
| `data/cards/` | 40 утверждённых карт: `ashravael.json`, `nerqathen.json`, `dumoryss.json`, `khevaruun.json`, `neutral.json` (по 8 карт) |
| `data/heroes/` · `decks/` · `balance/` | Данные героев, стартовых колод, баланса — следующие этапы |
| `assets/ui/` | UI-ресурсы; сейчас только временная тема `placeholder_theme.tres` |
| `assets/heroes/` · `cards/` · `backgrounds/` · `effects/` · `audio/` · `fonts/` | Зарезервировано под утверждённые ассеты |
| `tests/` | Headless smoke-тест, тесты базы карт, независимая таблица утверждённых карт, скрипт запуска проверок |
| `docs/` | Документация |

Пустые зарезервированные каталоги содержат `.gitkeep` (Git не хранит пустые каталоги). Файлы `*.gd.uid` генерируются Godot 4.4+ и **коммитятся**: на них ссылаются сцены.

## 3. Autoload-сервисы

Порядок регистрации в `project.godot`: `EventBus` → `SceneRouter` → `AppState` → `CardDatabase`.

| Autoload | Скрипт | Ответственность | Почему глобальный |
|---|---|---|---|
| `EventBus` | `scripts/core/event_bus.gd` | Только сигналы для слабосвязанных уведомлений между системами: `route_changed`, `save_error` | Суть паттерна — единая точка подписки |
| `SceneRouter` | `scripts/core/scene_router.gd` | Переходы между экранами, история, параметры маршрутов, системная кнопка «Назад» Android | Должен переживать смену сцен |
| `AppState` | `scripts/core/app_state.gd` | Состояние уровня приложения: статус инициализации, загруженный профиль (сохранение) | Данные, общие для всех экранов и переживающие их смену |
| `CardDatabase` | `scripts/cards/card_database.gd` | Неизменяемый реестр определений карт: загрузка, валидация, поиск | Статические справочные данные, нужные коллекции, редактору колод и бою |

**Не autoload** (обычные классы, `class_name`):

| Класс | Файл | Почему не autoload |
|---|---|---|
| `SaveManager` | `scripts/save/save_manager.gd` | Чистый ввод-вывод без состояния сцены. Экземпляр принадлежит `AppState`; тесты создают свой с временным путём |
| `Routes` | `scripts/core/routes.gd` | Константы маршрутов и статические функции |
| `GameRules` | `scripts/core/game_rules.gd` | Константы утверждённых числовых правил (включая Осколки души) |
| `CardSchema`, `CardDefinition`, `CardEffectSpec`, `EffectVocabulary` | `scripts/cards/` | Валидация и модель данных карт; без состояния сцены |
| `Faction`, `CardEnums`, `MatchOutcome` | `scripts/core/`, `scripts/cards/`, `scripts/battle/` | Перечисления baseline |
| `SafeAreaContainer`, `PlaceholderScreen`, `ResultScreen` | `scripts/ui/` | UI-компоненты сцен |

Правила для autoload:

- `EventBus` не ссылается ни на один другой autoload и не хранит состояние.
- Autoload не вызывают экраны и не знают об их внутреннем устройстве.
- Новый autoload добавляется только с записью в `DECISIONS.md` и обоснованием.

## 4. Граф зависимостей

```
UI-экраны (scripts/ui, scripts/core/boot.gd)
   │  вызывают
   ▼
SceneRouter ──► Routes                    AppState ──► SaveManager
   │                                         │
   └──────────────► EventBus ◄───────────────┘
                    (лист, ни от кого не зависит)

CardDatabase ──► CardSchema ──► CardDefinition, CardEffectSpec
                    │
                    └──► EffectVocabulary, CardEnums, Faction, GameRules ──► CardEnums
```

- Экраны зависят от сервисов, сервисы — никогда от экранов.
- `boot.gd` — единственное место, задающее порядок инициализации: `AppState.initialize()` → `CardDatabase.load_directory()` → `SceneRouter.reset_to(MAIN_MENU)`.
- Циклов нет. Сервисы не обращаются к autoload в `_init`/`_ready` друг друга — инициализацию запускает Boot.

## 5. Навигация

### 5.1. Маршруты

`Routes` — единственное место, где маршрут сопоставлен со сценой и русским заголовком. Экраны не ссылаются на пути `.tscn`.

| Route id | Сцена | Заголовок |
|---|---|---|
| `boot` | `scenes/boot/boot.tscn` | Загрузка |
| `main_menu` | `scenes/menu/main_menu.tscn` | Главное меню |
| `hero_select` | `scenes/heroes/hero_select.tscn` | Выбор героя |
| `collection` | `scenes/collection/collection.tscn` | Коллекция |
| `deck_builder` | `scenes/deck_builder/deck_builder.tscn` | Редактор колоды |
| `prebattle` | `scenes/prebattle/prebattle.tscn` | Подготовка к бою |
| `battle` | `scenes/battle/battle.tscn` | Боевой экран |
| `result` | `scenes/result/result.tscn` | Результат боя |
| `progress` | `scenes/progress/progress.tscn` | Прогресс |
| `settings` | `scenes/settings/settings.tscn` | Настройки |

`Routes.APPROVED_FLOW` хранит утверждённый порядок потока (PRODUCT_BASELINE §8).

### 5.2. API SceneRouter

| Метод | История | Применение |
|---|---|---|
| `go_to(route, params = {})` | текущий экран кладётся в стек | обычный переход вперёд |
| `replace_with(route, params = {})` | не меняется | экран, к которому нельзя вернуться (бой → результат) |
| `reset_to(route, params = {})` | очищается | возврат в главное меню, Boot → меню |
| `go_back()` | снимается верхняя запись | кнопка «Назад», системный жест Android |

- Все методы возвращают `Error`: неизвестный маршрут → `ERR_DOES_NOT_EXIST`, повторный вызов во время смены сцены → `ERR_BUSY` (защита от двойного нажатия).
- Переход: `load()` сцены → `instantiate()` → `apply_route_params(params)` (если метод есть у корня экрана) → `SceneTree.change_scene_to_node()`. После `SceneTree.scene_changed` роутер эмитит `EventBus.route_changed(route)`.
- Параметры глубоко копируются и хранятся в истории вместе с маршрутом, поэтому «Назад» восстанавливает экран с теми же параметрами.
- Системная кнопка «Назад» Android (`NOTIFICATION_WM_GO_BACK_REQUEST`, `application/config/quit_on_go_back=false`): есть история → `go_back()`, корневой экран → выход из приложения. Обработка отложена (`call_deferred`), потому что уведомление рассылается по дереву, и в этот момент нельзя удалять текущую сцену.
- Экраны **никогда** не вызывают `change_scene_*` сами.

### 5.3. Параметры вместо глобального состояния

Кратковременные данные передаются параметрами маршрута. Пример Stage 0: бой передаёт результат на экран результата:

```gdscript
SceneRouter.replace_with(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.VICTORY})
```

Получатель объявляет ключи своих параметров константами (`ResultScreen.PARAM_OUTCOME`). Тот же механизм в будущем передаст на экран боя конфигурацию матча (герой, колода, противник, сложность), не храня её в `AppState`.

### 5.4. Placeholder-экраны Stage 0

- `scenes/common/placeholder_screen.tscn` + `PlaceholderScreen` — базовый временный экран: заголовок, «Назад», «Далее: <следующий экран потока>», «В главное меню».
- Экраны маршрутов — **наследованные сцены** от базовой; переопределяют `route_id`, при необходимости подпись кнопки (`next_button_text`) или скрипт (`battle_placeholder.gd`, `result_screen.gd`).
- Боевой placeholder имитирует три исхода, чтобы проверить переход к результату. Логики боя в нём нет.
- При реализации финального экрана наследованная сцена заменяется самостоятельной; маршрут в `Routes` остаётся прежним.

## 6. Boot

`scenes/boot/boot.tscn` — main scene проекта. `boot.gd` в отложенном вызове:

1. `AppState.initialize()` — загрузка локального сохранения.
2. `CardDatabase.load_directory()` — загрузка 40 карт из `res://data/cards/*.json`. При ошибке данных Boot пишет ошибку в лог и продолжает с прежним (пустым) содержимым базы.
3. `SceneRouter.reset_to(Routes.MAIN_MENU)`.

## 7. Сохранения

- Файл: `user://odraveth_save.json` (на Android — приватное хранилище приложения). Только локально.
- Формат: JSON-объект, обязательное поле `save_version` (сейчас `1`). Других секций на Stage 0 нет — они добавляются задачами соответствующих экранов.
- **Загрузка** (`SaveManager.load_data()`) всегда возвращает пригодные данные и выставляет `last_load_status`:

| Статус | Ситуация | Поведение |
|---|---|---|
| `NOT_FOUND` | первый запуск | значения по умолчанию |
| `OK` | файл прочитан | данные мигрированы до текущей версии |
| `CORRUPTED` | не JSON-объект, нет/неверный `save_version`, нет шага миграции | копия `*.corrupted`, значения по умолчанию |
| `READ_FAILED` | файл есть, но не открывается | значения по умолчанию, **запись заблокирована** |
| `UNSUPPORTED_VERSION` | сохранение более новой версии игры | значения по умолчанию, **запись заблокирована** (файл не перезаписывается) |

- **Запись** (`write_data()`) атомарная: временный файл `*.tmp` → `rename`. Поле `save_version` проставляется автоматически.
- **Миграции:** шаг с версии N на N+1 — метод `_migrate_from_vN(data) -> Dictionary` в `SaveManager`; при повышении `CURRENT_SAVE_VERSION` нужно добавить шаг. Отсутствие шага → `CORRUPTED`, а не падение.
- JSON хранит числа как `float` — код, читающий сохранение, приводит типы явно.
- `AppState` владеет экземпляром `SaveManager` и эмитит `EventBus.save_error` при проблемах.
- Runtime-состояние матча **не** сохраняется и не хранится в `AppState`.

## 8. Данные карт

### 8.1. Конвейер

```
res://data/cards/*.json ──► CardSchema.validate() ──► CardSchema.build() ──► CardDefinition ──► CardDatabase
```

- JSON — **канонический** источник данных карт. Пять файлов, по одному на фракцию; карта лежит в файле своей фракции.
- Каждый файл — объект ровно с одним ключом: `{"cards": [ ... ]}`.
- `CardDatabase.load_directory()` читает все `*.json` каталога в алфавитном порядке. Загрузка **всё или ничего**: при любой проблеме в любом файле прежнее содержимое не меняется, а `get_last_load_problems()` перечисляет все найденные проблемы.
- Ни одна проблема не исправляется молча. Единственное преобразование — целые числа JSON (`1.0`) в `int` после проверки.
- Каталог без `*.json` — ошибка (`ERR_FILE_NOT_FOUND`): так экспорт без файлов данных не пройдёт незамеченным.

### 8.2. Схема карты

| Поле | Тип | Правило |
|---|---|---|
| `id` | строка | snake_case, уникален; начинается с фракции (`ashravael_…`, `neutral_…` — проверяется тестами) |
| `name_en` | строка | непустое английское имя (латиница), уникально без учёта регистра |
| `name_ru` | строка | непустое русское имя (кириллица, без латиницы), уникально без учёта регистра |
| `faction` | строка | ключ `Faction.Id` |
| `type` | строка | ключ `CardEnums.Type` |
| `rarity` | строка | ключ `CardEnums.Rarity` |
| `cost` | целое | ≥ 0 |
| `deck_limit` | целое | ровно `GameRules.max_copies_in_deck(rarity)`: LEGENDARY — 1, остальные — 2 |
| `attack`, `health`, `armor` | целые | только и обязательно у `CREATURE`; `attack` ≥ 0, `health` ≥ 1, `armor` ≥ 0 |
| `charges` | целое | только у `ARTIFACT`, ≥ 1; есть тогда и только тогда, когда эффект расходует заряды |
| `rules_text_ru` | строка | утверждённый текст правил; пустой только у существ без способностей |
| `effects` | массив | декларативные эффекты; пуст тогда и только тогда, когда пуст `rules_text_ru` |

Неизвестные поля запрещены — и у карты, и у эффекта, и у параметров. Лор-тексты и поля «на будущее» не добавляются.

`CardDefinition` (`scripts/cards/card_definition.gd`) — типизированная модель тех же полей: `faction` — `Faction.Id`, `card_type` — `CardEnums.Type`, `rarity` — `CardEnums.Rarity`; у карт других типов характеристики существ и заряды равны 0.

### 8.3. Эффекты (только данные)

`CardEffectSpec` описывает одну способность. На Stage 1 эффекты **не исполняются**: нет боя, целей, RNG и изменения состояния.

Пример — «Кровный присяжник» (01) и «Углекоготь» (02):

```json
[
	{
		"effect_id": "enter_battle_attack_bonus",
		"trigger": "ENTER_BATTLE",
		"conditions": [{"type": "OWN_HERO_DAMAGED_THIS_TURN"}],
		"actions": [{"type": "MODIFY_STATS", "target": "SELF", "attack": 1, "duration": "NOT_STATED"}]
	},
	{
		"effect_id": "frenzy",
		"keyword": "FRENZY",
		"trigger": "SELF_DAMAGED",
		"limits": {"per_turn": 1},
		"actions": [{"type": "MODIFY_STATS", "target": "SELF", "attack": 1, "duration": "NOT_STATED"}]
	}
]
```

- `effect_id` (обязателен) — snake_case, уникален в пределах карты.
- `keyword` (необязателен) — метка утверждённого ключевого слова: `ONSLAUGHT`, `PROVOKE`, `DEFERRAL`, `FRENZY`. Эффект без действий допустим только как ключевое слово с триггером `STATIC` (например, «Провокация.»).
- `trigger` (обязателен) — событие из текста карты; для каждого триггера задано, каким типам карт он разрешён (`ON_PLAY` — только заклинания и т. д.).
- `conditions` (необязателен) — условия эффекта.
- `limits` (необязателен) — `per_turn`: сколько раз за ход эффект может сработать («Первый раз за ход…» и «Максимум N раз за ход»).
- `actions` (обязателен) — действия в порядке текста. У действия могут быть собственные `conditions`, которые проверяются непосредственно перед ним. Поэтому «вместо этого» («Железная память») записано как два действия со взаимоисключающими условиями, и проверка «броня полная» стоит первой.

Словарь идентификаторов (`EffectVocabulary`) закрыт: неизвестный триггер, условие, действие, цель, длительность, ключевое слово или параметр отвергаются. Каждый идентификатор используется хотя бы одной утверждённой картой (проверяется тестами). Новый идентификатор добавляется только вместе с утверждённой картой, которой он нужен.

| Группа | Идентификаторы |
|---|---|
| Триггеры | `ON_PLAY`, `ENTER_BATTLE`, `LAST_BREATH`, `STATIC`, `SELF_DAMAGED`, `AFTER_SELF_ATTACK`, `SELF_ARMOR_DEPLETED`, `SELF_SURVIVED_CREATURE_ATTACK`, `OWN_HERO_DAMAGED`, `ALLY_CREATURE_DIED`, `ALLY_CREATURE_PLAYED`, `OPPONENT_PLAYS_CARD`, `OPPONENT_PAYS_INCREASED_COST` |
| Действия | `MODIFY_STATS`, `DEAL_DAMAGE`, `DRAW_CARDS`, `GRANT_KEYWORD`, `GRANT_EXTRA_ATTACK`, `DESTROY`, `RETURN_TO_BOARD`, `RESTORE_ARMOR`, `SPEND_CHARGES`, `GAIN_SOUL_SHARDS`, `SPEND_SOUL_SHARDS`, `INCREASE_NEXT_OPPONENT_CARD_COST`, `INCREASE_PLAYED_CARD_COST`, `CREATE_ECHO_IN_HAND`, `LOOK_AT_TOP_CARDS` |
| Условия | `OWN_HERO_DAMAGED_THIS_TURN`, `OWN_HERO_HEALTH_AT_MOST`, `IS_OWN_TURN`, `FIRST_ATTACK_THIS_TURN`, `OWN_SOUL_SHARDS_AT_LEAST`, `SOUL_SHARDS_SPENT_EQUALS`, `PLAYED_CARD_TYPE`, `PLAYED_CARD_COST_AT_LEAST`, `PLAYED_CARD_COST_INCREASED_BY_YOU`, `TARGET_ARMOR_FULL`, `TARGET_ARMOR_NOT_FULL`, `NO_OTHER_ALLY_CREATURES`, `OWN_ACTIVE_ARTIFACT`, `OWN_DECK_SIZE_AT_MOST` |
| Длительности | `END_OF_TURN`, `END_OF_YOUR_NEXT_TURN`, `OWNER_NEXT_TURN`, `PERMANENT`, `WHILE_ACTIVE` (для `STATIC`), `NOT_STATED` (срок не указан в тексте — Q-17) |

Чего в данных нет намеренно:

- семантики ключевых слов, которые baseline не определяет (Натиск, Провокация, Предсмертие — Q-18);
- точного момента срабатывания: формулировки «когда» и «после того как» хранятся в `rules_text_ru`;
- правил, не записанных в тексте карты (например, дополнительных правил стоимости Эхо).

Осколки души: действия `GAIN_SOUL_SHARDS` (`amount`) и `SPEND_SOUL_SHARDS` (`amount` — обязательная стоимость, `up_to` — необязательная трата от 0 до N), условия `OWN_SOUL_SHARDS_AT_LEAST`, `SOUL_SHARDS_SPENT_EQUALS`, множитель `SOUL_SHARDS_SPENT`. Предел 0…10 — в `GameRules`. Счётчика Осколков во время матча на Stage 1 нет: он появится в MatchEngine, а не в `AppState`.

### 8.4. API CardDatabase

| Метод | Результат |
|---|---|
| `load_directory(dir = "res://data/cards") -> Error` | `OK`, `ERR_PARSE_ERROR` (битый JSON), `ERR_INVALID_DATA` (схема, дубликаты), `ERR_FILE_NOT_FOUND` |
| `get_last_load_problems() -> PackedStringArray` | все проблемы последней неудачной загрузки |
| `get_card(id) -> CardDefinition` | **копия** определения или `null` |
| `get_all_cards() -> Array[CardDefinition]` | копии всех карт в порядке `id` |
| `get_card_ids() -> PackedStringArray` | `id` по возрастанию (копия) |
| `has_card(id)`, `get_card_count()` | — |

Реестр никогда не отдаёт собственные экземпляры: изменение полученной копии не влияет на базу.

## 9. UI и адаптивность

- Дизайн-разрешение 1920×1080, `canvas_items` + `expand`: высота 1080 сохраняется, на вытянутых экранах (20:9 и т. п.) расширяется ширина, на планшетах (4:3) — высота. Вёрстка — контейнеры и якоря, без абсолютных координат.
- Ориентация `sensor_landscape`: только альбомная, допускается переворот на 180°.
- `SafeAreaContainer` — корневой контейнер каждого экрана: базовый отступ 32 px плюс вырезы/скругления из `DisplayServer.get_display_safe_area()` на мобильных устройствах. Отступы симметричны, потому что переворот на 180° переносит вырез на другую сторону без события изменения размера.
- Минимальная высота интерактивных кнопок — 112 px дизайна (≈ 48 dp на типичном 1080p-телефоне).
- Тема `assets/ui/placeholder_theme.tres` задаёт только размер шрифта (40). Шрифт — встроенный шрифт Godot (поддерживает кириллицу; проверяется тестом). Финальный шрифт не выбран (PRODUCT_BASELINE §9).
- Планшеты: точка расширения — проверка соотношения сторон / размера экрана в корне экрана и выбор альтернативной компоновки контейнеров. На Stage 0 не реализовано.
- Пользовательские строки — на русском прямо в сценах/скриптах (единственный язык первой версии).

## 10. Следующие модули (план, не реализовано)

| Модуль | Где | Ключевые требования |
|---|---|---|
| Герои | `data/heroes/`, `scripts/heroes/` | 4 утверждённых героя, способности из baseline |
| MatchEngine | `scripts/battle/` | Чистая логика (`RefCounted`), без узлов и UI; детерминированный RNG с seed; принадлежит экрану боя; числовые правила — из `GameRules`; исполнение `CardEffectSpec` и счётчик Осколков души — после решения Q-17, Q-18 |
| ИИ | `scripts/ai/` | Получает только публичное представление состояния (без руки и порядка колоды игрока, без будущих случайных результатов). Уровни NOVICE / TACTICIAN / STRATEGIST |
| Колоды | `scripts/decks/`, `data/decks/` | Валидация: 30 карт, своя фракция + нейтральные, лимиты копий (`GameRules.max_copies_in_deck`) |
| Финальный UI | `scenes/*`, `scripts/ui/` | По утверждённому дизайну; заменяет placeholder-сцены |
| Android build | export preset | Отдельная задача (раздел «Android» в DEVELOPMENT.md) |

## 11. Тестирование

- `tests/smoke_test.tscn` — headless smoke-тест: версия движка, настройки проекта, autoload, компиляция всех скриптов, загрузка всех сцен, таблица маршрутов, константы baseline, кириллица в шрифте, SaveManager, база карт, полная навигация (Boot → меню → все пункты меню → весь поток → три исхода → «Назад» Android).
- `tests/card_database_tests.gd` — тесты базы карт (запускаются smoke-тестом): точные значения всех 40 карт против независимой таблицы `tests/approved_cards.gd`, распределение по фракциям, типам и редкостям, целостность, данные эффектов, неизменяемость, детерминизм, 50 отвергаемых некорректных фикстур, отсутствие частичной загрузки. Фикстуры — вымышленные карты `test_*`, только во временном каталоге `user://`.
- Тест перехватывает все ошибки и предупреждения движка (`Logger`): вне блоков ожидаемых ошибок любая ошибка проваливает тест.
- `tests/run_tests.sh` — импорт, smoke-тест, запуск main scene. Подробности — в [`DEVELOPMENT.md`](DEVELOPMENT.md).
- Предупреждения GDScript, указывающие на вероятные дефекты (неиспользуемые переменные, затенение, недостижимый код, вызов static через экземпляр и др.), переведены в ошибки в `project.godot`, поэтому headless-проверка их видит.
