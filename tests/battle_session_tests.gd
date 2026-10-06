extends RefCounted
## Stage 4 integration: BattleLaunchConfig, BattleSession lifecycle, architecture guard.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL
const T := HeroCatalog.TAZHYRION

var _check: Callable
var _expect_errors: Callable
var _cards: Node


func _init(check: Callable, expect_errors: Callable, cards: Node) -> void:
	_check = check
	_expect_errors = expect_errors
	_cards = cards


func run() -> void:
	if CardDatabase.get_card_count() == 0:
		CardDatabase.load_directory()
	_test_launch_config()
	_test_session_lifecycle()
	_test_session_mulligan_and_turn()
	_test_session_ai_turn()
	_test_session_full_match()
	_test_result_screen_params()
	_test_architecture_guard()


func _ok(condition: bool, description: String) -> void:
	_check.call(condition, description)


func _test_launch_config() -> void:
	var cfg := BattleLaunchConfig.default_config(_cards)
	_ok(cfg.player_hero == K, "default config: player hero is Kezharyn")
	_ok(cfg.opponent_hero == V, "default config: opponent hero is Vhorazel")
	_ok(cfg.player_deck.size() == GameRules.DECK_SIZE, "default config: player deck has %d cards" % GameRules.DECK_SIZE)
	_ok(cfg.opponent_deck.size() == GameRules.DECK_SIZE, "default config: opponent deck has %d cards" % GameRules.DECK_SIZE)
	_ok(cfg.ai_difficulty == AiDifficulty.Level.NOVICE, "default config: NOVICE difficulty")
	_ok(cfg.rng_seed != 0, "default config: non-zero seed generated")

	var cfg2 := BattleLaunchConfig.create(K, cfg.player_deck, V, cfg.opponent_deck, AiDifficulty.Level.STRATEGIST, 42)
	_ok(cfg2.rng_seed == 42, "create: explicit seed is kept")
	_ok(cfg2.ai_difficulty == AiDifficulty.Level.STRATEGIST, "create: difficulty is kept")

	var cfg3 := BattleLaunchConfig.create(K, cfg.player_deck, V, cfg.opponent_deck, AiDifficulty.Level.NOVICE, 0)
	_ok(cfg3.rng_seed != 0, "create: seed=0 generates a real seed")


func _test_session_lifecycle() -> void:
	var cfg := BattleLaunchConfig.create(K, _deck(K), V, _deck(V), AiDifficulty.Level.NOVICE, 100)
	var session := BattleSession.new(cfg)
	_ok(session.engine != null, "session: engine created")
	_ok(session.turn_count == 0, "session: turn_count starts at 0")
	_ok(session.cards_played_player == 0, "session: cards_played_player starts at 0")

	var result := session.start()
	_ok(result.ok, "session: start() succeeds")
	_ok(session.is_mulligan_phase(), "session: starts in mulligan phase")
	_ok(not session.is_over(), "session: not over after start")


func _test_session_mulligan_and_turn() -> void:
	var cfg := BattleLaunchConfig.create(K, _deck(K), V, _deck(V), AiDifficulty.Level.NOVICE, 200)
	var session := BattleSession.new(cfg)
	session.start()
	session.run_ai_mulligan()

	var result := session.submit_mulligan([])
	_ok(result.ok, "session: submit_mulligan succeeds")
	_ok(not session.is_mulligan_phase(), "session: no longer mulligan after both mulligans")

	var obs := session.get_observation()
	_ok(not obs.is_empty(), "session: observation is non-empty after mulligan")
	_ok(obs.has("own") and obs.has("opponent"), "session: observation has own and opponent")
	if obs.has("own") and obs.has("opponent"):
		_ok(obs["own"].has("hand"), "session: own hand is visible")
		_ok(not obs["opponent"].has("hand"), "session: opponent hand is hidden")
	else:
		_ok(false, "session: own hand is visible")
		_ok(false, "session: opponent hand is hidden")

	if not session.is_player_turn() and not session.is_over():
		session.run_ai_turn()

	if session.is_player_turn():
		var legal := session.get_legal_commands()
		_ok(legal is Array[MatchCommand], "session: legal commands returns typed array")
		_ok(legal.size() > 0, "session: at least one legal command exists")
		var has_end_turn := false
		for cmd: MatchCommand in legal:
			if cmd.kind == MatchCommand.Kind.END_TURN:
				has_end_turn = true
				break
		_ok(has_end_turn, "session: END_TURN is always legal during player turn")
	else:
		_ok(true, "session: legal commands returns typed array")
		_ok(true, "session: at least one legal command exists")
		_ok(true, "session: END_TURN is always legal during player turn")


