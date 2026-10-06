extends Node
## Headless smoke test of the Stage 0 foundation.
##
## Run (after a one-time import, see docs/DEVELOPMENT.md or tests/run_tests.sh):
##   godot --headless --path . --scene res://tests/smoke_test.tscn
## Exit code 0 = all checks passed, 1 = at least one check failed.
##
## Card tests live in tests/card_database_tests.gd; their fixtures are fictional
## "test_" cards written only to user://, never to res://data.
## Every engine error or warning is captured: those logged inside an
## _expect_errors(true) ... _expect_errors(false) block belong to negative checks
## and are printed but allowed; any other one fails the run.

const CardDatabaseTests := preload("res://tests/card_database_tests.gd")
const CardDatabaseScript := preload("res://scripts/cards/card_database.gd")
const BattleUiTests := preload("res://tests/battle_ui_tests.gd")
const PlayerSetupTests := preload("res://tests/player_setup_tests.gd")
const PlayerSetupUiTests := preload("res://tests/player_setup_ui_tests.gd")
const ENGINE_TEST_MODULES := [
	["MatchEngine core rules", preload("res://tests/engine/engine_core_tests.gd")],
	["Hero abilities", preload("res://tests/engine/hero_power_tests.gd")],
	["Keywords, durations, static abilities, timing", preload("res://tests/engine/keyword_tests.gd")],
	["Behaviour of the 40 approved cards", preload("res://tests/engine/card_behavior_tests.gd")],
	["Determinism, replay and fuzz matches", preload("res://tests/engine/determinism_tests.gd")],
	["AI observation, policies and deterministic turns", preload("res://tests/ai/ai_tests.gd")],
	["AI vs AI and stress matches", preload("res://tests/ai/ai_stress_tests.gd")],
	["Battle session and UI integration", preload("res://tests/battle_session_tests.gd")],
]
const EXPECTED_AUTOLOADS: Array[String] = ["EventBus", "SceneRouter", "AppState", "CardDatabase"]
const MAIN_MENU_BUTTONS := [
	["PlayButton", "Играть", Routes.DECK_BUILDER],
	["CollectionButton", "Коллекция", Routes.COLLECTION],
	["DecksButton", "Колоды", Routes.DECK_BUILDER],
	["HeroesButton", "Герои", Routes.HERO_SELECT],
	["ProgressButton", "Прогресс", Routes.PROGRESS],
	["SettingsButton", "Настройки", Routes.SETTINGS],
]
const ROUTE_TIMEOUT_FRAMES := 120
const WATCHDOG_SECONDS := 60.0
const TEMP_DIR := "user://odraveth_smoke_test"

var _check_count := 0
var _failures: PackedStringArray = []
var _route_log: Array[StringName] = []
var _engine_log := EngineErrorLog.new()


## Collects engine errors and warnings (including push_error/push_warning).
class EngineErrorLog extends Logger:
	var expecting := false
	var expected_count := 0
	var unexpected: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		if expecting:
			expected_count += 1
		else:
			unexpected.append("%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file, line])
		_mutex.unlock()


class MigratingSaveManager extends SaveManager:
	func _migrate_from_v1(data: Dictionary) -> Dictionary:
		data["migrated_field"] = true
		return data


func _ready() -> void:
	OS.add_logger(_engine_log)
	# Give up the "current scene" slot so SceneRouter can swap screens without
	# freeing this runner.
	get_tree().current_scene = null
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog_timeout)
	_run.call_deferred()


func _run() -> void:
	print("== ODRAVETH smoke test ==")
	_test_engine_version()
	_test_project_settings()
	_test_android_export_config()
	_test_autoloads()
	_test_scripts_compile()
	_test_scenes_instantiate()
	_test_routes()
	_test_game_rules()
	_test_cyrillic_font()
	_test_save_manager()
	_test_card_database()
	_section("Player setup data and persistence")
	PlayerSetupTests.new(_check, CardDatabaseScript.new()).run()
	_test_match_engine()
	_section("BattleScene interactive integration")
	var ui_cards: Node = CardDatabaseScript.new()
	ui_cards.load_directory()
	await BattleUiTests.new(_check, _expect_errors, ui_cards, get_tree()).run()
	ui_cards.free()
	_section("Stage 5 interactive setup screens and responsive layout")
	await PlayerSetupUiTests.new(_check, get_tree()).run()
	await _test_navigation()
	_remove_temp_dir()
	_test_no_unexpected_engine_errors()
	_finish()


