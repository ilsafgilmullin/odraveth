# odraveth
ODRAVETH — offline fantasy card strategy game for Android

**ODRAVETH / Одравет** — оригинальная офлайн карточная стратегическая игра. Мир — **NULMERYS / Нулмерис**. Игрок против ИИ, без сети.

- Движок: **Godot 4.7.2 stable**, язык **GDScript**
- Платформа №1: **Android**, только альбомная ориентация
- Интерфейс первой версии: **русский**

## Статус

**Stage 5 — пользовательская подготовка к бою.** Поверх Stage 0 foundation, Stage 1 CardDatabase, Stage 2 MatchEngine и Stage 3 AI реализованы:

- честный sanitized observation API без opponent hand, deck order, future draw и RNG;
- NOVICE / TACTICIAN / STRATEGIST с детерминированным explainable command scoring;
- mulligan, play/targets, Soulmonger choice, hero powers, Impulse Shard, attacks, Cartographer CHOOSE и полный AI turn;
- canonical tie-break без AI randomness и guard от бесконечного хода;
- information-barrier, determinism, AI-vs-AI, stress и mutation tests.

Путь «Герои → Колоды → Играть → Подготовка к бою → Начать бой» запускает матч с сохранённой пользовательской колодой из 30 карт. Коллекция содержит все 40 карт; фильтры и описание доступны без системы владения. До утверждения колод ИИ внутренняя техническая генерация используется только для противника. Battle UI включает выбор целей, информационную карточку, пошаговое отображение AI и результат с повтором. Финальный art и Android-сборка пока не утверждены; содержимое «Прогресса» и «Настроек» открыто (Q-15). AI не использует neural network, external API или сеть.

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
| [docs/AI_DESIGN.md](docs/AI_DESIGN.md) | Information boundary, scoring, difficulty, turn loop и QA AI |
| [docs/BATTLE_UI.md](docs/BATTLE_UI.md) | Боевой UI, пользовательский запуск, presentation и интеграционные тесты |
| [docs/DECKS_AND_COLLECTION.md](docs/DECKS_AND_COLLECTION.md) | Hero Select, Collection, Deck Builder, сохранения и тесты Stage 5 |
| [CLAUDE.md](CLAUDE.md) | Правила работы Claude в репозитории |
