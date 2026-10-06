# ODRAVETH — Разработка

## 1. Требования

| Инструмент | Версия | Примечание |
|---|---|---|
| Godot Engine | **4.7.2 stable**, стандартная сборка (не .NET) | Другие версии не используются. Скрипт проверок отказывается работать с иной версией |
| Bash | любой современный | для `tests/run_tests.sh` (Linux/macOS/WSL) |
| Git | любой современный | |

Android-инструменты (JDK, Android SDK, export templates) на Stage 0 не нужны — см. раздел 8.

### Установка Godot 4.7.2 stable

Только официальные источники:

- архив версий на сайте Godot: <https://godotengine.org/download/archive/> → 4.7.2-stable;
- релиз на GitHub: <https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable> (файлы и `SHA512-SUMS.txt`).

Пример для Linux x86_64 с проверкой контрольной суммы:

```bash
BASE=https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable
curl -LO "$BASE/Godot_v4.7.2-stable_linux.x86_64.zip"
curl -LO "$BASE/SHA512-SUMS.txt"
grep "Godot_v4.7.2-stable_linux.x86_64.zip" SHA512-SUMS.txt | sha512sum -c -
unzip Godot_v4.7.2-stable_linux.x86_64.zip
./Godot_v4.7.2-stable_linux.x86_64 --version   # 4.7.2.stable.official.ed1daf0bf
```

Бинарники Godot в репозиторий не коммитятся (`.gitignore`: `Godot_v*`).

## 2. Первый запуск

Каталог `.godot/` (кэш импорта и реестр `class_name`) не хранится в Git. После клонирования его нужно построить, иначе глобальные классы (`Routes`, `SaveManager` и т. д.) не будут найдены:

```bash
godot --headless --path . --import
```

Либо просто открыть проект в редакторе — он сделает это сам.

## 3. Запуск

```bash
godot --path .                      # игра в окне 1280×720 (только для десктопа)
godot --path . --editor             # редактор
godot --headless --path . --quit-after 300 --verbose   # headless: Boot → Main Menu
```

Размер окна 1280×720 задан `window_width_override`/`window_height_override` и влияет только на десктоп; дизайн-разрешение остаётся 1920×1080. Чтобы проверить вытянутый экран, растяните окно или используйте `--resolution 2400x1080`.

## 4. Проверки

Одна команда запускает все доступные проверки:

```bash
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 tests/run_tests.sh
```

| Шаг | Что делает | Условие провала |
|---|---|---|
| версия | `godot --version` | не `4.7.2.stable*` (exit 2) |
| `import` | `--import`: строит `.godot/`, компилирует autoload и глобальные классы | ненулевой код или строки `ERROR`/`WARNING`/`SCRIPT ERROR`/`Parse Error` в логе |
| `smoke_test` | `--scene res://tests/smoke_test.tscn` | ненулевой код, нет строки `SMOKE TEST PASSED`, ошибки парсера, утечки при выходе |
| `main_scene` | реальная main scene 300 кадров с `--verbose` | ошибки/предупреждения в логе или нет `SceneRouter: opened 'main_menu'` |

Коды выхода: `0` — всё прошло, `1` — проверка провалена, `2` — Godot не найден или не той версии. Каждый шаг ограничен по времени (`timeout`, 600 с) и по числу кадров, поэтому сломанный скрипт теста не подвешивает запуск.

Smoke-тест отдельно:

```bash
godot --headless --path . --scene res://tests/smoke_test.tscn
```

Негативные проверки внутри теста намеренно вызывают ошибки (повреждённое сохранение, неизвестный маршрут и т. п.). Они печатаются между маркерами `[expected errors/warnings below]` и `[end of expected errors/warnings]`. Любая ошибка движка вне этих блоков проваливает тест.

### Тесты MatchEngine

Модули `tests/engine/*.gd` запускает тот же smoke-тест (секции `MatchEngine core rules`, `Hero abilities`, `Keywords, durations, static abilities, timing`, `Behaviour of the 40 approved cards`, `Determinism, replay and fuzz matches`). Сторонних фреймворков нет: модуль — класс с `_init(check, expect_errors, cards)` и `run()`.

