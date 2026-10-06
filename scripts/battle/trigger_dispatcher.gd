class_name TriggerDispatcher
extends RefCounted
## Finds the abilities that react to a match event and builds queue entries in a
## deterministic order: the board left to right, then the active artifact.
## Listeners are read from the current state every time - nothing is registered,
## so an ability can neither be subscribed twice nor fire after its source left.
##
## Entry: {"timing", "source_kind", "source_id", "owner", "card_id", "effect_index", "event"}.

const SELF_TRIGGERS: Array[String] = [
	"SELF_DAMAGED", "SELF_ARMOR_DEPLETED", "AFTER_SELF_ATTACK", "SELF_SURVIVED_CREATURE_ATTACK",
]
const OWN_PLAYER_TRIGGERS: Array[String] = ["OWN_HERO_DAMAGED", "ALLY_CREATURE_DIED", "ALLY_CREATURE_PLAYED"]
const OPPONENT_TRIGGERS: Array[String] = ["OPPONENT_PLAYS_CARD", "OPPONENT_PAYS_INCREASED_COST"]
const DEFAULT_TIMING := "WHEN"


## Entries for [param trigger]. [param event] has "creature_id" for SELF_*
## triggers and "player" (the player the event happened to) otherwise.
static func collect(state: MatchState, trigger: StringName, event: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var name := String(trigger)
	if name in SELF_TRIGGERS:
		var creature := state.find_creature(event["creature_id"])
		if creature != null:
			_add_effects(entries, EffectContext.SOURCE_CREATURE, creature.instance_id, creature.owner,
				creature.definition(), name, event)
		return entries
	var listener: int
	if name in OWN_PLAYER_TRIGGERS:
		listener = event["player"]
	elif name in OPPONENT_TRIGGERS:
		listener = state.opponent_of(event["player"])
	else:
		push_error("TriggerDispatcher: unsupported trigger %s." % trigger)
		return entries
	var player := state.players[listener]
	for creature in player.board:
		if name == "ALLY_CREATURE_PLAYED" and creature.instance_id == int(event.get("creature_id", 0)):
			continue
		_add_effects(entries, EffectContext.SOURCE_CREATURE, creature.instance_id, creature.owner,
			creature.definition(), name, event)
	if player.active_artifact != null:
		_add_effects(entries, EffectContext.SOURCE_ARTIFACT, player.active_artifact.instance_id, listener,
			player.active_artifact.definition(), name, event)
	return entries


## LAST_BREATH entries of a creature that just died.
static func last_breath(creature: CreatureInstance) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_add_effects(entries, EffectContext.SOURCE_DEAD_CREATURE, creature.instance_id, creature.owner,
		creature.definition(), "LAST_BREATH", {"creature_id": creature.instance_id})
	return entries


## Cost-phase listeners (OPPONENT_PLAYS_CARD abilities that change the played
## card's cost) of the opponent of [param player_index].
static func cost_phase_entries(state: MatchState, player_index: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in collect(state, &"OPPONENT_PLAYS_CARD", {"player": player_index}):
		if entry["cost_phase"]:
			entries.append(entry)
	return entries


## True for abilities resolved while the cost of a played card is computed.
static func is_cost_phase(effect: CardEffectSpec) -> bool:
	return effect.actions.any(func(action: Dictionary) -> bool: return action["type"] == "INCREASE_PLAYED_CARD_COST")


static func _add_effects(entries: Array[Dictionary], kind: StringName, source_id: int, owner: int,
		definition: CardDefinition, trigger: String, event: Dictionary) -> void:
	for index in definition.effects.size():
		var effect := definition.effects[index]
		if String(effect.trigger) != trigger:
			continue
		var cost_phase := trigger == "OPPONENT_PLAYS_CARD" and is_cost_phase(effect)
		entries.append({
			"timing": String(effect.timing) if effect.timing != &"" else DEFAULT_TIMING,
			"source_kind": kind, "source_id": source_id, "owner": owner, "card_id": definition.id,
			"effect_index": index, "event": event.duplicate(true), "cost_phase": cost_phase,
		})
