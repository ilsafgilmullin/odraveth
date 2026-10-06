class_name CostCalculator
extends RefCounted
## Current cost of a hand card, computed without changing the match.
##
## Order: base cost (an Echo: its own base cost) -> the opponent's pending
## "next card" increases, oldest first, each checked against the cost at that
## moment (at most one distortion charge per card; other increases may add up)
## -> the opponent's cost-phase abilities («Пустостекло») against the resulting cost.

const DISTORTION := "DISTORTION"


## Returns {"cost", "base_cost", "consumed_modifiers": [seq], "cost_triggers": [entries],
## "increased_by_opponent"}. Charges and counters are only checked here; the
## play itself consumes them.
static func quote(state: MatchState, player_index: int, card: CardInstance) -> Dictionary:
	var cost := card.base_cost
	var consumed: Array[int] = []
	var distortion_applied := false
	for modifier in state.players[player_index].incoming_cost_modifiers:
		var only_at_most := int(modifier.get("only_cost_at_most", -1))
		if only_at_most >= 0 and cost > only_at_most:
			continue
		if modifier["source"] == DISTORTION:
			if distortion_applied:
				continue
			distortion_applied = true
		cost += int(modifier["amount"])
		if modifier.has("cost_cap"):
			cost = mini(cost, int(modifier["cost_cap"]))
		consumed.append(int(modifier["seq"]))

	var triggers: Array[Dictionary] = []
	for entry in TriggerDispatcher.cost_phase_entries(state, player_index):
		var source := _source_counts(state, entry)
		var effect := _effect(state, entry)
		var limit := int(effect.limits.get("per_turn", 0))
		if limit > 0 and int(source.get(effect.effect_id, 0)) >= limit:
			continue
		var event := {"player": player_index, "card_id": card.card_id(), "card_instance_id": card.instance_id,
			"card_type": CardEnums.Type.find_key(card.definition.card_type), "cost": cost}
		var context := EffectContext.from_entry(entry, effect)
		context.event = event
		if not EffectConditions.all_true(state, effect.conditions, context):
			continue
		entry["event"] = event
		triggers.append(entry)
		for action in effect.actions:
			if action["type"] == "INCREASE_PLAYED_CARD_COST":
				cost += int(action["amount"])
	return {"cost": cost, "base_cost": card.base_cost, "consumed_modifiers": consumed,
		"cost_triggers": triggers, "increased_by_opponent": cost - card.base_cost}


static func _effect(state: MatchState, entry: Dictionary) -> CardEffectSpec:
	return _source_definition(state, entry).effects[int(entry["effect_index"])]


static func _source_definition(state: MatchState, entry: Dictionary) -> CardDefinition:
	var owner := state.players[int(entry["owner"])]
	if entry["source_kind"] == EffectContext.SOURCE_ARTIFACT:
		return owner.active_artifact.definition()
	return owner.find_on_board(int(entry["source_id"])).definition()


static func _source_counts(state: MatchState, entry: Dictionary) -> Dictionary:
	var owner := state.players[int(entry["owner"])]
	if entry["source_kind"] == EffectContext.SOURCE_ARTIFACT:
		return owner.active_artifact.trigger_counts
	return owner.find_on_board(int(entry["source_id"])).trigger_counts