| Файл | Что проверяет |
|---|---|
| `engine_core_tests.gd` | Подготовка и колоды, замена стартовых карт, энергия и «Осколок импульса», рука и сгорание, «Разлом», лимит поля, бой и броня, гибель и её порядок, исходы, артефакты, обязательные `CHOSEN_*` цели и legal commands, FIFO/stacking cost modifiers, снимок, отвергнутые команды без изменений, предохранитель, изоляция RNG |
| `hero_power_tests.gd` | Четыре способности героев и их соответствие baseline |
| `keyword_tests.gd` | Вход в бой, Предсмертие, Натиск, Провокация, Неистовство, Отложение, Эхо, длительности, статические способности, `per_turn`, WHEN / AFTER |
| `card_behavior_tests.gd` | Поведение каждой из 40 карт: функции `test_<карта>` с `_cover([...])`; в конце — проверка, что покрыты все 40 карт и что [`CARD_TEST_COVERAGE.md`](CARD_TEST_COVERAGE.md) перечисляет каждую пару «карта → тест» |
| `determinism_tests.gd` | Replay (один seed и одни команды — одинаковые снимки после каждой команды и одинаковый журнал) и 24 fuzz-матча случайной политикой по `get_legal_commands()` с проверкой инвариантов после каждой команды |
| `match_fixture.gd`, `scripted_rng.gd` | Сценарии с точным состоянием (`scenario()`: ход игрока 0, пустые руки и поле, 10 энергии, колоды-филлеры) и RNG с заданной последовательностью |

Новый поведенческий тест карты: функция `test_…` в `card_behavior_tests.gd` с вызовом `_cover([&"id_карты"])` и строка (или имя теста) в `docs/CARD_TEST_COVERAGE.md` — иначе проверка покрытия упадёт.

Мутационные проверки (намеренно сломанный движок должен провалить тесты) выполняются только во временной копии проекта вне репозитория; копии и патчи не коммитятся.

Corrective regression Stage 2 дополнительно фиксирует четыре обязательные мутации: возврат creature-target bypass, обратный порядок cost modifiers, применение более одного Distortion к карте и расход skipped Thoughtscar. Каждая такая временная мутация должна приводить к провалу набора тестов; изменённые копии не попадают в рабочую ветку.

**Не используйте `--check-only --script` для проверки скриптов проекта**: в этом режиме Godot не регистрирует autoload, и все скрипты, обращающиеся к `EventBus`/`SceneRouter`/`AppState`/`CardDatabase`, ложно падают с `Identifier not found`. Компиляцию всех скриптов в контексте проекта проверяет smoke-тест.

Перед завершением любой задачи запускайте `tests/run_tests.sh`. Если Godot 4.7.2 недоступен — так и напишите в отчёте; не заменяйте его другой версией.

## 5. Соглашения по коду

- [Официальный стиль GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html): табы, `snake_case` для файлов/функций/переменных, `PascalCase` для классов и узлов, `CONSTANT_CASE` для констант.
- Статическая типизация везде, где тип известен (`:=`, аннотации параметров и возвращаемых значений).
- Идентификаторы и комментарии в коде — на английском; документация — на русском; **все строки, видимые игроку, — на русском**.
- Предупреждения GDScript, указывающие на дефекты, в проекте являются ошибками (`project.godot`, секция `[debug]`). Не ослабляйте их ради прохождения проверки — исправляйте код.
- Пути сцен — только в `Routes`. Экраны переходят через `SceneRouter`, никогда через `change_scene_*`.
- Числа из правил матча — только из `GameRules`; таксономия — из `CardEnums` и `Faction`. Не дублируйте литералы.
- Новый autoload — только с обоснованием в `DECISIONS.md`.
- Не хранить состояние матча в autoload. `MatchEngine` — обычный объект: один экземпляр — один матч.
- Правила матча — только в `scripts/battle/`. UI и ИИ не проверяют правила сами: они спрашивают `MatchEngine` (`validate`, `get_legal_commands`, `get_valid_*_targets`, `get_card_cost`).
- В коде матча нет глобальной случайности (`randi`, `randf`, `randomize`, `Array.shuffle`): только переданный `MatchRng`.
- Карты не дублируются в коде движка: поведение задают данные `CardEffectSpec`; новый идентификатор словаря — только вместе с утверждённой картой и тестом.

## 6. Как добавить экран

1. Добавить константу маршрута, путь сцены и русский заголовок в `scripts/core/routes.gd`.
2. Создать сцену в `scenes/<раздел>/`. Корень — `Control` на весь экран, первым потомком — `MarginContainer` со скриптом `SafeAreaContainer`.
3. Если экрану нужны входные данные — реализовать `apply_route_params(params: Dictionary)` в скрипте корня и объявить ключи константами.
4. Переходы — только `SceneRouter.go_to/replace_with/reset_to/go_back`.
5. Дополнить `tests/smoke_test.gd` проверкой перехода и запустить `tests/run_tests.sh`.

Изменение утверждённого UI flow — только по заданию пользователя (`PRODUCT_BASELINE.md`).

## 7. Данные карт

