# odraveth
ODRAVETH — offline fantasy card strategy game for Android

**ODRAVETH / Одравет** — оригинальная офлайн карточная стратегическая игра. Мир — **NULMERYS / Нулмерис**. Игрок против ИИ, без сети.

- Движок: **Godot 4.7.2 stable**, язык **GDScript**
- Платформа №1: **Android**, только альбомная ориентация
- Интерфейс первой версии: **русский**

## Статус

**Stage 1 — база карт.** Поверх технического фундамента Stage 0 (сервисы ядра, Boot → главное меню, временные экраны утверждённого UI flow) есть:

- строгая типизированная `CardDatabase` с ровно 40 утверждёнными картами из `data/cards/*.json` (по 8 на четыре фракции и нейтральные);
- декларативная модель эффектов карт (только данные, без исполнения);
- правила ресурса «Осколки души»;
- headless-тесты: точные значения всех карт, целостность данных, отказ на некорректных данных.

Игровой логики пока нет: MatchEngine и исполнение эффектов, ИИ, финальный UI и Android-сборка — следующие этапы.

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