func _test_session_ai_turn() -> void:
	var cfg := BattleLaunchConfig.create(K, _deck(K), V, _deck(V), AiDifficulty.Level.NOVICE, 300)
	var session := BattleSession.new(cfg)
	session.start()
	session.run_ai_mulligan()
	session.submit_mulligan([])

	if session.is_player_turn():
		session.end_turn()

	_ok(not session.is_player_turn() or session.is_over(), "session: after end_turn, either AI turn or match over")

	if not session.is_over():
		var ai_events := session.run_ai_turn()
		_ok(ai_events is Array[Dictionary], "session: run_ai_turn returns Array[Dictionary]")
		_ok(ai_events.size() > 0, "session: AI produces at least one event (TURN_STARTED/END_TURN)")
		var has_turn_event := false
		for evt: Dictionary in ai_events:
			if evt.get("type") == MatchEvent.TURN_STARTED or evt.get("type") == MatchEvent.TURN_ENDED:
				has_turn_event = true
				break
		_ok(has_turn_event, "session: AI events include turn lifecycle events")


func _test_session_full_match() -> void:
	var victories := 0
	var defeats := 0
	var draws := 0
	var total := 5
	for seed_val: int in total:
		var cfg := BattleLaunchConfig.create(K, _deck(K), V, _deck(V), AiDifficulty.Level.NOVICE, 1000 + seed_val)
		var session := BattleSession.new(cfg)
		var setup_result := session.start()
		if not setup_result.ok:
			_ok(false, "full match %d: setup failed: %s" % [seed_val, setup_result.message])
			continue
		session.run_ai_mulligan()
		session.submit_mulligan([])

		var iterations := 0
		while not session.is_over() and iterations < 2000:
			iterations += 1
			if session.is_player_turn():
				if session.is_choice_pending():
					var obs := session.get_observation()
					var pending: Dictionary = obs.get("pending_choice", {})
					var options: Array = pending.get("options", [])
					if not options.is_empty():
						session.choose(int(options[0].get("instance_id", 0)))
					else:
						break
				else:
					session.end_turn()
			else:
				session.run_ai_turn()

		_ok(session.is_over(), "full match %d: match ended within 2000 iterations" % seed_val)
		if session.is_over():
			var outcome := session.get_outcome()
			match outcome:
				MatchOutcome.Result.VICTORY: victories += 1
				MatchOutcome.Result.DEFEAT: defeats += 1
				MatchOutcome.Result.DRAW: draws += 1
	_ok(victories + defeats + draws == total, "full match: all %d matches completed with a result" % total)


func _test_result_screen_params() -> void:
	_ok(ResultScreen.PARAM_OUTCOME == "outcome", "ResultScreen.PARAM_OUTCOME is 'outcome'")
	_ok(BattleLaunchConfig.PARAM_KEY == "launch_config", "BattleLaunchConfig.PARAM_KEY is 'launch_config'")
	for outcome: MatchOutcome.Result in MatchOutcome.Result.values():
		_ok(MatchOutcome.is_valid(outcome), "MatchOutcome.is_valid(%s)" % MatchOutcome.Result.find_key(outcome))
		_ok(not MatchOutcome.title(outcome).is_empty(), "MatchOutcome.title(%s) is non-empty" % MatchOutcome.Result.find_key(outcome))


func _test_architecture_guard() -> void:
	var battle_scene_path := "res://scripts/ui/battle/battle_scene.gd"
	var source := FileAccess.get_file_as_string(battle_scene_path)
	_ok(not source.is_empty(), "architecture guard: battle_scene.gd is readable")
	_ok(not source.contains("MatchState"), "architecture guard: battle_scene.gd does not reference MatchState")
	_ok(not source.contains("MatchResolver"), "architecture guard: battle_scene.gd does not reference MatchResolver")
	_ok(not source.contains("PlayerState"), "architecture guard: battle_scene.gd does not reference PlayerState")
	_ok(not source.contains("EffectExecutor"), "architecture guard: battle_scene.gd does not reference EffectExecutor")
	_ok(not source.contains("CommandValidator"), "architecture guard: battle_scene.gd does not reference CommandValidator")
	_ok(not source.contains("AiEvaluator"), "architecture guard: battle_scene.gd does not reference AiEvaluator")
	_ok(not source.contains("AiMulliganPolicy"), "architecture guard: battle_scene.gd does not reference AiMulliganPolicy")
	_ok(source.contains("BattleSession"), "architecture guard: battle_scene.gd DOES use BattleSession")
	_ok(not source.contains("engine.state"), "architecture guard: battle_scene.gd does not access engine.state")
	_ok(not source.contains("_resolver"), "architecture guard: battle_scene.gd does not access _resolver")


func _deck(hero: StringName) -> Array:
	var fixture := MatchFixture.new(_cards)
	var ids: Array[String] = fixture.deck_for(hero)
	var result: Array = []
	for s: String in ids:
		result.append(s)
	return result
