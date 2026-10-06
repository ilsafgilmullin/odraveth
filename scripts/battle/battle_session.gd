class_name BattleSession
extends RefCounted
## Orchestration layer: owns one MatchEngine instance, the AI runner and the
## match lifecycle. BattleScene delegates every command here; it never touches
## MatchState or MatchResolver directly.

signal match_ended(outcome: MatchOutcome.Result)

var engine: MatchEngine
var config: BattleLaunchConfig
var player_index: int = 0
var ai_index: int = 1
var turn_count: int:
	get:
		return int(get_observation().get("turn_number", 0))
var cards_played_player: int = 0
var cards_played_ai: int = 0

var _ai_controller: AiController
var _ai_runner: AiTurnRunner
var _last_event_seq: int = 0


func _init(launch_config: BattleLaunchConfig) -> void:
	config = launch_config
	var rng := DeterministicRng.new(config.rng_seed)
	engine = MatchEngine.new(CardDatabase, rng)
	_ai_controller = AiController.new(config.ai_difficulty)
	_ai_runner = AiTurnRunner.new(_ai_controller)


func start() -> ActionResult:
	var configs: Array = [
		{"hero": config.player_hero, "deck": config.player_deck},
		{"hero": config.opponent_hero, "deck": config.opponent_deck},
	]
	var result := engine.setup(configs)
	if result.ok:
		_advance_seq()
	return result


func get_observation() -> Dictionary:
	return engine.get_observation(player_index)


func get_legal_commands() -> Array[MatchCommand]:
	return engine.get_legal_commands(player_index)


func get_valid_play_targets(card_id: int) -> Array[int]:
	return engine.get_valid_play_targets(player_index, card_id)


func get_valid_attack_targets(attacker_id: int) -> Array[int]:
	return engine.get_valid_attack_targets(player_index, attacker_id)


func get_valid_hero_power_targets() -> Array[int]:
	return engine.get_valid_hero_power_targets(player_index)


func get_card_cost(card_id: int) -> int:
	return engine.get_card_cost(player_index, card_id)


func submit_mulligan(replace_ids: Array[int]) -> ActionResult:
	var result := engine.submit_mulligan(player_index, replace_ids)
	if result.ok:
		_advance_seq()
	return result


func play_card(card_id: int, target_id: int = 0, choices: Dictionary = {}) -> ActionResult:
	var result := engine.play_card(player_index, card_id, target_id, choices)
	if result.ok:
		cards_played_player += 1
		_advance_seq()
	return result


func attack(attacker_id: int, target_id: int) -> ActionResult:
	var result := engine.attack(player_index, attacker_id, target_id)
	if result.ok:
		_advance_seq()
	return result


func use_hero_power(target_id: int = 0) -> ActionResult:
	var result := engine.use_hero_power(player_index, target_id)
	if result.ok:
		_advance_seq()
	return result


func use_impulse_shard() -> ActionResult:
	var result := engine.use_impulse_shard(player_index)
	if result.ok:
		_advance_seq()
	return result


func end_turn() -> ActionResult:
	var result := engine.end_turn(player_index)
	if result.ok:
		_advance_seq()
	return result


func choose(option_id: int) -> ActionResult:
	var result := engine.choose(player_index, option_id)
	if result.ok:
		_advance_seq()
	return result


func run_ai_mulligan() -> void:
	var _trace := _ai_runner.run(engine, ai_index, false)
	_advance_seq()


func run_ai_turn() -> Array[Dictionary]:
	var all_events: Array[Dictionary] = []
	for step: Dictionary in run_ai_turn_steps():
		all_events.append_array(step["events"])
	return all_events


## One sanitized player-view observation after each accepted AI command.
## The runner still decides synchronously; the UI controls presentation time.
func run_ai_turn_steps() -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var commands: Array[Dictionary] = []
	var callback := func(_ai_observation: Dictionary) -> void:
		var events := engine.get_events(_last_event_seq)
		_last_event_seq += events.size()
		for evt: Dictionary in events:
			if evt.get("type") == MatchEvent.CARD_PLAYED:
				cards_played_ai += 1
		steps.append({"events": events, "observation_after_command": get_observation()})
	var trace := _ai_runner.run(engine, ai_index, false, callback)
	for decision: Dictionary in trace.get("decisions", []):
		commands.append(decision.get("selected_command", {}).duplicate(true))
	for i in steps.size():
		steps[i]["command"] = commands[i] if i < commands.size() else {}
	if engine.is_over():
		match_ended.emit(get_outcome())
	return steps


func is_over() -> bool:
	return engine.is_over()


func is_player_turn() -> bool:
	if engine.is_over():
		return false
	var obs := get_observation()
	if obs.is_empty():
		return false
	return obs.get("phase") == "TURN" and int(obs.get("active_player", -1)) == player_index


func is_mulligan_phase() -> bool:
	var obs := get_observation()
	if obs.is_empty():
		return false
	return obs.get("phase") == "MULLIGAN"


func is_choice_pending() -> bool:
	var obs := get_observation()
	if obs.is_empty():
		return false
	var choice: Variant = obs.get("pending_choice", {})
	return typeof(choice) == TYPE_DICTIONARY and not (choice as Dictionary).is_empty()


func get_outcome() -> MatchOutcome.Result:
	if engine.is_draw():
		return MatchOutcome.Result.DRAW
	if engine.get_winner() == player_index:
		return MatchOutcome.Result.VICTORY
	return MatchOutcome.Result.DEFEAT


func hero_power_name() -> String:
	var hero_data: Dictionary = HeroCatalog.HEROES.get(config.player_hero, {})
	return hero_data.get("power_ru", "")


func _advance_seq() -> void:
	_last_event_seq = engine.get_events(0).size()
