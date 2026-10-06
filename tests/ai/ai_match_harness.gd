extends RefCounted
## QA-only AI-vs-AI harness. It uses real MatchEngine setup and commands.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")
const ScriptedRng := preload("res://tests/engine/scripted_rng.gd")
const MAX_TOTAL_COMMANDS := 4000
const MAX_TURNS := 500

var cards: Node


func _init(card_database: Node) -> void:
	cards = card_database


func play_match(hero_a: StringName, hero_b: StringName, difficulty_a: AiDifficulty.Level,
		difficulty_b: AiDifficulty.Level, rng: MatchRng) -> Dictionary:
	var fixture := MatchFixture.new(cards)
	var engine := fixture.setup(hero_a, hero_b, rng)
	var runners := [
		AiTurnRunner.new(AiController.new(difficulty_a)),
		AiTurnRunner.new(AiController.new(difficulty_b)),
	]
	var errors := PackedStringArray()
	var violations := PackedStringArray()
	var commands := 0
	var guards := 0

	for player_index in 2:
		var mulligan_trace: Dictionary = runners[player_index].run(engine, player_index, false,
			func(observation: Dictionary) -> void: _collect_invariants(observation, violations))
		commands += int(mulligan_trace["commands_executed"])
		guards += 1 if mulligan_trace["guard_triggered"] else 0
		if not String(mulligan_trace["error"]).is_empty():
			errors.append("mulligan player %d: %s" % [player_index, mulligan_trace["error"]])

	while not engine.is_over() and commands < MAX_TOTAL_COMMANDS:
		var observation := engine.get_observation(0)
		if observation.is_empty() or observation["phase"] != "TURN":
			errors.append("no active turn while match is running")
			break
		if int(observation["turn_number"]) > MAX_TURNS:
			errors.append("turn guard exceeded: %d" % int(observation["turn_number"]))
			break
		var active := int(observation["active_player"])
		var trace: Dictionary = runners[active].run(engine, active, false,
			func(after: Dictionary) -> void: _collect_invariants(after, violations))
		commands += int(trace["commands_executed"])
		guards += 1 if trace["guard_triggered"] else 0
		if not String(trace["error"]).is_empty():
			errors.append("player %d turn %d: %s" % [active, int(observation["turn_number"]), trace["error"]])
			break
		if int(trace["commands_executed"]) <= 0 and not engine.is_over():
			errors.append("AI made no progress on turn %d" % int(observation["turn_number"]))
			break

	return {
		"engine": engine,
		"ended": engine.is_over(),
		"winner": engine.get_winner(),
		"is_draw": engine.is_draw(),
		"first_player": engine.get_observation(0).get("first_player", -1),
		"commands": commands,
		"turns": int(engine.get_observation(0).get("turn_number", 0)),
		"guard_count": guards,
		"errors": errors,
		"invariant_violations": violations,
	}


static func _collect_invariants(observation: Dictionary, violations: PackedStringArray) -> void:
	if observation.is_empty():
		violations.append("empty observation")
		return
	if observation["phase"] == "TURN" and not observation["match_over"] 			and int(observation["active_player"]) not in [0, 1]:
		violations.append("invalid active player during TURN: %s" % observation["active_player"])
	for side_name in ["own", "opponent"]:
		var side: Dictionary = observation[side_name]
		if int(side["hand_count"]) > GameRules.MAX_HAND_SIZE:
			violations.append("%s hand=%d" % [side_name, int(side["hand_count"])])
		if (side["board"] as Array).size() > GameRules.MAX_CREATURES_PER_SIDE:
			violations.append("%s board=%d" % [side_name, (side["board"] as Array).size()])
		if int(side["soul_shards"]) < 0 or int(side["soul_shards"]) > GameRules.MAX_SOUL_SHARDS:
			violations.append("%s soul_shards=%d" % [side_name, int(side["soul_shards"])])
		if int(side["energy_current"]) < 0:
			violations.append("%s negative energy" % side_name)
		for creature: Dictionary in side["board"]:
			if int(creature["armor"]) < 0 or int(creature["armor"]) > int(creature["max_armor"]):
				violations.append("%s invalid armor: %s" % [side_name, creature])
			if int(creature["health"]) > int(creature["max_health"]):
				violations.append("%s invalid health: %s" % [side_name, creature])
