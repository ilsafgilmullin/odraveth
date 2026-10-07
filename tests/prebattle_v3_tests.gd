extends RefCounted
## Stage 7 Prebattle V3, weighted opponent selection and Opponent Search reveal.

const PresentationAudit := preload("res://tests/visual_qa/presentation_audit.gd")
const VIEWPORTS := [Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(2800, 1752)]
const K := HeroCatalog.KEZHARYN
const ROUTE_TIMEOUT_FRAMES := 120

var check: Callable
var tree: SceneTree
var saved_profile: Dictionary
var saved_manager: SaveManager


func _init(check_fn: Callable, game_tree: SceneTree) -> void:
	check = check_fn
	tree = game_tree


func _ok(value: bool, description: String) -> void:
	check.call(value, "prebattle V3: " + description)


func run() -> void:
	saved_profile = AppState.profile
	saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new("user://odraveth_smoke_test/prebattle_v3.json")
	CardDatabase.load_directory()
	_test_selector_weights()
	_test_selector_distribution_and_determinism()
	_test_no_global_rng()
	await _test_prebattle_controls()
	await _test_responsive()
	await _test_search_reveal_contract()
	await _test_route_flow()
	AppState.profile = saved_profile
	AppState._save_manager = saved_manager
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)


func _ready_profile() -> Dictionary:
	var profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), K)
	var deck := UserDeck.create(K)
	deck.name = "Колода Кежарина"
	for id: Variant in BattleLaunchConfig.technical_opponent_deck(K, CardDatabase):
		deck.card_ids.append(String(id))
	return PlayerSetupData.upsert(profile, deck, CardDatabase)


func _test_selector_weights() -> void:
	var heroes: Array[StringName] = PlayerSetupData.HERO_IDS
	var table := OpponentSelector.weights(K, heroes)
	var total := 0
	for hero: StringName in table:
		total += int(table[hero])
	_ok(total == OpponentSelector.TOTAL_WEIGHT and int(table[K]) == 100,
		"same exact hero_id (mirror) weighs 10%")
	_ok(int(table[HeroCatalog.VHORAZEL]) == 300 and int(table[HeroCatalog.SYRRAVETH]) == 300
		and int(table[HeroCatalog.TAZHYRION]) == 300, "remaining 90% is shared equally, not hard-coded per faction")
	var extended: Array[StringName] = [K, HeroCatalog.VHORAZEL, HeroCatalog.SYRRAVETH, HeroCatalog.TAZHYRION,
		&"FUTURE_ASHRAVAEL_HERO", &"FUTURE_NERQATHEN_HERO"]
	var wide := OpponentSelector.weights(K, extended)
	var wide_total := 0
	for hero: StringName in wide:
		wide_total += int(wide[hero])
	_ok(wide_total == 1000 and int(wide[K]) == 100 and int(wide[&"FUTURE_ASHRAVAEL_HERO"]) == 180,
		"multiple heroes per faction: a same-faction different hero is a normal opponent, mirror stays exact hero_id")
	var others_only: Array[StringName] = [HeroCatalog.VHORAZEL, HeroCatalog.SYRRAVETH]
	var no_mirror := OpponentSelector.weights(K, others_only)
	_ok(not no_mirror.has(K) and int(no_mirror[HeroCatalog.VHORAZEL]) == 500, "ineligible player hero gets no mirror share")


func _test_selector_distribution_and_determinism() -> void:
	_ok(OpponentSelector.pick_with_seed(K, 424242) == OpponentSelector.pick_with_seed(K, 424242),
		"same setup seed gives the same opponent")
	var rng := DeterministicRng.new(77)
	var counts := {}
	var draws := 20000
	for _i in draws:
		var hero := OpponentSelector.pick(K, PlayerSetupData.HERO_IDS, rng)
		counts[hero] = int(counts.get(hero, 0)) + 1
	var mirror := float(counts.get(K, 0)) / float(draws)
	var balanced := true
	for hero: StringName in PlayerSetupData.HERO_IDS:
		if hero != K:
			var share := float(counts.get(hero, 0)) / float(draws)
			balanced = balanced and share > 0.28 and share < 0.32
	_ok(mirror > 0.085 and mirror < 0.115 and balanced,
		"20000 draws: mirror %.1f%%, other heroes ~30%% each" % (mirror * 100.0))


