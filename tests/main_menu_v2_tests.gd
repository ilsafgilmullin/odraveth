extends RefCounted
## Stage 7B Main Menu runtime/regression checks.

const VIEWPORTS := [
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2400, 1080),
]
const NAV_LABELS := [
	["PlayButton", "ВОЙТИ В НУЛМЕРИС"],
	["CollectionButton", "КОЛЛЕКЦИЯ"],
	["DecksButton", "КОЛОДЫ"],
	["HeroesButton", "ГЕРОИ"],
	["HistoryButton", "ИСТОРИЯ"],
	["ProgressButton", "ПРОГРЕСС"],
	["SettingsButton", "НАСТРОЙКИ"],
]
const ROUTE_TIMEOUT_FRAMES := 120

var check: Callable
var tree: SceneTree
var saved_profile: Dictionary
var saved_manager: SaveManager


func _init(check_fn: Callable, game_tree: SceneTree) -> void:
	check = check_fn
	tree = game_tree


func _ok(value: bool, description: String) -> void:
	check.call(value, "main menu V2: " + description)


func run() -> void:
	saved_profile = AppState.profile
	saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new("user://odraveth_smoke_test/main_menu_v2.json")
	CardDatabase.load_directory()

	await _test_responsive_composition()
	await _test_authoritative_status_and_routes()
	await _test_history_shell()
	await _test_reentry_stability()

	AppState.profile = saved_profile
	AppState._save_manager = saved_manager
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)


func _test_responsive_composition() -> void:
	for viewport_size: Vector2i in VIEWPORTS:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		tree.root.add_child(viewport)

		var packed := load(Routes.scene_path(Routes.MAIN_MENU)) as PackedScene
		var menu := packed.instantiate() as MainMenuV2 if packed != null else null
		_ok(menu != null, "%dx%d Main Menu instantiates" % [viewport_size.x, viewport_size.y])
		if menu == null:
			viewport.queue_free()
			await tree.process_frame
			continue
		viewport.add_child(menu)
		await tree.process_frame
		await tree.process_frame

		_ok(menu.theme != null and menu.theme.resource_path == UiKit.THEME_PATH,
			"%dx%d Stage 7A theme applied" % [viewport_size.x, viewport_size.y])
		_ok(menu.find_child("GuardianPlaceholder", true, false) is GuardianPlaceholder,
			"%dx%d Guardian production placeholder slot exists" % [viewport_size.x, viewport_size.y])
		_ok(menu.find_child("GuardianTerraceBackdrop", true, false) is MainMenuBackdrop,
			"%dx%d Guardian Terrace composition placeholder exists" % [viewport_size.x, viewport_size.y])

		var guardian := menu.guardian_region.get_global_rect()
		var right := menu.right_region.get_global_rect()
		_ok(guardian.end.x + 8.0 <= right.position.x,
			"%dx%d Guardian region does not overlap navigation" % [viewport_size.x, viewport_size.y])
		_ok(right.position.x >= 0.0 and right.end.x <= float(viewport_size.x) + 1.0
			and right.position.y >= 0.0 and right.end.y <= float(viewport_size.y) + 1.0,
			"%dx%d navigation region remains inside viewport" % [viewport_size.x, viewport_size.y])

		for entry: Array in NAV_LABELS:
			var button := menu.find_child(entry[0], true, false) as Button
			_ok(button != null and button.text == entry[1],
				"%dx%d exact label %s" % [viewport_size.x, viewport_size.y, entry[1]])
			if button == null:
				continue
			var font := button.get_theme_font("font")
			var font_size := button.get_theme_font_size("font_size")
			var text_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			_ok(button.size.y >= 64.0 and button.custom_minimum_size.y >= 64.0,
				"%dx%d %s keeps Android touch height" % [viewport_size.x, viewport_size.y, entry[0]])
			_ok(text_width <= button.size.x - 32.0,
				"%dx%d %s text fits without destructive clipping" % [viewport_size.x, viewport_size.y, entry[0]])

		_ok(menu.wordmark.get_theme_font_size("font_size") >= 62,
			"%dx%d wordmark remains readable" % [viewport_size.x, viewport_size.y])
		_ok(menu.status_panel.size.y >= 100.0
			and menu.hero_status.size.x > 0.0 and menu.deck_status.size.x > 0.0,
			"%dx%d tertiary setup status fits" % [viewport_size.x, viewport_size.y])

		viewport.queue_free()
		await tree.process_frame


