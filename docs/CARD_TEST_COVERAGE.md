# ODRAVETH — покрытие карт поведенческими тестами

Каждая из 40 утверждённых карт проверяется поведенческими тестами MatchEngine в `tests/engine/card_behavior_tests.gd`. Тест сам проверяет, что покрыты все 40 карт и что эта таблица перечисляет каждую пару «карта → тест».

Ключевые слова, длительности, статические эффекты и тайминг дополнительно проверяются в `tests/engine/keyword_tests.gd`, способности героев — в `tests/engine/hero_power_tests.gd`.

| № | id | Карта | Тесты |
|---|---|---|---|
| 01 | `ashravael_bloodsworn` | Кровный присяжник | `test_bloodsworn` |
| 02 | `ashravael_cinderclaw` | Углекоготь | `test_cinderclaw` |
| 03 | `ashravael_emberbound` | Скованный жаром | `test_emberbound` |
| 04 | `ashravael_gorebrand` | Клеймённый кровью | `test_gorebrand` |
| 05 | `ashravael_warfiend` | Изверг войны | `test_warfiend` |
| 06 | `ashravael_blood_tithe` | Кровавая десятина | `test_blood_tithe` |
| 07 | `ashravael_cinder_oath` | Клятва пепла | `test_cinder_oath` |
| 08 | `ashravael_furnace_sigil` | Печать горнила | `test_furnace_sigil` |
| 09 | `nerqathen_gravewisp` | Могильный огонёк | `test_gravewisp` |
| 10 | `nerqathen_pale_binder` | Бледный пленитель | `test_pale_binder` |
| 11 | `nerqathen_bone_cantor` | Певец костей | `test_bone_cantor` |
| 12 | `nerqathen_mourning_husk` | Скорбная оболочка | `test_mourning_husk` |
| 13 | `nerqathen_soulmonger` | Скупщик душ | `test_soulmonger` |
| 14 | `nerqathen_soul_harvest` | Жатва душ | `test_soul_harvest` |
| 15 | `nerqathen_second_burial` | Второе погребение | `test_second_burial` |
| 16 | `nerqathen_ossuary_bell` | Колокол костницы | `test_ossuary_bell` |
| 17 | `dumoryss_veilbreaker` | Разрушитель Завесы | `test_veilbreaker` |
| 18 | `dumoryss_thoughtscar` | Шрам разума | `test_thoughtscar` |
| 19 | `dumoryss_null_seer` | Провидец Пустоты | `test_null_seer` |
| 20 | `dumoryss_rift_scribe` | Писец Разлома | `test_rift_scribe` |
| 21 | `dumoryss_echo_leech` | Пиявка эха | `test_echo_leech` |
| 22 | `dumoryss_fractured_moment` | Расколотый миг | `test_fractured_moment` |
| 23 | `dumoryss_veil_tax` | Дань Завесе | `test_veil_tax` |
| 24 | `dumoryss_nullglass` | Пустостекло | `test_nullglass` |
| 25 | `khevaruun_aegis_hound` | Гончая Эгиды | `test_aegis_hound` |
| 26 | `khevaruun_shieldroot` | Щитокорень | `test_shieldroot` |
| 27 | `khevaruun_ironwarden` | Железный хранитель | `test_ironwarden` |
| 28 | `khevaruun_platecaller` | Призыватель лат | `test_platecaller` |
| 29 | `khevaruun_wallforged` | Стенокованный | `test_wallforged` |
| 30 | `khevaruun_temper_rite` | Обряд закалки | `test_temper_rite` |
| 31 | `khevaruun_iron_memory` | Железная память | `test_iron_memory` |
| 32 | `khevaruun_bastion_core` | Сердце бастиона | `test_bastion_core` |
| 33 | `neutral_mireglass_wanderer` | Странник болотного стекла | `test_mireglass_wanderer` |
| 34 | `neutral_vantrel_duskling` | Сумеречник Вантрела | `test_vantrel_duskling` |
| 35 | `neutral_threnic_cartographer` | Тренический картограф | `test_threnic_cartographer` |
| 36 | `neutral_orryxian_wayfarer` | Орриксийский путник | `test_orryxian_wayfarer` |
| 37 | `neutral_sablequill_nomad` | Кочевник Чёрного Пера | `test_sablequill_nomad` |
| 38 | `neutral_kelvarn_relicbearer` | Реликвеносец Келварна | `test_kelvarn_relicbearer` |
| 39 | `neutral_rivenshade_grazer` | Травояд Ривеншейда | `test_rivenshade_grazer` |
| 40 | `neutral_pale_meridian` | Бледный меридиан | `test_pale_meridian` |
