extends RefCounted
## Stage 7C Hero Select V1 runtime/regression checks.

const VIEWPORTS := [
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2400, 1080),
]
const ROUTE_TIMEOUT_FRAMES := 120
const PresentationAudit := preload("res://tests/visual_qa/presentation_audit.gd")

var check: Callable
var tree: SceneTree
var saved_profile: Dictionary
var saved_manager: SaveManager


func _init(check_fn: Callable, game_tree: SceneTree) -> void:
	check = check_fn
	tree = game_tree


func _ok(value: bool, description: String) -> void:
	check.call(value, "hero select V1: " + description)


func run() -> void:
	saved_profile = AppState.profile
	saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new("user://odraveth_smoke_test/hero_select_v1.json")
	CardDatabase.load_directory()

	await _test_responsive_scene()
	await _test_preview_and_information()
	await _test_confirm_and_deck_invariant()
	await _test_back_without_commit()
	await _test_reentry_stability()

	AppState.profile = saved_profile
	AppState._save_manager = saved_manager
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)


func _test_responsive_scene() -> void:
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	for viewport_size: Vector2i in VIEWPORTS:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		tree.root.add_child(viewport)

		var packed := load(Routes.scene_path(Routes.HERO_SELECT)) as PackedScene
		var scene := packed.instantiate() as HeroSelectScreen if packed != null else null
		_ok(scene != null, "%dx%d scene instantiates" % [viewport_size.x, viewport_size.y])
		if scene == null:
			viewport.queue_free()
			await tree.process_frame
			continue
		viewport.add_child(scene)
		await tree.process_frame
		await tree.process_frame

		_ok(scene.theme != null and scene.theme.resource_path == UiKit.THEME_PATH,
			"%dx%d Stage 7A theme applied" % [viewport_size.x, viewport_size.y])
		_ok(scene.hero_buttons.size() == 4 and scene.hero_row.get_child_count() == 4,
			"%dx%d exactly four simultaneous hero panels" % [viewport_size.x, viewport_size.y])

		var previous_end := -1.0
		for i in PlayerSetupData.HERO_IDS.size():
			var hero: StringName = PlayerSetupData.HERO_IDS[i]
			var card := scene.hero_buttons[hero] as HeroSelectCard
			_ok(card != null and card.hero_id == hero,
				"%dx%d card %d preserves authoritative hero ID" % [viewport_size.x, viewport_size.y, i])
			if card == null:
				continue
			var hero_data: Dictionary = HeroCatalog.HEROES[hero]
			_ok(card.hero_name_label.text == String(hero_data["name_ru"]).to_upper(),
				"%dx%d %s Russian name from HeroCatalog" % [viewport_size.x, viewport_size.y, hero])
			_ok(card.faction_label.text == SetupUi.faction_name(HeroCatalog.faction_of(hero)).to_upper(),
				"%dx%d %s faction label authoritative" % [viewport_size.x, viewport_size.y, hero])
			_ok(card.portrait.hero_id == hero
				and card.portrait.faction == HeroCatalog.faction_of(hero),
				"%dx%d %s portrait resolves for the correct hero" % [viewport_size.x, viewport_size.y, hero])
			_ok(card.faction_symbol.kind == NulmerisEmblems.Kind.FACTION
				and card.faction_symbol.faction == HeroCatalog.faction_of(hero),
				"%dx%d %s shows its own faction symbol" % [viewport_size.x, viewport_size.y, hero])
			_ok(not _has_developer_words(card),
				"%dx%d %s exposes no developer placeholder words" % [viewport_size.x, viewport_size.y, hero])
			var rect := card.get_global_rect()
			_ok(rect.position.x >= 0.0 and rect.end.x <= float(viewport_size.x) + 1.0,
				"%dx%d %s card remains horizontally visible" % [viewport_size.x, viewport_size.y, hero])
			if previous_end >= 0.0:
				_ok(rect.position.x >= previous_end - 1.0,
					"%dx%d hero cards do not overlap" % [viewport_size.x, viewport_size.y])
			previous_end = rect.end.x
			_ok(card.size.y >= 260.0 and card.size.x >= 240.0,
				"%dx%d %s portrait panel remains usable" % [viewport_size.x, viewport_size.y, hero])

		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_ok(viewport_rect.encloses(scene.info_panel.get_global_rect()),
			"%dx%d lower information panel remains in viewport" % [viewport_size.x, viewport_size.y])
		_ok(viewport_rect.encloses(scene.confirm_button.get_global_rect())
			and scene.confirm_button.size.y >= 64.0,
			"%dx%d confirm remains accessible with Android touch height" % [viewport_size.x, viewport_size.y])
		_ok(scene.power_description_label.autowrap_mode != TextServer.AUTOWRAP_OFF
			and not scene.power_description_label.clip_text
			and scene.power_description_label.custom_minimum_size.y >= 84.0
			and scene.power_description_label.get_theme_font_size("font_size") >= 26,
			"%dx%d full power text uses semantic wrapping and reserved readable height" % [viewport_size.x, viewport_size.y])
		_ok(scene.hero_row.get_global_rect().end.y <= scene.info_panel.get_global_rect().position.y + 1.0,
			"%dx%d four-card row does not force info panel off-screen" % [viewport_size.x, viewport_size.y])

		viewport.queue_free()
		await tree.process_frame


