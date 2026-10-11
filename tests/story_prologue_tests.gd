extends RefCounted
## First narrative slice: Library entry, canonical page sequence and setup handoff.

const PresentationAudit := preload("res://tests/visual_qa/presentation_audit.gd")
const VIEWPORTS: Array[Vector2i] = [
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2400, 1080),
	Vector2i(2800, 1752),
]

var _check: Callable
var _tree: SceneTree
var _saved_profile: Dictionary


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	_saved_profile = AppState.profile
	CardDatabase.load_directory()
	await _test_library_entry_and_pages()
	await _test_responsive_layout()
	await _test_setup_handoff()
	AppState.profile = _saved_profile
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait(Routes.MAIN_MENU)


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "story prologue: " + label)


func _wait(route: StringName) -> bool:
	for _i in 120:
		await _tree.process_frame
		if SceneRouter.current_route == route and not SceneRouter.is_changing() and _tree.current_scene != null:
			return true
	return false


func _open_story(page: int = 0) -> StoryPrologueScreen:
	SceneRouter.reset_to(Routes.STORY_PROLOGUE, {"page": page})
	await _wait(Routes.STORY_PROLOGUE)
	return _tree.current_scene as StoryPrologueScreen


func _test_library_entry_and_pages() -> void:
	SceneRouter.reset_to(Routes.HISTORY)
	await _wait(Routes.HISTORY)
	var library := _tree.current_scene as HistoryShell
	library.show_section("ХРОНИКИ")
	await _tree.process_frame
	_ok(library.prologue_button != null and library.prologue_button.text == "ПРОЧИТАТЬ ПРОЛОГ",
		"Chronicles contains the explicit prologue entry")
	library.prologue_button.pressed.emit()
	_ok(await _wait(Routes.STORY_PROLOGUE), "Library entry opens the narrative route")
	var story := _tree.current_scene as StoryPrologueScreen
	_ok(story != null and story.title_label.text == "СТРАНИЦА БЕЗ ИМЕНИ"
		and story.body_label.text.contains("Четыре исхода противоречат друг другу")
		and story.page_label.text == "СТРАНИЦА 1 ИЗ 3", "first page presents the contradictory victories")
	story.next_button.pressed.emit()
	_ok(story.current_page == 1 and story.title_label.text == "ПАМЯТЬ СТЁРТОГО"
		and not story.body_label.text.contains("Одравет"), "second page preserves the delayed identity reveal")
	story.next_button.pressed.emit()
	_ok(story.current_page == 2 and story.title_label.text == "ЦИТАДЕЛЬ НУЛМЕРИСА"
		and story.next_button.text == "ВОЙТИ В ЦИТАДЕЛЬ", "third page leads into the existing setup flow")
	_ok(story.handle_back_request() and story.current_page == 1 and SceneRouter.current_route == Routes.STORY_PROLOGUE,
		"Android Back moves to the previous page before leaving")
	_ok(not PresentationAudit.has_developer_words(story), "player-facing pages contain no developer vocabulary")


func _test_responsive_layout() -> void:
	var original_size := _tree.root.size
	var story := await _open_story(2)
	for size: Vector2i in VIEWPORTS:
		_tree.root.size = size
		await _tree.process_frame
		await _tree.process_frame
		var viewport := story.get_viewport_rect().grow(1.0)
		var controls: Array[Control] = [
			story.story_panel,
			story.find_child("BackButton", true, false) as Control,
			story.find_child("LibraryButton", true, false) as Control,
			story.previous_button,
			story.next_button,
		]
		var inside := true
		for control: Control in controls:
			inside = inside and control != null and viewport.encloses(control.get_global_rect())
		_ok(inside, "%dx%d keeps the complete story interface inside the viewport" % [size.x, size.y])
		_ok(story.previous_button.size.y >= 64.0 and story.next_button.size.y >= 64.0,
			"%dx%d keeps navigation touch targets" % [size.x, size.y])
		_ok(story.page_label.get_line_count() == 1,
			"%dx%d keeps the page indicator on one line" % [size.x, size.y])
		_ok(story.body_label.get_visible_line_count() >= 4,
			"%dx%d keeps the canonical body readable" % [size.x, size.y])
	_tree.root.size = original_size
	await _tree.process_frame


func _test_setup_handoff() -> void:
	AppState.profile = SaveManager.create_default_data()
	var story := await _open_story(2)
	story.next_button.pressed.emit()
	_ok(await _wait(Routes.HERO_SELECT), "no selected hero routes to Hero Select")

	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	story = await _open_story(2)
	story.next_button.pressed.emit()
	_ok(await _wait(Routes.DECK_BUILDER), "selected hero without a ready deck routes to Deck Builder")

	var ready := PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	var deck := UserDeck.create(HeroCatalog.KEZHARYN)
	deck.name = "Колода Кежарина"
	for card_id: StringName in BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase):
		deck.card_ids.append(String(card_id))
	AppState.profile = PlayerSetupData.upsert(ready, deck, CardDatabase)
	story = await _open_story(2)
	story.next_button.pressed.emit()
	_ok(await _wait(Routes.PREBATTLE), "ready hero and deck route to ordinary Prebattle")
	_ok(SceneRouter._current_params.is_empty(), "handoff adds no hidden battle or modifier parameters")
