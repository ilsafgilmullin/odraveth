extends RefCounted
## Stage 3 deterministic AI: information boundary, policies, decisions and turn execution.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")
const ScriptedRng := preload("res://tests/engine/scripted_rng.gd")
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL
const S := HeroCatalog.SYRRAVETH
const T := HeroCatalog.TAZHYRION

var _check: Callable
var _cards: Node
var f: MatchFixture


class IllegalController extends AiController:
	func _init() -> void:
		super(AiDifficulty.Level.NOVICE)

	func decide(observation: Dictionary, legal_commands: Array[MatchCommand]) -> AiDecision:
		var decision := AiDecision.new()
		decision.difficulty = difficulty
		decision.candidate_count = legal_commands.size()
		decision.selected_command = MatchCommand.play_card(int(observation["viewer"]), 999999)
		decision.selected_score = 999999
		return decision


func _init(check: Callable, _expect_errors: Callable, cards: Node) -> void:
	_check = check
	_cards = cards
	f = MatchFixture.new(cards)


func run() -> void:
	_test_observation_boundary()
	_test_information_barriers()
	_test_static_anti_cheat_guard()
	_test_decision_determinism()
	_test_immediate_lethal()
	_test_self_lethal_avoidance()
	_test_difficulty_separation()
	_test_mulligan()
	_test_cartographer_choice()
	_test_soulmonger_choice()
	_test_hero_powers()
	_test_impulse_and_full_turn()
	_test_target_selection()
	_test_runner_rejects_nonlegal_command()
	_test_turn_guard()
	_test_trace_sanitization()


func _ok(condition: bool, description: String) -> void:
	_check.call(condition, description)


func _test_observation_boundary() -> void:
	var engine := f.scenario(K, T)
	f.hand(0, &"ashravael_blood_tithe")
	f.hand(1, &"khevaruun_wallforged")
	f.board(0, &"neutral_vantrel_duskling")
	f.board(1, &"khevaruun_ironwarden")
	var observation := engine.get_observation(0)
	_ok(observation.has("own") and observation.has("opponent") and observation["own"].has("hand"),
		"AI observation: own visible hand is exposed")
	_ok(not observation["opponent"].has("hand") and int(observation["opponent"]["hand_count"]) == 1,
		"AI observation: opponent hand identities are hidden, count is public")
	_ok(observation["own"].has("deck_count") and observation["opponent"].has("deck_count")
		and not observation["own"].has("deck") and not observation["opponent"].has("deck"),
		"AI observation: both deck orders and identities are hidden")
	var serialized := JSON.stringify(observation)
	_ok(not serialized.contains("rng_state") and not serialized.contains("when_queue")
		and not serialized.contains("after_queue") and not serialized.contains("delayed_actions"),
		"AI observation: RNG and internal resolution queues are absent")
	var original_health := int(engine.get_observation(0)["own"]["hero"]["health"])
	observation["own"]["hero"]["health"] = 1
	_ok(int(engine.get_observation(0)["own"]["hero"]["health"]) == original_health,
		"AI observation: returned plain data is an independent copy")


func _test_information_barriers() -> void:
	var first := f.scenario(K, T)
	f.hand(0, &"neutral_vantrel_duskling")
	f.hand(1, &"khevaruun_wallforged")
	var command_a := _selected_key(first, 0, AiDifficulty.Level.STRATEGIST)
	var obs_a := JSON.stringify(first.get_observation(0))

	var second_fixture := MatchFixture.new(_cards)
	var second := second_fixture.scenario(K, T)
	second_fixture.hand(0, &"neutral_vantrel_duskling")
	second_fixture.hand(1, &"ashravael_warfiend")
	_ok(JSON.stringify(second.get_observation(0)) == obs_a
		and _selected_key(second, 0, AiDifficulty.Level.STRATEGIST) == command_a,
		"information barrier A: different opponent hand identity cannot change the decision")

	first = f.scenario(K, T)
	f.hand(0, &"neutral_vantrel_duskling")
	var before_deck_key := _selected_key(first, 0, AiDifficulty.Level.STRATEGIST)
	var deck := f.player(1).deck
	var swap := deck[0]
	deck[0] = deck[1]
	deck[1] = swap
	_ok(_selected_key(first, 0, AiDifficulty.Level.STRATEGIST) == before_deck_key,
		"information barrier B: opponent deck order cannot change the decision")

	first = f.scenario(K, T)
	f.hand(0, &"neutral_vantrel_duskling")
	before_deck_key = _selected_key(first, 0, AiDifficulty.Level.STRATEGIST)
	deck = f.player(0).deck
	swap = deck[0]
	deck[0] = deck[1]
	deck[1] = swap
	_ok(_selected_key(first, 0, AiDifficulty.Level.STRATEGIST) == before_deck_key,
		"information barrier C: own future deck order cannot change the decision")

	first = f.scenario(K, T)
	f.hand(0, &"neutral_vantrel_duskling")
	var rng_key := _selected_key(first, 0, AiDifficulty.Level.STRATEGIST)
	var state_before := first.snapshot()["rng_state"]
	first._rng.set_state(987654321)
	_ok(_selected_key(first, 0, AiDifficulty.Level.STRATEGIST) == rng_key
		and first.snapshot()["rng_state"] != state_before,
		"information barrier D: different hidden RNG state cannot change the decision")

	first = f.scenario(K, T)
	f.player(0).energy_current = 2
	f.deck_top(0, ["neutral_vantrel_duskling"])
	var before_draw := AiController.new(AiDifficulty.Level.TACTICIAN).decide(
		first.get_observation(0), first.get_legal_commands(0))
	_ok(before_draw.selected_command.kind == MatchCommand.Kind.END_TURN,
		"information barrier E: future draw is not anticipated")
	first._resolver.draw_card(0)
	var after_draw := AiController.new(AiDifficulty.Level.TACTICIAN).decide(
		first.get_observation(0), first.get_legal_commands(0))
	_ok(after_draw.selected_command.kind == MatchCommand.Kind.PLAY_CARD,
		"information barrier E: a card may affect decisions only after it is actually drawn")


