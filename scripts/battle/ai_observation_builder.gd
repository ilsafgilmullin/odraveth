class_name AiObservationBuilder
extends RefCounted
## Builds a plain-data, viewer-specific representation of a match.
## Hidden hands, deck identities/order, RNG and internal queues are never exposed.


static func build(state: MatchState, viewer: int) -> Dictionary:
	if state.players.size() != 2 or viewer < 0 or viewer > 1:
		return {}
	var opponent := state.opponent_of(viewer)
	var data := {
		"viewer": viewer,
		"phase": MatchState.Phase.find_key(state.phase),
		"turn_number": state.turn_number,
		"first_player": state.first_player,
		"active_player": state.active_player,
		"match_over": state.is_over(),
		"winner": state.winner,
		"is_draw": state.is_draw,
		"own": _player_view(state, viewer, true),
		"opponent": _player_view(state, opponent, false),
		"pending_choice": {},
	}
	if not state.pending_choice.is_empty() and int(state.pending_choice["player"]) == viewer:
		var options: Array[Dictionary] = []
		for option_id: int in state.pending_choice["options"]:
			var card := _find_card(state.players[viewer].deck, option_id)
			if card != null:
				options.append(_card_view(state, viewer, card, false))
		data["pending_choice"] = {
			"kind": String(state.pending_choice["kind"]),
			"options": options,
		}
	return data


static func _player_view(state: MatchState, index: int, include_hand: bool) -> Dictionary:
	var player := state.players[index]
	var board: Array[Dictionary] = []
	for creature in player.board:
		board.append(_creature_view(creature))
	var graveyard: Array[Dictionary] = []
	for card in player.graveyard:
		graveyard.append(_card_view(state, index, card, false))
	var modifiers: Array[Dictionary] = []
	for modifier in player.incoming_cost_modifiers:
		var item := {
			"source": String(modifier["source"]),
			"amount": int(modifier["amount"]),
		}
		if modifier.has("only_cost_at_most"):
			item["only_cost_at_most"] = int(modifier["only_cost_at_most"])
		if modifier.has("cost_cap"):
			item["cost_cap"] = int(modifier["cost_cap"])
		modifiers.append(item)
	var result := {
		"index": index,
		"hero": {
			"instance_id": player.hero_instance_id,
			"id": String(player.hero_id),
			"health": player.hero_health,
		},
		"energy_max": player.energy_max,
		"energy_current": player.energy_current,
		"soul_shards": player.soul_shards,
		"impulse_shard_available": player.impulse_shard_available,
		"hero_power_used_this_turn": player.hero_power_used_this_turn,
		"hero_damaged_this_turn": player.hero_damaged_this_turn,
		"friendly_creature_died_this_turn": player.friendly_creature_died_this_turn,
		"mulligan_done": player.mulligan_done,
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"rift_damage_next": player.rift_damage_next,
		"board": board,
		"artifact": _artifact_view(player.active_artifact),
		"graveyard": graveyard,
		"incoming_cost_modifiers": modifiers,
	}
	if include_hand:
		var hand: Array[Dictionary] = []
		for card in player.hand:
			hand.append(_card_view(state, index, card, true))
		result["hand"] = hand
	return result


static func _card_view(state: MatchState, owner: int, card: CardInstance, include_current_cost: bool) -> Dictionary:
	var result := {
		"instance_id": card.instance_id,
		"card_id": String(card.card_id()),
		"base_cost": card.base_cost,
		"is_echo": card.is_echo,
		"definition": _definition_view(card.definition),
	}
	if card.is_echo:
		result["echo_expires_turn"] = card.echo_expires_turn
	if include_current_cost:
		result["current_cost"] = int(CostCalculator.quote(state, owner, card)["cost"])
	return result


static func _creature_view(creature: CreatureInstance) -> Dictionary:
	return {
		"instance_id": creature.instance_id,
		"card_id": String(creature.card.card_id()),
		"definition": _definition_view(creature.definition()),
		"attack": creature.get_attack(),
		"health": creature.health,
		"max_health": creature.max_health,
		"armor": creature.armor,
		"max_armor": creature.max_armor,
		"keywords": creature.get_keywords(),
		"entered_turn": creature.entered_turn,
		"attacks_this_turn": creature.attacks_this_turn,
		"max_attacks_this_turn": creature.max_attacks_this_turn,
		"deferral_pending": creature.deferral_pending,
		"attack_blocked_turn": creature.attack_blocked_turn,
	}


static func _artifact_view(artifact: ArtifactInstance) -> Dictionary:
	if artifact == null:
		return {}
	return {
		"instance_id": artifact.instance_id,
		"card_id": String(artifact.card.card_id()),
		"charges": artifact.charges,
		"definition": _definition_view(artifact.definition()),
	}


static func _definition_view(definition: CardDefinition) -> Dictionary:
	var effects: Array[Dictionary] = []
	for effect in definition.effects:
		effects.append({
			"effect_id": String(effect.effect_id),
			"keyword": String(effect.keyword),
			"trigger": String(effect.trigger),
			"timing": String(effect.timing),
			"conditions": effect.conditions.duplicate(true),
			"actions": effect.actions.duplicate(true),
			"limits": effect.limits.duplicate(true),
		})
	return {
		"id": String(definition.id),
		"type": CardEnums.Type.find_key(definition.card_type),
		"rarity": CardEnums.Rarity.find_key(definition.rarity),
		"cost": definition.cost,
		"attack": definition.attack,
		"health": definition.health,
		"armor": definition.armor,
		"charges": definition.charges,
		"effects": effects,
	}


static func _find_card(cards: Array[CardInstance], instance_id: int) -> CardInstance:
	for card in cards:
		if card.instance_id == instance_id:
			return card
	return null
