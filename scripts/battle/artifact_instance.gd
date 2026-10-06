class_name ArtifactInstance
extends RefCounted
## Runtime state of the active artifact of a hero.

var instance_id: int
var owner: int
var card: CardInstance
var charges: int
## Effect id -> resolutions in the current turn (limits.per_turn).
var trigger_counts: Dictionary = {}


static func create(from_card: CardInstance) -> ArtifactInstance:
	var artifact := ArtifactInstance.new()
	artifact.instance_id = from_card.instance_id
	artifact.owner = from_card.owner
	artifact.card = from_card
	artifact.charges = from_card.definition.charges
	return artifact


func definition() -> CardDefinition:
	return card.definition


func clone() -> ArtifactInstance:
	var copy := ArtifactInstance.new()
	copy.instance_id = instance_id
	copy.owner = owner
	copy.card = card.clone()
	copy.charges = charges
	copy.trigger_counts = trigger_counts.duplicate(true)
	return copy


func snapshot() -> Dictionary:
	return {"id": instance_id, "card": String(card.card_id()), "charges": charges,
		"trigger_counts": trigger_counts.duplicate(true)}
