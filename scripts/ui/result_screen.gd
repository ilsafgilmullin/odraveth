class_name ResultScreen
extends PlaceholderScreen
## Battle result and technical Stage 4 return routes.

const PARAM_OUTCOME := "outcome"


func _build_content() -> void:
	var outcome: Variant = route_params.get(PARAM_OUTCOME)
	if MatchOutcome.is_valid(outcome):
		set_message(MatchOutcome.title(outcome))
	else:
		push_warning("ResultScreen: missing or invalid '%s' param: %s." % [PARAM_OUTCOME, outcome])
		set_message("Результат неизвестен")

	var turns: int = int(route_params.get("turns", 0))
	var cfg: Variant = route_params.get(BattleLaunchConfig.PARAM_KEY)
	if cfg is BattleLaunchConfig:
		var current := cfg as BattleLaunchConfig
		var stats_lbl := Label.new()
		stats_lbl.name = "ResultStats"
		stats_lbl.text = "Вы: %s  |  Противник: %s  |  ИИ: %s\nХодов: %d  |  Карт сыграно: %d (вы) / %d (ИИ)" % [
			_hero_name(current.player_hero), _hero_name(current.opponent_hero),
			AiDifficulty.name_ru(current.ai_difficulty), turns,
			int(route_params.get("cards_player", 0)), int(route_params.get("cards_ai", 0))]
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var content := _actions.get_parent()
		content.add_child(stats_lbl)
		content.move_child(stats_lbl, _actions.get_index())
	if cfg is BattleLaunchConfig:
		add_action("ПОВТОРИТЬ БОЙ", _rematch, "RematchButton")
	add_action("ВЫБОР ПРОТИВНИКА", SceneRouter.replace_with.bind(Routes.PREBATTLE), "OpponentButton")
	add_action("СМЕНИТЬ КОЛОДУ", SceneRouter.replace_with.bind(Routes.DECK_BUILDER), "DeckButton")
	add_action("ГЛАВНОЕ МЕНЮ", SceneRouter.reset_to.bind(Routes.MAIN_MENU), "MainMenuButton")


func _hero_name(hero_id: StringName) -> String:
	var hero: Dictionary = HeroCatalog.HEROES.get(hero_id, {})
	return hero.get("name_ru", String(hero_id))


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
