class_name EffectConditions
extends RefCounted
## Evaluates EffectVocabulary conditions against the current state. Pure: never
## changes the match.


static func all_true(state: MatchState, conditions: Array, context: EffectContext) -> bool:
	for condition: Dictionary in conditions:
		if not is_true(state, condition, context):
			return false
	return true


static func is_true(state: MatchState, condition: Dictionary, context: EffectContext) -> bool:
	var player := state.players[context.owner]
	match String(condition["type"]):
		"OWN_HERO_DAMAGED_THIS_TURN":
			return player.hero_damaged_this_turn
		"OWN_HERO_HEALTH_AT_MOST":
			return player.hero_health <= int(condition["value"])
		"IS_OWN_TURN":
			return state.active_player == context.owner
		"FIRST_ATTACK_THIS_TURN":
			var source := state.find_creature(context.source_id)
			return source != null and source.attacks_this_turn == 1
		"OWN_SOUL_SHARDS_AT_LEAST":
			return player.soul_shards >= int(condition["value"])
		"SOUL_SHARDS_SPENT_EQUALS":
			return context.soul_shards_spent == int(condition["value"])
		"PLAYED_CARD_TYPE":
			return context.event.get("card_type", "") == condition["card_type"]
		"PLAYED_CARD_COST_AT_LEAST":
			return int(context.event.get("cost", -1)) >= int(condition["value"])
		"PLAYED_CARD_COST_INCREASED_BY_YOU":
			return int(context.event.get("increased_by_opponent", 0)) > 0
		"TARGET_ARMOR_FULL", "TARGET_ARMOR_NOT_FULL":
			var target := state.find_creature(context.target_id)
			if target == null:
				return false
			var full := target.armor >= target.max_armor
			return full if condition["type"] == "TARGET_ARMOR_FULL" else not full
		"NO_OTHER_ALLY_CREATURES":
			return player.board.all(func(creature: CreatureInstance) -> bool:
				return creature.instance_id == context.source_id)
		"OWN_ACTIVE_ARTIFACT":
			return player.active_artifact != null
		"OWN_DECK_SIZE_AT_MOST":
			return player.deck.size() <= int(condition["value"])
	push_error("EffectConditions: unsupported condition %s." % condition)
	return false
