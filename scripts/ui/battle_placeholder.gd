extends PlaceholderScreen
## Battle screen placeholder. MatchEngine is not implemented yet (separate task);
## the buttons only simulate the three approved outcomes to check routing to the
## result screen.


func _build_content() -> void:
	for outcome: MatchOutcome.Result in MatchOutcome.Result.values():
		var key: String = MatchOutcome.Result.find_key(outcome)
		add_action(
			"Завершить бой: %s" % MatchOutcome.title(outcome),
			_finish_match.bind(outcome),
			"Finish%sButton" % key.capitalize())
	add_action("В главное меню", SceneRouter.reset_to.bind(Routes.MAIN_MENU), "MainMenuButton")


func _finish_match(outcome: MatchOutcome.Result) -> void:
	# The finished battle is replaced, so "back" from the result skips it.
	SceneRouter.replace_with(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: outcome})
