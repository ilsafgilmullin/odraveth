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


static func card_caption(card: CardDefinition) -> String:
	var stats := ""
	if card.card_type == CardEnums.Type.CREATURE:
		stats = "  %d/%d" % [card.attack, card.health]
		if card.armor > 0:
			stats += "  Б:%d" % card.armor
	elif card.card_type == CardEnums.Type.ARTIFACT:
		stats = "  Заряды:%d" % card.charges
	return "[%d] %s\n%s · %s · %s%s" % [card.cost, card.name_ru, faction_name(card.faction),
		RARITY_NAMES[card.rarity], TYPE_NAMES[card.card_type], stats]


static func card_tile(card: CardDefinition) -> Button:
	var button := Button.new()
	button.name = "Card_%s" % card.id
	button.text = card_caption(card)
	button.custom_minimum_size = Vector2(210, 142)
	button.clip_text = true
	button.add_theme_color_override("font_color", ACCENTS.get(card.faction, Color.WHITE))
	return button