func _test_preview_and_information() -> void:
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	var packed := load(Routes.scene_path(Routes.HERO_SELECT)) as PackedScene
	var scene := packed.instantiate() as HeroSelectScreen
	tree.root.add_child(scene)
	await tree.process_frame

	_ok(scene.pending_hero == HeroCatalog.KEZHARYN, "persisted hero opens as current preview")
	for hero: StringName in PlayerSetupData.HERO_IDS:
		var card := scene.hero_buttons[hero] as HeroSelectCard
		card.pressed.emit()
		await tree.process_frame
		var data: Dictionary = HeroCatalog.HEROES[hero]
		_ok(scene.pending_hero == hero, "%s tap updates pending preview" % hero)
		_ok(scene.hero_name_label.text == String(data["name_ru"]).to_upper()
			and scene.faction_label.text == SetupUi.faction_name(HeroCatalog.faction_of(hero)).to_upper(),
			"%s info panel updates identity and faction" % hero)
		_ok(scene.power_name_label.text == String(data["power_ru"]).to_upper(),
			"%s power name comes from HeroCatalog" % hero)
		_ok(scene.power_cost_label.text.contains(str(GameRules.HERO_ABILITY_COST)),
			"%s power cost comes from GameRules" % hero)
		_ok(scene.power_description_label.text == HeroPresentation.power_description(hero)
			and scene.power_description_label.text.length() >= 40,
			"%s full hero power description is present" % hero)
		_ok(scene.playstyle_label.text == HeroPresentation.playstyle(hero)
			and not scene.playstyle_label.text.is_empty(),
			"%s approved playstyle summary shown" % hero)

		var selected_count := 0
		for other: StringName in PlayerSetupData.HERO_IDS:
			var other_card := scene.hero_buttons[other] as HeroSelectCard
			if other_card.selected_marker.visible:
				selected_count += 1
		_ok(selected_count == 1 and card.selected_marker.visible and card.button_pressed,
			"%s has one explicit selected marker" % hero)
		_ok(card.scale.x > 1.0
			and card.get_theme_stylebox("pressed").get_border_width(SIDE_LEFT) >
				card.get_theme_stylebox("normal").get_border_width(SIDE_LEFT),
			"%s selected state changes geometry and frame, not hue only" % hero)

	var syrraveth := scene.hero_buttons[HeroCatalog.SYRRAVETH] as HeroSelectCard
	_ok(HeroPresentation.presentation_gender(HeroCatalog.SYRRAVETH) == "female"
		and syrraveth.portrait.presentation_gender == "female",
		"Syrraveth presentation contract is explicitly female")
	_ok(not scene.confirm_button.disabled and scene.confirm_button.text == "ПОДТВЕРДИТЬ",
		"valid preview exposes explicit confirmation")
	scene.queue_free()
	await tree.process_frame


func _test_confirm_and_deck_invariant() -> void:
	var profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	var kezharin_deck := _ready_deck(HeroCatalog.KEZHARYN, "Кежарин QA")
	var syrraveth_deck := _ready_deck(HeroCatalog.SYRRAVETH, "Сирравет QA")
	profile = PlayerSetupData.upsert(profile, kezharin_deck, CardDatabase)
	profile = PlayerSetupData.upsert(profile, syrraveth_deck, CardDatabase)
	_ok(profile["selected_deck_id"] == kezharin_deck.id and profile["user_decks"].size() == 2,
		"fixture starts with selected Kezharyn deck and two stored decks")
	AppState.profile = profile

	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)
	SceneRouter.go_to(Routes.HERO_SELECT)
	_ok(await _wait_for_route(Routes.HERO_SELECT), "Hero Select opens from Main Menu")
	var scene := tree.current_scene as HeroSelectScreen
	(scene.hero_buttons[HeroCatalog.SYRRAVETH] as HeroSelectCard).pressed.emit()
	_ok(AppState.profile["selected_hero_id"] == String(HeroCatalog.KEZHARYN)
		and AppState.profile["selected_deck_id"] == kezharin_deck.id,
		"tap is preview-only and does not mutate persisted hero/deck")
	scene.confirm_button.pressed.emit()
	_ok(await _wait_for_route(Routes.MAIN_MENU), "confirm returns to previous screen")
	_ok(AppState.profile["selected_hero_id"] == String(HeroCatalog.SYRRAVETH)
		and AppState.profile["selected_deck_id"] == "",
		"confirm changes hero and clears incompatible selected deck")
	_ok(AppState.profile["user_decks"].size() == 2
		and PlayerSetupData.decks_for(AppState.profile, HeroCatalog.KEZHARYN).any(
			func(deck: UserDeck) -> bool: return deck.id == kezharin_deck.id)
		and PlayerSetupData.decks_for(AppState.profile, HeroCatalog.SYRRAVETH).any(
			func(deck: UserDeck) -> bool: return deck.id == syrraveth_deck.id),
		"hero change preserves stored decks for both heroes")

	SceneRouter.go_to(Routes.HERO_SELECT)
	await _wait_for_route(Routes.HERO_SELECT)
	scene = tree.current_scene as HeroSelectScreen
	(scene.hero_buttons[HeroCatalog.KEZHARYN] as HeroSelectCard).pressed.emit()
	scene.confirm_button.pressed.emit()
	await _wait_for_route(Routes.MAIN_MENU)
	_ok(AppState.profile["selected_hero_id"] == String(HeroCatalog.KEZHARYN)
		and AppState.profile["selected_deck_id"] == ""
		and PlayerSetupData.decks_for(AppState.profile, HeroCatalog.KEZHARYN).size() == 1,
		"switching back preserves old deck but does not silently reactivate it")


