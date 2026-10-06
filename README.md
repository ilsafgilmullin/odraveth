# odraveth
ODRAVETH — offline fantasy card strategy game for Android

**ODRAVETH / Одравет** — оригинальная офлайн карточная стратегическая игра. Мир — **NULMERYS / Нулмерис**. Игрок против ИИ, без сети.

- Движок: **Godot 4.7.2 stable**, язык **GDScript**
- Платформа №1: **Android**, только альбомная ориентация
- Интерфейс первой версии: **русский**

## Статус

**Stage 2 — MatchEngine.** Поверх технического фундамента Stage 0 (сервисы ядра, Boot → главное меню, временные экраны утверждённого UI flow) и базы карт Stage 1 (строгая типизированная `CardDatabase` с ровно 40 утверждёнными картами из `data/cards/*.json`) есть:

- детерминированный `MatchEngine` (`scripts/battle/`): подготовка матча и проверка колод, замена стартовых карт, ходы, энергия и «Осколок импульса», добор и сгорание, «Разлом», бой и броня, гибель существ, Осколки души, артефакты, 4 способности героев, исполнение всех 40 карт по их данным, Победа / Поражение / Ничья;
- инжектируемый seeded RNG, канонические снимки состояния, структурированный журнал событий, отказ от недопустимых команд без изменения состояния;
- headless-тесты: правила, каждая карта и способность, ключевые слова, replay и fuzz-матчи.

ИИ, финальный UI (включая боевой экран) и Android-сборка — следующие этапы. Матч пока нельзя сыграть из интерфейса.

## Быстрый старт

```bash
# Godot 4.7.2 stable: https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable
godot --headless --path . --import      # построить кэш .godot/ после клонирования
godot --path .                          # запустить игру
GODOT_BIN=/path/to/godot-4.7.2 tests/run_tests.sh   # все проверки
```

## Документация

| Документ | Содержание |
|---|---|
| [docs/PRODUCT_BASELINE.md](docs/PRODUCT_BASELINE.md) | Утверждённые продуктовые решения — source of truth |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Архитектура проекта |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Установка, запуск, проверки, соглашения |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Журнал технических решений |
| [docs/CARD_TEST_COVERAGE.md](docs/CARD_TEST_COVERAGE.md) | Покрытие 40 карт поведенческими тестами |
| [CLAUDE.md](CLAUDE.md) | Правила работы Claude в репозитории |
