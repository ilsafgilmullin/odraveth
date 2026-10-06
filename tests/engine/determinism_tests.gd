extends RefCounted
## Determinism and robustness:
## - replay: the same seed and the same commands give identical snapshots after
##   every command and an identical event log;
## - fuzz: complete matches driven by a seeded random policy over
##   get_legal_commands() keep every invariant after every command and end.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")
const HEROES: Array[StringName] = [HeroCatalog.KEZHARYN, HeroCatalog.VHORAZEL, HeroCatalog.SYRRAVETH, HeroCatalog.TAZHYRION]
const MAX_COMMANDS := 3000
const ACTIONS_PER_TURN := 10

var _check: Callable
var _cards: Node


func _init(check: Callable, _expect_errors: Callable, cards: Node) -> void:
	_check = check
	_cards = cards


func run() -> void:
	_test_replay()
	_test_fuzz()


func _ok(condition: bool, description: String) -> void:
	_check.call(condition, description)


func _test_replay() -> void:
	var fixture := MatchFixture.new(_cards)
	var engine := fixture.setup(HeroCatalog.SYRRAVETH, HeroCatalog.VHORAZEL, DeterministicRng.new(4242))
	var snapshots: Array[String] = [JSON.stringify(engine.snapshot())]
	var commands := _play(engine, 99, func(played: MatchEngine) -> void:
		snapshots.append(JSON.stringify(played.snapshot())))
	_ok(engine.is_over() and commands.size() > 50, "replay: the recorded match ran to the end (%d commands)" % commands.size())

	var replay := MatchFixture.new(_cards).setup(HeroCatalog.SYRRAVETH, HeroCatalog.VHORAZEL, DeterministicRng.new(4242))
	var mismatch := -1
	if JSON.stringify(replay.snapshot()) != snapshots[0]:
		mismatch = 0
	for index in commands.size():
		var result := replay.execute(MatchCommand.from_dictionary(commands[index]))
		if mismatch < 0 and (not result.ok or JSON.stringify(replay.snapshot()) != snapshots[index + 1]):
			mismatch = index + 1
	_ok(mismatch == -1, "replay: same seed + same commands -> identical snapshot after every command (first mismatch %d)" % mismatch)
	_ok(JSON.stringify(replay.get_events()) == JSON.stringify(engine.get_events()), "replay: identical event log")

	var other := MatchFixture.new(_cards).setup(HeroCatalog.SYRRAVETH, HeroCatalog.VHORAZEL, DeterministicRng.new(4243))
	_ok(JSON.stringify(other.snapshot()) != snapshots[0], "replay: a different seed gives a different match")


func _test_fuzz() -> void:
	var matches := 0
	var ended := 0
	var commands_total := 0
	var violations := PackedStringArray()
	for seed in 24:
		var fixture := MatchFixture.new(_cards)
		var engine := fixture.setup(HEROES[seed % 4], HEROES[(seed + 1 + seed % 3) % 4], DeterministicRng.new(1000 + seed))
		var commands := _play(engine, 2000 + seed, func(played: MatchEngine) -> void:
			for problem in _invariants(played):
				if violations.size() < 10:
					violations.append("seed %d turn %d: %s" % [seed, played.state.turn_number, problem]))
		matches += 1
		commands_total += commands.size()
		if engine.is_over():
			ended += 1
	_ok(violations.is_empty(), "fuzz: invariants hold after every command in %d matches (%d commands) %s" % [
		matches, commands_total, violations])
	_ok(ended == matches, "fuzz: every match ended (%d/%d)" % [ended, matches])


