class_name CreatureInstance
extends RefCounted
## Runtime state of one creature on the board. Created when a creature enters
## the board and discarded when it leaves; a returned creature is a new instance.
##
## Attack = definition attack + permanent bonus + active temporary bonuses +
## static bonus. "+N health" raises max and current health; "+N armor" raises
## max and current armor; restoring armor never exceeds max armor.

var instance_id: int
var owner: int
## The card this creature came from (goes to the graveyard on death).
var card: CardInstance
var entered_turn: int
var attack_bonus: int = 0
## Temporary attack bonuses: {"amount": int, "expires_turn": int}.
var temporary_attack: Array[Dictionary] = []
var static_attack_bonus: int = 0
var max_health: int
var health: int
var max_armor: int
var armor: int
var static_armor_bonus: int = 0
## Temporary keywords: {"keyword": String, "expires_turn": int}.
var temporary_keywords: Array[Dictionary] = []
var static_keywords: Array[String] = []
var attacks_this_turn: int = 0
var max_attacks_this_turn: int = 1
## DEFERRAL waiting for the owner's next turn.
var deferral_pending := false
## Turn number in which DEFERRAL forbids attacking; -1 when none.
var attack_blocked_turn: int = -1
## Armor gained per source card id (Temper Rite cap).
var armor_gained_from: Dictionary = {}
## Effect id -> resolutions in the current turn (limits.per_turn).
var trigger_counts: Dictionary = {}
var destroyed := false


static func create(id: int, from_card: CardInstance, turn: int) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.instance_id = id
	creature.owner = from_card.owner
	creature.card = from_card
	creature.entered_turn = turn
	creature.max_health = from_card.definition.health
	creature.health = from_card.definition.health
	creature.max_armor = from_card.definition.armor
	creature.armor = from_card.definition.armor
	return creature


func definition() -> CardDefinition:
	return card.definition


func get_attack() -> int:
	var total := card.definition.attack + attack_bonus + static_attack_bonus
	for bonus in temporary_attack:
		total += int(bonus["amount"])
	return maxi(total, 0)


func is_dead() -> bool:
	return health <= 0 or destroyed


## Keywords the creature has now: intrinsic (keyword-only STATIC abilities such
## as «Провокация»), temporary and static.
func get_keywords() -> Array[String]:
	var keywords: Array[String] = []
	for effect in card.definition.effects:
		if effect.trigger == &"STATIC" and effect.actions.is_empty() and effect.keyword != &"":
			keywords.append(String(effect.keyword))
	for granted in temporary_keywords:
		keywords.append(String(granted["keyword"]))
	keywords.append_array(static_keywords)
	var unique: Array[String] = []
	for keyword in keywords:
		if keyword not in unique:
			unique.append(keyword)
	unique.sort()
	return unique


func has_keyword(keyword: String) -> bool:
	return keyword in get_keywords()


func clone() -> CreatureInstance:
	var copy := CreatureInstance.new()
	copy.instance_id = instance_id
	copy.owner = owner
	copy.card = card.clone()
	copy.entered_turn = entered_turn
	copy.attack_bonus = attack_bonus
	copy.temporary_attack = temporary_attack.duplicate(true)
	copy.static_attack_bonus = static_attack_bonus
	copy.max_health = max_health
	copy.health = health
	copy.max_armor = max_armor
	copy.armor = armor
	copy.static_armor_bonus = static_armor_bonus
	copy.temporary_keywords = temporary_keywords.duplicate(true)
	copy.static_keywords = static_keywords.duplicate()
	copy.attacks_this_turn = attacks_this_turn
	copy.max_attacks_this_turn = max_attacks_this_turn
	copy.deferral_pending = deferral_pending
	copy.attack_blocked_turn = attack_blocked_turn
	copy.armor_gained_from = armor_gained_from.duplicate(true)
	copy.trigger_counts = trigger_counts.duplicate(true)
	copy.destroyed = destroyed
	return copy


func snapshot() -> Dictionary:
	return {
		"id": instance_id, "card": String(card.card_id()), "card_instance": card.instance_id,
		"attack": get_attack(), "attack_bonus": attack_bonus, "temporary_attack": temporary_attack.duplicate(true),
		"static_attack_bonus": static_attack_bonus, "health": health, "max_health": max_health,
		"armor": armor, "max_armor": max_armor, "static_armor_bonus": static_armor_bonus,
		"keywords": get_keywords(), "temporary_keywords": temporary_keywords.duplicate(true),
		"entered_turn": entered_turn, "attacks_this_turn": attacks_this_turn,
		"max_attacks_this_turn": max_attacks_this_turn, "deferral_pending": deferral_pending,
		"attack_blocked_turn": attack_blocked_turn, "armor_gained_from": armor_gained_from.duplicate(true),
		"trigger_counts": trigger_counts.duplicate(true),
	}