func _test_static_anti_cheat_guard() -> void:
	var offenders := PackedStringArray()
	var forbidden := [".state", ".snapshot()", "._rng", "._resolver", "randi(", "randf(", "randomize(", "RandomNumberGenerator"]
	for file_name in DirAccess.get_files_at("res://scripts/ai"):
		if file_name.get_extension() != "gd":
			continue
		var source := FileAccess.get_file_as_string("res://scripts/ai".path_join(file_name))
		var lines := source.split("\n")
		source = "\n".join(Array(lines).filter(func(line: String) -> bool:
			return not line.strip_edges().begins_with("#")))
		for token in forbidden:
			if source.contains(token):
				offenders.append("%s: %s" % [file_name, token])
	_ok(offenders.is_empty(), "anti-cheat source audit: scripts/ai uses no private state/snapshot/RNG %s" % [offenders])


func _test_decision_determinism() -> void:
	var engine := f.scenario(K, T)
	f.hand(0, &"ashravael_blood_tithe")
	f.hand(0, &"neutral_vantrel_duskling")
	f.board(0, &"neutral_mireglass_wanderer")
	f.board(1, &"neutral_vantrel_duskling")
	var observation := engine.get_observation(0)
	var legal := engine.get_legal_commands(0)
	for difficulty: AiDifficulty.Level in AiDifficulty.Level.values():
		var controller := AiController.new(difficulty)
		var first := controller.decide(observation, legal)
		var key := AiController.canonical_command_key(first.selected_command)
		var stable := true
		for _iteration in 100:
			var again := controller.decide(observation, legal)
			if AiController.canonical_command_key(again.selected_command) != key 					or again.selected_score != first.selected_score:
				stable = false
				break
		_ok(stable, "AI determinism: %s returns the same decision 100 times" % AiDifficulty.code(difficulty))

	var left_fixture := MatchFixture.new(_cards)
	var right_fixture := MatchFixture.new(_cards)
	var left := left_fixture.scenario(T, K)
	var right := right_fixture.scenario(T, K)
	left_fixture.hand(0, &"neutral_vantrel_duskling")
	right_fixture.hand(0, &"neutral_vantrel_duskling")
	var left_trace := AiTurnRunner.new(AiController.new(AiDifficulty.Level.TACTICIAN)).run(left, 0)
	var right_trace := AiTurnRunner.new(AiController.new(AiDifficulty.Level.TACTICIAN)).run(right, 0)
	_ok(JSON.stringify(left_trace) == JSON.stringify(right_trace)
		and JSON.stringify(left.snapshot()) == JSON.stringify(right.snapshot()),
		"AI determinism: identical real matches produce identical full-turn trace and state")


func _test_immediate_lethal() -> void:
	for difficulty: AiDifficulty.Level in AiDifficulty.Level.values():
		var engine := f.scenario(K, T)
		var attacker := f.board(0, &"neutral_rivenshade_grazer")
		f.player(1).hero_health = 5
		var decision := AiController.new(difficulty).decide(engine.get_observation(0), engine.get_legal_commands(0))
		_ok(decision.selected_command.kind == MatchCommand.Kind.ATTACK
			and decision.selected_command.source_id == attacker
			and decision.selected_command.target_id == f.hero_id(1),
			"immediate lethal: %s takes guaranteed lethal" % AiDifficulty.code(difficulty))


