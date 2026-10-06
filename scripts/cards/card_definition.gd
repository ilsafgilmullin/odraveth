class_name CardDefinition
extends RefCounted
## Typed definition of one approved card, built by CardSchema from JSON.
##
## Treated as read-only once loaded: CardDatabase keeps its own instances and
## hands out copies only.

var id: StringName
var name_en: String
var name_ru: String
@warning_ignore("enum_variable_without_default")
var faction: Faction.Id
@warning_ignore("enum_variable_without_default")
var card_type: CardEnums.Type
@warning_ignore("enum_variable_without_default")
var rarity: CardEnums.Rarity
var cost: int
## Copies allowed in a deck; always matches the rarity (GameRules.max_copies_in_deck).
var deck_limit: int
## Approved Russian rules text; empty for creatures without abilities.
var rules_text_ru: String
## Creature stats; 0 for other card types.
var attack: int
var health: int
var armor: int
## Artifact charges; 0 when the card has none.
var charges: int
var effects: Array[CardEffectSpec] = []


## Deep copy: changing it never affects the original.
func copy() -> CardDefinition:
	var result := CardDefinition.new()
	result.id = id
	result.name_en = name_en
	result.name_ru = name_ru
	result.faction = faction
	result.card_type = card_type
	result.rarity = rarity
	result.cost = cost
	result.deck_limit = deck_limit
	result.rules_text_ru = rules_text_ru
	result.attack = attack
	result.health = health
	result.armor = armor
	result.charges = charges
	for effect in effects:
		result.effects.append(effect.copy())
	return result