## Plays with a seeded random policy over the legal commands; returns the commands.
func _play(engine: MatchEngine, policy_seed: int, after_each: Callable) -> Array[Dictionary]:
	var policy := DeterministicRng.new(policy_seed)
	var recorded: Array[Dictionary] = []
	var turn := -1
	var actions := 0
	while not engine.is_over() and recorded.size() < MAX_COMMANDS:
		var state := engine.state
		if state.turn_number != turn:
			turn = state.turn_number
			actions = 0
		var player := _deciding_player(state)
		var legal := engine.get_legal_commands(player)
		var others := legal.filter(func(command: MatchCommand) -> bool: return command.kind != MatchCommand.Kind.END_TURN)
		var command: MatchCommand
		if others.is_empty() or (state.pending_choice.is_empty() and state.phase == MatchState.Phase.TURN
				and (actions >= ACTIONS_PER_TURN or policy.next_int(6) == 0)):
			command = MatchCommand.end_turn(player)
		else:
			command = others[policy.next_int(others.size())]
		var result := engine.execute(command)
		if not result.ok:
			_ok(false, "fuzz: a legal command was rejected: %s -> %s %s" % [command.to_dictionary(), result.error, result.message])
			break
		recorded.append(command.to_dictionary())
		actions += 1
		after_each.call(engine)
	return recorded


func _deciding_player(state: MatchState) -> int:
	if state.phase == MatchState.Phase.MULLIGAN:
		return 0 if not state.players[0].mulligan_done else 1
	if not state.pending_choice.is_empty():
		return int(state.pending_choice["player"])
	return state.active_player


func _invariants(engine: MatchEngine) -> PackedStringArray:
	var state := engine.state
	var problems := PackedStringArray()
	var ids := {}
	for player in state.players:
		var tag := "player %d" % player.index
		if player.hand.size() > GameRules.MAX_HAND_SIZE:
			problems.append("%s hand %d" % [tag, player.hand.size()])
		if player.board.size() > GameRules.MAX_CREATURES_PER_SIDE:
			problems.append("%s board %d" % [tag, player.board.size()])
		if player.soul_shards < 0 or player.soul_shards > GameRules.MAX_SOUL_SHARDS:
			problems.append("%s soul shards %d" % [tag, player.soul_shards])
		if player.energy_current < 0 or player.energy_max > GameRules.MAX_ENERGY_CAP \
				or player.energy_current > player.energy_max + GameRules.IMPULSE_SHARD_ENERGY:
			problems.append("%s energy %d/%d" % [tag, player.energy_current, player.energy_max])
		if player.hero_health > GameRules.HERO_STARTING_HEALTH:
			problems.append("%s hero health %d" % [tag, player.hero_health])
		for creature in player.board:
			if creature.is_dead() or creature.armor < 0 or creature.armor > creature.max_armor \
					or creature.health > creature.max_health or creature.attacks_this_turn > creature.max_attacks_this_turn \
					or creature.max_attacks_this_turn > 2 or creature.owner != player.index:
				problems.append("%s creature %s" % [tag, creature.snapshot()])
		if player.active_artifact != null and player.active_artifact.charges <= 0:
			problems.append("%s artifact without charges" % tag)
		var real_cards := player.deck.size() + player.board.size() + player.graveyard.size() \
			+ player.burned.filter(func(card: CardInstance) -> bool: return not card.is_echo).size() \
			+ player.hand.filter(func(card: CardInstance) -> bool: return not card.is_echo).size() \
			+ (1 if player.active_artifact != null else 0)
		if real_cards != GameRules.DECK_SIZE:
			problems.append("%s has %d of its 30 cards" % [tag, real_cards])
		var zones: Array = []
		zones.append_array(player.deck)
		zones.append_array(player.hand)
		zones.append_array(player.graveyard)
		zones.append_array(player.burned)
		for card: CardInstance in zones:
			if ids.has(card.instance_id):
				problems.append("duplicate card instance %d" % card.instance_id)
			ids[card.instance_id] = true
		for creature in player.board:
			if ids.has(creature.card.instance_id):
				problems.append("creature card %d also in another zone" % creature.card.instance_id)
			ids[creature.card.instance_id] = true
	if state.is_over() != (state.winner >= 0 or state.is_draw):
		problems.append("inconsistent outcome")
	if state.pending_choice.is_empty() and (not state.when_queue.is_empty() or not state.after_queue.is_empty()):
		problems.append("trigger queues not empty after a command")
	return problems
