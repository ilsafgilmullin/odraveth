class_name AiTurnRunner
extends RefCounted
## Executes one AI mulligan decision or one complete AI turn exclusively through
## MatchEngine public query/command APIs.

const MAX_AI_COMMANDS_PER_TURN := 64

var controller: AiController
var max_commands_per_turn := MAX_AI_COMMANDS_PER_TURN


func _init(ai_controller: AiController, command_limit: int = MAX_AI_COMMANDS_PER_TURN) -> void:
	controller = ai_controller
	max_commands_per_turn = maxi(1, command_limit)


func run(engine: MatchEngine, player: int, include_ranked_trace: bool = false,
		after_command: Callable = Callable()) -> Dictionary:
	var trace := {
		"player": player,
		"difficulty": AiDifficulty.code(controller.difficulty),
		"decisions": [],
		"commands_executed": 0,
		"guard_triggered": false,
		"error": "",
	}
	while int(trace["commands_executed"]) < max_commands_per_turn:
		var observation := engine.get_observation(player)
		if observation.is_empty() or observation["match_over"]:
			break
		if observation["phase"] == "MULLIGAN":
			if observation["own"]["mulligan_done"]:
				break
		elif observation["phase"] == "TURN":
			if observation["pending_choice"].is_empty() and int(observation["active_player"]) != player:
				break
		else:
			break

		var legal := engine.get_legal_commands(player)
		if legal.is_empty():
			break
		var decision := controller.decide(observation, legal)
		if decision.selected_command == null:
			trace["error"] = "AI returned no command while legal commands exist"
			break
		if not _contains_command(legal, decision.selected_command):
			trace["error"] = "AI selected a command outside the legal command set"
			break
		if not engine.validate(decision.selected_command).ok:
			trace["error"] = "AI selected a command rejected by MatchEngine.validate"
			break

		var selected_kind := decision.selected_command.kind
		var result := engine.execute(decision.selected_command)
		if not result.ok:
			trace["error"] = "MatchEngine rejected selected AI command: %s" % result.error
			break
		(trace["decisions"] as Array).append(decision.to_dictionary(include_ranked_trace))
		trace["commands_executed"] = int(trace["commands_executed"]) + 1
		if after_command.is_valid():
			after_command.call(engine.get_observation(player))
		if selected_kind == MatchCommand.Kind.MULLIGAN or selected_kind == MatchCommand.Kind.END_TURN:
			break

	if int(trace["commands_executed"]) >= max_commands_per_turn:
		var observation := engine.get_observation(player)
		if not observation.is_empty() and not observation["match_over"] and observation["phase"] == "TURN" 				and observation["pending_choice"].is_empty() and int(observation["active_player"]) == player:
			trace["guard_triggered"] = true
			var legal := engine.get_legal_commands(player)
			var end_turn := _find_end_turn(legal)
			if end_turn != null and engine.validate(end_turn).ok:
				var result := engine.execute(end_turn)
				if result.ok:
					trace["commands_executed"] = int(trace["commands_executed"]) + 1
					(trace["decisions"] as Array).append({
						"guard": true,
						"selected_command": end_turn.to_dictionary(),
					})
					if after_command.is_valid():
						after_command.call(engine.get_observation(player))
				else:
					trace["error"] = "safety END_TURN failed: %s" % result.error
	return trace


static func _contains_command(commands: Array[MatchCommand], selected: MatchCommand) -> bool:
	var key := AiController.canonical_command_key(selected)
	return commands.any(func(command: MatchCommand) -> bool:
		return AiController.canonical_command_key(command) == key)


static func _find_end_turn(commands: Array[MatchCommand]) -> MatchCommand:
	for command in commands:
		if command.kind == MatchCommand.Kind.END_TURN:
			return command
	return null