# --- Checks ---------------------------------------------------------------

func _test_engine_version() -> void:
	_section("engine version")
	var info := Engine.get_version_info()
	_check(info.major == 4 and info.minor == 7 and info.patch == 2 and info.status == "stable",
		"Godot 4.7.2 stable (running %s)" % info.string)


func _test_project_settings() -> void:
	_section("project settings")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(main_scene == Routes.scene_path(Routes.BOOT), "main scene is Boot")
	_check(ResourceLoader.exists(main_scene), "main scene file exists")
	_check(ResourceLoader.exists(ProjectSettings.get_setting("application/config/icon")),
		"technical QA launcher icon exists")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920
		and ProjectSettings.get_setting("display/window/size/viewport_height") == 1080,
		"design resolution 1920x1080")
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "stretch mode canvas_items")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "stretch aspect expand")
	_check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR_LANDSCAPE,
		"orientation sensor landscape (landscape only)")
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back") == false,
		"Android back is handled by SceneRouter")
	_check(PackedStringArray(ProjectSettings.get_setting("application/config/features")).has("4.7"),
		"project features target 4.7")
	_check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc") == true,
		"Android ETC2/ASTC texture import enabled")


func _test_android_export_config() -> void:
	_section("Android export configuration")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(not preset.is_empty() and preset.contains("platform=\"Android\""),
		"Android QA export preset exists")
	_check(preset.contains("package/unique_name=\"com.example.odraveth.qa\"")
		and preset.contains("version/name=\"0.6.0-qa\""),
		"temporary QA package and version are explicit")
	_check(preset.contains("screen/immersive_mode=true") and preset.contains("screen/edge_to_edge=true"),
		"Android fullscreen edge-to-edge enabled")
	_check(preset.contains("exclude_filter=\"tests/**,docs/**,.github/**\""),
		"tests, docs and CI files excluded from APK")
	_check(preset.contains("permissions/custom_permissions=PackedStringArray()")
		and not preset.to_lower().contains("permissions/internet=true"),
		"Android preset requests no custom or Internet permission")
	_check(not preset.contains("keystore/") and not preset.contains("/tmp/") and not preset.contains("Android/Sdk"),
		"export preset contains no signing secret or local SDK path")


func _test_autoloads() -> void:
	_section("autoloads")
	for autoload_name in EXPECTED_AUTOLOADS:
		_check(ProjectSettings.has_setting("autoload/" + autoload_name), "%s registered" % autoload_name)
		_check(get_tree().root.has_node(autoload_name), "%s instantiated" % autoload_name)


func _test_scripts_compile() -> void:
	_section("scripts compile")
	var paths := _find_files("res://", "gd")
	_check(not paths.is_empty(), "found %d scripts" % paths.size())
	for path in paths:
		var script := load(path) as GDScript
		_check(script != null and script.can_instantiate(), path)


func _test_scenes_instantiate() -> void:
	_section("scenes load and instantiate")
	var paths := _find_files("res://scenes", "tscn")
	_check(not paths.is_empty(), "found %d scenes" % paths.size())
	for path in paths:
		var packed := load(path) as PackedScene
		var instance: Node = packed.instantiate() if packed != null else null
		_check(instance != null, path)
		if instance != null:
			instance.free()


