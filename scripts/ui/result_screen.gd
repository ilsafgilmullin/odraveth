class_name ResultScreen
extends PlaceholderScreen
## Battle result placeholder: shows one of the three approved outcomes
## (Победа / Поражение / Ничья) passed in the route params.

const PARAM_OUTCOME := "outcome"


func _build_content() -> void:
	var outcome: Variant = route_params.get(PARAM_OUTCOME)
	if MatchOutcome.is_valid(outcome):
		set_message(MatchOutcome.title(outcome))
	else:
		push_warning("ResultScreen: missing or invalid '%s' param: %s." % [PARAM_OUTCOME, outcome])
		set_message("Результат неизвестен")
	add_action("В главное меню", SceneRouter.reset_to.bind(Routes.MAIN_MENU), "MainMenuButton")
