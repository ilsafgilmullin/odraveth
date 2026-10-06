class_name HeroCatalog
extends RefCounted
## The four approved heroes and the numbers of their abilities
## (docs/PRODUCT_BASELINE.md section 4). Every ability costs
## GameRules.HERO_ABILITY_COST energy and can be used once per own turn.

const KEZHARYN := &"KEZHARYN"
const VHORAZEL := &"VHORAZEL"
const SYRRAVETH := &"SYRRAVETH"
const TAZHYRION := &"TAZHYRION"

const HEROES := {
	KEZHARYN: {
		"faction": "ASHRAVAEL", "name_ru": "Кежарин", "name_en": "Kezharyn",
		"power_ru": "Кровавый приказ", "needs_friendly_target": true,
		"self_damage": 1, "attack_bonus": 2,
	},
	VHORAZEL: {
		"faction": "NERQATHEN", "name_ru": "Вхоразель", "name_en": "Vhorazel",
		"power_ru": "Извлечение", "needs_friendly_target": false,
		"soul_shards": 1, "soul_shards_after_ally_death": 2,
	},
	SYRRAVETH: {
		"faction": "DUMORYSS", "name_ru": "Сирравет", "name_en": "Syrraveth",
		"power_ru": "Искажение", "needs_friendly_target": false,
		"cost_increase": 1, "max_affected_cost": 3,
	},
	TAZHYRION: {
		"faction": "KHEVARUUN", "name_ru": "Тажирион", "name_en": "Tazhyrion",
		"power_ru": "Закалка", "needs_friendly_target": true,
		"armor": 1,
	},
}


static func has_hero(hero_id: StringName) -> bool:
	return HEROES.has(hero_id)


static func faction_of(hero_id: StringName) -> Faction.Id:
	return Faction.Id[HEROES[hero_id]["faction"]] as Faction.Id


static func needs_friendly_target(hero_id: StringName) -> bool:
	return HEROES[hero_id]["needs_friendly_target"]


static func value(hero_id: StringName, key: String) -> int:
	return HEROES[hero_id][key]
