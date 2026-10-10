# ODRAVETH — Art Deliverables (production art handoff)

Источник требований: art-pack `ODRAVETH_ART_ALL_SCREENS_CLAUDE` (ASSET_MANIFEST.csv, CARD_ART_MANIFEST_40.csv, канон из Master Task §5–13) и `docs/PRODUCT_BASELINE.md`.

## Почему здесь только слоты, а не готовые картины

В среде Claude Code нет инструмента генерации изображений, а пакет не содержит готовых production-слоёв (`final_art_assets_included: 0`). Концепты и утверждённая композиция Main Menu — это плоские изображения целых экранов с нарисованным текстом/кнопками; по ТЗ их **нельзя** класть в игру. Процедурные Visual Alpha слои не выдаются за финальный арт.

Поэтому сделано: **drop-in конвейер** (`scripts/ui/visual/art_assets.gd`). Каждый файл ниже кладётся по указанному пути, проект один раз импортируется (`godot --headless --path . --import`), и соответствующий экран сразу рисует его вместо процедурного слоя — без правки кода. UI (кнопки, имена, числа, правила, прогресс) остаётся живыми элементами Godot поверх арта. Тест `tests/art_assets_tests.gd` проверяет подмену на тестовых файлах.

## Статусы

`Missing` — файла нет, на экране временный процедурный слой. `Candidate` — создан, ждёт решения пользователя. `Approved` — утверждённый пользователем production-арт, интегрирован и протестирован.

## Окружения, персонажи, детали (растровые)

| Слот | Путь | Экран | Мастер / формат | Требования | Статус |
|---|---|---|---|---|---|
| guardian_terrace | `assets/environments/citadel_guardian_terrace.webp` | Главное меню | 16:9, мастер 3840×2160, игровой 2560×1440 | Без людей, текста, логотипа, кнопок; Цитадель, мосты, водопады, глубина; правая треть спокойная под меню | Missing |
| guardian | `assets/heroes/guardian_nulmeris.png` | Главное меню | PNG с честной альфой, ≥1600×2400, по пояс/колени | Мужчина ~70–75, крепкий, добрый, загадочный; седые волосы, аккуратная седая борода, стально-серо-зелёные **несветящиеся** глаза; многослойные нейтральные одежды Цитадели; жезл тёмный камень/металл/матовое золото с **тремя вложенными кольцами**, без кристалла; спокойная 3/4 поза, левая часть кадра | Approved |
| gates | `assets/environments/gates_of_nulmeris.webp` | Boot | 16:9, 3840×2160 | Врата без процентов и надписей; центр под Печать и линию прогресса | Missing |
| gates_left / gates_right | `assets/environments/gates_left.png`, `gates_right.png` | Boot | Полнокадровые PNG с альфой | Отдельные створки на том же кадре, что и фон; раздвигаются кодом | Approved |
| hero_hall | `assets/environments/citadel_hero_hall.webp` | Выбор героя | 16:9, ≥2560×1440 | Спокойный зал за четырьмя портретами | Missing |
| hero_KEZHARYN | `assets/heroes/kezharyn.png` | Герои, Prebattle, бой, результат | PNG 3:4 или 4:5, crop-safe | Мужчина 34–38, стройный командир Ашравайль; тёплая оливковая кожа; почти чёрные волосы с медным отливом; слегка кривой нос; короткий шрам через **правую** бровь; тёмно-янтарные глаза без свечения; асимметричная броня тяжелее слева, тёмно-красная/медь; плащ на одно плечо; длинный **однолезвийный** клинок. Не рогатый варвар/паладин | Approved |
| hero_VHORAZEL | `assets/heroes/vhorazel.png` | то же | PNG 3:4 или 4:5 | Мужчина ~50, высокий, сухой; серо-оливковая кожа; тёмные волосы с серебром на висках; серо-зелёные глаза; церемониальный исследователь душ; вертикальный грудной резонатор из тонких металлических сегментов; узкий резонансный жезл. Без черепов, косы, лича, большого светящегося камня | Approved |
| hero_SYRRAVETH | `assets/heroes/syrraveth.png` | то же | PNG 3:4 или 4:5 | **Женщина** 29–33, человек (обычные уши), стройная; тёмно-каштановые асимметричные волосы до шеи; серо-фиолетовые глаза без свечения; графит и приглушённая слива; механические/парящие металлические кольца **на левой руке**. Не эльф, не ведьма, не фиолетовые волосы, без посоха | Approved |
| hero_TAZHYRION | `assets/heroes/tazhyrion.png` | то же | PNG 3:4 или 4:5 | Мужчина 42–46, широкий; бронзово-коричневая кожа; короткие чёрные волосы с сединой; аккуратная борода; тёмно-карие глаза; броня из **взаимосцепленных нестандартных пластин**, глубокая синяя сталь и матовое золото; вертикальный геометрический щит; небольшой клевец. Без нимба, огромного молота, паладинского стиля | Approved |
| archive | `assets/environments/nulmeris_archive.webp` | Коллекция | 16:9, ≥2560×1440 | Приглушённый архив; карты — главный контент (поверх кладётся светлая вуаль) | Approved |
| deck_hall | `assets/environments/citadel_deck_hall.webp` | Редактор колоды | 16:9, ≥2560×1440 | Чистый фон за вкладками | Approved |
| staging_hall | `assets/environments/citadel_staging_hall.webp` | Prebattle | 16:9, ≥2560×1440 | Место под панели и кривую стоимости | Approved |
| convergence | `assets/environments/citadel_convergence.webp` | Поиск соперника | 16:9, ≥2560×1440 | Камера механизма; никакого портрета соперника | Approved |
| convergence_ring_outer / _inner | `assets/environment_details/convergence_ring_outer.png`, `convergence_ring_inner.png` | Поиск соперника | Квадратные PNG с альфой, центр = ось вращения | Каменно-металлические кольца; вращаются кодом; фракционные печати и окно раскрытия остаются живыми | Approved |
| arena | `assets/environments/citadel_arena.webp` | Бой, замена карт, результат | 16:9, 3840×2160 | Центр спокойный и играбельный; атмосфера по краям (водопады, скалы, архитектура); без карт и чисел | Missing |
| library | `assets/environments/library_of_nulmeris.webp` | Библиотека | 16:9, ≥2560×1440 | Монументальный физический архив | Approved |
| book | `assets/environment_details/book_of_nulmeris.png` | Библиотека | PNG с альфой, ~1600×1100 | Открытая книга без текста; текст страниц — живой Godot | Approved |
| hall | `assets/environments/citadel_hall.webp` | Настройки, Прогресс | 16:9, ≥2560×1440 | Общий зал; без фальшивых функций Q-15 | Approved |

