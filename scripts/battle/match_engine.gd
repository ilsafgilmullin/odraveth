class_name MatchEngine
extends RefCounted
## One deterministic ODRAVETH match (docs/ARCHITECTURE.md section 9).
##
## Not an autoload: one instance = one match, owned by whoever runs the match
## (the battle screen later). All randomness comes from the injected MatchRng;
## all rules are checked here, so UI and AI never duplicate them.
##
## Every command is validated first; a rejected command returns a failed
## ActionResult and changes nothing. An accepted command is applied completely;
## if a safety limit is hit during resolution, the whole command is rolled back
## and ENGINE_ERROR is returned.

var state := MatchState.new()

var _rng: MatchRng
var _card_source: Object
var _resolver: MatchResolver


## [param card_source]: any object with get_card(id) -> CardDefinition
## (CardDatabase). [param rng]: DeterministicRng for real matches.
func _init(card_source: Object, rng: MatchRng) -> void:
	_card_source = card_source
	_rng = rng
	_resolver = MatchResolver.new(state, rng, card_source)


## Creates the match: validates both decks, shuffles them, picks the first
## player and deals the starting hands. [param configs]:
## [{"hero": StringName, "deck": Array of 30 card ids}, {...}] for players 0 and 1.
func setup(configs: Array) -> ActionResult:
	if state.phase != MatchState.Phase.SETUP:
		return ActionResult.failure(ActionResult.INVALID_SETUP, "the match is already set up")
	if configs.size() != 2:
		return ActionResult.failure(ActionResult.INVALID_SETUP, "exactly two players are needed")
	var problems := PackedStringArray()
	for index in 2:
		var config: Dictionary = configs[index]
		for problem in DeckValidator.validate(StringName(str(config.get("hero", ""))), config.get("deck", []), _card_source):
			problems.append("player %d: %s" % [index, problem])
	if not problems.is_empty():
		return ActionResult.failure(ActionResult.INVALID_SETUP, "; ".join(problems))
	return _run(func() -> void: TurnFlow.setup(_resolver, configs))


## Applies [param command] if it is legal.
func execute(command: MatchCommand) -> ActionResult:
	var problem := CommandValidator.validate(state, command)
	if not problem.is_empty():
		return ActionResult.failure(problem["code"], problem["message"])
	return _run(func() -> void: _dispatch(command))


## Checks [param command] without applying it.
func validate(command: MatchCommand) -> ActionResult:
	var problem := CommandValidator.validate(state, command)
	if not problem.is_empty():
		return ActionResult.failure(problem["code"], problem["message"])
	return ActionResult.success([])


func submit_mulligan(player: int, replace_ids: Array[int]) -> ActionResult:
	return execute(MatchCommand.mulligan(player, replace_ids))


func play_card(player: int, card_id: int, target_id: int = 0, choices: Dictionary = {}) -> ActionResult:
	return execute(MatchCommand.play_card(player, card_id, target_id, choices))


func attack(player: int, attacker_id: int, target_id: int) -> ActionResult:
	return execute(MatchCommand.attack(player, attacker_id, target_id))


func use_hero_power(player: int, target_id: int = 0) -> ActionResult:
	return execute(MatchCommand.use_hero_power(player, target_id))


func use_impulse_shard(player: int) -> ActionResult:
	return execute(MatchCommand.use_impulse_shard(player))


func end_turn(player: int) -> ActionResult:
	return execute(MatchCommand.end_turn(player))


func choose(player: int, option_id: int) -> ActionResult:
	return execute(MatchCommand.choose(player, option_id))


## Every legal command of [param player] now (targets and choices included).
func get_legal_commands(player: int) -> Array[MatchCommand]:
	return CommandValidator.legal_commands(state, player)


## Sanitized, viewer-specific plain data for UI/AI. The result intentionally
## excludes hidden hand identities, all deck identities/order, RNG and resolver queues.
func get_observation(viewer_player: int) -> Dictionary:
	return AiObservationBuilder.build(state, viewer_player)


## Valid target ids for playing hand card [param card_id] (0 = "no target").
func get_valid_play_targets(player: int, card_id: int) -> Array[int]:
	var targets: Array[int] = []
	for command in get_legal_commands(player):
		if command.kind == MatchCommand.Kind.PLAY_CARD and command.source_id == card_id \
				and command.target_id not in targets:
			targets.append(command.target_id)
	return targets


