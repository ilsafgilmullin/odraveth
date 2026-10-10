class_name CardPresentation
extends RefCounted
## Thin UI adapter over authoritative CardDefinition. No gameplay rules live here.

const KEYWORD_RU := {
	"ONSLAUGHT": "Натиск",
	"PROVOKE": "Провокация",
	"DEFERRAL": "Отложение",
	"FRENZY": "Неистовство",
}
const TRIGGER_LABELS := {
	"ENTER_BATTLE": "Вход в бой",
	"LAST_BREATH": "Предсмертие",
}

var id: StringName
var name_ru := ""
var name_en := ""
var faction: Faction.Id
var card_type: CardEnums.Type
var rarity: CardEnums.Rarity
var cost := 0
var current_cost := 0
var attack := 0
var health := 0
var armor := 0
var charges := 0
var rules_text_ru := ""
var keywords := PackedStringArray()

var faction_label := ""
var type_label := ""
var rarity_label := ""
var faction_accent := VisualTokens.COLOR_STEEL_500
var type_key := ""
var rarity_key := ""
var frame_variant := "standard"


static func from_definition(card: CardDefinition, override_cost: int = -1) -> CardPresentation:
	if card == null:
		return null
	var result := CardPresentation.new()
	result.id = card.id
	result.name_ru = card.name_ru
	result.name_en = card.name_en
	result.faction = card.faction
	result.card_type = card.card_type
	result.rarity = card.rarity
	result.cost = card.cost
	result.current_cost = override_cost if override_cost >= 0 else card.cost
	result.attack = card.attack
	result.health = card.health
	result.armor = card.armor
	result.charges = card.charges
	result.rules_text_ru = card.rules_text_ru
	result.faction_label = CardFactionPresentation.label(card.faction)
	result.type_label = SetupUi.TYPE_NAMES.get(card.card_type, "")
	result.rarity_label = SetupUi.RARITY_NAMES.get(card.rarity, "")
	result.faction_accent = CardFactionPresentation.accent(card.faction)
	result.type_key = str(CardEnums.Type.find_key(card.card_type))
	result.rarity_key = str(CardEnums.Rarity.find_key(card.rarity))
	result.frame_variant = "curse" if card.card_type == CardEnums.Type.CURSE else "standard"
	result.keywords = _collect_keywords(card)
	return result


static func _collect_keywords(card: CardDefinition) -> PackedStringArray:
	var labels := PackedStringArray()
	for effect: CardEffectSpec in card.effects:
		var trigger := String(effect.trigger)
		if TRIGGER_LABELS.has(trigger) and TRIGGER_LABELS[trigger] not in labels:
			labels.append(TRIGGER_LABELS[trigger])
		var keyword := String(effect.keyword)
		if not keyword.is_empty():
			var label_value: String = KEYWORD_RU.get(keyword, keyword)
			if label_value not in labels:
				labels.append(label_value)
	return labels


func is_creature() -> bool:
	return card_type == CardEnums.Type.CREATURE


func is_spell() -> bool:
	return card_type == CardEnums.Type.SPELL


func is_artifact() -> bool:
	return card_type == CardEnums.Type.ARTIFACT


func is_curse() -> bool:
	return card_type == CardEnums.Type.CURSE


func shows_armor() -> bool:
	return is_creature() and armor > 0


func shows_charges() -> bool:
	return is_artifact() and charges > 0
