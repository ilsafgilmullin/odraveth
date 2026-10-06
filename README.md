# odraveth
ODRAVETH — offline fantasy card strategy game for Android

**ODRAVETH / Одравет** — оригинальная офлайн карточная стратегическая игра. Мир — **NULMERYS / Нулмерис**. Игрок против ИИ, без сети.

- Движок: **Godot 4.7.2 stable**, язык **GDScript**
- Платформа №1: **Android**, только альбомная ориентация
- Интерфейс первой версии: **русский**

## Статус

**Stage 3 — deterministic offline AI.** Поверх Stage 0 foundation, Stage 1 CardDatabase и Stage 2 MatchEngine реализованы:

- честный sanitized observation API без opponent hand, deck order, future draw и RNG;
- NOVICE / TACTICIAN / STRATEGIST с детерминированным explainable command scoring;
- mulligan, play/targets, Soulmonger choice, hero powers, Impulse Shard, attacks, Cartographer CHOOSE и полный AI turn;
- canonical tie-break без AI randomness и guard от бесконечного хода;
- information-barrier, determinism, AI-vs-AI, stress и mutation tests.

AI не использует neural network, external API или сеть. Финальный Battle UI и Android-сборка в Stage 3 не входят; матч пока не подключён к финальному игровому интерфейсу.

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
| [CLAUDE.md](CLAUDE.md) | Правила работы Claude в репозитории |