## Valid attack targets of creature [param attacker_id].
func get_valid_attack_targets(player: int, attacker_id: int) -> Array[int]:
	var targets: Array[int] = []
	for command in get_legal_commands(player):
		if command.kind == MatchCommand.Kind.ATTACK and command.source_id == attacker_id:
			targets.append(command.target_id)
	return targets


## Legal hero-power targets (0 means no target), derived from the same command
## enumeration used to validate execution. Empty when the power is unavailable.
func get_valid_hero_power_targets(player: int) -> Array[int]:
	var targets: Array[int] = []
	for command in get_legal_commands(player):
		if command.kind == MatchCommand.Kind.USE_HERO_POWER and command.target_id not in targets:
			targets.append(command.target_id)
	return targets


## Current cost of hand card [param card_id] for its owner, or -1.
func get_card_cost(player: int, card_id: int) -> int:
	if state.players.size() != 2:
		return -1
	var card := state.players[player].find_in_hand(card_id)
	return int(CostCalculator.quote(state, player, card)["cost"]) if card != null else -1


## Canonical plain-data snapshot of the match state and the RNG position.
## Changing it never changes the match.
func snapshot() -> Dictionary:
	var data := state.snapshot()
	data["rng_state"] = _rng.get_state()
	return data


## Copies of the events with seq > [param after_seq].
func get_events(after_seq: int = 0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event in state.events.slice(after_seq):
		events.append(event.duplicate(true))
	return events


func is_over() -> bool:
	return state.is_over()


## Winning player index; -1 while running or after a draw.
func get_winner() -> int:
	return state.winner


func is_draw() -> bool:
	return state.is_draw


func _dispatch(command: MatchCommand) -> void:
	match command.kind:
		MatchCommand.Kind.MULLIGAN:
			TurnFlow.submit_mulligan(_resolver, command.player, command.replace_ids)
		MatchCommand.Kind.PLAY_CARD:
			CardPlay.play(_resolver, command.player, command.source_id, command.target_id, command.choices)
		MatchCommand.Kind.USE_HERO_POWER:
			HeroPowers.use(_resolver, command.player, command.target_id)
		MatchCommand.Kind.USE_IMPULSE_SHARD:
			var player := state.players[command.player]
			player.impulse_shard_available = false
			player.energy_current += GameRules.IMPULSE_SHARD_ENERGY
			_resolver.emit(MatchEvent.IMPULSE_SHARD_USED, {"player": command.player, "energy_current": player.energy_current})
		MatchCommand.Kind.ATTACK:
			Combat.attack(_resolver, command.source_id, command.target_id)
		MatchCommand.Kind.END_TURN:
			TurnFlow.end_turn(_resolver)
		MatchCommand.Kind.CHOOSE:
			_resolve_choice(command)


## «Тренический картограф»: the chosen card stays on top, the others go to the
## bottom of the deck in their current order; then pending triggers continue.
func _resolve_choice(command: MatchCommand) -> void:
	var choice := state.pending_choice
	var player := state.players[int(choice["player"])]
	var kept := int(command.choices[MatchCommand.CHOICE_OPTION])
	var looked: Array[CardInstance] = []
	for card in player.deck.slice(0, (choice["options"] as Array).size()):
		looked.append(card)
	for card in looked:
		player.deck.erase(card)
	for card in looked:
		if card.instance_id == kept:
			player.deck.push_front(card)
	for card in looked:
		if card.instance_id != kept:
			player.deck.append(card)
	state.pending_choice = {}
	_resolver.emit(MatchEvent.CHOICE_MADE, {"player": player.index, "kind": choice["kind"], "kept_on_top": kept})
	if _resolver.step():
		_resolver.drain()


## Runs [param action] as one transaction: on an engine error the state and the
## RNG are restored.
func _run(action: Callable) -> ActionResult:
	var backup := state.clone(false)
	var rng_backup: Variant = _rng.get_state()
	var first_event := state.events.size()
	_resolver.begin_command()
	action.call()
	if not _resolver.engine_error.is_empty():
		var message := _resolver.engine_error
		backup.events = state.events.slice(0, first_event)
		state = backup
		_resolver.state = backup
		_rng.set_state(rng_backup)
		_resolver.begin_command()
		push_error("MatchEngine: %s; command rolled back." % message)
		return ActionResult.failure(ActionResult.ENGINE_ERROR, message)
	return ActionResult.success(get_events(first_event), not state.pending_choice.is_empty())
