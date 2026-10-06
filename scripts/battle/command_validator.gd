class_name CommandValidator
extends RefCounted
## Authoritative, side-effect-free validation of player commands, and the list
## of all legal commands. UI and AI never repeat these rules; they ask MatchEngine.


## Returns {} when [param command] is legal, otherwise {"code", "message"}.
static func validate(state: MatchState, command: MatchCommand) -> Dictionary:
	if state.players.size() != 2:
		return _error(ActionResult.NO_MATCH, "the match is not set up")
	if state.is_over():
		return _error(ActionResult.MATCH_ENDED, "the match is over")
	if command.player < 0 or command.player > 1:
		return _error(ActionResult.NOT_YOUR_TURN, "unknown player %d" % command.player)
	if command.kind == MatchCommand.Kind.MULLIGAN:
		return _validate_mulligan(state, command)
	if state.phase != MatchState.Phase.TURN:
		return _error(ActionResult.WRONG_PHASE, "no turn is in progress")
	if not state.pending_choice.is_empty():
		if command.kind != MatchCommand.Kind.CHOOSE:
			return _error(ActionResult.CHOICE_PENDING, "a choice must be made first")
		return _validate_choice(state, command)
	if command.player != state.active_player:
		return _error(ActionResult.NOT_YOUR_TURN, "player %d is not active" % command.player)
	match command.kind:
		MatchCommand.Kind.END_TURN:
			return {}
		MatchCommand.Kind.USE_IMPULSE_SHARD:
			if not state.players[command.player].impulse_shard_available:
				return _error(ActionResult.NOT_AVAILABLE, "no Impulse Shard")
			return {}
		MatchCommand.Kind.USE_HERO_POWER:
			return _validate_hero_power(state, command)
		MatchCommand.Kind.PLAY_CARD:
			return _validate_play(state, command)
		MatchCommand.Kind.ATTACK:
			return _validate_attack(state, command)
		MatchCommand.Kind.CHOOSE:
			return _error(ActionResult.WRONG_PHASE, "no choice is pending")
	return _error(ActionResult.WRONG_PHASE, "unknown command")


## Every legal command of [param player_index] in the current state.
static func legal_commands(state: MatchState, player_index: int) -> Array[MatchCommand]:
	var candidates: Array[MatchCommand] = []
	if state.players.size() != 2 or state.is_over():
		return candidates
	var player := state.players[player_index]
	if state.phase == MatchState.Phase.MULLIGAN:
		var hand_ids: Array[int] = []
		for card in player.hand:
			hand_ids.append(card.instance_id)
		for mask in 1 << hand_ids.size():
			var chosen: Array[int] = []
			for bit in hand_ids.size():
				if mask & (1 << bit):
					chosen.append(hand_ids[bit])
			candidates.append(MatchCommand.mulligan(player_index, chosen))
	elif not state.pending_choice.is_empty():
		for option: int in state.pending_choice["options"]:
			candidates.append(MatchCommand.choose(player_index, option))
	else:
		candidates.append(MatchCommand.end_turn(player_index))
		candidates.append(MatchCommand.use_impulse_shard(player_index))
		for target in _all_target_ids(state, true):
			candidates.append(MatchCommand.use_hero_power(player_index, target))
		for card in player.hand:
			var spend_max := TargetRules.optional_soul_shard_spend(card.definition)
			for target in _all_target_ids(state, true):
				if spend_max < 0:
					candidates.append(MatchCommand.play_card(player_index, card.instance_id, target))
				else:
					for spend in mini(spend_max, player.soul_shards) + 1:
						candidates.append(MatchCommand.play_card(player_index, card.instance_id, target,
							{MatchCommand.CHOICE_SOUL_SHARDS: spend}))
		for creature in player.board:
			for target in _all_target_ids(state, false):
				candidates.append(MatchCommand.attack(player_index, creature.instance_id, target))
	var legal: Array[MatchCommand] = []
	for command in candidates:
		if validate(state, command).is_empty():
			legal.append(command)
	return legal


static func _validate_mulligan(state: MatchState, command: MatchCommand) -> Dictionary:
	if state.phase != MatchState.Phase.MULLIGAN:
		return _error(ActionResult.WRONG_PHASE, "the mulligan is over")
	var player := state.players[command.player]
	if player.mulligan_done:
		return _error(ActionResult.ALREADY_USED, "mulligan already submitted")
	var seen := {}
	for id in command.replace_ids:
		if seen.has(id) or player.find_in_hand(id) == null:
			return _error(ActionResult.INVALID_CHOICE, "card %d cannot be replaced" % id)
		seen[id] = true
	return {}


static func _validate_choice(state: MatchState, command: MatchCommand) -> Dictionary:
	if command.player != int(state.pending_choice["player"]):
		return _error(ActionResult.NOT_YOUR_TURN, "the choice belongs to the other player")
	if int(command.choices.get(MatchCommand.CHOICE_OPTION, -1)) not in state.pending_choice["options"]:
		return _error(ActionResult.INVALID_CHOICE, "not one of the offered options")
	return {}


