class_name AiController
extends RefCounted
## Pure decision maker: observation + legal commands -> deterministic decision.

var difficulty: AiDifficulty.Level


func _init(level: AiDifficulty.Level) -> void:
	difficulty = level


func decide(observation: Dictionary, legal_commands: Array[MatchCommand]) -> AiDecision:
	var decision := AiDecision.new()
	decision.difficulty = difficulty
	decision.candidate_count = legal_commands.size()
	if legal_commands.is_empty():
		return decision
	var ranked: Array[Dictionary] = []
	for command in legal_commands:
		var scored := _score(observation, command, legal_commands)
		ranked.append({
			"command_object": command,
			"command": command.to_dictionary(),
			"total": int(scored["total"]),
			"components": scored["components"].duplicate(true),
			"key": canonical_command_key(command),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["total"]) != int(b["total"]):
			return int(a["total"]) > int(b["total"])
		return String(a["key"]) < String(b["key"]))
	var best: Dictionary = ranked[0]
	decision.selected_command = best["command_object"]
	decision.selected_score = int(best["total"])
	decision.score_components = best["components"].duplicate(true)
	for entry: Dictionary in ranked:
		decision.ranked_candidates.append({
			"command": entry["command"].duplicate(true),
			"total": int(entry["total"]),
			"components": entry["components"].duplicate(true),
			"key": String(entry["key"]),
		})
	return decision


static func canonical_command_key(command: MatchCommand) -> String:
	var replacements := command.replace_ids.duplicate()
	replacements.sort()
	var choice_keys := command.choices.keys()
	choice_keys.sort()
	var replace_parts := PackedStringArray()
	for id: int in replacements:
		replace_parts.append(str(id))
	var choice_parts := PackedStringArray()
	for key: Variant in choice_keys:
		choice_parts.append("%s=%s" % [String(key), str(command.choices[key])])
	return "%02d|%010d|%010d|%s|%s" % [
		command.kind, command.source_id, command.target_id,
		",".join(replace_parts), ";".join(choice_parts),
	]


func _score(observation: Dictionary, command: MatchCommand,
		legal_commands: Array[MatchCommand]) -> Dictionary:
	if command.kind == MatchCommand.Kind.MULLIGAN:
		return AiMulliganPolicy.score(observation, command, difficulty)
	if command.kind == MatchCommand.Kind.CHOOSE:
		return AiChoicePolicy.score(observation, command, difficulty)
	return AiEvaluator.score_command(observation, command, legal_commands, difficulty)