func _test_self_lethal_avoidance() -> void:
	for difficulty: AiDifficulty.Level in AiDifficulty.Level.values():
		var engine := f.scenario(K, T)
		f.board(0, &"neutral_vantrel_duskling", false)
		f.player(0).hero_health = 1
		f.player(0).energy_current = 2
		var decision := AiController.new(difficulty).decide(engine.get_observation(0), engine.get_legal_commands(0))
		_ok(decision.selected_command.kind != MatchCommand.Kind.USE_HERO_POWER,
			"self-lethal: %s avoids losing Kezharyn power when END_TURN exists" % AiDifficulty.code(difficulty))


func _test_difficulty_separation() -> void:
	var engine := f.scenario(K, T)
	var attacker := f.board(0, &"neutral_vantrel_duskling")
	var threat := f.board(1, &"ashravael_cinderclaw")
	var novice := AiController.new(AiDifficulty.Level.NOVICE).decide(engine.get_observation(0), engine.get_legal_commands(0))
	var tactician := AiController.new(AiDifficulty.Level.TACTICIAN).decide(engine.get_observation(0), engine.get_legal_commands(0))
	var strategist := AiController.new(AiDifficulty.Level.STRATEGIST).decide(engine.get_observation(0), engine.get_legal_commands(0))
	_ok(novice.selected_command.kind == MatchCommand.Kind.ATTACK and novice.selected_command.source_id == attacker
		and novice.selected_command.target_id == f.hero_id(1),
		"difficulty: Novice prefers simple hero damage in the curated trade")
	_ok(tactician.selected_command.kind == MatchCommand.Kind.ATTACK and tactician.selected_command.target_id == threat,
		"difficulty: Tactician values the favorable threat-removing trade")
	_ok(strategist.selected_command.kind == MatchCommand.Kind.ATTACK and strategist.selected_command.target_id == threat,
		"difficulty: Strategist also preserves tactical board control")


func _test_mulligan() -> void:
	for difficulty: AiDifficulty.Level in AiDifficulty.Level.values():
		var fixture := MatchFixture.new(_cards)
		var engine := fixture.setup(K, T, ScriptedRng.new([0]))
		var player := engine.state.first_player
		var legal := engine.get_legal_commands(player)
		var decision := AiController.new(difficulty).decide(engine.get_observation(player), legal)
		_ok(decision.selected_command.kind == MatchCommand.Kind.MULLIGAN
			and engine.validate(decision.selected_command).ok,
			"mulligan: %s selects a legal deterministic replacement set" % AiDifficulty.code(difficulty))
		var trace := AiTurnRunner.new(AiController.new(difficulty)).run(engine, player)
		_ok(String(trace["error"]).is_empty() and engine.state.players[player].mulligan_done,
			"mulligan: %s submits the decision only through MatchEngine" % AiDifficulty.code(difficulty))


func _test_cartographer_choice() -> void:
	var engine := f.scenario(K, T)
	var top := f.deck_top(0, ["neutral_rivenshade_grazer", "neutral_mireglass_wanderer"])
	var cartographer := f.hand(0, &"neutral_threnic_cartographer")
	var result := engine.play_card(0, cartographer)
	var observation := engine.get_observation(0)
	_ok(result.awaiting_choice and (observation["pending_choice"]["options"] as Array).size() == 2,
		"Cartographer: revealed CHOOSE options enter the sanitized observation")
	var decision := AiController.new(AiDifficulty.Level.STRATEGIST).decide(observation, engine.get_legal_commands(0))
	_ok(decision.selected_command.kind == MatchCommand.Kind.CHOOSE
		and int(decision.selected_command.choices[MatchCommand.CHOICE_OPTION]) == top[0],
		"Cartographer: Strategist chooses the higher visible card value from revealed options")
	_ok(engine.execute(decision.selected_command).ok, "Cartographer: selected option is a real legal MatchEngine command")


func _test_soulmonger_choice() -> void:
	var engine := f.scenario(V, T)
	var card := f.hand(0, &"nerqathen_soulmonger")
	f.player(0).soul_shards = 3
	var legal := engine.get_legal_commands(0)
	var tactician := AiController.new(AiDifficulty.Level.TACTICIAN).decide(engine.get_observation(0), legal)
	var strategist := AiController.new(AiDifficulty.Level.STRATEGIST).decide(engine.get_observation(0), legal)
	_ok(tactician.selected_command.kind == MatchCommand.Kind.PLAY_CARD and tactician.selected_command.source_id == card
		and int(tactician.selected_command.choices.get(MatchCommand.CHOICE_SOUL_SHARDS, -1)) == 3,
		"Soulmonger: Tactician spends 3 for immediate stats and armor in an empty-board scenario")
	_ok(strategist.selected_command.kind == MatchCommand.Kind.PLAY_CARD and strategist.selected_command.source_id == card
		and int(strategist.selected_command.choices.get(MatchCommand.CHOICE_SOUL_SHARDS, -1)) == 0,
		"Soulmonger: Strategist preserves Soul Shards when public pressure is absent")