static func _validate_hero_power(state: MatchState, command: MatchCommand) -> Dictionary:
	var player := state.players[command.player]
	if player.hero_power_used_this_turn:
		return _error(ActionResult.ALREADY_USED, "hero ability already used this turn")
	if player.energy_current < GameRules.HERO_ABILITY_COST:
		return _error(ActionResult.NOT_ENOUGH_ENERGY, "needs %d energy" % GameRules.HERO_ABILITY_COST)
	if HeroCatalog.needs_friendly_target(player.hero_id):
		if command.target_id == 0:
			return _error(ActionResult.TARGET_REQUIRED, "choose a friendly creature")
		if player.find_on_board(command.target_id) == null:
			return _error(ActionResult.INVALID_TARGET, "target must be a friendly creature")
	elif command.target_id != 0:
		return _error(ActionResult.INVALID_TARGET, "this ability has no target")
	return {}


static func _validate_play(state: MatchState, command: MatchCommand) -> Dictionary:
	var player := state.players[command.player]
	var card := player.find_in_hand(command.source_id)
	if card == null:
		return _error(ActionResult.UNKNOWN_CARD, "card %d is not in hand" % command.source_id)
	var definition := card.definition
	var cost := int(CostCalculator.quote(state, command.player, card)["cost"])
	if cost > player.energy_current:
		return _error(ActionResult.NOT_ENOUGH_ENERGY, "costs %d, has %d" % [cost, player.energy_current])
	if (definition.card_type == CardEnums.Type.CREATURE or TargetRules.returns_creature(definition)) \
			and player.board.size() >= GameRules.MAX_CREATURES_PER_SIDE:
		return _error(ActionResult.BOARD_FULL, "the board already has %d creatures" % GameRules.MAX_CREATURES_PER_SIDE)
	if TargetRules.returns_creature(definition) and TargetRules.last_died_creature(state, command.player) == null:
		return _error(ActionResult.INVALID_TARGET, "no friendly creature has died")
	if TargetRules.mandatory_soul_shard_spend(definition) > player.soul_shards:
		return _error(ActionResult.NOT_ENOUGH_SOUL_SHARDS, "not enough Soul Shards")

	var spend_max := TargetRules.optional_soul_shard_spend(definition)
	if spend_max >= 0:
		var spend: Variant = command.choices.get(MatchCommand.CHOICE_SOUL_SHARDS)
		if typeof(spend) != TYPE_INT or spend < 0 or spend > mini(spend_max, player.soul_shards):
			return _error(ActionResult.INVALID_CHOICE, "choose 0..%d Soul Shards" % mini(spend_max, player.soul_shards))
	elif command.choices.has(MatchCommand.CHOICE_SOUL_SHARDS):
		return _error(ActionResult.INVALID_CHOICE, "this card takes no Soul Shard choice")

	var kind := TargetRules.chosen_target_kind(definition)
	if kind.is_empty():
		if command.target_id != 0:
			return _error(ActionResult.INVALID_TARGET, "this card has no target")
		return {}
	var targets := TargetRules.chosen_targets(state, command.player, kind)
	if targets.is_empty():
		if definition.card_type == CardEnums.Type.CREATURE and command.target_id == 0:
			return {}
		return _error(ActionResult.TARGET_REQUIRED if command.target_id == 0 else ActionResult.INVALID_TARGET,
			"no valid target for %s" % kind)
	if command.target_id == 0:
		return _error(ActionResult.TARGET_REQUIRED, "choose a target (%s)" % kind)
	if command.target_id not in targets:
		return _error(ActionResult.INVALID_TARGET, "target %d is not a valid %s" % [command.target_id, kind])
	return {}


static func _validate_attack(state: MatchState, command: MatchCommand) -> Dictionary:
	var attacker := state.players[command.player].find_on_board(command.source_id)
	if attacker == null:
		return _error(ActionResult.CANNOT_ATTACK, "creature %d is not on your board" % command.source_id)
	var reason := TargetRules.attack_block_reason(state, attacker)
	if not reason.is_empty():
		return _error(ActionResult.CANNOT_ATTACK, reason)
	if command.target_id not in TargetRules.attack_targets(state, attacker):
		return _error(ActionResult.INVALID_TARGET, "target %d cannot be attacked" % command.target_id)
	return {}


## 0 (no target), every creature and, optionally, both heroes.
static func _all_target_ids(state: MatchState, include_none: bool) -> Array[int]:
	var ids: Array[int] = []
	if include_none:
		ids.append(0)
	for player in state.players:
		ids.append(player.hero_instance_id)
		for creature in player.board:
			ids.append(creature.instance_id)
	return ids


static func _error(code: StringName, message: String) -> Dictionary:
	return {"code": code, "message": message}