func _test_routes() -> void:
	_section("route table")
	for route_id in Routes.all_routes():
		_check(ResourceLoader.exists(Routes.scene_path(route_id)) and not Routes.title(route_id).is_empty(),
			"route '%s' has a scene and a title" % route_id)
	_check(Routes.APPROVED_FLOW == [Routes.BOOT, Routes.MAIN_MENU, Routes.HERO_SELECT, Routes.COLLECTION,
		Routes.DECK_BUILDER, Routes.PREBATTLE, Routes.BATTLE, Routes.RESULT], "approved UI flow order")
	_check(Routes.next_in_flow(Routes.PREBATTLE) == Routes.BATTLE, "prebattle is followed by battle")
	_check(Routes.next_in_flow(Routes.RESULT) == &"", "result ends the flow")
	_check(Routes.next_in_flow(Routes.SETTINGS) == &"", "settings is outside the flow")


func _test_game_rules() -> void:
	_section("game rules match docs/PRODUCT_BASELINE.md")
	_check(GameRules.HERO_STARTING_HEALTH == 30, "hero health 30")
	_check(GameRules.HERO_ABILITY_COST == 2, "hero ability cost 2")
	_check(GameRules.DECK_SIZE == 30, "deck size 30")
	_check(GameRules.MAX_HAND_SIZE == 10, "hand limit 10")
	_check(GameRules.MAX_CREATURES_PER_SIDE == 7, "board limit 7 creatures per side")
	_check(GameRules.STARTING_SOUL_SHARDS == 0 and GameRules.MAX_SOUL_SHARDS == 10, "soul shards start at 0, maximum 10")
	_check(GameRules.FIRST_PLAYER_STARTING_HAND == 3 and GameRules.SECOND_PLAYER_STARTING_HAND == 4,
		"starting hands 3 / 4")
	_check(GameRules.STARTING_HAND_REPLACEMENTS == 1, "one starting hand replacement")
	_check(GameRules.STARTING_MAX_ENERGY == 1 and GameRules.MAX_ENERGY_GROWTH_PER_TURN == 1
		and GameRules.MAX_ENERGY_CAP == 10, "energy 1, +1 per turn, cap 10")
	_check(GameRules.IMPULSE_SHARD_ENERGY == 1, "impulse shard +1 energy")
	_check(GameRules.RIFT_FIRST_DAMAGE == 1 and GameRules.RIFT_DAMAGE_STEP == 1, "rift damage 1, 2, 3...")
	_check(GameRules.max_copies_in_deck(CardEnums.Rarity.COMMON) == 2
		and GameRules.max_copies_in_deck(CardEnums.Rarity.RARE) == 2
		and GameRules.max_copies_in_deck(CardEnums.Rarity.EPIC) == 2
		and GameRules.max_copies_in_deck(CardEnums.Rarity.LEGENDARY) == 1, "copy limits 2 / legendary 1")
	_check(GameRules.MAX_ACTIVE_ARTIFACTS == 1, "one active artifact")
	_check(CardEnums.Type.keys() == ["CREATURE", "SPELL", "ARTIFACT", "CURSE"], "card types")
	_check(CardEnums.Rarity.keys() == ["COMMON", "RARE", "EPIC", "LEGENDARY"], "rarities")
	_check(Faction.Id.keys() == ["ASHRAVAEL", "NERQATHEN", "DUMORYSS", "KHEVARUUN", "NEUTRAL"], "factions")
	_check(MatchOutcome.Result.size() == 3 and MatchOutcome.title(MatchOutcome.Result.VICTORY) == "Победа"
		and MatchOutcome.title(MatchOutcome.Result.DEFEAT) == "Поражение"
		and MatchOutcome.title(MatchOutcome.Result.DRAW) == "Ничья", "three result states")


func _test_cyrillic_font() -> void:
	_section("default font covers Russian text")
	var font := ThemeDB.fallback_font
	var text := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя«»—…№"
	var missing := ""
	for character in text:
		if not font.has_char(character.unicode_at(0)):
			missing += character
	_check(missing.is_empty(), "fallback font '%s' has all glyphs (missing: '%s')" % [font.get_font_name(), missing])


