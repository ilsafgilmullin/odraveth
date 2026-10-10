class_name CardFactionPresentation
extends RefCounted
## Presentation-only faction labels and restrained accents for the shared card system.

const ACCENTS := {
	Faction.Id.ASHRAVAEL: Color("8f493e"),
	Faction.Id.NERQATHEN: Color("58a4a5"),
	Faction.Id.DUMORYSS: Color("75677f"),
	Faction.Id.KHEVARUUN: Color("526d84"),
	Faction.Id.NEUTRAL: Color("858d90"),
}


static func label(faction: Faction.Id) -> String:
	return SetupUi.faction_name(faction)


static func accent(faction: Faction.Id) -> Color:
	return ACCENTS.get(faction, VisualTokens.COLOR_STEEL_500)
