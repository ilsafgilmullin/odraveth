extends RefCounted
## Stage 7 Result V1 and Library of Nulmeris.

const PresentationAudit := preload("res://tests/visual_qa/presentation_audit.gd")
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL

var _check: Callable
var _tree: SceneTree


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	CardDatabase.load_directory()
	await _test_result_outcomes()
	await _test_result_actions()
	await _test_library()
	await _test_settings_progress_shell()


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "result/library: " + label)


func _wait(route: StringName) -> bool:
	for _i in 120:
		await _tree.process_frame
		if SceneRouter.current_route == route and not SceneRouter.is_changing() and _tree.current_scene != null:
			return true
	return false


func _config() -> BattleLaunchConfig:
	var config := BattleLaunchConfig.create(K, BattleLaunchConfig.technical_opponent_deck(K, CardDatabase), V,
		BattleLaunchConfig.technical_opponent_deck(V, CardDatabase), AiDifficulty.Level.TACTICIAN, 4242,
		{PlayerSetupData.ANIMATIONS: false, PlayerSetupData.HINTS: true, PlayerSetupData.FORECAST: true})
	config.player_deck_name = "Колода Кежарина"
	return config


func _open_result(outcome: MatchOutcome.Result, config: BattleLaunchConfig) -> ResultScreen:
	SceneRouter.reset_to(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: outcome, BattleLaunchConfig.PARAM_KEY: config,
		"turns": 9, "cards_player": 6, "cards_ai": 5})
	await _wait(Routes.RESULT)
	return _tree.current_scene as ResultScreen


func _test_result_outcomes() -> void:
	for outcome: MatchOutcome.Result in MatchOutcome.Result.values():
		var screen := await _open_result(outcome, _config())
		_ok(screen != null and screen.message_label.text == MatchOutcome.title(outcome) and screen.message_label.uppercase,
			"%s headline is shown in capitals" % MatchOutcome.title(outcome))
		_ok(screen.find_child("PlayerSide", true, false) != null and screen.find_child("OpponentSide", true, false) != null
			and screen.find_child("Battlefield", true, false) is BattlefieldTheme and screen.find_child("Dim", true, false) != null,
			"%s: both sides over the dimmed battlefield" % MatchOutcome.title(outcome))
		_ok(not PresentationAudit.has_developer_words(screen), "%s: no developer words" % MatchOutcome.title(outcome))
	var screen := _tree.current_scene as ResultScreen
	var player := screen.find_child("PlayerSide", true, false) as Control
	var opponent := screen.find_child("OpponentSide", true, false) as Control
	_ok((player.find_child("SideDetail", true, false) as Label).text == "Колода Кежарина"
		and (opponent.find_child("SideDetail", true, false) as Label).text == "Сложность: Тактик"
		and screen.stats_label.text == "Ходов: 9\nСыграно карт:\n6 (вы) / 5 (ИИ)",
		"deck name, difficulty and authoritative stats only")
	for size: Vector2i in [Vector2i(1600, 900), Vector2i(2400, 1080), Vector2i(2800, 1752), Vector2i(1920, 1080)]:
		_tree.root.size = size
		await _tree.process_frame
		await _tree.process_frame
		var view := screen.get_viewport_rect().grow(1.0)
		var inside := true
		for button: Button in [screen.rematch_button, screen.opponent_button, screen.deck_button, screen.menu_button]:
			inside = inside and view.encloses(button.get_global_rect())
		inside = inside and view.encloses(player.get_global_rect()) and view.encloses(opponent.get_global_rect())
		_ok(inside, "%dx%d: result content stays in the viewport" % [size.x, size.y])