func _test_save_manager() -> void:
	_section("SaveManager")
	var path := TEMP_DIR.path_join("save.json")
	_remove_temp_dir()

	var manager := SaveManager.new(path)
	var data := manager.load_data()
	_check(manager.last_load_status == SaveManager.LoadStatus.NOT_FOUND, "first launch: NOT_FOUND")
	_check(data == SaveManager.create_default_data(), "first launch: defaults")
	_check(data[SaveManager.VERSION_KEY] == SaveManager.CURRENT_SAVE_VERSION, "defaults carry save_version")

	data["probe"] = "значение"
	_check(manager.write_data(data) == OK, "write succeeds")
	_check(FileAccess.file_exists(path) and not FileAccess.file_exists(path + SaveManager.TEMP_SUFFIX),
		"atomic write leaves no temporary file")

	var reloaded := SaveManager.new(path).load_data()
	_check(reloaded.get("probe") == "значение", "round trip keeps data")
	_check(typeof(reloaded[SaveManager.VERSION_KEY]) == TYPE_INT
		and reloaded[SaveManager.VERSION_KEY] == SaveManager.CURRENT_SAVE_VERSION, "round trip keeps int save_version")

	_expect_errors(true)
	_write_text(path, "{ not json")
	var corrupted := SaveManager.new(path)
	_check(corrupted.load_data() == SaveManager.create_default_data()
		and corrupted.last_load_status == SaveManager.LoadStatus.CORRUPTED, "corrupted save: defaults")
	_check(FileAccess.get_file_as_string(path + SaveManager.CORRUPTED_SUFFIX) == "{ not json",
		"corrupted save: copy kept")
	_check(corrupted.write_data(SaveManager.create_default_data()) == OK, "corrupted save: can be replaced")

	_write_text(path, JSON.stringify({"probe": 1}))
	var unversioned := SaveManager.new(path)
	unversioned.load_data()
	_check(unversioned.last_load_status == SaveManager.LoadStatus.CORRUPTED, "save without save_version is rejected")

	var future_text := JSON.stringify({SaveManager.VERSION_KEY: SaveManager.CURRENT_SAVE_VERSION + 1, "probe": 1})
	_write_text(path, future_text)
	var future := SaveManager.new(path)
	future.load_data()
	_check(future.last_load_status == SaveManager.LoadStatus.UNSUPPORTED_VERSION, "newer save: UNSUPPORTED_VERSION")
	_check(future.write_data({}) == ERR_LOCKED and FileAccess.get_file_as_string(path) == future_text,
		"newer save is never overwritten")

	var migrated := MigratingSaveManager.new(path).migrate({SaveManager.VERSION_KEY: 1}, 1, 2)
	_check(migrated.get("migrated_field") == true and migrated[SaveManager.VERSION_KEY] == 2,
		"migration steps run in order")
	_check(SaveManager.new(path).migrate({SaveManager.VERSION_KEY: 2}, 2, 3).is_empty(),
		"missing migration step fails safely")
	_expect_errors(false)


func _test_card_database() -> void:
	_section("CardDatabase and the approved cards")
	CardDatabaseTests.new(_check, _expect_errors, TEMP_DIR.path_join("cards")).run()


func _test_match_engine() -> void:
	var cards: Node = CardDatabaseScript.new()
	cards.load_directory()
	for module: Array in ENGINE_TEST_MODULES:
		_section(module[0])
		module[1].new(_check, _expect_errors, cards).run()
	cards.free()


