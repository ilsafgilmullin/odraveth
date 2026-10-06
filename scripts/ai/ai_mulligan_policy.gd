class_name AiMulliganPolicy
extends RefCounted
## Deterministic mulligan scoring. Replacement results are never inspected.


static func score(observation: Dictionary, command: MatchCommand, difficulty: AiDifficulty.Level) -> Dictionary:
	var kept: Array = []
	for card: Dictionary in observation["own"].get("hand", []):
		if int(card["instance_id"]) not in command.replace_ids:
			kept.append(card)
	var components: Dictionary = {}
	var curve := 0
	var definitions: Array = []
	for card: Dictionary in kept:
		var definition: Dictionary = card["definition"]
		definitions.append(definition)
		var cost := int(definition["cost"])
		match difficulty:
			AiDifficulty.Level.NOVICE:
				curve += 28 if cost <= 3 else -12 * (cost - 3)
			AiDifficulty.Level.TACTICIAN:
				curve += _curve_value(cost, false)
				curve += AiEvaluator.estimate_definition_value(definition, difficulty) / 8
			AiDifficulty.Level.STRATEGIST:
				curve += _curve_value(cost, true)
				curve += AiEvaluator.estimate_definition_value(definition, difficulty) / 7
	components["CURVE"] = curve
	if difficulty == AiDifficulty.Level.STRATEGIST:
		components["SYNERGY"] = AiEvaluator.synergy_score(definitions, difficulty)
	components["MULLIGAN_SIZE"] = -command.replace_ids.size()
	var total := 0
	for value: Variant in components.values():
		total += int(value)
	return {"total": total, "components": components}


static func _curve_value(cost: int, strategist: bool) -> int:
	match cost:
		0, 1:
			return 55
		2:
			return 50
		3:
			return 36
		4:
			return 12 if strategist else 8
		5:
			return -25
		_:
			return -45
