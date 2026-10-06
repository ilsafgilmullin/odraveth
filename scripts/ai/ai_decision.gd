class_name AiDecision
extends RefCounted
## Explainable result of one AI decision. Ranked candidates contain public
## command data and score components only.

@warning_ignore("enum_variable_without_default")
var difficulty: AiDifficulty.Level
var selected_command: MatchCommand = null
var selected_score := -2147483648
var score_components: Dictionary = {}
var candidate_count := 0
var ranked_candidates: Array[Dictionary] = []


func to_dictionary(include_ranked: bool = false) -> Dictionary:
	var data := {
		"difficulty": AiDifficulty.code(difficulty),
		"selected_command": selected_command.to_dictionary() if selected_command != null else {},
		"selected_score": selected_score,
		"score_components": score_components.duplicate(true),
		"candidate_count": candidate_count,
	}
	if include_ranked:
		data["ranked_candidates"] = ranked_candidates.duplicate(true)
	return data
