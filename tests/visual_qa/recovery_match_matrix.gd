extends SceneTree
## All ordered non-mirror faction pairs at all three existing AI levels.
## QA deck fixtures only: no product presets, rule or balance change.

const Harness := preload("res://tests/ai/ai_match_harness.gd")
const HEROES: Array[StringName] = [HeroCatalog.KEZHARYN, HeroCatalog.VHORAZEL, HeroCatalog.SYRRAVETH, HeroCatalog.TAZHYRION]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cards := load("res://scripts/cards/card_database.gd").new() as Node
	cards.load_directory()
	var harness := Harness.new(cards)
	var results: Array[Dictionary] = []
	var failed := 0
	for a in HEROES.size():
		for b in HEROES.size():
			if a == b:
				continue
			for difficulty: AiDifficulty.Level in AiDifficulty.Level.values():
				var seed_value := 14000 + a * 100 + b * 10 + int(difficulty)
				var result := harness.play_match(HEROES[a], HEROES[b], difficulty, difficulty, DeterministicRng.new(seed_value))
				var engine: MatchEngine = result["engine"]
				var event_counts: Dictionary = {}
				var played: Dictionary = {}
				for event: Dictionary in engine.state.events:
					var kind := String(event["type"])
					event_counts[kind] = int(event_counts.get(kind, 0)) + 1
					if event["type"] == MatchEvent.CARD_PLAYED:
						var id := String(event["card_id"])
						played[id] = int(played.get(id, 0)) + 1
				var ok: bool = result["ended"] and result["errors"].is_empty() \
					and result["invariant_violations"].is_empty() and result["guard_count"] == 0
				if not ok:
					failed += 1
				results.append({"hero_a": String(HEROES[a]), "hero_b": String(HEROES[b]),
					"difficulty": AiDifficulty.code(difficulty), "seed": seed_value, "passed": ok,
					"winner": result["winner"], "is_draw": result["is_draw"], "turns": result["turns"],
					"commands": result["commands"], "event_counts": event_counts, "played_cards": played,
					"errors": result["errors"], "invariant_violations": result["invariant_violations"]})
				print("MATCH_MATRIX %s/%s %s seed=%d passed=%s turns=%d" % [HEROES[a], HEROES[b],
					AiDifficulty.code(difficulty), seed_value, ok, result["turns"]])
	var destination := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			destination = argument.trim_prefix("--out=")
	if destination.is_empty():
		push_error("--out=<absolute JSON path> is required")
		cards.free()
		quit(2)
		return
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write match matrix")
		cards.free()
		quit(2)
		return
	file.store_string(JSON.stringify({"godot": Engine.get_version_info()["string"], "matches": results.size(),
		"failed": failed, "results": results}, "\t"))
	file.close()
	cards.free()
	print("RECOVERY MATCH MATRIX: %d/%d PASS" % [results.size() - failed, results.size()])
	quit(0 if failed == 0 and results.size() == 36 else 1)