func _test_hero_powers() -> void:
	var cases := [
		[K, T],
		[V, T],
		[S, T],
		[T, K],
	]
	for pair: Array in cases:
		var engine := f.scenario(pair[0], pair[1])
		if pair[0] == K or pair[0] == T:
			f.board(0, &"neutral_vantrel_duskling", false)
		if pair[0] == S:
			f.hand(1, &"neutral_vantrel_duskling")
		f.player(0).energy_current = 2
		var decision := AiController.new(AiDifficulty.Level.TACTICIAN).decide(
			engine.get_observation(0), engine.get_legal_commands(0))
		_ok(decision.selected_command.kind == MatchCommand.Kind.USE_HERO_POWER,
			"hero power: Tactician uses %s in a useful legal position" % String(pair[0]))


func _test_impulse_and_full_turn() -> void:
	var engine := f.scenario(V, T)
	f.player(0).impulse_shard_available = true
	f.player(0).energy_current = 1
	var card := f.hand(0, &"neutral_vantrel_duskling")
	var trace := AiTurnRunner.new(AiController.new(AiDifficulty.Level.TACTICIAN)).run(engine, 0, true)
	var kinds: Array = []
	for decision: Dictionary in trace["decisions"]:
		if decision.has("selected_command"):
			kinds.append(decision["selected_command"]["kind"])
	_ok(String(trace["error"]).is_empty() and "USE_IMPULSE_SHARD" in kinds and "PLAY_CARD" in kinds
		and f.creature(card) != null,
		"Impulse/full turn: AI spends shard only because +1 unlocks a visible play, then plays it")
	_ok(engine.get_observation(0)["active_player"] == 1 or engine.is_over(),
		"full turn: AI eventually ends the turn and hands control to the opponent")


func _test_target_selection() -> void:
	var engine := f.scenario(K, T)
	var card := f.hand(0, &"ashravael_gorebrand")
	var high_threat := f.board(1, &"ashravael_cinderclaw")
	f.board(1, &"neutral_rivenshade_grazer")
	var decision := AiController.new(AiDifficulty.Level.TACTICIAN).decide(
		engine.get_observation(0), engine.get_legal_commands(0))
	_ok(decision.selected_command.kind == MatchCommand.Kind.PLAY_CARD and decision.selected_command.source_id == card
		and decision.selected_command.target_id == high_threat,
		"target selection: Tactician chooses the killable high-threat enemy for Gorebrand")


func _test_runner_rejects_nonlegal_command() -> void:
	var engine := f.scenario(K, T)
	var before := JSON.stringify(engine.snapshot())
	var trace := AiTurnRunner.new(IllegalController.new()).run(engine, 0)
	_ok(String(trace["error"]).contains("outside the legal command set")
		and int(trace["commands_executed"]) == 0 and JSON.stringify(engine.snapshot()) == before,
		"AI runner: a controller cannot execute a command outside MatchEngine legal commands")


func _test_turn_guard() -> void:
	var engine := f.scenario(T, K)
	f.hand(0, &"neutral_vantrel_duskling")
	var runner := AiTurnRunner.new(AiController.new(AiDifficulty.Level.TACTICIAN), 1)
	var trace := runner.run(engine, 0)
	_ok(trace["guard_triggered"] and String(trace["error"]).is_empty(),
		"AI turn guard: command limit is detected")
	_ok(engine.is_over() or int(engine.get_observation(0)["active_player"]) == 1,
		"AI turn guard: a legal safety END_TURN prevents an infinite loop")


func _test_trace_sanitization() -> void:
	var engine := f.scenario(K, T)
	f.hand(0, &"neutral_vantrel_duskling")
	f.hand(1, &"khevaruun_wallforged")
	var trace := AiTurnRunner.new(AiController.new(AiDifficulty.Level.STRATEGIST)).run(engine, 0, true)
	var serialized := JSON.stringify(trace)
	_ok(not serialized.contains("khevaruun_wallforged") and not serialized.contains("rng_state")
		and not serialized.contains("deck"),
		"AI trace: ranked debug data contains no hidden opponent hand/deck/RNG information")


func _selected_key(engine: MatchEngine, player: int, difficulty: AiDifficulty.Level) -> String:
	var decision := AiController.new(difficulty).decide(engine.get_observation(player), engine.get_legal_commands(player))
	return AiController.canonical_command_key(decision.selected_command)
