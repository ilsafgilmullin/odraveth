class_name EffectExecutor
extends RefCounted
## Executes CardEffectSpec data (docs/ARCHITECTURE.md section 9). Only the
## EffectVocabulary identifiers used by the approved cards exist here.
##
## limits.per_turn counts resolutions whose conditions held. Actions run in text
## order; an action's own conditions are checked right before it. Each action is
## an atomic step followed by MatchResolver.step(); resolution stops as soon as
## the match ends or a player choice is pending.


static func resolve(resolver: MatchResolver, context: EffectContext) -> void:
	var state := resolver.state
	var effect := context.effect
	var counts := _trigger_counts(state, context)
	var limit := int(effect.limits.get("per_turn", 0))
	if limit > 0 and int(counts.get(effect.effect_id, 0)) >= limit:
		return
	if not EffectConditions.all_true(state, effect.conditions, context):
		return
	if limit > 0:
		counts[effect.effect_id] = int(counts.get(effect.effect_id, 0)) + 1
	if context.source_kind != EffectContext.SOURCE_SPELL:
		resolver.emit(MatchEvent.TRIGGER_RESOLVED, {"source_id": context.source_id, "card": String(context.card_id),
			"effect_id": String(effect.effect_id), "trigger": String(effect.trigger)})
	for action in effect.actions:
		if not resolver.can_continue():
			return
		if not EffectConditions.all_true(state, action.get("conditions", []), context):
			continue
		if not _apply(resolver, action, context):
			break
		if not resolver.step():
			return
	if context.source_kind == EffectContext.SOURCE_ARTIFACT:
		var artifact := state.players[context.owner].active_artifact
		if artifact != null and artifact.instance_id == context.source_id and artifact.charges <= 0:
			resolver.expire_artifact_if_empty(artifact)
			resolver.step()


## Applies one action. Returns false when the rest of the effect must not run
## (a mandatory Soul Shard cost could not be paid, or a choice is pending).
static func _apply(resolver: MatchResolver, action: Dictionary, context: EffectContext) -> bool:
	var state := resolver.state
	match String(action["type"]):
		"MODIFY_STATS":
			var multiplier := context.soul_shards_spent if action.get("multiplier") == "SOUL_SHARDS_SPENT" else 1
			if multiplier <= 0:
				return true
			for creature in _creature_targets(resolver, action["target"], context):
				if action.has("attack"):
					resolver.add_attack(creature, int(action["attack"]) * multiplier, action["duration"], context.owner)
				if action.has("health"):
					resolver.add_health(creature, int(action["health"]) * multiplier)
				if action.has("armor"):
					resolver.add_armor(creature, int(action["armor"]) * multiplier, context.card_id,
						int(action.get("armor_cap_from_this_card", -1)))
		"DEAL_DAMAGE":
			var amount := int(action["amount"])
			if action["target"] == "OWN_HERO":
				resolver.damage_hero(context.owner, amount, {"kind": "EFFECT", "card": String(context.card_id)})
			elif action.get("delay") == "END_OF_TURN":
				for creature in _creature_targets(resolver, action["target"], context):
					state.delayed_actions.append({"seq": state.take_sequence(), "turn": state.turn_number,
						"kind": "DAMAGE", "target_id": creature.instance_id, "amount": amount, "owner": context.owner,
						"card_id": String(context.card_id)})
			else:
				for creature in _creature_targets(resolver, action["target"], context):
					resolver.damage_creature(creature, amount, {"kind": "EFFECT", "card": String(context.card_id)})
		"DRAW_CARDS":
			for _index in int(action["amount"]):
				if not resolver.draw_card(context.owner):
					return false
		"GRANT_KEYWORD":
			for creature in _creature_targets(resolver, action["target"], context):
				_grant_keyword(resolver, creature, action["keyword"], action["duration"])
		"GRANT_EXTRA_ATTACK":
			for creature in _creature_targets(resolver, action["target"], context):
				creature.max_attacks_this_turn = mini(int(action["max_attacks_per_turn"]),
					creature.max_attacks_this_turn + int(action["amount"]))
				resolver.emit(MatchEvent.EXTRA_ATTACK_GRANTED, {"creature_id": creature.instance_id,
					"max_attacks_this_turn": creature.max_attacks_this_turn})
		"DESTROY":
			for creature in _creature_targets(resolver, action["target"], context):
				resolver.destroy(creature)
		"RETURN_TO_BOARD":
			var card := TargetRules.last_died_creature(state, context.owner)
			if card != null and state.players[context.owner].board.size() < GameRules.MAX_CREATURES_PER_SIDE:
				resolver.return_to_board(card, int(action["set_health"]))
		"RESTORE_ARMOR":
			for creature in _creature_targets(resolver, action["target"], context):
				resolver.restore_armor(creature, -1 if action.get("all_lost", false) else int(action["amount"]))
		"SPEND_CHARGES":
			var artifact := state.players[context.owner].active_artifact
			if context.source_kind == EffectContext.SOURCE_ARTIFACT and artifact != null \
					and artifact.instance_id == context.source_id:
				resolver.spend_charges(artifact, int(action["amount"]))
		"GAIN_SOUL_SHARDS":
			resolver.gain_soul_shards(context.owner, int(action["amount"]))
		"SPEND_SOUL_SHARDS":
			if action.has("up_to"):
				var wanted := int(context.choices.get(MatchCommand.CHOICE_SOUL_SHARDS, 0))
				var spend := clampi(wanted, 0, mini(int(action["up_to"]), state.players[context.owner].soul_shards))
				resolver.spend_soul_shards(context.owner, spend)
				context.soul_shards_spent = spend
			else:
				if not resolver.spend_soul_shards(context.owner, int(action["amount"])):
					return false
				context.soul_shards_spent = int(action["amount"])
		"INCREASE_NEXT_OPPONENT_CARD_COST":
			var modifier := {"seq": state.take_sequence(), "source": String(context.card_id), "source_owner": context.owner,
				"amount": int(action["amount"])}
			if action.has("only_cost_at_most"):
				modifier["only_cost_at_most"] = int(action["only_cost_at_most"])
			if action.has("cost_cap"):
				modifier["cost_cap"] = int(action["cost_cap"])
			state.players[state.opponent_of(context.owner)].incoming_cost_modifiers.append(modifier)
			resolver.emit(MatchEvent.COST_MODIFIER_ADDED, modifier.duplicate())
		"INCREASE_PLAYED_CARD_COST":
			# Applied while the cost was computed (CostCalculator); recorded here.
			resolver.emit(MatchEvent.COST_MODIFIED, {"card_instance_id": context.event.get("card_instance_id", 0),
				"amount": int(action["amount"]), "source": String(context.card_id)})
		"CREATE_ECHO_IN_HAND":
			_create_echo(resolver, action, context)
		"LOOK_AT_TOP_CARDS":
			return _look_at_top_cards(resolver, action, context)
		_:
			resolver.engine_error = "unsupported action %s" % action["type"]
			return false
	return true