func _test_no_global_rng() -> void:
	var clean := true
	for path: String in ["res://scripts/decks/opponent_selector.gd", "res://scripts/ui/prebattle_screen.gd",
			"res://scripts/ui/opponent_search_screen.gd", "res://scripts/ui/visual/citadel_mechanism_view.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for token: String in ["randi(", "randf(", "randomize(", ".shuffle("]:
			if source.contains(" " + token) or source.contains("\t" + token) or source.contains("(" + token):
				clean = false
	_ok(clean and FileAccess.get_file_as_string("res://scripts/decks/opponent_selector.gd").contains("MatchRng"),
		"opponent selection uses the injectable MatchRng abstraction with a setup seed, no global randomness")


func _open_prebattle(viewport_size: Vector2i = Vector2i(1920, 1080)) -> Array:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var scene := (load(Routes.scene_path(Routes.PREBATTLE)) as PackedScene).instantiate() as PrebattleScreen
	viewport.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	return [viewport, scene]


func _test_prebattle_controls() -> void:
	AppState.profile = _ready_profile()
	var pair: Array = await _open_prebattle()
	var scene: PrebattleScreen = pair[1]
	_ok(not scene.find_button.disabled and scene.find_button.text == "НАЙТИ СОПЕРНИКА",
		"ready deck enables НАЙТИ СОПЕРНИКА")
	_ok(scene.find_child("Opponent_*", true, false) == null and not "opponent_buttons" in scene,
		"there is no manual opponent selection")
	_ok((scene.find_child("PlayerHero", true, false) as Label).text == "КЕЖАРИН"
		and scene.deck_name_label.text == "Колода Кежарина" and scene.deck_summary.text == "30/30",
		"own hero and own deck are shown")
	var labels := PackedStringArray()
	for key: String in PrebattleScreen.DIFFICULTY_KEYS:
		labels.append((scene.difficulty_buttons[key] as Button).text)
	_ok(labels == PackedStringArray(["НОВИЧОК", "ТАКТИК", "СТРАТЕГ"]), "difficulties НОВИЧОК / ТАКТИК / СТРАТЕГ")
	_ok(scene.toggles.size() == 3 and scene.toggles.values().all(func(toggle: CheckButton) -> bool: return toggle.button_pressed)
		and (scene.toggles[PlayerSetupData.HINTS] as CheckButton).text == "Подсказки"
		and (scene.toggles[PlayerSetupData.ANIMATIONS] as CheckButton).text == "Анимации"
		and (scene.toggles[PlayerSetupData.FORECAST] as CheckButton).text == "Прогноз урона",
		"Подсказки / Анимации / Прогноз урона default ON")
	var on_icon := (scene.toggles[PlayerSetupData.HINTS] as CheckButton).get_theme_icon("checked")
	var off_icon := (scene.toggles[PlayerSetupData.HINTS] as CheckButton).get_theme_icon("unchecked")
	_ok(on_icon != null and off_icon != null and on_icon != off_icon and on_icon.resource_path.ends_with("switch_on.svg"),
		"switches use Visual Alpha knob-position icons instead of default Godot switches")
	(scene.toggles[PlayerSetupData.FORECAST] as CheckButton).button_pressed = false
	(scene.difficulty_buttons["STRATEGIST"] as Button).button_pressed = true
	_ok(AppState.profile["prebattle"][PlayerSetupData.FORECAST] == false
		and AppState.profile["prebattle"]["ai_difficulty"] == "STRATEGIST", "toggle and difficulty persist locally")
	_ok((scene.difficulty_buttons["STRATEGIST"] as Button).icon != null
		and (scene.difficulty_buttons["NOVICE"] as Button).icon == null, "selected difficulty is not colour-only")
	_ok(not PresentationAudit.has_developer_words(scene), "no developer placeholder words are visible")
	var before_engine_free := scene.find_child("FindOpponentButton", true, false) != null
	_ok(before_engine_free, "main action node exists for Android navigation")
	(pair[0] as Node).queue_free()
	await tree.process_frame

	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), K)
	pair = await _open_prebattle()
	scene = pair[1]
	_ok(scene.find_button.disabled and scene.deck_name_label.text == "НЕТ ГОТОВОЙ КОЛОДЫ"
		and scene.choose_deck_button.text == "СОБРАТЬ КОЛОДУ", "missing ready deck blocks search and offers deck building")
	_ok(scene.find_opponent() == null, "find opponent refuses to launch without a ready deck")
	(pair[0] as Node).queue_free()
	await tree.process_frame


func _test_responsive() -> void:
	AppState.profile = _ready_profile()
	for viewport_size: Vector2i in VIEWPORTS:
		var pair: Array = await _open_prebattle(viewport_size)
		var scene: PrebattleScreen = pair[1]
		var rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var controls: Array[Control] = [scene.find_button, scene.find_child("BackButton", true, false),
			scene.find_child("HeroPanel", true, false), scene.find_child("DeckPanel", true, false),
			scene.find_child("SettingsPanel", true, false)]
		for key: String in scene.toggles:
			controls.append(scene.toggles[key])
		for key: String in scene.difficulty_buttons:
			controls.append(scene.difficulty_buttons[key])
		_ok(controls.all(func(control: Control) -> bool: return rect.encloses(control.get_global_rect())),
			"%dx%d: panels, difficulty, toggles and main action stay inside the viewport" % [viewport_size.x, viewport_size.y])
		_ok(scene.find_button.size.y >= 76 and (scene.toggles[PlayerSetupData.HINTS] as Control).size.y >= 64,
			"%dx%d: Android touch heights" % [viewport_size.x, viewport_size.y])
		(pair[0] as Node).queue_free()
		await tree.process_frame


func _search_scene(config: BattleLaunchConfig) -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var scene := (load(Routes.scene_path(Routes.OPPONENT_SEARCH)) as PackedScene).instantiate() as OpponentSearchScreen
	scene.apply_route_params({BattleLaunchConfig.PARAM_KEY: config})
	viewport.add_child(scene)
	scene.set_process(false)
	await tree.process_frame
	return [viewport, scene]


func _config(opponent: StringName, animations: bool) -> BattleLaunchConfig:
	var prefs := {PlayerSetupData.ANIMATIONS: animations}
	return BattleLaunchConfig.create(K, BattleLaunchConfig.technical_opponent_deck(K, CardDatabase), opponent,
		BattleLaunchConfig.technical_opponent_deck(opponent, CardDatabase), AiDifficulty.Level.NOVICE, 5150, prefs)


func _test_search_reveal_contract() -> void:
	for opponent: StringName in PlayerSetupData.HERO_IDS:
		var config := _config(opponent, true)
		var pair: Array = await _search_scene(config)
		var scene: OpponentSearchScreen = pair[1]
		var faction := HeroCatalog.faction_of(opponent)
		_ok(scene.phase == OpponentSearchScreen.Phase.ACTIVATING and scene.mechanism.shown_faction == -1,
			"%s: search starts with the activation light, no faction yet" % opponent)
		_ok(scene.faction_at(OpponentSearchScreen.CYCLE_END) == faction
			and scene.faction_at(OpponentSearchScreen.ACTIVATION + 0.2) != -1,
			"%s: symbols cycle and the sequence ends on the drawn faction" % opponent)
		for _i in 60:
			scene._process(0.1)
			if scene.phase == OpponentSearchScreen.Phase.FOUND:
				break
		_ok(scene.phase == OpponentSearchScreen.Phase.FOUND and scene.mechanism.highlight_faction == faction
			and scene.found_label.text == "СОПЕРНИК НАЙДЕН"
			and scene.faction_label.text == SetupUi.faction_name(faction).to_upper(),
			"%s: mechanism slows and locks: СОПЕРНИК НАЙДЕН + faction" % opponent)
		_ok(scene.config == config and config.opponent_hero == opponent and config.rng_seed == 5150,
			"%s: animation never changes the drawn opponent or match seed" % opponent)
		var texts := PresentationAudit.visible_texts(scene)
		var leaks := false
		for hero: StringName in PlayerSetupData.HERO_IDS:
			var name_ru := String(HeroCatalog.HEROES[hero]["name_ru"]).to_upper()
			for text_value: String in texts:
				if text_value.to_upper().contains(name_ru):
					leaks = true
		_ok(not leaks and scene.find_children("*", "HeroPortraitPlaceholder", true, false).is_empty(),
			"%s: no hero portrait or name before the battle" % opponent)
		(pair[0] as Node).queue_free()
		await tree.process_frame
	var still := _config(HeroCatalog.SYRRAVETH, false)
	var pair_still: Array = await _search_scene(still)
	var still_scene: OpponentSearchScreen = pair_still[1]
	_ok(still_scene.phase == OpponentSearchScreen.Phase.FOUND
		and still_scene.faction_label.text == SetupUi.faction_name(Faction.Id.DUMORYSS).to_upper(),
		"animations OFF: same result is shown immediately")
	(pair_still[0] as Node).queue_free()
	await tree.process_frame


func _test_route_flow() -> void:
	AppState.profile = _ready_profile()
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)
	SceneRouter.go_to(Routes.PREBATTLE)
	_ok(await _wait_for_route(Routes.PREBATTLE), "route opens Prebattle")
	var prebattle := tree.current_scene as PrebattleScreen
	prebattle.find_button.pressed.emit()
	var chosen := prebattle.last_config
	_ok(chosen != null and chosen.player_deck == AppState.profile["user_decks"][0]["card_ids"]
		and chosen.player_deck_name == "Колода Кежарина" and chosen.player_hero == K,
		"exact saved deck snapshot and deck metadata are launched")
	_ok(await _wait_for_route(Routes.OPPONENT_SEARCH), "НАЙТИ СОПЕРНИКА opens the search scene")
	var search := tree.current_scene as OpponentSearchScreen
	_ok(search != null and search.handle_back_request(), "Back cancels the search")
	_ok(await _wait_for_route(Routes.PREBATTLE), "cancelled search returns to Prebattle without a match")
	prebattle = tree.current_scene as PrebattleScreen
	prebattle.find_button.pressed.emit()
	_ok(await _wait_for_route(Routes.OPPONENT_SEARCH), "search can be restarted")
	search = tree.current_scene as OpponentSearchScreen
	var revealed := search.config
	search.finish_now()
	search.proceed()
	_ok(await _wait_for_route(Routes.BATTLE), "revealed opponent proceeds to Battle")
	var battle := tree.current_scene
	_ok(battle._session != null and battle._session.config == revealed and battle._ui_state == battle.UIState.MULLIGAN,
		"Battle receives the same config and starts in Mulligan")
	_ok(SceneRouter.get_history_size() == 2, "search is replaced by Battle in history (Menu, Prebattle)")


func _wait_for_route(route_id: StringName) -> bool:
	for _frame in ROUTE_TIMEOUT_FRAMES:
		await tree.process_frame
		if SceneRouter.current_route == route_id and not SceneRouter.is_changing():
			return tree.current_scene != null and tree.current_scene.scene_file_path == Routes.scene_path(route_id)
	return false