func _test_result_actions() -> void:
	var config := _config()
	var screen := await _open_result(MatchOutcome.Result.DEFEAT, config)
	screen.rematch_button.pressed.emit()
	var rematch := screen.last_config
	_ok(rematch != null and rematch.player_hero == K and rematch.opponent_hero == V and rematch.player_deck == config.player_deck
		and rematch.ai_difficulty == config.ai_difficulty and rematch.presentation_options == config.presentation_options
		and rematch.rng_seed != config.rng_seed and rematch.player_deck_name == config.player_deck_name,
		"ПОВТОРИТЬ БОЙ: same hero, exact deck, same enemy and settings, fresh seed")
	_ok(await _wait(Routes.BATTLE), "rematch opens Battle")
	screen = await _open_result(MatchOutcome.Result.VICTORY, config)
	screen.opponent_button.pressed.emit()
	var next := screen.last_config
	_ok(next != null and next.player_deck == config.player_deck and next.ai_difficulty == config.ai_difficulty
		and next.opponent_hero in PlayerSetupData.HERO_IDS, "НОВЫЙ СОПЕРНИК keeps the deck snapshot and draws a hero")
	_ok(await _wait(Routes.OPPONENT_SEARCH), "НОВЫЙ СОПЕРНИК opens the Citadel search")
	screen = await _open_result(MatchOutcome.Result.DRAW, config)
	_ok(screen.handle_back_request() and await _wait(Routes.MAIN_MENU), "Back from Result returns to Main Menu")


func _test_library() -> void:
	SceneRouter.reset_to(Routes.HISTORY)
	await _wait(Routes.HISTORY)
	var library := _tree.current_scene as HistoryShell
	_ok(library != null and (library.find_child("HistoryTitle", true, false) as Label).text == "КНИГА НУЛМЕРИСА"
		and library.section_buttons.size() == 8, "Library shows «КНИГА НУЛМЕРИСА» with eight sections")
	library.show_section("ГЕРОИ")
	var texts := PresentationAudit.visible_texts(library)
	var heroes_ok := true
	for hero_id: StringName in PlayerSetupData.HERO_IDS:
		heroes_ok = heroes_ok and ("%s · %s" % [String(HeroCatalog.HEROES[hero_id]["name_ru"]).to_upper(),
			HeroCatalog.HEROES[hero_id]["name_en"]]) in texts
	_ok(heroes_ok, "ГЕРОИ lists the four approved heroes")
	for section: String in ["ЦИТАДЕЛЬ НУЛМЕРИСА", "ЛИЧНОСТИ", "МЕСТА", "ХРОНИКИ", "АВТОРЫ"]:
		library.show_section(section)
		await _tree.process_frame
		_ok(library.find_child("SealedLabel", true, false) != null, "%s is a sealed page, not invented lore" % section)
	_ok(not PresentationAudit.has_developer_words(library), "Library has no developer words")
	_ok(library.handle_back_request() and await _wait(Routes.MAIN_MENU), "Back leaves the Library")


func _test_settings_progress_shell() -> void:
	SceneRouter.reset_to(Routes.SETTINGS)
	await _wait(Routes.SETTINGS)
	var settings := _tree.current_scene as CitadelShellScreen
	_ok(settings != null and settings.toggles.size() == 3, "Settings shows the three persisted battle switches")
	if settings != null:
		var animations := settings.toggles[PlayerSetupData.ANIMATIONS] as CheckButton
		var before := animations.button_pressed
		animations.button_pressed = not before
		_ok(bool(PlayerSetupData.normalized(AppState.profile)["prebattle"][PlayerSetupData.ANIMATIONS]) == (not before),
			"a Settings switch persists the same profile field as Prebattle")
		animations.button_pressed = before
		_ok(not PresentationAudit.has_developer_words(settings), "Settings has no developer words")
	SceneRouter.reset_to(Routes.PROGRESS)
	await _wait(Routes.PROGRESS)
	var progress := _tree.current_scene
	_ok(progress.find_child("SealedLabel", true, false) != null and not PresentationAudit.has_developer_words(progress),
		"Progress is a sealed shell: no XP, rewards or currency (Q-15 open)")