## Creature targets of an action that are on the board right now.
static func _creature_targets(resolver: MatchResolver, target: String, context: EffectContext) -> Array[CreatureInstance]:
	var state := resolver.state
	var result: Array[CreatureInstance] = []
	var creature: CreatureInstance = null
	match target:
		"SELF":
			creature = state.find_creature(context.source_id)
		"CHOSEN_ALLY_CREATURE", "CHOSEN_OTHER_ALLY_CREATURE", "CHOSEN_ENEMY_CREATURE":
			creature = state.find_creature(context.target_id)
		"PLAYED_CREATURE":
			creature = state.find_creature(int(context.event.get("creature_id", 0)))
		"RANDOM_ALLY_CREATURE":
			var board := state.players[context.owner].board
			if not board.is_empty():
				creature = board[resolver.rng.next_int(board.size())]
	if creature != null and not creature.is_dead():
		result.append(creature)
	return result


static func _grant_keyword(resolver: MatchResolver, creature: CreatureInstance, keyword: String, duration: String) -> void:
	if keyword == "DEFERRAL":
		# Blocks attacks in the owner's next turn; repeating it does not extend it.
		creature.deferral_pending = true
		resolver.emit(MatchEvent.DEFERRAL_APPLIED, {"creature_id": creature.instance_id})
		return
	var expires := resolver.state.turn_number
	if duration == "END_OF_YOUR_NEXT_TURN":
		expires = resolver.next_own_turn_end(creature.owner)
	creature.temporary_keywords.append({"keyword": keyword, "expires_turn": expires})
	resolver.emit(MatchEvent.KEYWORD_GRANTED, {"creature_id": creature.instance_id, "keyword": keyword,
		"expires_turn": expires})
	resolver.recalculate_statics()


## Echo: a copy of the base definition of the opponent's spell, not of its runtime state.
static func _create_echo(resolver: MatchResolver, action: Dictionary, context: EffectContext) -> void:
	var card := resolver.new_card(context.owner, StringName(context.event["card_id"]))
	card.is_echo = true
	card.base_cost = maxi(int(action["min_cost"]), card.definition.cost)
	card.echo_expires_turn = resolver.next_own_turn_end(context.owner)
	resolver.emit(MatchEvent.ECHO_CREATED, {"player": context.owner, "card_instance_id": card.instance_id,
		"card": String(card.card_id()), "cost": card.base_cost, "expires_turn": card.echo_expires_turn})
	resolver.add_to_hand(context.owner, card, MatchEvent.CARD_ADDED_TO_HAND)


## Shows the top cards to their owner; the choice of the card kept on top is a
## separate CHOOSE command. Must be the last action of its effect.
static func _look_at_top_cards(resolver: MatchResolver, action: Dictionary, context: EffectContext) -> bool:
	var deck := resolver.state.players[context.owner].deck
	var count := mini(int(action["amount"]), deck.size())
	if count <= int(action["keep_on_top"]):
		return true
	var options: Array[int] = []
	for index in count:
		options.append(deck[index].instance_id)
	resolver.state.pending_choice = {"player": context.owner, "kind": "KEEP_ON_TOP", "options": options,
		"keep_on_top": int(action["keep_on_top"])}
	resolver.emit(MatchEvent.CHOICE_REQUIRED, {"player": context.owner, "kind": "KEEP_ON_TOP", "options": options.duplicate()})
	return false


static func _trigger_counts(state: MatchState, context: EffectContext) -> Dictionary:
	match context.source_kind:
		EffectContext.SOURCE_CREATURE:
			var creature := state.find_creature(context.source_id)
			if creature != null:
				return creature.trigger_counts
		EffectContext.SOURCE_ARTIFACT:
			var artifact := state.players[context.owner].active_artifact
			if artifact != null:
				return artifact.trigger_counts
	return {}
