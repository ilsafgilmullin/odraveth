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
var turn_count: int = 0
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
		turn_count += 1
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
	var seq_before: int = _last_event_seq
	var _trace := _ai_runner.run(engine, ai_index, false)
	var all_events := engine.get_events(seq_before)
	_last_event_seq += all_events.size()
	for evt: Dictionary in all_events:
		if evt.get("type") == MatchEvent.CARD_PLAYED:
			cards_played_ai += 1
	if engine.is_over():
		match_ended.emit(get_outcome())
	return all_events


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


func needs_hero_power_target() -> bool:
	return HeroCatalog.needs_friendly_target(config.player_hero)


func hero_power_name() -> String:
	var hero_data: Dictionary = HeroCatalog.HEROES.get(config.player_hero, {})
	return hero_data.get("power_ru", "")


func _advance_seq() -> void:
	_last_event_seq = engine.get_events(0).size()