func _test_back_without_commit() -> void:
	var original := PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	AppState.profile = original
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)

	SceneRouter.go_to(Routes.HERO_SELECT)
	await _wait_for_route(Routes.HERO_SELECT)
	var scene := tree.current_scene as HeroSelectScreen
	(scene.hero_buttons[HeroCatalog.VHORAZEL] as HeroSelectCard).pressed.emit()
	scene.back_button.pressed.emit()
	_ok(await _wait_for_route(Routes.MAIN_MENU)
		and AppState.profile["selected_hero_id"] == String(HeroCatalog.KEZHARYN),
		"UI Back discards unconfirmed preview")

	SceneRouter.go_to(Routes.HERO_SELECT)
	await _wait_for_route(Routes.HERO_SELECT)
	scene = tree.current_scene as HeroSelectScreen
	(scene.hero_buttons[HeroCatalog.TAZHYRION] as HeroSelectCard).pressed.emit()
	tree.root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(await _wait_for_route(Routes.MAIN_MENU)
		and AppState.profile["selected_hero_id"] == String(HeroCatalog.KEZHARYN),
		"system Back discards unconfirmed preview")


func _test_reentry_stability() -> void:
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)
	for cycle in 3:
		SceneRouter.go_to(Routes.HERO_SELECT)
		_ok(await _wait_for_route(Routes.HERO_SELECT), "cycle %d opens Hero Select" % (cycle + 1))
		var scene := tree.current_scene as HeroSelectScreen
		_ok(scene.hero_buttons.size() == 4 and scene.hero_row.get_child_count() == 4,
			"cycle %d contains one set of four hero cards" % (cycle + 1))
		_ok(scene.confirm_button.pressed.get_connections().size() == 1
			and scene.back_button.pressed.get_connections().size() == 1,
			"cycle %d screen actions have one signal connection each" % (cycle + 1))
		for hero: StringName in PlayerSetupData.HERO_IDS:
			_ok((scene.hero_buttons[hero] as HeroSelectCard).pressed.get_connections().size() == 1,
				"cycle %d %s card has one signal connection" % [cycle + 1, hero])
		scene.back_button.pressed.emit()
		_ok(await _wait_for_route(Routes.MAIN_MENU), "cycle %d returns to Main Menu" % (cycle + 1))
		var hero_select_roots := 0
		for child: Node in tree.root.get_children():
			if child.name == "HeroSelect":
				hero_select_roots += 1
		_ok(hero_select_roots == 0, "cycle %d leaves no stale Hero Select root" % (cycle + 1))


func _has_developer_words(root: Node) -> bool:
	return PresentationAudit.has_developer_words(root)


func _ready_deck(hero: StringName, deck_name: String) -> UserDeck:
	var deck := UserDeck.create(hero)
	deck.name = deck_name
	for id: StringName in BattleLaunchConfig.technical_opponent_deck(hero, CardDatabase):
		deck.card_ids.append(String(id))
	_ok(deck.is_ready(CardDatabase), "%s fixture is DeckValidator-ready" % hero)
	return deck


func _wait_for_route(route_id: StringName) -> bool:
	for _frame in ROUTE_TIMEOUT_FRAMES:
		await tree.process_frame
		if SceneRouter.current_route == route_id and not SceneRouter.is_changing():
			return tree.current_scene != null and tree.current_scene.scene_file_path == Routes.scene_path(route_id)
	return false
