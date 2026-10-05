# odraveth
ODRAVETH — offline fantasy card strategy game for Android

**ODRAVETH / Одравет** — оригинальная офлайн карточная стратегическая игра. Мир — **NULMERIS / Нулмерис**. Игрок против ИИ, без сети.

- Движок: **Godot 4.7.2 stable**, язык **GDScript**
- Платформа №1: **Android**, только альбомная ориентация
- Интерфейс первой версии: **русский**

## Статус

**Stage 0 — технический фундамент.** Есть структура проекта, сервисы ядра (EventBus, SceneRouter, AppState, SaveManager, CardDatabase), Boot → главное меню и временные экраны для проверки навигации по утверждённому UI flow, headless smoke-тест.

Игровой логики пока нет: база карт, MatchEngine, ИИ, финальный UI и Android-сборка — следующие этапы.

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
| [CLAUDE.md](CLAUDE.md) | Правила работы Claude в репозитории |
