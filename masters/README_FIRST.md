# ODRAVETH — утверждённый художественный пакет

Статус: **APPROVED / FROZEN**

Этот каталог содержит только утверждённые пользователем игровые изображения. Изображения из `rejected/` и промежуточные contact sheet в пакет не включены.

## Состав

- `assets/cards/` — 40 игровых иллюстраций карт, WebP, 640×800.
- `masters/cards/` — 40 мастер-файлов карт, PNG, 1122×1402.
- `assets/environments/` — 6 фонов, WebP, 2560×1440.
- `assets/heroes/` — Хранитель и 4 героя, PNG с альфа-каналом.
- `assets/environment_details/` — книга и 2 кольца Конвергенции, PNG с альфа-каналом.
- `assets/environments/gates_left.png`, `gates_right.png` — отдельные створки ворот с альфа-каналом.
- `ASSET_MANIFEST.csv` — машинно-читаемый перечень файлов и назначений.
- `SHA256SUMS.txt` — контрольные суммы всех файлов пакета, кроме самого списка сумм.

## Жёсткие правила интеграции

1. Не перерисовывать, не заменять и не генерировать заново эти изображения.
2. Не использовать портреты героев как иллюстрации карт.
3. Не добавлять в изображения текст, рамки, числа и случайные эмблемы — они создаются живым UI Godot.
4. Допустимы только технические операции импорта: масштабирование в контейнере, обрезка маской интерфейса, фильтрация текстуры и анимация отдельных слоёв.
5. Khevaruun использует только исправленную вторую версию; отклонённая первая версия в этот пакет не входит.

## Карты

### Ashravael

- `ashravael_bloodsworn` — Кровный присяжник
- `ashravael_cinderclaw` — Углекоготь
- `ashravael_emberbound` — Скованный жаром
- `ashravael_gorebrand` — Клеймённый кровью
- `ashravael_warfiend` — Изверг войны
- `ashravael_blood_tithe` — Кровавая десятина
- `ashravael_cinder_oath` — Клятва пепла
- `ashravael_furnace_sigil` — Печать горнила

### Nerqathen

- `nerqathen_gravewisp` — Могильный огонёк
- `nerqathen_pale_binder` — Бледный пленитель
- `nerqathen_bone_cantor` — Певец костей
- `nerqathen_mourning_husk` — Скорбная оболочка
- `nerqathen_soulmonger` — Скупщик душ
- `nerqathen_soul_harvest` — Жатва душ
- `nerqathen_second_burial` — Второе погребение
- `nerqathen_ossuary_bell` — Колокол костницы

### Dumoryss

- `dumoryss_veilbreaker` — Разрушитель Завесы
- `dumoryss_thoughtscar` — Шрам разума
- `dumoryss_null_seer` — Провидец Пустоты
- `dumoryss_rift_scribe` — Писец Разлома
- `dumoryss_echo_leech` — Пиявка эха
- `dumoryss_fractured_moment` — Расколотый миг
- `dumoryss_veil_tax` — Дань Завесе
- `dumoryss_nullglass` — Пустостекло

### Khevaruun — исправленная версия

- `khevaruun_aegis_hound` — Гончая Эгиды
- `khevaruun_shieldroot` — Щитокорень
- `khevaruun_ironwarden` — Железный хранитель
- `khevaruun_platecaller` — Призыватель лат
- `khevaruun_wallforged` — Стенокованный
- `khevaruun_temper_rite` — Обряд закалки
- `khevaruun_iron_memory` — Железная память
- `khevaruun_bastion_core` — Сердце бастиона

### Neutral

- `neutral_mireglass_wanderer` — Странник болотного стекла
- `neutral_vantrel_duskling` — Сумеречник Вантрела
- `neutral_threnic_cartographer` — Тренический картограф
- `neutral_orryxian_wayfarer` — Орриксийский путник
- `neutral_sablequill_nomad` — Кочевник Чёрного Пера
- `neutral_kelvarn_relicbearer` — Реликвеносец Келварна
- `neutral_rivenshade_grazer` — Травояд Ривеншейда
- `neutral_pale_meridian` — Бледный меридиан
