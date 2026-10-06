extends RefCounted
## Approved values of the 40 Stage 1 cards, transcribed from the user's Stage 1
## specification independently of data/cards/*.json. The tests compare the
## loaded database against this table field by field.
##
## Row: [id, name_en, name_ru, faction, type, rarity, cost, attack, health, armor,
##       charges, deck_limit, rules_text_ru]
## Stats of non-creatures and charges of cards without charges are 0.

const CARDS := [
	# --- ASHRAVAEL ---
	["ashravael_bloodsworn", "Ashravael Bloodsworn", "Кровный присяжник", "ASHRAVAEL", "CREATURE", "COMMON", 1, 2, 1, 0, 0, 2,
		"Вход в бой: если ваш герой уже получил урон в этом ходу, получает +1 к атаке."],
	["ashravael_cinderclaw", "Ashravael Cinderclaw", "Углекоготь", "ASHRAVAEL", "CREATURE", "COMMON", 2, 3, 2, 0, 0, 2,
		"Неистовство: первый раз за ход после получения урона получает +1 к атаке."],
	["ashravael_emberbound", "Ashravael Emberbound", "Скованный жаром", "ASHRAVAEL", "CREATURE", "RARE", 3, 3, 4, 0, 0, 2,
		"После того как ваш герой получает урон в ваш ход, получает +1 к атаке до конца хода. Максимум 2 раза за ход."],
	["ashravael_gorebrand", "Ashravael Gorebrand", "Клеймённый кровью", "ASHRAVAEL", "CREATURE", "EPIC", 4, 4, 4, 0, 0, 2,
		"Вход в бой: ваш герой получает 1 урон. Нанесите 2 урона выбранному вражескому существу."],
	["ashravael_warfiend", "Ashravael Warfiend", "Изверг войны", "ASHRAVAEL", "CREATURE", "LEGENDARY", 7, 7, 6, 0, 0, 1,
		"Если у вашего героя 15 здоровья или меньше, получает Натиск. После первой атаки, если ваш герой получал урон в этом ходу, может атаковать ещё раз. Максимум 2 атаки за ход."],
	["ashravael_blood_tithe", "Ashravael Blood Tithe", "Кровавая десятина", "ASHRAVAEL", "SPELL", "RARE", 2, 0, 0, 0, 0, 2,
		"Ваш герой получает 2 урона. Возьмите 2 карты."],
	["ashravael_cinder_oath", "Ashravael Cinder Oath", "Клятва пепла", "ASHRAVAEL", "SPELL", "COMMON", 3, 0, 0, 0, 0, 2,
		"Выбранное союзное существо получает +3 к атаке и Натиск до конца хода. В конце хода оно получает 1 урон."],
	["ashravael_furnace_sigil", "Ashravael Furnace Sigil", "Печать горнила", "ASHRAVAEL", "ARTIFACT", "EPIC", 4, 0, 0, 0, 3, 2,
		"Первый раз за ход, когда ваш герой получает урон: расходуется 1 заряд; случайное союзное существо получает +1 к атаке и +1 к здоровью."],
	# --- NERQATHEN ---
	["nerqathen_gravewisp", "Nerqathen Gravewisp", "Могильный огонёк", "NERQATHEN", "CREATURE", "COMMON", 1, 1, 2, 0, 0, 2,
		"Предсмертие: получите 1 Осколок души."],
	["nerqathen_pale_binder", "Nerqathen Pale Binder", "Бледный пленитель", "NERQATHEN", "CREATURE", "COMMON", 2, 2, 3, 0, 0, 2,
		"Вход в бой: если у вас есть хотя бы 1 Осколок души, получает +1 брони. Осколок не расходуется."],
	["nerqathen_bone_cantor", "Nerqathen Bone Cantor", "Певец костей", "NERQATHEN", "CREATURE", "RARE", 3, 2, 4, 0, 0, 2,
		"Первый раз за ход после гибели союзного существа получает постоянный +1 к атаке."],
	["nerqathen_mourning_husk", "Nerqathen Mourning Husk", "Скорбная оболочка", "NERQATHEN", "CREATURE", "RARE", 4, 3, 5, 1, 0, 2,
		"Провокация. Предсмертие: получите 1 Осколок души."],
	["nerqathen_soulmonger", "Nerqathen Soulmonger", "Скупщик душ", "NERQATHEN", "CREATURE", "LEGENDARY", 7, 5, 7, 0, 0, 1,
		"Вход в бой: можно потратить до 3 Осколков души. За каждый потраченный Осколок получает +1 к атаке и +1 к здоровью. Если потрачено ровно 3, получает +1 брони."],
	["nerqathen_soul_harvest", "Nerqathen Soul Harvest", "Жатва душ", "NERQATHEN", "SPELL", "COMMON", 2, 0, 0, 0, 0, 2,
		"Уничтожьте выбранное союзное существо. Получите 2 Осколка души и возьмите 1 карту."],
	["nerqathen_second_burial", "Nerqathen Second Burial", "Второе погребение", "NERQATHEN", "SPELL", "EPIC", 4, 0, 0, 0, 0, 2,
		"Верните на поле последнее погибшее союзное существо. Оно возвращается с 1 здоровьем. Его эффект “Вход в бой” повторно не срабатывает."],
	["nerqathen_ossuary_bell", "Nerqathen Ossuary Bell", "Колокол костницы", "NERQATHEN", "ARTIFACT", "EPIC", 3, 0, 0, 0, 4, 2,
		"Первый раз за ход, когда погибает ваше существо, расходуется 1 заряд и вы получаете 1 Осколок души."],
	# --- DUMORYSS ---
	["dumoryss_veilbreaker", "Veilbreaker", "Разрушитель Завесы", "DUMORYSS", "CREATURE", "COMMON", 1, 1, 3, 0, 0, 2,
		"Когда противник разыгрывает карту, стоимость которой была увеличена вами, получает +1 к атаке до конца вашего следующего хода."],
	["dumoryss_thoughtscar", "Thoughtscar", "Шрам разума", "DUMORYSS", "CREATURE", "COMMON", 2, 2, 2, 0, 0, 2,
		"Вход в бой: следующая карта противника стоимостью 3 или меньше стоит на 1 больше."],
	["dumoryss_null_seer", "Null Seer", "Провидец Пустоты", "DUMORYSS", "CREATURE", "RARE", 3, 2, 4, 0, 0, 2,
		"Каждый раз, когда противник платит увеличенную вами стоимость карты, получает постоянный +1 к атаке. Максимум 1 раз за ход."],
	["dumoryss_rift_scribe", "Rift Scribe", "Писец Разлома", "DUMORYSS", "CREATURE", "RARE", 4, 3, 5, 0, 0, 2,
		"Вход в бой: выбранное вражеское существо получает Отложение. Оно не может атаковать во время следующего хода своего владельца."],
	["dumoryss_echo_leech", "Echo Leech", "Пиявка эха", "DUMORYSS", "CREATURE", "LEGENDARY", 6, 4, 6, 1, 0, 1,
		"После того как противник разыгрывает заклинание, первая такая карта за ход создаёт в вашей руке Эхо — копию этого заклинания. Стоимость Эхо не может быть меньше 1. Эхо исчезает из руки в конце вашего следующего хода."],
	["dumoryss_fractured_moment", "Fractured Moment", "Расколотый миг", "DUMORYSS", "SPELL", "COMMON", 2, 0, 0, 0, 0, 2,
		"Наложите Отложение на выбранное вражеское существо. Оно не может атаковать во время следующего хода своего владельца."],
	["dumoryss_veil_tax", "Veil Tax", "Дань Завесе", "DUMORYSS", "SPELL", "RARE", 3, 0, 0, 0, 0, 2,
		"Следующая карта противника стоит на 2 больше. Максимальная стоимость карты — 10."],
	["dumoryss_nullglass", "Nullglass", "Пустостекло", "DUMORYSS", "ARTIFACT", "EPIC", 4, 0, 0, 0, 3, 2,
		"Первую карту противника стоимостью 4 или больше за ход: её стоимость увеличивается на 1, затем расходуется 1 заряд."],
	# --- KHEVARUUN ---
	["khevaruun_aegis_hound", "Aegis Hound", "Гончая Эгиды", "KHEVARUUN", "CREATURE", "COMMON", 1, 1, 2, 1, 0, 2,
		""],
	["khevaruun_shieldroot", "Shieldroot", "Щитокорень", "KHEVARUUN", "CREATURE", "COMMON", 2, 2, 3, 1, 0, 2,
		"Когда его броня полностью уничтожена, получает +1 к атаке до конца хода."],
	["khevaruun_ironwarden", "Ironwarden", "Железный хранитель", "KHEVARUUN", "CREATURE", "RARE", 3, 2, 4, 2, 0, 2,
		"Провокация."],
	["khevaruun_platecaller", "Platecaller", "Призыватель лат", "KHEVARUUN", "CREATURE", "RARE", 4, 4, 4, 1, 0, 2,
		"Вход в бой: другое выбранное союзное существо получает +1 брони."],
	["khevaruun_wallforged", "Wallforged", "Стенокованный", "KHEVARUUN", "CREATURE", "LEGENDARY", 7, 5, 7, 3, 0, 1,
		"Провокация. Когда теряет последнюю единицу брони, восстанавливает 1 броню. Максимум 1 раз за ход."],
	["khevaruun_temper_rite", "Temper Rite", "Обряд закалки", "KHEVARUUN", "SPELL", "COMMON", 2, 0, 0, 0, 0, 2,
		"Выбранное союзное существо получает +2 брони. Максимум брони, получаемой от этой карты, — 4."],
	["khevaruun_iron_memory", "Iron Memory", "Железная память", "KHEVARUUN", "SPELL", "RARE", 3, 0, 0, 0, 0, 2,
		"Восстановите выбранному союзному существу всю потерянную броню. Если его броня уже полная, вместо этого оно получает +2 здоровья."],
	["khevaruun_bastion_core", "Bastion Core", "Сердце бастиона", "KHEVARUUN", "ARTIFACT", "EPIC", 4, 0, 0, 0, 3, 2,
		"Первое существо, которое вы разыгрываете в свой ход, получает +1 брони и расходует 1 заряд."],
	# --- NEUTRAL ---
	["neutral_mireglass_wanderer", "Mireglass Wanderer", "Странник болотного стекла", "NEUTRAL", "CREATURE", "COMMON", 1, 1, 2, 0, 0, 2,
		"Вход в бой: если у вас нет других существ, получает +1 здоровья."],
	["neutral_vantrel_duskling", "Vantrel Duskling", "Сумеречник Вантрела", "NEUTRAL", "CREATURE", "COMMON", 2, 2, 3, 0, 0, 2,
		""],
	["neutral_threnic_cartographer", "Threnic Cartographer", "Тренический картограф", "NEUTRAL", "CREATURE", "RARE", 3, 2, 3, 0, 0, 2,
		"Вход в бой: посмотрите 2 верхние карты вашей колоды. Выберите, какая останется сверху; вторую поместите под низ колоды."],
	["neutral_orryxian_wayfarer", "Orryxian Wayfarer", "Орриксийский путник", "NEUTRAL", "CREATURE", "COMMON", 3, 3, 3, 0, 0, 2,
		"Пока на вашей стороне поля нет других существ, получает +1 брони."],
	["neutral_sablequill_nomad", "Sablequill Nomad", "Кочевник Чёрного Пера", "NEUTRAL", "CREATURE", "RARE", 4, 4, 4, 0, 0, 2,
		"После того как переживает атаку другого существа, получает +1 здоровья. Максимум 1 раз за ход."],
	["neutral_kelvarn_relicbearer", "Kelvarn Relicbearer", "Реликвеносец Келварна", "NEUTRAL", "CREATURE", "RARE", 4, 3, 5, 1, 0, 2,
		"Если у вас установлен активный артефакт, получает +1 к атаке."],
	["neutral_rivenshade_grazer", "Rivenshade Grazer", "Травояд Ривеншейда", "NEUTRAL", "CREATURE", "COMMON", 5, 5, 6, 0, 0, 2,
		""],
	["neutral_pale_meridian", "Pale Meridian", "Бледный меридиан", "NEUTRAL", "SPELL", "EPIC", 3, 0, 0, 0, 0, 2,
		"Возьмите 1 карту. Если в вашей колоде осталось 15 карт или меньше, возьмите ещё 1 карту."],
]

## Names that must never be cards: Soul Shard and Impulse Shard are resources,
## hero abilities and heroes are not collection cards.
const FORBIDDEN_CARD_NAMES_RU: Array[String] = [
	"Осколок души", "Осколок импульса",
	"Кровавый приказ", "Извлечение", "Искажение", "Закалка",
	"Кежарин", "Вхоразель", "Сирравет", "Тажирион",
]
const FORBIDDEN_CARD_NAMES_EN: Array[String] = [
	"Soul Shard", "Kezharyn", "Vhorazel", "Syrraveth", "Tazhyrion",
]