## Символы (векторные)

| Путь | Назначение | Статус |
|---|---|---|
| `assets/ui/brand/odraveth_o_mark.svg` | O-знак ODRAVETH (монохром) | Candidate |
| `assets/ui/world/seal_of_nulmeris.svg` | Печать Нулмериса — внутриигровой символ, **не** иконка | Candidate |
| `assets/ui/factions/ashravael.svg` | Сломанное лезвие через угловатую корону пламени | Candidate |
| `assets/ui/factions/nerqathen.svg` | Сегментированный круг с пустым центром | Candidate |
| `assets/ui/factions/dumoryss.svg` | Смещённое разорванное кольцо с трещиной | Candidate |
| `assets/ui/factions/khevaruun.svg` | Сцепленные пластины щита (шов-шеврон, не крест) | Candidate |

Генератор: `tools/art/generate_symbols.py` (та же геометрия, что `NulmerisEmblems` в игре). Иконка приложения — `assets/ui/brand/app_icon*.svg` (O-знак), Candidate.

## 40 уникальных иллюстраций карт

Путь: `assets/cards/<card_id>.webp` (поддерживаются также `.png` / `.svg`), мастер 4:5, crop-safe. **Без цифр, названий, описаний и рамок** — всё это рисует `FullCardView` / `CardPresentation`. Каждая работа оригинальная; не 40 клонов фракционного воина. Разрешение — `CardArtResolver` (только точный ID, без фракционных подстановок). До появления файла карта показывает процедурную композицию, уникальную для ID (статус `placeholder`).

