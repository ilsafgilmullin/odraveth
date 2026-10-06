class_name EffectContext
extends RefCounted
## Everything one effect resolution needs. References instances by id only.

const SOURCE_CREATURE := &"CREATURE"
const SOURCE_ARTIFACT := &"ARTIFACT"
## A creature that already left the board (LAST_BREATH).
const SOURCE_DEAD_CREATURE := &"DEAD_CREATURE"
const SOURCE_SPELL := &"SPELL"

var owner: int
var source_kind: StringName
var source_id: int
var card_id: StringName
var effect: CardEffectSpec
## Chosen target from the command (0 = none).
var target_id: int = 0
var choices: Dictionary = {}
## Data of the triggering event: played card, creature ids, cost...
var event: Dictionary = {}
## Set by SPEND_SOUL_SHARDS for later actions of the same effect.
var soul_shards_spent: int = 0


static func create(owner_index: int, kind: StringName, id: int, card: StringName, spec: CardEffectSpec) -> EffectContext:
	var context := EffectContext.new()
	context.owner = owner_index
	context.source_kind = kind
	context.source_id = id
	context.card_id = card
	context.effect = spec
	return context


static func from_entry(entry: Dictionary, spec: CardEffectSpec) -> EffectContext:
	var context := create(entry["owner"], entry["source_kind"], entry["source_id"], entry["card_id"], spec)
	context.event = entry["event"].duplicate(true)
	return context
