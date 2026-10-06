class_name CardInstance
extends RefCounted
## One card of a match: in a deck, hand, graveyard or the burned zone.
## The definition is shared and never changed; everything mutable lives here.

var instance_id: int
var owner: int
var definition: CardDefinition
## Cost before match modifiers (an Echo: base spell cost, at least its minimum).
var base_cost: int
var is_echo := false
## Echo only: number of the turn at whose end it leaves the hand.
var echo_expires_turn := -1


static func create(id: int, owner_index: int, card_definition: CardDefinition) -> CardInstance:
	var card := CardInstance.new()
	card.instance_id = id
	card.owner = owner_index
	card.definition = card_definition
	card.base_cost = card_definition.cost
	return card


func card_id() -> StringName:
	return definition.id


func clone() -> CardInstance:
	var copy := CardInstance.new()
	copy.instance_id = instance_id
	copy.owner = owner
	copy.definition = definition
	copy.base_cost = base_cost
	copy.is_echo = is_echo
	copy.echo_expires_turn = echo_expires_turn
	return copy


func snapshot() -> Dictionary:
	var data := {"id": instance_id, "card": String(card_id()), "base_cost": base_cost}
	if is_echo:
		data["echo_expires_turn"] = echo_expires_turn
	return data