| card_id | Карта | Фракция | Тип | Направление | Статус |
|---|---|---|---|---|---|
| `ashravael_bloodsworn` | Кровный присяжник | Ashravael | CREATURE | воин, присяга, опасная решимость без эмблем-солнц | Approved |
| `ashravael_cinderclaw` | Углекоготь | Ashravael | CREATURE | существо угля и закалённых когтей, контролируемый жар | Approved |
| `ashravael_emberbound` | Скованный жаром | Ashravael | CREATURE | воин, заключённый в обожжённые металлические пластины | Approved |
| `ashravael_gorebrand` | Клеймённый кровью | Ashravael | CREATURE | метка и след боевой цены, не чрезмерная жестокость | Approved |
| `ashravael_warfiend` | Изверг войны | Ashravael | CREATURE | легендарное олицетворение войны, не демонический клон | Approved |
| `ashravael_blood_tithe` | Кровавая десятина | Ashravael | SPELL | ритуальная цена силы, символика кровной клятвы без текста | Approved |
| `ashravael_cinder_oath` | Клятва пепла | Ashravael | SPELL | искры и клятва над пеплом, без обязательной фигуры | Approved |
| `ashravael_furnace_sigil` | Печать горнила | Ashravael | ARTIFACT | самостоятельная металлическая печать горнила | Approved |
| `nerqathen_gravewisp` | Могильный огонёк | Nerqathen | CREATURE | тихий огонёк душ, не череп и не живой факел | Approved |
| `nerqathen_pale_binder` | Бледный пленитель | Nerqathen | CREATURE | ритуальный хранитель душ, вертикальная композиция | Approved |
| `nerqathen_bone_cantor` | Певец костей | Nerqathen | CREATURE | церемониальный фигурант, без брони из черепов | Approved |
| `nerqathen_mourning_husk` | Скорбная оболочка | Nerqathen | CREATURE | скорбная защитная фигура с архаичным панцирем | Approved |
| `nerqathen_soulmonger` | Скупщик душ | Nerqathen | CREATURE | легендарный собиратель душ, не стандартный лич | Approved |
| `nerqathen_soul_harvest` | Жатва душ | Nerqathen | SPELL | души в геометрическом резонаторе, без клише-косы | Approved |
| `nerqathen_second_burial` | Второе погребение | Nerqathen | SPELL | возврат из памяти/погребения через древний ритуал | Approved |
| `nerqathen_ossuary_bell` | Колокол костницы | Nerqathen | ARTIFACT | самостоятельный церемониальный колокол и резонанс | Approved |
| `dumoryss_veilbreaker` | Разрушитель Завесы | Dumoryss | CREATURE | существо на границе разрыва пространственной ткани | Approved |
| `dumoryss_thoughtscar` | Шрам разума | Dumoryss | CREATURE | психическое искажение через тонкие смещённые плоскости | Approved |
| `dumoryss_null_seer` | Провидец Пустоты | Dumoryss | CREATURE | видящий пустоту исследователь, не ведьма-штамп | Approved |
| `dumoryss_rift_scribe` | Писец Разлома | Dumoryss | CREATURE | летописец нестабильного пространства и сломанных линий | Approved |
| `dumoryss_echo_leech` | Пиявка эха | Dumoryss | CREATURE | легендарное существо повторений и отражений | Approved |
| `dumoryss_fractured_moment` | Расколотый миг | Dumoryss | SPELL | остановленный миг и смещённые сегменты архитектуры | Approved |
| `dumoryss_veil_tax` | Дань Завесе | Dumoryss | SPELL | сдвиг платы за действие, без цифр и букв | Approved |
| `dumoryss_nullglass` | Пустостекло | Dumoryss | ARTIFACT | изделие из нестабильного стекла и металла | Approved |
| `khevaruun_aegis_hound` | Гончая Эгиды | Khevaruun | CREATURE | бронированная гончая с состыкованными пластинами | Approved |
| `khevaruun_shieldroot` | Щитокорень | Khevaruun | CREATURE | живой щитокорень, древесно-металлическая защита | Approved |
| `khevaruun_ironwarden` | Железный хранитель | Khevaruun | CREATURE | страж с сочленённой бронёй и щитом | Approved |
| `khevaruun_platecaller` | Призыватель лат | Khevaruun | CREATURE | мастер, собирающий взаимосвязанные бронепластины | Approved |
| `khevaruun_wallforged` | Стенокованный | Khevaruun | CREATURE | легендарный живой бастион со структурными плитами | Approved |
| `khevaruun_temper_rite` | Обряд закалки | Khevaruun | SPELL | укрепление брони, слои соединяются на каменном постаменте | Approved |
| `khevaruun_iron_memory` | Железная память | Khevaruun | SPELL | регенерация броневой геометрии, память металла | Approved |
| `khevaruun_bastion_core` | Сердце бастиона | Khevaruun | ARTIFACT | сердечник древнего бастиона, самостоятельный артефакт | Approved |
| `neutral_mireglass_wanderer` | Странник болотного стекла | Neutral | CREATURE | путник через стеклянное болото и туман | Approved |
| `neutral_vantrel_duskling` | Сумеречник Вантрела | Neutral | CREATURE | редкое сумеречное существо Вантрела | Approved |
| `neutral_threnic_cartographer` | Тренический картограф | Neutral | CREATURE | учёный-картограф в геометрической архитектуре | Approved |
| `neutral_orryxian_wayfarer` | Орриксийский путник | Neutral | CREATURE | одинокий путешественник при далёком горизонте | Approved |
| `neutral_sablequill_nomad` | Кочевник Чёрного Пера | Neutral | CREATURE | кочевник с чёрным пером, узнаваемый силуэт | Approved |
| `neutral_kelvarn_relicbearer` | Реликвеносец Келварна | Neutral | CREATURE | носитель отдельной древней реликвии | Approved |
| `neutral_rivenshade_grazer` | Травояд Ривеншейда | Neutral | CREATURE | оригинальное травоядное существо среды Ривеншейда | Approved |
| `neutral_pale_meridian` | Бледный меридиан | Neutral | SPELL | световая геометрическая ось над горизонтом | Approved |

## Импорт и мобильные ограничения

- Мастера 3840×2160 хранить вне репозитория или в отдельном art-хранилище; в `assets/` класть игровые варианты: окружения 2560×1440 WebP (lossy ~85), портреты ≤1200 px по большей стороне, кольца ≤1024², карты 640×800 WebP.
- После добавления файлов: `godot --headless --path . --import`, коммитить файл вместе с его `.import`. Для окружений в импорте: `mipmaps/generate=false`, `process/size_limit=2560`; для карт `size_limit=1024`.
- Проверить права: только собственные или лицензированные изображения; никаких ассетов из других игр (Hearthstone, Warcraft, Drova и др.).
- После интеграции: `tests/visual_qa` скриншоты на 1600×900, 1920×1080, 2400×1080, 2800×1752 и ручной просмотр (пропорции, кадрирование, альфа, швы, читаемость UI поверх арта).
