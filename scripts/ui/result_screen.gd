class_name ResultScreen
extends PlaceholderScreen
## Battle result screen: shows outcome, match stats, rematch and main menu.

const PARAM_OUTCOME := "outcome"


func _build_content() -> void:
	var outcome: Variant = route_params.get(PARAM_OUTCOME)
	if MatchOutcome.is_valid(outcome):
		set_message(MatchOutcome.title(outcome))
	else:
		push_warning("ResultScreen: missing or invalid '%s' param: %s." % [PARAM_OUTCOME, outcome])
		set_message("Результат неизвестен")

	var turns: int = int(route_params.get("turns", 0))
	if turns > 0:
		var cards_player: int = int(route_params.get("cards_player", 0))
		var cards_ai: int = int(route_params.get("cards_ai", 0))
		var stats_lbl := Label.new()
		stats_lbl.text = "Ходов: %d  |  Карт сыграно: %d (вы) / %d (ИИ)" % [turns, cards_player, cards_ai]
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var content := _actions.get_parent()
		content.add_child(stats_lbl)
		content.move_child(stats_lbl, _actions.get_index())

	var cfg: Variant = route_params.get(BattleLaunchConfig.PARAM_KEY)
	if cfg is BattleLaunchConfig:
		add_action("Реванш", _rematch, "RematchButton")
	add_action("В главное меню", SceneRouter.reset_to.bind(Routes.MAIN_MENU), "MainMenuButton")


func _rematch() -> void:
	var old_cfg: Variant = route_params.get(BattleLaunchConfig.PARAM_KEY)
	if not old_cfg is BattleLaunchConfig:
		return
	var prev := old_cfg as BattleLaunchConfig
	var new_cfg := BattleLaunchConfig.create(
		prev.player_hero, prev.player_deck,
		prev.opponent_hero, prev.opponent_deck,
		prev.ai_difficulty)
	SceneRouter.replace_with(Routes.BATTLE, {BattleLaunchConfig.PARAM_KEY: new_cfg})
