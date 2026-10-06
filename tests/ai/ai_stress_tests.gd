extends RefCounted
## Full AI-vs-AI and fixed-seed stress regression.

const Harness := preload("res://tests/ai/ai_match_harness.gd")
const ScriptedRng := preload("res://tests/engine/scripted_rng.gd")
const HEROES: Array[StringName] = [
	HeroCatalog.KEZHARYN, HeroCatalog.VHORAZEL, HeroCatalog.SYRRAVETH, HeroCatalog.TAZHYRION,
]

var _check: Callable
var _cards: Node


func _init(check: Callable, _expect_errors: Callable, cards: Node) -> void:
	_check = check
	_cards = cards


func run() -> void:
	_test_ai_vs_ai_matrix()
	_test_stress_matches()


func _ok(condition: bool, description: String) -> void:
	_check.call(condition, description)


func _test_ai_vs_ai_matrix() -> void:
	var harness := Harness.new(_cards)
	var matches := 0
	var ended := 0
	var commands := 0
	var guard_count := 0
	var errors := PackedStringArray()
	var violations := PackedStringArray()
	var seen_first := {}
	for hero_index in HEROES.size():
		for difficulty: AiDifficulty.Level in AiDifficulty.Level.values():
			for forced_first in 2:
				var result := harness.play_match(
					HEROES[hero_index],
					HEROES[(hero_index + 1) % HEROES.size()],
					difficulty,
					difficulty,
					ScriptedRng.new([forced_first]))
				matches += 1
				ended += 1 if result["ended"] else 0
				commands += int(result["commands"])
				guard_count += int(result["guard_count"])
				seen_first[int(result["first_player"])] = true
				for error: String in result["errors"]:
					if errors.size() < 10:
						errors.append("h%d d%d f%d: %s" % [hero_index, difficulty, forced_first, error])
				for problem: String in result["invariant_violations"]:
					if violations.size() < 10:
						violations.append("h%d d%d f%d: %s" % [hero_index, difficulty, forced_first, problem])
	_ok(matches == 24 and ended == matches,
		"AI-vs-AI: all 4 heroes × 3 difficulties × both first-player cases ended (%d/%d, %d commands)" % [
			ended, matches, commands])
	_ok(errors.is_empty() and violations.is_empty(),
		"AI-vs-AI: no illegal command or invariant violation %s %s" % [errors, violations])
	_ok(seen_first.has(0) and seen_first.has(1), "AI-vs-AI: both first-player positions were exercised")
	_ok(guard_count == 0, "AI-vs-AI: normal matches never needed the per-turn safety guard")
	print("AI_QA_MATRIX matches=%d ended=%d commands=%d guards=%d first_players=%s" % [
		matches, ended, commands, guard_count, seen_first.keys()])


func _test_stress_matches() -> void:
	var harness := Harness.new(_cards)
	var matches := 0
	var ended := 0
	var commands := 0
	var guard_count := 0
	var errors := PackedStringArray()
	var violations := PackedStringArray()
	for index in 30:
		var result := harness.play_match(
			HEROES[index % HEROES.size()],
			HEROES[(index + 1 + index % 3) % HEROES.size()],
			AiDifficulty.Level.values()[index % AiDifficulty.Level.size()],
			AiDifficulty.Level.values()[(index + 1) % AiDifficulty.Level.size()],
			DeterministicRng.new(8000 + index))
		matches += 1
		ended += 1 if result["ended"] else 0
		commands += int(result["commands"])
		guard_count += int(result["guard_count"])
		for error: String in result["errors"]:
			if errors.size() < 10:
				errors.append("seed %d: %s" % [8000 + index, error])
		for problem: String in result["invariant_violations"]:
			if violations.size() < 10:
				violations.append("seed %d: %s" % [8000 + index, problem])
	_ok(ended == matches, "AI stress: every fixed-seed match ended (%d/%d, %d commands)" % [ended, matches, commands])
	_ok(errors.is_empty(), "AI stress: no MatchEngine command rejection or loop failure %s" % [errors])
	_ok(violations.is_empty(), "AI stress: public engine invariants hold after every AI command %s" % [violations])
	_ok(guard_count == 0, "AI stress: fixed-seed matches never exceeded MAX_AI_COMMANDS_PER_TURN")
	print("AI_QA_STRESS matches=%d ended=%d commands=%d guards=%d" % [
		matches, ended, commands, guard_count])
