class_name AiChoicePolicy
extends RefCounted
## Scores only options already revealed by MatchEngine to the deciding player.


static func score(observation: Dictionary, command: MatchCommand, difficulty: AiDifficulty.Level) -> Dictionary:
	var option_id := int(command.choices.get(MatchCommand.CHOICE_OPTION, -1))
	var option := _find_option(observation["pending_choice"].get("options", []), option_id)
	var components: Dictionary = {}
	if option.is_empty():
		components["INVALID_CONTEXT"] = -100000
	else:
		var definition: Dictionary = option["definition"]
		components["CARD_ADVANTAGE"] = AiEvaluator.estimate_definition_value(definition, difficulty)
		var current_energy := int(observation["own"]["energy_current"])
		var cost := int(definition["cost"])
		if cost <= current_energy:
			components["CURVE"] = 8 if difficulty == AiDifficulty.Level.NOVICE else 18
		elif difficulty != AiDifficulty.Level.NOVICE:
			components["CURVE"] = -min(20, (cost - current_energy) * 4)
		if difficulty == AiDifficulty.Level.STRATEGIST:
			components["SYNERGY"] = AiEvaluator.synergy_with_hand(
				definition, observation["own"].get("hand", []), difficulty)
	var total := 0
	for value: Variant in components.values():
		total += int(value)
	return {"total": total, "components": components}


static func _find_option(options: Array, instance_id: int) -> Dictionary:
	for option: Dictionary in options:
		if int(option["instance_id"]) == instance_id:
			return option
	return {}
