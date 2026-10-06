class_name CardPlay
extends RefCounted
## Plays a validated card from hand (docs/ARCHITECTURE.md section 9.3):
## 1. pay the quoted cost: energy, consumed "next card" increases, cost-phase
##    abilities of the opponent («Пустостекло»);
## 2. the card leaves the hand (CARD_PLAYED);
## 3. WHEN: the opponent's «paid an increased cost» and «plays a card» abilities;
## 4. creature: enters the board, «ally played» abilities, then «Вход в бой»;
##    spell: ON_PLAY effects, then the graveyard (an Echo just disappears);
##    artifact: replaces the active one;
## 5. AFTER triggers (e.g. «Пиявка эха»).


static func play(resolver: MatchResolver, player_index: int, card_id: int, target_id: int, choices: Dictionary) -> void:
	var state := resolver.state
	var player := state.players[player_index]
	var card := player.find_in_hand(card_id)
	var quote := CostCalculator.quote(state, player_index, card)
	var cost := int(quote["cost"])

	player.energy_current -= cost
	resolver.emit(MatchEvent.ENERGY_SPENT, {"player": player_index, "amount": cost, "left": player.energy_current})
	for modifier in player.incoming_cost_modifiers.duplicate():
		if int(modifier["seq"]) in quote["consumed_modifiers"]:
			player.incoming_cost_modifiers.erase(modifier)
			resolver.emit(MatchEvent.COST_MODIFIED, {"card_instance_id": card.instance_id, "modifier": modifier.duplicate()})
	for entry: Dictionary in quote["cost_triggers"]:
		var effect := resolver.effect_for(entry)
		if effect != null:
			EffectExecutor.resolve(resolver, EffectContext.from_entry(entry, effect))
	player.hand.erase(card)
	var card_type: String = CardEnums.Type.find_key(card.definition.card_type)
	var event := {"player": player_index, "card_instance_id": card.instance_id, "card_id": String(card.card_id()),
		"card_type": card_type, "cost": cost, "base_cost": card.base_cost,
		"increased_by_opponent": int(quote["increased_by_opponent"]), "is_echo": card.is_echo}
	resolver.emit(MatchEvent.CARD_PLAYED, event)
	if not resolver.step():
		return
	if int(quote["increased_by_opponent"]) > 0:
		resolver.queue_trigger(&"OPPONENT_PAYS_INCREASED_COST", event)
	resolver.queue_trigger(&"OPPONENT_PLAYS_CARD", event)
	if not resolver.step():
		return

	match card.definition.card_type:
		CardEnums.Type.CREATURE:
			var creature := resolver.summon(card)
			resolver.queue_trigger(&"ALLY_CREATURE_PLAYED", {"player": player_index, "creature_id": creature.instance_id})
			if not resolver.step():
				return
			for effect in TargetRules.play_effects(card.definition):
				if not resolver.can_continue() or state.find_creature(creature.instance_id) == null:
					break
				var context := EffectContext.create(player_index, EffectContext.SOURCE_CREATURE, creature.instance_id,
					card.card_id(), effect)
				context.target_id = target_id
				context.choices = choices
				EffectExecutor.resolve(resolver, context)
		CardEnums.Type.SPELL:
			for effect in TargetRules.play_effects(card.definition):
				if not resolver.can_continue():
					break
				var context := EffectContext.create(player_index, EffectContext.SOURCE_SPELL, card.instance_id,
					card.card_id(), effect)
				context.target_id = target_id
				context.choices = choices
				EffectExecutor.resolve(resolver, context)
			if not card.is_echo:
				player.graveyard.append(card)
			resolver.emit(MatchEvent.SPELL_RESOLVED, {"player": player_index, "card_instance_id": card.instance_id})
		CardEnums.Type.ARTIFACT:
			resolver.play_artifact(card)
	if resolver.step():
		resolver.drain()
