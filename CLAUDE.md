# CLAUDE.md — правила работы Claude в репозитории ODRAVETH

ODRAVETH / Одравет — офлайн карточная стратегическая игра для Android (Godot 4.7.2 stable, GDScript).
Source of truth по продукту: [`docs/PRODUCT_BASELINE.md`](docs/PRODUCT_BASELINE.md).

## Обязательные правила

1. **Сначала анализировать существующий проект.** Перед изменениями проверить ветку, HEAD, текущее содержимое репозитория и документацию в `docs/`.
2. **Не переписывать исправный код без необходимости.** Минимальные изменения в рамках задачи; рефакторинг — только если он нужен задаче.
3. **Не менять product baseline самостоятельно.** `docs/PRODUCT_BASELINE.md` меняется только по прямому заданию пользователя; открытые вопросы (раздел 11) не закрываются предположениями — их задают пользователю.
4. **Не придумывать новые карты, героев, фракции и механики.** Только то, что утверждено пользователем.
5. **Не добавлять сеть, backend или сторонние SDK без отдельного ТЗ.** Сюда же: Firebase, аккаунты, авторизация, multiplayer, websocket, telemetry, analytics, реклама, магазин, покупки, облачные сохранения.
6. **Все пользовательские строки первой версии — на русском языке.**
7. **Android landscape — основная целевая платформа.** 1920×1080, `canvas_items` + `expand`, только альбомная ориентация, safe area.
8. **Перед завершением задачи запускать доступные проверки:** `GODOT_BIN=<Godot 4.7.2> tests/run_tests.sh`.
9. **Не утверждать, что что-либо протестировано, если тест фактически не запускался.**
10. **Если среда не позволяет выполнить проверку — явно указать это в итоговом отчёте** (что проверено, что нет и почему). Не подменять Godot 4.7.2 другой версией молча.

## Технические правила проекта

- Godot **4.7.2 stable** и GDScript; никакого C#, никаких 4.8 dev/beta.
- Переходы между экранами — только через `SceneRouter` с id из `Routes`; экраны не вызывают `change_scene_*`.
- Состояние матча не хранится в autoload; данные между экранами передаются параметрами маршрута.
- Новый autoload — только с обоснованием в `docs/DECISIONS.md`.
- Числовые правила матча — из `GameRules`, таксономия — из `CardEnums` / `Faction`; при изменении baseline обновлять их вместе с документом и smoke-тестом.
- Карты — только 40 утверждённых (`data/cards/*.json` — канонический источник). Изменение карты — только по решению пользователя и одновременно в JSON, `tests/approved_cards.gd` и `PRODUCT_BASELINE.md` §6.6.
- Эффекты карт — декларативные данные из закрытого словаря `EffectVocabulary`; их исполняет MatchEngine по правилам PRODUCT_BASELINE §5–6. Не дублировать карты в коде движка и не придумывать правила, которых нет в baseline.
- `MatchEngine` — не autoload: один экземпляр — один матч. Правила матча — только в `scripts/battle/`; UI и ИИ получают проверку и допустимые команды от движка и не дублируют её.
- Production AI в scripts/ai/ получает состояние только через MatchEngine.get_observation(); прямые .state, .snapshot(), ._rng, ._resolver запрещены.
- Боевой UI получает публичные наблюдения, цели и доступность команд через `BattleSession`; `BattleLaunchConfig.technical_dev_config()` существует только для dev/test; обычный Prebattle запускает сохранённый UserDeck игрока. Временная генерация применяется только к внутренней колоде ИИ.
- Готовность пользовательской колоды определяет только `DeckValidator`, а сохранения v2 содержат только plain data; Q-02/Q-14/Q-16 закрыты, Q-15 открыт.
- AI выбирает только из get_legal_commands() и выполняет команды только через MatchEngine. Нельзя использовать global RNG, hidden opponent hand, identity/order колод или future draw/random results.
- Различие NOVICE / TACTICIAN / STRATEGIST — только scoring quality; tie-break всегда canonical deterministic.
- Вся случайность матча — через инжектируемый `MatchRng`; глобальные `randi`/`randf`/`randomize`/`Array.shuffle` в коде матча запрещены. Отвергнутая команда не должна менять состояние.
- Изменение правила матча — вместе с тестом в `tests/engine/`; каждая карта должна иметь поведенческий тест и строку в `docs/CARD_TEST_COVERAGE.md`.
- Не ослаблять строгие предупреждения GDScript в `project.godot` — исправлять код.
- Не коммитить `.godot/`, сборки, keystore, пароли и другие секреты. Коммитить `*.uid` вместе со скриптами.
- Не работать в `main` и не делать в него merge; не делать force-push.
- Не скачивать случайные ассеты; финальный шрифт и дизайн не выбирать самостоятельно.
- Технические решения фиксировать в `docs/DECISIONS.md`.

## Где что

| Документ | Содержание |
|---|---|
| [`docs/PRODUCT_BASELINE.md`](docs/PRODUCT_BASELINE.md) | Утверждённые продуктовые решения и открытые вопросы |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Устройство проекта, autoload, навигация, сохранения, данные, MatchEngine |
| [`docs/CARD_TEST_COVERAGE.md`](docs/CARD_TEST_COVERAGE.md) | Поведенческие тесты каждой из 40 карт |
| [docs/AI_DESIGN.md](docs/AI_DESIGN.md) | Stage 3 AI boundary, scoring, deterministic loop и QA |
| [docs/BATTLE_UI.md](docs/BATTLE_UI.md) | Battle flow, состояния UI, презентация AI и Result |
| [docs/DECKS_AND_COLLECTION.md](docs/DECKS_AND_COLLECTION.md) | Пользовательские колоды, коллекция, сохранения и Prebattle |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | Установка Godot, запуск, проверки, соглашения |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Журнал технических решений |

## Проверки

```bash
godot --headless --path . --import                              # после клонирования
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 tests/run_tests.sh
```

`--check-only --script` для скриптов проекта не использовать: в этом режиме autoload не регистрируются и проверка ложно падает (см. DEVELOPMENT §4).
