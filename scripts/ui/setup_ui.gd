class_name SetupUi
extends RefCounted
## Presentation labels only; identities and numeric rules come from catalogs.

const FACTION_NAMES := {
	Faction.Id.ASHRAVAEL: "Ашравайль", Faction.Id.NERQATHEN: "Неркатен",
	Faction.Id.DUMORYSS: "Думорисс", Faction.Id.KHEVARUUN: "Кеваруун",
	Faction.Id.NEUTRAL: "Нейтральные",
}
const ACCENTS := {
	Faction.Id.ASHRAVAEL: Color("b15c51"), Faction.Id.NERQATHEN: Color("5ca9a8"),
	Faction.Id.DUMORYSS: Color("8977bb"), Faction.Id.KHEVARUUN: Color("c5a85d"),
	Faction.Id.NEUTRAL: Color("9299a3"),
}
const TYPE_NAMES := {
	CardEnums.Type.CREATURE: "Существо", CardEnums.Type.SPELL: "Заклинание",
	CardEnums.Type.ARTIFACT: "Артефакт", CardEnums.Type.CURSE: "Проклятие",
}
const RARITY_NAMES := {
	CardEnums.Rarity.COMMON: "Обычная", CardEnums.Rarity.RARE: "Редкая",
	CardEnums.Rarity.EPIC: "Эпическая", CardEnums.Rarity.LEGENDARY: "Легендарная",
}


static func faction_name(id: Faction.Id) -> String:
	return FACTION_NAMES.get(id, "")