func _test_authoritative_status_and_routes() -> void:
	var no_deck := PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	AppState.profile = no_deck
	SceneRouter.reset_to(Routes.MAIN_MENU)
	_ok(await _wait_for_route(Routes.MAIN_MENU), "route opens without selected deck")
	var menu := tree.current_scene as MainMenuV2
	_ok(menu != null and menu.enter_button.text == "ВОЙТИ В НУЛМЕРИС", "primary action text is exact")
	_ok(menu.hero_status.text.contains(String(HeroCatalog.HEROES[HeroCatalog.KEZHARYN]["name_ru"]))
		and menu.hero_status.text.contains(SetupUi.faction_name(HeroCatalog.faction_of(HeroCatalog.KEZHARYN))),
		"hero/faction status comes from actual selected hero")
	_ok(menu.deck_status.text == "Колода: не выбрана", "missing selected deck is concise")
	menu.enter_button.pressed.emit()
	_ok(await _wait_for_route(Routes.DECK_BUILDER), "without valid selected deck primary action opens Deck Builder")

	var ready_profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	var deck := UserDeck.create(HeroCatalog.KEZHARYN)
	deck.name = "Меню QA"
	for id: StringName in BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase):
		deck.card_ids.append(String(id))
	_ok(deck.is_ready(CardDatabase), "test fixture deck is validator-ready")
	ready_profile = PlayerSetupData.upsert(ready_profile, deck, CardDatabase)
	_ok(PlayerSetupData.selected_deck(ready_profile, CardDatabase) != null,
		"PlayerSetupData recognizes selected saved deck")
	AppState.profile = ready_profile

	SceneRouter.reset_to(Routes.MAIN_MENU)
	_ok(await _wait_for_route(Routes.MAIN_MENU), "route reopens with valid setup")
	menu = tree.current_scene as MainMenuV2
	_ok(menu.deck_status.text.contains(deck.name)
		and menu.deck_status.text.contains("%d/%d" % [GameRules.DECK_SIZE, GameRules.DECK_SIZE])
		and menu.deck_status.text.contains("ГОТОВА"),
		"deck status uses saved name/count and authoritative readiness")
	menu.enter_button.pressed.emit()
	_ok(await _wait_for_route(Routes.PREBATTLE), "valid selected saved deck opens Prebattle")
	var prebattle := tree.current_scene as PrebattleScreen
	_ok(prebattle != null and prebattle.route_params.is_empty(),
		"Main Menu enters normal Prebattle without technical battle config")
	_ok(prebattle.deck_name_label.text == deck.name and prebattle.deck_summary.text.contains("30/30")
		and not prebattle.find_button.disabled,
		"Prebattle receives the same selected saved deck")


func _test_history_shell() -> void:
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)
	var menu := tree.current_scene as MainMenuV2
	menu.history_button.pressed.emit()
	_ok(await _wait_for_route(Routes.HISTORY), "History navigation opens route-safe shell")
	var title := tree.current_scene.find_child("HistoryTitle", true, false) as Label
	_ok(title != null and title.text == "КНИГА НУЛМЕРИСА", "History shell is intentional and does not invent library content")
	SceneRouter.go_back()
	_ok(await _wait_for_route(Routes.MAIN_MENU), "History shell returns to Main Menu")


func _test_reentry_stability() -> void:
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)
	for cycle in 3:
		var menu := tree.current_scene as MainMenuV2
		_ok(menu.enter_button.pressed.get_connections().size() == 1,
			"cycle %d primary action has exactly one signal connection" % (cycle + 1))
		_ok(menu.collection_button.pressed.get_connections().size() == 1,
			"cycle %d navigation action has exactly one signal connection" % (cycle + 1))
		menu.collection_button.pressed.emit()
		_ok(await _wait_for_route(Routes.COLLECTION), "cycle %d opens Collection" % (cycle + 1))
		SceneRouter.go_back()
		_ok(await _wait_for_route(Routes.MAIN_MENU), "cycle %d returns to Main Menu" % (cycle + 1))
		var menu_roots := 0
		for child: Node in tree.root.get_children():
			if child.name == "MainMenu":
				menu_roots += 1
		_ok(menu_roots == 1, "cycle %d leaves one Main Menu root" % (cycle + 1))


func _wait_for_route(route_id: StringName) -> bool:
	for _frame in ROUTE_TIMEOUT_FRAMES:
		await tree.process_frame
		if SceneRouter.current_route == route_id and not SceneRouter.is_changing():
			return tree.current_scene != null and tree.current_scene.scene_file_path == Routes.scene_path(route_id)
	return false
