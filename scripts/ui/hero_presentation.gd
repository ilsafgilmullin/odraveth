class_name HeroPresentation
extends RefCounted
## Stage 7C presentation metadata. Numeric mechanics come from HeroCatalog/GameRules.

const PLAYSTYLES := {
	HeroCatalog.KEZHARYN: "АГРЕССИЯ · САМОПОВРЕЖДЕНИЕ · ДАВЛЕНИЕ",
	HeroCatalog.VHORAZEL: "ДУШИ · СМЕРТЬ · НАКОПЛЕНИЕ РЕСУРСА",
	HeroCatalog.SYRRAVETH: "КОНТРОЛЬ · ЗАДЕРЖКА · ИСКАЖЕНИЕ СТОИМОСТИ",
	HeroCatalog.TAZHYRION: "БРОНЯ · ЗАЩИТА · УСТОЙЧИВОСТЬ",
}

const PRESENTATION_GENDER := {
	HeroCatalog.KEZHARYN: "male",
	HeroCatalog.VHORAZEL: "male",
	HeroCatalog.SYRRAVETH: "female",
	HeroCatalog.TAZHYRION: "male",
}

const FACTION_ACCENTS := {
	Faction.Id.ASHRAVAEL: Color("985146"),
	Faction.Id.NERQATHEN: Color("5caaa9"),
	Faction.Id.DUMORYSS: Color("766887"),
	Faction.Id.KHEVARUUN: Color("536c83"),
}


static func power_cost(_hero_id: StringName) -> int:
	return GameRules.HERO_ABILITY_COST


static func power_description(hero_id: StringName) -> String:
	match hero_id:
		HeroCatalog.KEZHARYN:
			return "Герой получает %d урон. Выбранное союзное существо получает +%d к атаке до конца хода." % [
				HeroCatalog.value(hero_id, "self_damage"),
				HeroCatalog.value(hero_id, "attack_bonus"),
			]
		HeroCatalog.VHORAZEL:
			return "Получите +%d Осколок души; если союзное существо погибло в этом ходу — +%d вместо этого." % [
				HeroCatalog.value(hero_id, "soul_shards"),
				HeroCatalog.value(hero_id, "soul_shards_after_ally_death"),
			]
		HeroCatalog.SYRRAVETH:
			return "Способность добавляет заряд Искажения. Следующая подходящая карта противника стоимостью не более %d получает +%d к стоимости согласно правилам Искажения." % [
				HeroCatalog.value(hero_id, "max_affected_cost"),
				HeroCatalog.value(hero_id, "cost_increase"),
			]
		HeroCatalog.TAZHYRION:
			return "Выбранное союзное существо получает +%d к броне." % HeroCatalog.value(hero_id, "armor")
		_:
			return ""


static func playstyle(hero_id: StringName) -> String:
	return PLAYSTYLES.get(hero_id, "")


static func presentation_gender(hero_id: StringName) -> String:
	return PRESENTATION_GENDER.get(hero_id, "")


static func faction_accent(hero_id: StringName) -> Color:
	if not HeroCatalog.has_hero(hero_id):
		return VisualTokens.COLOR_STEEL_500
	return FACTION_ACCENTS.get(HeroCatalog.faction_of(hero_id), VisualTokens.COLOR_STEEL_500)