func _test_navigation() -> void:
	_section("navigation")
	EventBus.route_changed.connect(_on_route_changed)
	AppState._save_manager = SaveManager.new(TEMP_DIR.path_join("setup_profile.json"))
	AppState.is_initialized = false

	SceneRouter.reset_to(Routes.BOOT)
	_check(await _wait_for_route(Routes.MAIN_MENU), "Boot opens the main menu")
	_check(_route_log == [Routes.BOOT, Routes.MAIN_MENU], "route_changed emitted for Boot and Main Menu")
	_check(AppState.is_initialized, "AppState initialised by Boot")
	_check(CardDatabase.get_card_count() == 40, "Boot loaded the 40 approved cards into CardDatabase")
	_check(SceneRouter.get_history_size() == 0, "main menu is the history root")

	var menu := get_tree().current_scene
	var captions: Array[String] = []
	for entry: Array in MAIN_MENU_BUTTONS:
		var button := menu.find_child(entry[0]) as Button
		captions.append(button.text if button != null else "<missing %s>" % entry[0])
	_check(captions == ["Играть", "Коллекция", "Колоды", "Герои", "Прогресс", "Настройки"],
		"main menu buttons in approved order: %s" % ", ".join(captions))

	for entry: Array in MAIN_MENU_BUTTONS:
		var button := get_tree().current_scene.find_child(entry[0]) as Button
		if button == null:
			_check(false, "%s exists" % entry[0])
			continue
		button.pressed.emit()
		_check(await _wait_for_route(entry[2]), "'%s' opens %s" % [entry[1], Routes.title(entry[2])])
		SceneRouter.go_back()
		_check(await _wait_for_route(Routes.MAIN_MENU), "back returns to the main menu")

	# Fresh save: choose hero, build and persist an exact 30-card deck, then launch.
	SceneRouter.go_to(Routes.HERO_SELECT)
	_check(await _wait_for_route(Routes.HERO_SELECT), "flow reaches Hero Select")
	var hero_screen := get_tree().current_scene as HeroSelectScreen
	_check(hero_screen.hero_buttons.size() == 4, "Hero Select presents four approved heroes")
	hero_screen.hero_buttons[HeroCatalog.KEZHARYN].pressed.emit()
	_find_button("ConfirmHeroButton").pressed.emit()
	_check(await _wait_for_route(Routes.MAIN_MENU), "hero confirmation returns to menu")
	_check(AppState.profile["selected_hero_id"] == String(HeroCatalog.KEZHARYN), "hero selection persisted")
	_find_button("PlayButton").pressed.emit()
	_check(await _wait_for_route(Routes.DECK_BUILDER), "Play without ready deck opens Deck Builder")
	var editor := get_tree().current_scene as DeckBuilderScreen
	var exact_cards := BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase)
	_check(exact_cards.size() == GameRules.DECK_SIZE, "test builds a validator-legal 30-card set")
	for id: StringName in exact_cards:
		var add := editor.find_child("Add_%s" % id, true, false) as Button
		if add != null:
			add.pressed.emit()
	_check(editor.draft.is_ready(CardDatabase) and editor.draft.card_ids.size() == 30,
		"UI add actions produce validator-ready 30/30 deck")
	var selected_id: String = editor.draft.id
	_find_button("SaveDeckButton").pressed.emit()
	_check(AppState.profile["selected_deck_id"] == selected_id, "first ready deck auto selected")
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)
	_find_button("PlayButton").pressed.emit()
	_check(await _wait_for_route(Routes.PREBATTLE), "Play with selected ready deck opens Prebattle")
	var prebattle := get_tree().current_scene as PrebattleScreen
	_check(not prebattle.start_button.disabled and prebattle.deck_summary.text.contains("30/30"),
		"Prebattle shows selected ready deck")
	prebattle.opponent_buttons[HeroCatalog.TAZHYRION].pressed.emit()
	prebattle.difficulty.select(2)
	prebattle.difficulty.item_selected.emit(2)
	_check(prebattle.start_button.text == "НАЧАТЬ БОЙ", "prebattle offers 'Начать бой'")
	prebattle.start_button.pressed.emit()
	_check(await _wait_for_route(Routes.BATTLE), "flow reaches Battle with saved deck")
	if SceneRouter.current_route == Routes.BATTLE:
		var launched := get_tree().current_scene
		_check(launched.route_params.get(BattleLaunchConfig.PARAM_KEY) is BattleLaunchConfig,
			"normal Prebattle passes a real BattleLaunchConfig")
		_check(launched._ui_state == launched.UIState.MULLIGAN,
			"normal Battle route opens MULLIGAN rather than TEST_MODE")
		_check(launched._session.config.player_deck.map(func(id: Variant) -> String: return String(id)) == exact_cards.map(func(id: Variant) -> String: return String(id))
			and launched._session.config.player_hero == HeroCatalog.KEZHARYN,
			"E2E: exact saved player deck and selected hero reach BattleSession")
		_check(launched._session.config.opponent_hero == HeroCatalog.TAZHYRION
			and launched._session.config.ai_difficulty == AiDifficulty.Level.STRATEGIST,
			"E2E: chosen opponent and AI difficulty reach BattleSession")
		var battle_snapshot: Dictionary = launched._session.engine.snapshot()
		get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(SceneRouter.current_route == Routes.BATTLE and launched._exit_dialog.visible
			and launched._session.engine.snapshot() == battle_snapshot,
			"Android Back keeps the live match and requests confirmation")
		launched.handle_back_request()
		var old_seed: int = launched._session.config.rng_seed
		var player_name: String = HeroCatalog.HEROES[launched._session.config.player_hero]["name_ru"]
		var opponent_name: String = HeroCatalog.HEROES[launched._session.config.opponent_hero]["name_ru"]
		launched._session.engine.state.phase = MatchState.Phase.ENDED
		launched._session.engine.state.winner = 0
		launched._session.engine.state.turn_number = 3
		launched._session.cards_played_player = 2
		launched._session.cards_played_ai = 1
		launched._end_match()
		_check(await _wait_for_route(Routes.RESULT), "real Battle result route opens")
		var result_scene := get_tree().current_scene
		var stats := result_scene.find_child("ResultStats", true, false) as Label
		_check(stats != null and stats.text.contains("Ходов: 3") and stats.text.contains("2 (вы) / 1 (ИИ)")
			and stats.text.contains("Стратег")
			and stats.text.contains(player_name) and stats.text.contains(opponent_name),
			"Result displays both heroes, authoritative turns and difficulty (%s)" % (stats.text if stats != null else "missing"))
		_check(_find_button("OpponentButton") != null and _find_button("DeckButton") != null
			and _find_button("RematchButton") != null and _find_button("MainMenuButton") != null,
			"Result exposes all four Stage 4 actions")
		_find_button("RematchButton").pressed.emit()
		_check(await _wait_for_route(Routes.BATTLE), "Rematch opens a fresh Battle route")
		var rematch := get_tree().current_scene
		_check(rematch._ui_state == rematch.UIState.MULLIGAN
			and rematch._session.config.rng_seed != old_seed and rematch._session.turn_count == 0,
			"Rematch creates a fresh match and seed with the same config")
		var return_params := {
			ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.VICTORY,
			BattleLaunchConfig.PARAM_KEY: rematch._session.config,
		}
		SceneRouter.replace_with(Routes.RESULT, return_params)
		await _wait_for_route(Routes.RESULT)
		_find_button("OpponentButton").pressed.emit()
		_check(await _wait_for_route(Routes.PREBATTLE), "Result opponent action uses persisted Prebattle")
		SceneRouter.replace_with(Routes.RESULT, return_params)
		await _wait_for_route(Routes.RESULT)
		_find_button("DeckButton").pressed.emit()
		_check(await _wait_for_route(Routes.DECK_BUILDER), "Result deck action uses real Deck Builder")

	# Legacy route-without-config smoke coverage is explicit, not the user flow.
	for outcome: MatchOutcome.Result in MatchOutcome.Result.values():
		SceneRouter.replace_with(Routes.BATTLE)
		await _wait_for_route(Routes.BATTLE)
		var key: String = MatchOutcome.Result.find_key(outcome)
		var finish := _find_button("Finish%sButton" % key.capitalize())
		if finish == null:
			_check(false, "battle offers outcome %s" % key)
			continue
		finish.pressed.emit()
		_check(await _wait_for_route(Routes.RESULT), "battle leads to result (%s)" % key)
		var message := get_tree().current_scene.find_child("MessageLabel") as Label
		_check(message != null and message.visible and message.text == MatchOutcome.title(outcome),
			"result shows '%s'" % MatchOutcome.title(outcome))

	_find_button("MainMenuButton").pressed.emit()
	_check(await _wait_for_route(Routes.MAIN_MENU) and SceneRouter.get_history_size() == 0,
		"result returns to the main menu and clears history")

	SceneRouter.go_to(Routes.SETTINGS)
	await _wait_for_route(Routes.SETTINGS)
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(await _wait_for_route(Routes.MAIN_MENU), "Android back request returns to the previous screen")

	_expect_errors(true)
	_check(SceneRouter.go_to(&"missing_route") == ERR_DOES_NOT_EXIST, "unknown route is rejected")
	_check(SceneRouter.go_to(Routes.SETTINGS) == OK and SceneRouter.go_to(Routes.PROGRESS) == ERR_BUSY,
		"navigation during a scene change is rejected")
	_check(await _wait_for_route(Routes.SETTINGS), "pending navigation completes")

	var result_without_params := SceneRouter.go_to(Routes.RESULT)
	_check(result_without_params == OK and await _wait_for_route(Routes.RESULT)
		and (get_tree().current_scene.find_child("MessageLabel") as Label).text == "Результат неизвестен",
		"result without outcome does not crash")
	_expect_errors(false)
	EventBus.route_changed.disconnect(_on_route_changed)


