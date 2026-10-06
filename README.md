# odraveth
ODRAVETH — offline fantasy card strategy game for Android

**ODRAVETH / Одравет** — оригинальная офлайн карточная стратегическая игра. Мир — **NULMERYS / Нулмерис**. Игрок против ИИ, без сети.

- Движок: **Godot 4.7.2 stable**, язык **GDScript**
- Платформа №1: **Android**, только альбомная ориентация
- Интерфейс первой версии: **русский**

## Статус

**Stage 4 — playable технический Battle UI.** Поверх Stage 0 foundation, Stage 1 CardDatabase, Stage 2 MatchEngine и Stage 3 AI реализованы:

- честный sanitized observation API без opponent hand, deck order, future draw и RNG;
- NOVICE / TACTICIAN / STRATEGIST с детерминированным explainable command scoring;
- mulligan, play/targets, Soulmonger choice, hero powers, Impulse Shard, attacks, Cartographer CHOOSE и полный AI turn;
- canonical tie-break без AI randomness и guard от бесконечного хода;
- information-barrier, determinism, AI-vs-AI, stress и mutation tests.

Путь «Играть → Подготовка к бою → Начать бой» запускает реальный матч с заменой стартовой руки и AI. Временная техническая конфигурация выбирает две тестовые колоды; это не утверждённые preset decks. Battle UI включает выбор целей, информационную карточку, пошаговое отображение AI и результат с повтором. Финальные UX, art и Android-сборка пока не утверждены. AI не использует neural network, external API или сеть.

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
| [docs/BATTLE_UI.md](docs/BATTLE_UI.md) | Боевой UI, технический запуск, presentation и интеграционные тесты |
| [CLAUDE.md](CLAUDE.md) | Правила работы Claude в репозитории |