- Канонический источник — `data/cards/<фракция>.json`. Формат и словарь эффектов — `ARCHITECTURE.md` §8.
- Карты, их названия, характеристики и тексты меняются **только** по решению пользователя (`PRODUCT_BASELINE.md` §6.6).
- Любое изменение карты делается одновременно в трёх местах: JSON, `tests/approved_cards.gd` и таблица в `PRODUCT_BASELINE.md`. Иначе тесты упадут — так и задумано.
- После правки запустите `tests/run_tests.sh`. Если данные не проходят проверку, лог перечисляет все проблемы с путём до поля, например `CardDatabase: res://data/cards/dumoryss.json: cards[7] (dumoryss_nullglass): effects[0].actions[0]: unknown action …`.
- Фикстуры для негативных проверок пишутся только в тестах (во временный каталог `user://`), никогда в `data/cards`.
- У событийного эффекта обязателен `timing`: `WHEN` для «когда», `AFTER` для «после» / «после того как» (ARCHITECTURE §8.3). Ожидаемые значения дублируются в `EXPECTED_TIMINGS` теста базы карт.

## 8. Сохранения при разработке

`user://` на десктопе:

| ОС | Путь |
|---|---|
| Linux | `~/.local/share/godot/app_userdata/ODRAVETH/` |
| Windows | `%APPDATA%\Godot\app_userdata\ODRAVETH\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/ODRAVETH/` |

Сброс сохранения — удалить `odraveth_save.json` в этом каталоге. Smoke-тест использует отдельный каталог `user://odraveth_smoke_test/` и удаляет его после себя; файл реального сохранения он только читает (через Boot).

При изменении формата сохранения: увеличить `SaveManager.CURRENT_SAVE_VERSION`, добавить `_migrate_from_vN`, добавить проверку миграции в smoke-тест, записать решение в `DECISIONS.md`.

## 9. Android

На Stage 0 Android-экспорт **не настроен** и APK не собирается. Отдельная задача Android build должна:

- установить export templates **4.7.2 stable**, JDK и Android SDK по [официальной инструкции](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html);
- создать `export_presets.cfg` (его можно коммитить: пароли и пути к keystore Godot хранит в `.godot/export_credentials.cfg`, который игнорируется);
- исключить `tests/*` из экспорта и убедиться, что `data/**/*.json` попадает в пакет;
- проверить на устройстве: полноэкранный/immersive режим, edge-to-edge, safe area с вырезом, переворот на 180°, системную кнопку «Назад»;
- **никогда** не коммитить keystore, пароли и `local.properties` (закрыто `.gitignore`).

## 10. Git

- Не работать напрямую в `main`, не делать merge в `main` без решения владельца репозитория.
- Каждая задача — отдельная ветка и PR.
- Не делать force-push в общие ветки.
- Коммитить `*.uid` вместе с соответствующими скриптами; не коммитить `.godot/`.


## 11. Разработка и проверка AI

Stage 3 находится в scripts/ai/; безопасное представление MatchEngine — scripts/battle/ai_observation_builder.gd.

Основной regression по-прежнему запускается одной командой tests/run_tests.sh с GODOT_BIN, указывающим на Godot 4.7.2 stable.

Smoke runner включает два AI-модуля:
- tests/ai/ai_tests.gd — observation boundary, information barriers, source anti-cheat, 100× determinism, difficulty scenarios, mulligan/choice/resources/targets/full turn/guard;
- tests/ai/ai_stress_tests.gd — QA-only AI-vs-AI matrix и fixed-seed stress matches.

tests/ai/ai_match_harness.gd — только тестовый harness; он не является игровым режимом и не переносится в product flow.

Ручной benchmark без pass/fail threshold находится в tests/ai/benchmark_ai.gd. Stage 3 намеренно не использует minimax/game tree/deep clones.

CI workflow .github/workflows/stage2-corrective.yml сохраняет четыре Stage 2 mutations и добавляет Stage 3 mutations: попытка читать opponent hand через .state, утечка deck order в observation, random tie-break, отключение legal-set guard и отключение per-turn guard. Все изменения выполняются только в checkout runner и затем восстанавливаются.

## 12. Проверки Stage 4 Battle UI

`tests/run_tests.sh` на Godot 4.7.2 выполняет существующий regression (baseline 744 checks) и `tests/battle_ui_tests.gd`: реальные экземпляры BattleScene с `BattleLaunchConfig`, управление mulligan/картами/целями/способностями/модальными окнами, AI presentation, lock и layout при 1920×1080 и 2400×1080. Smoke navigation отдельно проходит Main Menu → Prebattle → реальный Battle MULLIGAN и Result/rematch. Legacy TEST_MODE проверяется только явным маршрутом без конфигурации.

Техническая колода создаётся `BattleLaunchConfig.technical_dev_config(CardDatabase)` и не является пользовательским preset. Чтобы проверить другой состав, используйте `BattleLaunchConfig.create()` с валидными колодами. Не делайте игровых утверждений по временной технической конфигурации; подробности — [BATTLE_UI.md](BATTLE_UI.md).
