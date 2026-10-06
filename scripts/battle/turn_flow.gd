class_name TurnFlow
extends RefCounted
## Match setup, mulligan and turn structure (docs/PRODUCT_BASELINE.md section 5).
##
## Random order at setup: first player (next_int(2)), then the decks of player 0
## and player 1 are shuffled. Mulligans are resolved together once both players
## decided, first player first.


## [param configs]: [{"hero": StringName, "deck": Array of card ids}, x2] (validated).
static func setup(resolver: MatchResolver, configs: Array) -> void:
	var state := resolver.state
	for index in 2:
		var player := PlayerState.new()
		player.index = index
		player.hero_id = StringName(configs[index]["hero"])
		player.faction = HeroCatalog.faction_of(player.hero_id)
		player.hero_instance_id = state.take_id()
		state.players.append(player)
	for player in state.players:
		for card_id: Variant in configs[player.index]["deck"]:
			player.deck.append(resolver.new_card(player.index, StringName(str(card_id))))
	resolver.emit(MatchEvent.MATCH_STARTED, {"heroes": [String(state.players[0].hero_id), String(state.players[1].hero_id)]})

	state.first_player = resolver.rng.next_int(2)
	resolver.emit(MatchEvent.FIRST_PLAYER_CHOSEN, {"player": state.first_player})
	for player in state.players:
		resolver.rng.shuffle(player.deck)
	var second := state.opponent_of(state.first_player)
	_deal(resolver, state.first_player, GameRules.FIRST_PLAYER_STARTING_HAND)
	_deal(resolver, second, GameRules.SECOND_PLAYER_STARTING_HAND)
	state.players[second].impulse_shard_available = true
	state.phase = MatchState.Phase.MULLIGAN


## Records a mulligan decision; when both players decided, resolves both and
## starts the first turn. Replaced cards are set aside, the same number of cards
## is drawn, then the replaced cards return to the deck and it is shuffled.
static func submit_mulligan(resolver: MatchResolver, player_index: int, replace_ids: Array[int]) -> void:
	var state := resolver.state
	state.mulligan_choices[player_index] = replace_ids.duplicate()
	state.players[player_index].mulligan_done = true
	if state.mulligan_choices.size() < 2:
		return
	for index in [state.first_player, state.opponent_of(state.first_player)]:
		var player := state.players[index]
		var chosen: Array = state.mulligan_choices[index]
		var set_aside: Array[CardInstance] = []
		for card in player.hand.duplicate():
			if card.instance_id in chosen:
				player.hand.erase(card)
				set_aside.append(card)
		for _card in set_aside:
			player.hand.append(player.deck.pop_front())
		if not set_aside.is_empty():
			player.deck.append_array(set_aside)
			resolver.rng.shuffle(player.deck)
		resolver.emit(MatchEvent.MULLIGAN_DONE, {"player": index,
			"replaced": set_aside.map(func(card: CardInstance) -> int: return card.instance_id)})
	state.mulligan_choices.clear()
	start_turn(resolver, state.first_player)


## Turn start: energy, per-turn resets, «Отложение» activation, mandatory draw.
static func start_turn(resolver: MatchResolver, player_index: int) -> void:
	var state := resolver.state
	var player := state.players[player_index]
	state.phase = MatchState.Phase.TURN
	state.turn_number += 1
	state.active_player = player_index
	player.turns_started += 1
	player.energy_max = GameRules.STARTING_MAX_ENERGY if player.turns_started == 1 \
		else mini(GameRules.MAX_ENERGY_CAP, player.energy_max + GameRules.MAX_ENERGY_GROWTH_PER_TURN)
	player.energy_current = player.energy_max
	player.hero_power_used_this_turn = false
	for side in state.players:
		side.hero_damaged_this_turn = false
		side.friendly_creature_died_this_turn = false
		for creature in side.board:
			creature.attacks_this_turn = 0
			creature.max_attacks_this_turn = 1
			creature.trigger_counts.clear()
		if side.active_artifact != null:
			side.active_artifact.trigger_counts.clear()
	for creature in player.board:
		if creature.deferral_pending:
			creature.deferral_pending = false
			creature.attack_blocked_turn = state.turn_number
	resolver.emit(MatchEvent.TURN_STARTED, {"player": player_index, "turn": state.turn_number})
	resolver.emit(MatchEvent.ENERGY_REFILLED, {"player": player_index, "energy_max": player.energy_max,
		"energy_current": player.energy_current})
	if resolver.draw_card(player_index):
		resolver.drain()


## Turn end: delayed end-of-turn damage, then expiry of temporary effects,
## Echo cards and «Отложение»; unused energy (including the Impulse Shard's) is
## lost; the opponent's turn starts.
static func end_turn(resolver: MatchResolver) -> void:
	var state := resolver.state
	var player_index := state.active_player
	var turn := state.turn_number
	var due := state.delayed_actions.filter(func(action: Dictionary) -> bool: return int(action["turn"]) == turn)
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["seq"]) < int(b["seq"]))
	for action: Dictionary in due:
		state.delayed_actions.erase(action)
		var target := state.find_creature(int(action["target_id"]))
		if target != null and not target.is_dead():
			resolver.damage_creature(target, int(action["amount"]), {"kind": "EFFECT", "card": action["card_id"]})
			if not resolver.step():
				return
	resolver.drain()
	if not resolver.can_continue():
		return

	for side in state.players:
		for creature in side.board:
			_expire_creature_effects(resolver, creature, turn)
		for card in side.hand.duplicate():
			if card.is_echo and card.echo_expires_turn <= turn:
				side.hand.erase(card)
				resolver.emit(MatchEvent.ECHO_EXPIRED, {"player": side.index, "card_instance_id": card.instance_id})
	state.players[player_index].energy_current = 0
	resolver.recalculate_statics()
	resolver.emit(MatchEvent.TURN_ENDED, {"player": player_index, "turn": turn})
	start_turn(resolver, state.opponent_of(player_index))


static func _expire_creature_effects(resolver: MatchResolver, creature: CreatureInstance, turn: int) -> void:
	var attack_before := creature.temporary_attack.size()
	creature.temporary_attack.assign(creature.temporary_attack.filter(
		func(bonus: Dictionary) -> bool: return int(bonus["expires_turn"]) > turn))
	var keywords_before := creature.temporary_keywords.size()
	creature.temporary_keywords.assign(creature.temporary_keywords.filter(
		func(granted: Dictionary) -> bool: return int(granted["expires_turn"]) > turn))
	var deferral_ended := creature.attack_blocked_turn == turn
	if deferral_ended:
		creature.attack_blocked_turn = -1
	if attack_before != creature.temporary_attack.size() or keywords_before != creature.temporary_keywords.size() \
			or deferral_ended:
		resolver.emit(MatchEvent.MODIFIER_EXPIRED, {"creature_id": creature.instance_id, "turn": turn})


static func _deal(resolver: MatchResolver, player_index: int, count: int) -> void:
	var player := resolver.state.players[player_index]
	for _index in count:
		var card: CardInstance = player.deck.pop_front()
		player.hand.append(card)
		resolver.emit(MatchEvent.CARD_DRAWN, {"player": player_index, "card_instance_id": card.instance_id,
			"card": String(card.card_id())})