func _test_no_unexpected_engine_errors() -> void:
	_section("engine log")
	_check(_engine_log.expected_count > 0, "negative checks were observed by the error log (%d)" % _engine_log.expected_count)
	_check(_engine_log.unexpected.is_empty(), "no unexpected engine errors or warnings")
	for entry in _engine_log.unexpected:
		print("         unexpected: %s" % entry)


# --- Helpers --------------------------------------------------------------

func _wait_for_route(route_id: StringName) -> bool:
	for _frame in ROUTE_TIMEOUT_FRAMES:
		await get_tree().process_frame
		if SceneRouter.current_route == route_id and not SceneRouter.is_changing():
			return get_tree().current_scene != null \
				and get_tree().current_scene.scene_file_path == Routes.scene_path(route_id)
	return false


func _find_button(node_name: String) -> Button:
	var scene := get_tree().current_scene
	return scene.find_child(node_name, true, false) as Button if scene != null else null


func _on_route_changed(route_id: StringName) -> void:
	_route_log.append(route_id)


func _find_files(root: String, extension: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name in DirAccess.get_files_at(root):
		if file_name.get_extension() == extension:
			found.append(root.path_join(file_name))
	for directory in DirAccess.get_directories_at(root):
		if not directory.begins_with("."):
			found.append_array(_find_files(root.path_join(directory), extension))
	return found


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_temp_dir() -> void:
	_remove_recursive(TEMP_DIR)


func _remove_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory in DirAccess.get_directories_at(path):
		_remove_recursive(path.path_join(directory))
	DirAccess.remove_absolute(path)


func _expect_errors(enabled: bool) -> void:
	_engine_log.expecting = enabled
	print("   [%s]" % ("expected errors/warnings below" if enabled else "end of expected errors/warnings"))


func _section(title: String) -> void:
	print("-- %s" % title)


func _check(condition: bool, description: String) -> void:
	_check_count += 1
	if condition:
		print("   ok    %s" % description)
	else:
		print("   FAIL  %s" % description)
		_failures.append(description)


func _finish() -> void:
	OS.remove_logger(_engine_log)
	if _failures.is_empty():
		print("SMOKE TEST PASSED: %d checks in %d frames." % [_check_count, Engine.get_process_frames()])
		get_tree().quit(0)
	else:
		print("SMOKE TEST FAILED: %d of %d checks failed:" % [_failures.size(), _check_count])
		for failure in _failures:
			print("   - %s" % failure)
		get_tree().quit(1)


func _on_watchdog_timeout() -> void:
	OS.remove_logger(_engine_log)
	print("SMOKE TEST FAILED: watchdog timeout after %d s." % WATCHDOG_SECONDS)
	get_tree().quit(1)
