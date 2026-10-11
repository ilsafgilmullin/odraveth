extends RefCounted
## Story Mode V1 «Страница без имени → Испытание Цитадели» (docs/STORY_MODE_V1.md):
## routes, approved pages, readiness, story opponent draw, STORY context through
## Search/Battle/Result, real-engine outcome routing, Back chain, Normal/Story
## separation, no modifiers/progress/save changes, responsive containment.

const PresentationAudit := preload("res://tests/visual_qa/presentation_audit.gd")
const VIEWPORTS: Array[Vector2i] = [
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2400, 1080),
	Vector2i(2800, 1752),
]
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL
const S := HeroCatalog.SYRRAVETH
const T := HeroCatalog.TAZHYRION
const TEST_SAVE := "user://odraveth_smoke_test/story_mode_v1.json"
const STORY_SCRIPTS: Array[String] = ["res://scripts/ui/story_citadel.gd", "res://scripts/ui/story_aftermath.gd",
	"res://scripts/ui/story_flow.gd", "res://scripts/ui/story_prologue.gd"]

var _check: Callable
var _tree: SceneTree
var _saved_profile: Dictionary
var _saved_manager: SaveManager


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	_saved_profile = AppState.profile
	_saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new(TEST_SAVE)
	CardDatabase.load_directory()
	_test_launch_config_metadata()
	_test_story_selector()
	_test_normal_selector_unchanged()
	_test_aftermath_texts()
	_test_static_contracts()
	_test_engine_inputs_identical()
	await _test_chronicles_and_pages()
	await _test_readiness_and_setup_return()
	await _test_normal_mode_separation()
	await _test_story_end_to_end()
	await _test_story_result_actions_and_outcomes()
	await _test_back_chain()
	await _test_repeat_without_progress()
	await _test_responsive()
	AppState.profile = _saved_profile
	AppState._save_manager = _saved_manager
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait(Routes.MAIN_MENU)


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "story mode V1: " + label)


func _wait(route: StringName) -> bool:
	for _i in 120:
		await _tree.process_frame
		if SceneRouter.current_route == route and not SceneRouter.is_changing() and _tree.current_scene != null:
			return true
	return false


func _open(route: StringName, params: Dictionary = {}) -> Node:
	SceneRouter.reset_to(route, params)
	await _wait(route)
	return _tree.current_scene


func _system_back(route: StringName) -> bool:
	_tree.root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _tree.process_frame
	return await _wait(route)


func _ready_profile(hero: StringName = K) -> Dictionary:
	var profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), hero)
	var deck := UserDeck.create(hero)
	deck.name = "Колода %s" % StoryFlow.hero_genitive(hero)
	for id: Variant in BattleLaunchConfig.technical_opponent_deck(hero, CardDatabase):
		deck.card_ids.append(String(id))
	return PlayerSetupData.upsert(profile, deck, CardDatabase)


func _use(profile: Dictionary) -> void:
	AppState.persist_profile(profile)


func _story_config(opponent: StringName = V, seed_value: int = 4242) -> BattleLaunchConfig:
	var config := BattleLaunchConfig.create(K, BattleLaunchConfig.technical_opponent_deck(K, CardDatabase), opponent,
		BattleLaunchConfig.technical_opponent_deck(opponent, CardDatabase), AiDifficulty.Level.NOVICE, seed_value,
		{PlayerSetupData.HINTS: true, PlayerSetupData.ANIMATIONS: false})
	config.player_deck_name = "Колода Кежарина"
	config.set_story(BattleLaunchConfig.STORY_CHAPTER_CITADEL_TRIAL, Routes.HISTORY)
	return config


func _button(root: Node, node_name: String) -> Button:
	return root.find_child(node_name, true, false) as Button


func _texts(root: Node) -> String:
	return "\n".join(PresentationAudit.visible_texts(root))


## Real MatchEngine play-out: the AI plays its turns, the player only passes.
func _play_out(session: BattleSession) -> void:
	var keep_all: Array[int] = []
	session.submit_mulligan(keep_all)
	var guard := 0
	while not session.is_over() and guard < 400:
		guard += 1
		if session.is_player_turn():
			session.end_turn()
		else:
			session.run_ai_turn()


# ------------------------------------------------------------------------------
#  Pure contracts
# ------------------------------------------------------------------------------

func _test_launch_config_metadata() -> void:
	var normal := BattleLaunchConfig.create(K, [], V, [], AiDifficulty.Level.NOVICE, 1)
	_ok(normal.mode == BattleLaunchConfig.Mode.NORMAL and normal.story_chapter == &"" and not normal.is_story(),
		"a new BattleLaunchConfig is NORMAL by default")
	_ok(not normal.set_story(&"unknown_chapter", Routes.HISTORY) and not normal.is_story(),
		"an unknown chapter id is rejected and the config stays NORMAL")
	var story := _story_config()
	_ok(story.is_story() and story.story_chapter == BattleLaunchConfig.STORY_CHAPTER_CITADEL_TRIAL
		and story.story_return_route == Routes.HISTORY, "story metadata uses typed constants")
	var rematch := story.rematch()
	_ok(rematch.is_story() and rematch.story_chapter == story.story_chapter
		and rematch.story_return_route == story.story_return_route, "rematch() keeps the STORY context")
	_ok(rematch.rng_seed != story.rng_seed and rematch.opponent_hero == story.opponent_hero
		and rematch.player_deck == story.player_deck and rematch.ai_difficulty == story.ai_difficulty,
		"rematch() keeps hero, deck snapshot, opponent and difficulty with a new seed")
	var other := story.with_opponent(T, CardDatabase)
	_ok(other.is_story() and other.opponent_hero == T and other.player_deck == story.player_deck,
		"with_opponent() keeps the STORY context")
	var names := PackedStringArray()
	for property: Dictionary in story.get_property_list():
		names.append(String(property["name"]).to_lower())
	_ok(not ",".join(names).contains("modifier"), "story battle config carries no modifiers payload")


func _test_story_selector() -> void:
	var heroes: Array[StringName] = PlayerSetupData.HERO_IDS
	var table := OpponentSelector.story_trial_weights(K, heroes)
	_ok(table.size() == 3 and not table.has(K) and int(table[V]) == int(table[S]) and int(table[S]) == int(table[T])
		and int(table[V]) > 0, "story trial: three other heroes with equal integer weights, no mirror")
	var never_mirror := true
	var reachable := {}
	for hero: StringName in heroes:
		reachable[hero] = {}
		for seed_value in 400:
			var picked := OpponentSelector.pick_story_trial_with_seed(hero, seed_value + 1)
			never_mirror = never_mirror and picked != hero and heroes.has(picked)
			(reachable[hero] as Dictionary)[picked] = true
	_ok(never_mirror, "story opponent never equals the player's hero_id (4 heroes × 400 seeds)")
	var all_reachable := true
	for hero: StringName in heroes:
		all_reachable = all_reachable and (reachable[hero] as Dictionary).size() == 3
	_ok(all_reachable, "all three permitted story opponents are reachable for every hero")
	var rng := DeterministicRng.new(99)
	var counts := {}
	var draws := 30000
	for _i in draws:
		var picked := OpponentSelector.pick_story_trial(K, heroes, rng)
		counts[picked] = int(counts.get(picked, 0)) + 1
	var balanced := not counts.has(K)
	for hero: StringName in [V, S, T]:
		balanced = balanced and absf(float(counts.get(hero, 0)) / draws - 1.0 / 3.0) < 0.02
	_ok(balanced, "story draw is uniform over the three others (%s)" % counts)
	_ok(OpponentSelector.pick_story_trial_with_seed(K, 5150) == OpponentSelector.pick_story_trial_with_seed(K, 5150),
		"the same setup seed gives the same story opponent")


func _test_normal_selector_unchanged() -> void:
	var heroes: Array[StringName] = PlayerSetupData.HERO_IDS
	var table := OpponentSelector.weights(K, heroes)
	_ok(int(table[K]) == OpponentSelector.MIRROR_WEIGHT and int(table[V]) == 300 and int(table[S]) == 300
		and int(table[T]) == 300, "ordinary selector keeps the ~10% exact mirror contract")
	var rng := DeterministicRng.new(1234)
	var mirrors := 0
	var draws := 20000
	for _i in draws:
		if OpponentSelector.pick(K, heroes, rng) == K:
			mirrors += 1
	_ok(absf(float(mirrors) / draws - 0.1) < 0.015, "ordinary draw still produces ~10%% mirrors (%d)" % mirrors)


func _test_aftermath_texts() -> void:
	_ok(StoryFlow.aftermath_title(MatchOutcome.Result.VICTORY) == "КНИГА ПРИНЯЛА ПОБЕДУ"
		and StoryFlow.aftermath_title(MatchOutcome.Result.DEFEAT) == "СТЁРТЫЙ ОТТИСК"
		and StoryFlow.aftermath_title(MatchOutcome.Result.DRAW) == "РАЗДЕЛЁННАЯ СТРАНИЦА", "approved aftermath titles")
	_ok(StoryFlow.aftermath_body(MatchOutcome.Result.VICTORY, K, V) == "Книга записывает победу Кежарина. Чернила "
		+ "высыхают — и под ними проступает более старая строка: в этом же испытании победил Вхоразель. Обе записи подлинны.",
		"victory text names the real player and opponent")
	_ok(StoryFlow.aftermath_body(MatchOutcome.Result.DEFEAT, T, S) == "Книга записывает победу Сирравет. Но под новой "
		+ "строкой сохраняется стёртый оттиск: Тажирион уже выходил из этого испытания победителем.",
		"defeat text names the real player and opponent")
	_ok(StoryFlow.aftermath_body(MatchOutcome.Result.DRAW, S, K) == "Книга делит страницу надвое. В одной строке пала "
		+ "Сирравет, в другой — Кежарин. Ни одна запись не исчезает.", "draw text names both heroes with agreement")
	_ok(StoryFlow.CLOSING_LINE == "Хранитель закрывает страницу раньше, чем герои успевают её прочесть.",
		"shared closing line")


func _test_static_contracts() -> void:
	var clean := true
	for path: String in STORY_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		for token: String in ["change_scene", "randi(", "randf(", "randomize(", ".shuffle(", "Одравет", "save_version",
				"persist_profile"]:
			clean = clean and not source.contains(token)
	_ok(clean, "story scripts use SceneRouter only, no global RNG, no player name reveal, no save writes")
	var session_source := FileAccess.get_file_as_string("res://scripts/battle/battle_session.gd")
	_ok(not session_source.contains("story") and not session_source.contains(".mode"),
		"BattleSession never reads story metadata")
	_ok(SaveManager.CURRENT_SAVE_VERSION == 2 and not SaveManager.create_default_data().has("story"),
		"save schema version and default fields are unchanged")


## Identical seed, heroes, decks and difficulty: NORMAL and STORY play out identically.
func _test_engine_inputs_identical() -> void:
	var story := _story_config(V, 909)
	var normal := BattleLaunchConfig.create(story.player_hero, story.player_deck, story.opponent_hero,
		story.opponent_deck, story.ai_difficulty, story.rng_seed, story.presentation_options)
	var a := BattleSession.new(normal)
	var b := BattleSession.new(story)
	a.start()
	b.start()
	a.run_ai_mulligan()
	b.run_ai_mulligan()
	_ok(a.engine.snapshot() == b.engine.snapshot(), "MatchEngine receives identical setup for NORMAL and STORY")
	_play_out(a)
	_play_out(b)
	_ok(a.is_over() and b.is_over() and a.engine.snapshot() == b.engine.snapshot()
		and a.get_outcome() == b.get_outcome(), "the same commands give the same state and outcome in both modes")
	_ok(not JSON.stringify(b.engine.snapshot()).contains(String(BattleLaunchConfig.STORY_CHAPTER_CITADEL_TRIAL)),
		"no story metadata reaches the engine state")


# ------------------------------------------------------------------------------
#  Screens and routes
# ------------------------------------------------------------------------------

func _test_chronicles_and_pages() -> void:
	_use(_ready_profile())
	var library := await _open(Routes.HISTORY, {HistoryShell.PARAM_SECTION: HistoryShell.CHRONICLES}) as HistoryShell
	_ok(library != null and library.current_section == HistoryShell.CHRONICLES, "Library opens directly on «ХРОНИКИ»")
	var fallback := await _open(Routes.HISTORY, {HistoryShell.PARAM_SECTION: "ЧУЖОЙ РАЗДЕЛ"}) as HistoryShell
	_ok(fallback.current_section == HistoryShell.DEFAULT_SECTION, "an unknown section param is ignored")
	fallback = await _open(Routes.HISTORY, {HistoryShell.PARAM_SECTION: 7}) as HistoryShell
	_ok(fallback.current_section == HistoryShell.DEFAULT_SECTION, "a non-string section param is ignored")
	library = await _open(Routes.HISTORY, {HistoryShell.PARAM_SECTION: HistoryShell.CHRONICLES}) as HistoryShell
	library.prologue_button.pressed.emit()
	_ok(await _wait(Routes.STORY_PROLOGUE), "Chronicles open the prologue")
	var prologue := _tree.current_scene as StoryPrologueScreen
	_ok(prologue.current_page == 0 and StoryPrologueScreen.PAGES.size() == 3, "the prologue starts on page 1 of 3")
	prologue.next_button.pressed.emit()
	prologue.next_button.pressed.emit()
	_ok(prologue.next_button.text == "ВОЙТИ В ЦИТАДЕЛЬ", "prologue keeps its final «ВОЙТИ В ЦИТАДЕЛЬ»")
	var prologue_hides_name := not _texts(prologue).contains("Одравет")
	prologue.next_button.pressed.emit()
	_ok(await _wait(Routes.STORY_CITADEL), "the prologue finale opens «Испытание Цитадели»")
	var citadel := _tree.current_scene as StoryCitadelScreen
	_ok(citadel.view == StoryCitadelScreen.View.INTRO and citadel.current_page == 0, "the trial starts with the intro")
	var expected := [
		["ХРАНИТЕЛЬ", "Хранитель поднимает жезл, и кольца Цитадели приходят в движение.", "Для героев оно действительно первое."],
		["ЧЕТЫРЕ СЛЕДА", "Книга хранит четыре следа победы.", "Все четыре записи подлинны."],
		["ПРОТИВОРЕЧИЕ", "Ты не знаешь, какая победа произошла первой.",
			"Войди в испытание и сохрани то, что Книга снова попытается забыть."],
	]
	var pages_ok := true
	var no_name := true
	for i in expected.size():
		var row: Array = expected[i]
		pages_ok = pages_ok and citadel.title_label.text == row[0] and citadel.body_label.text.begins_with(row[1]) \
			and citadel.emphasis_label.text == "«%s»" % row[2] and citadel.page_label.text == "СТРАНИЦА %d ИЗ 3" % (i + 1)
		no_name = no_name and not _texts(citadel).contains("Одравет")
		if i < expected.size() - 1:
			citadel.next_button.pressed.emit()
	_ok(pages_ok, "the three approved intro pages are shown in order")
	_ok(no_name and prologue_hides_name, "Odraveth's name is not revealed")
	_ok(not PresentationAudit.has_developer_words(citadel), "intro pages contain no developer vocabulary")
	_ok(citadel.next_button.text == "К ПОДГОТОВКЕ", "the last intro page leads to preparation")
	citadel.next_button.pressed.emit()
	_ok(await _wait(Routes.STORY_CITADEL) and (_tree.current_scene as StoryCitadelScreen).view
		== StoryCitadelScreen.View.PREPARATION, "intro finale opens the preparation view")


func _test_readiness_and_setup_return() -> void:
	_use(SaveManager.create_default_data())
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait(Routes.MAIN_MENU)
	SceneRouter.go_to(Routes.STORY_CITADEL, {StoryFlow.PARAM_VIEW: StoryFlow.VIEW_PREPARATION})
	await _wait(Routes.STORY_CITADEL)
	var prep := _tree.current_scene as StoryCitadelScreen
	_ok(prep.start_button.disabled and not prep.start_trial() and SceneRouter.current_route == Routes.STORY_CITADEL,
		"without a hero «НАЧАТЬ ИСПЫТАНИЕ» is blocked")
	_ok(prep.hero_button.text == "ВЫБРАТЬ ГЕРОЯ" and prep.status_label.text.contains("Выберите героя"),
		"without a hero the screen offers «ВЫБРАТЬ ГЕРОЯ»")
	prep.hero_button.pressed.emit()
	_ok(await _wait(Routes.HERO_SELECT), "«ВЫБРАТЬ ГЕРОЯ» opens the existing Hero Select")
	var select := _tree.current_scene as HeroSelectScreen
	select._choose(K)
	select._confirm()
	_ok(await _wait(Routes.STORY_CITADEL), "confirming a hero returns to the story preparation")
	prep = _tree.current_scene as StoryCitadelScreen
	_ok(prep.view == StoryCitadelScreen.View.PREPARATION and prep.hero_button.text == "СМЕНИТЬ ГЕРОЯ"
		and _texts(prep).contains("КЕЖАРИН"), "the preparation re-reads the saved hero")
	_ok(prep.start_button.disabled and prep.deck_button.text == "СОБРАТЬ КОЛОДУ"
		and prep.status_label.text.contains("готовую колоду"), "without a ready deck the start stays blocked")
	prep.deck_button.pressed.emit()
	_ok(await _wait(Routes.DECK_BUILDER), "«СОБРАТЬ КОЛОДУ» opens the existing Deck Builder")
	var editor := _tree.current_scene as DeckBuilderScreen
	for id: StringName in BattleLaunchConfig.technical_opponent_deck(K, CardDatabase):
		var add := editor.find_child("Add_%s" % id, true, false) as Button
		if add != null:
			add.pressed.emit()
	editor._save()
	_ok(PlayerSetupData.selected_deck(AppState.profile, CardDatabase) != null, "Deck Builder saved a ready deck")
	_ok(await _system_back(Routes.STORY_CITADEL), "Back from Deck Builder returns to the story preparation")
	prep = _tree.current_scene as StoryCitadelScreen
	_ok(not prep.start_button.disabled and prep.deck_button.text == "СМЕНИТЬ КОЛОДУ"
		and prep.find_child("DeckReadyMarker", true, false) != null, "readiness updates after Deck Builder")
	prep.hero_button.pressed.emit()
	await _wait(Routes.HERO_SELECT)
	_ok(await _system_back(Routes.STORY_CITADEL), "Back from Hero Select returns to the story preparation")
	prep = _tree.current_scene as StoryCitadelScreen
	_ok(prep.start_trial() and await _wait(Routes.PREBATTLE), "a ready profile opens Story Prebattle")
	var prebattle := _tree.current_scene as PrebattleScreen
	_ok(prebattle.is_story() and _texts(prebattle).contains(StoryFlow.MODIFIERS_NONE)
		and _texts(prebattle).contains(StoryFlow.CHAPTER_CAPTION), "Story Prebattle shows «МОДИФИКАТОРЫ: НЕТ»")
	_ok(not _texts(prebattle).contains("НАГРАД") and not _texts(prebattle).contains("ОПЫТ")
		and not _texts(prebattle).contains("ПРОГРЕСС"), "Story Prebattle shows no rewards or progress")
	_ok(not prebattle.difficulty_buttons.is_empty() and prebattle.toggles.has(PlayerSetupData.HINTS)
		and prebattle.toggles.has(PlayerSetupData.ANIMATIONS), "Story Prebattle keeps difficulty and presentation toggles")
	_ok(await _system_back(Routes.STORY_CITADEL), "Back from Story Prebattle returns to the story screen")


func _test_normal_mode_separation() -> void:
	_use(_ready_profile())
	var normal := await _open(Routes.PREBATTLE) as PrebattleScreen
	_ok(not normal.is_story() and normal.find_child("StoryBattleBanner", true, false) == null
		and normal.find_child("OpponentNote", true, false) != null
		and not _texts(normal).contains(StoryFlow.MODIFIERS_NONE), "normal Prebattle does not receive Story UI")
	normal.find_opponent()
	var config := normal.last_config
	_ok(config != null and config.mode == BattleLaunchConfig.Mode.NORMAL and config.story_chapter == &""
		and config.story_return_route == &"", "the normal mode launch config receives no story parameters")
	await _wait(Routes.OPPONENT_SEARCH)
	var result := await _open(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.VICTORY,
		BattleLaunchConfig.PARAM_KEY: config, "turns": 4}) as ResultScreen
	_ok(not result.is_story() and _button(result, "OpponentButton") != null and _button(result, "DeckButton") != null
		and _button(result, "RematchButton").text == "ПОВТОРИТЬ БОЙ" and _button(result, "ContinueStoryButton") == null
		and result.find_child("StoryCaption", true, false) == null, "the ordinary Result is unchanged")
	result.handle_back_request()
	_ok(await _wait(Routes.MAIN_MENU), "ordinary Result Back still returns to the main menu")
	var menu := _tree.current_scene
	var play := _button(menu, "PlayButton")
	_ok(play != null and play.text == "ВОЙТИ В НУЛМЕРИС", "«Войти в Нулмерис» stays on the main menu")
	play.pressed.emit()
	_ok(await _wait(Routes.PREBATTLE) and not (_tree.current_scene as PrebattleScreen).is_story()
		and SceneRouter._current_params.is_empty(), "«Войти в Нулмерис» opens the ordinary Prebattle")


func _test_story_end_to_end() -> void:
	_use(_ready_profile())
	var profile_before := AppState.profile.duplicate(true)
	SceneRouter.reset_to(Routes.HISTORY, {HistoryShell.PARAM_SECTION: HistoryShell.CHRONICLES})
	await _wait(Routes.HISTORY)
	SceneRouter.go_to(Routes.STORY_CITADEL, {StoryFlow.PARAM_VIEW: StoryFlow.VIEW_PREPARATION})
	await _wait(Routes.STORY_CITADEL)
	(_tree.current_scene as StoryCitadelScreen).start_button.pressed.emit()
	await _wait(Routes.PREBATTLE)
	var prebattle := _tree.current_scene as PrebattleScreen
	prebattle.find_button.pressed.emit()
	var chosen := prebattle.last_config
	_ok(chosen != null and chosen.is_story() and chosen.opponent_hero != K and HeroCatalog.has_hero(chosen.opponent_hero),
		"Story Prebattle draws a non-mirror opponent into a STORY config")
	_ok(await _wait(Routes.OPPONENT_SEARCH), "Story Prebattle opens Opponent Search")
	var search := _tree.current_scene as OpponentSearchScreen
	_ok(search.config == chosen and search.config.is_story(), "STORY context passes Opponent Search")
	_ok(search.handle_back_request() and await _wait(Routes.PREBATTLE)
		and (_tree.current_scene as PrebattleScreen).is_story(), "Back from search returns to Story Prebattle")
	prebattle = _tree.current_scene as PrebattleScreen
	prebattle.find_button.pressed.emit()
	chosen = prebattle.last_config
	await _wait(Routes.OPPONENT_SEARCH)
	search = _tree.current_scene as OpponentSearchScreen
	search.finish_now()
	search.proceed()
	_ok(await _wait(Routes.BATTLE), "story search proceeds to Battle")
	var battle := _tree.current_scene
	var session: BattleSession = battle._session
	_ok(session != null and session.config == chosen and session.config.is_story()
		and battle._ui_state == battle.UIState.MULLIGAN, "STORY context passes Battle, which starts in Mulligan")
	var live_snapshot: Dictionary = session.engine.snapshot()
	_tree.root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _tree.process_frame
	await _tree.process_frame
	_ok(SceneRouter.current_route == Routes.BATTLE and battle._exit_dialog.visible
		and session.engine.snapshot() == live_snapshot, "Back in a story battle keeps the exit confirmation")
	battle.handle_back_request()
	_play_out(session)
	_ok(session.is_over(), "the story match ends through MatchEngine rules")
	var outcome := session.get_outcome()
	battle._end_match()
	_ok(await _wait(Routes.RESULT), "the finished story battle opens Result")
	var result := _tree.current_scene as ResultScreen
	_ok(result.is_story() and result.config == chosen and result.config.is_story(), "STORY context passes Result")
	_ok((result.find_child("MessageLabel", true, false) as Label).text == MatchOutcome.title(outcome)
		and result.continue_button != null and result.continue_button.text == "ПРОДОЛЖИТЬ ИСТОРИЮ",
		"Story Result shows the authoritative outcome and «ПРОДОЛЖИТЬ ИСТОРИЮ»")
	result.continue_button.pressed.emit()
	_ok(await _wait(Routes.STORY_AFTERMATH), "«ПРОДОЛЖИТЬ ИСТОРИЮ» opens the aftermath")
	var aftermath := _tree.current_scene as StoryAftermathScreen
	_ok(aftermath.valid and aftermath.outcome == outcome
		and aftermath.title_label.text == StoryFlow.aftermath_title(outcome)
		and aftermath.body_label.text == StoryFlow.aftermath_body(outcome, K, chosen.opponent_hero),
		"the aftermath matches the real engine outcome (%s)" % MatchOutcome.title(outcome))
	_ok(SceneRouter.get_history_size() <= 3, "the story loop keeps a bounded route history (%d)" % SceneRouter.get_history_size())
	aftermath.rematch_button.pressed.emit()
	_ok(await _wait(Routes.BATTLE), "aftermath «ПОВТОРИТЬ ИСПЫТАНИЕ» opens Battle")
	var again: BattleSession = _tree.current_scene._session
	_ok(again.config.is_story() and again.config.opponent_hero == chosen.opponent_hero
		and again.config.player_deck == chosen.player_deck and again.config.player_hero == K
		and again.config.ai_difficulty == chosen.ai_difficulty, "rematch keeps STORY context, hero, deck and opponent")
	_ok(again.config.rng_seed != chosen.rng_seed, "rematch gets a new match seed")
	_ok(AppState.profile == profile_before, "a complete story battle writes nothing to the profile")


func _test_story_result_actions_and_outcomes() -> void:
	for outcome: MatchOutcome.Result in MatchOutcome.Result.values():
		var config := _story_config(S)
		var result := await _open(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: outcome,
			BattleLaunchConfig.PARAM_KEY: config, "turns": 7, "cards_player": 3, "cards_ai": 4}) as ResultScreen
		var key: String = MatchOutcome.Result.find_key(outcome)
		_ok(result.is_story() and result.continue_button != null and _button(result, "RematchButton").text
			== "ПОВТОРИТЬ ИСПЫТАНИЕ" and _button(result, "ChroniclesButton") != null
			and _button(result, "MainMenuButton") != null, "%s: Story Result offers the four story actions" % key)
		_ok(_button(result, "OpponentButton") == null and _button(result, "DeckButton") == null,
			"%s: Story Result hides «Новый соперник» and «Сменить колоду»" % key)
		var visible := _texts(result).to_upper()
		_ok(not visible.contains("ОПЫТ") and not visible.contains("НАГРАД") and not visible.contains("ВАЛЮТ")
			and not visible.contains("РЕЙТИНГ") and not visible.contains("ПРОГРЕСС"),
			"%s: Story Result shows no experience, rewards, currency, rating or progress" % key)
		_ok(not PresentationAudit.has_developer_words(result), "%s: Story Result has no developer vocabulary" % key)
		result.continue_story()
		_ok(await _wait(Routes.STORY_AFTERMATH), "%s: continue opens the aftermath" % key)
		var aftermath := _tree.current_scene as StoryAftermathScreen
		_ok(aftermath.title_label.text == StoryFlow.aftermath_title(outcome)
			and aftermath.body_label.text == StoryFlow.aftermath_body(outcome, K, S)
			and aftermath.closing_label.text == "«%s»" % StoryFlow.CLOSING_LINE,
			"%s opens the matching aftermath with real hero names" % key)
		_ok(_button(aftermath, "RematchButton") != null and _button(aftermath, "ChroniclesButton") != null
			and _button(aftermath, "MainMenuButton") != null and not _texts(aftermath).contains("Одравет")
			and not PresentationAudit.has_developer_words(aftermath), "%s: aftermath actions and texts" % key)
		var visible_after := _texts(aftermath).to_upper()
		_ok(not visible_after.contains("НАГРАД") and not visible_after.contains("ОПЫТ")
			and not visible_after.contains("ОТКРЫТ"), "%s: aftermath grants no rewards, XP or unlocks" % key)
	var result := await _open(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.DEFEAT,
		BattleLaunchConfig.PARAM_KEY: _story_config(T, 777)}) as ResultScreen
	_button(result, "RematchButton").pressed.emit()
	_ok(await _wait(Routes.BATTLE), "Story Result «ПОВТОРИТЬ ИСПЫТАНИЕ» opens Battle")
	var cfg: BattleLaunchConfig = _tree.current_scene._session.config
	_ok(cfg.is_story() and cfg.opponent_hero == T and cfg.rng_seed != 777, "Story Result rematch: same opponent, new seed")
	result = await _open(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.DRAW,
		BattleLaunchConfig.PARAM_KEY: _story_config(T)}) as ResultScreen
	_button(result, "ChroniclesButton").pressed.emit()
	_ok(await _wait(Routes.HISTORY) and (_tree.current_scene as HistoryShell).current_section == HistoryShell.CHRONICLES
		and SceneRouter.get_history_size() == 0, "«В ХРОНИКИ» opens the Library on «ХРОНИКИ» with a fresh history")
	var invalid := await _open(Routes.STORY_AFTERMATH, {}) as StoryAftermathScreen
	_ok(not invalid.valid and invalid.rematch_button == null and invalid.chronicles_button != null,
		"an aftermath without a story config shows a safe fallback")


func _test_back_chain() -> void:
	_use(_ready_profile())
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait(Routes.MAIN_MENU)
	SceneRouter.go_to(Routes.HISTORY)
	await _wait(Routes.HISTORY)
	SceneRouter.go_to(Routes.STORY_PROLOGUE)
	await _wait(Routes.STORY_PROLOGUE)
	var prologue := _tree.current_scene as StoryPrologueScreen
	prologue.next_button.pressed.emit()
	_ok(await _system_back(Routes.STORY_PROLOGUE) and prologue.current_page == 0, "Back on a prologue page goes to the previous page")
	_ok(await _system_back(Routes.HISTORY) and (_tree.current_scene as HistoryShell).current_section
		== HistoryShell.CHRONICLES, "Back on the first prologue page returns to «ХРОНИКИ»")
	var citadel := await _open(Routes.STORY_CITADEL, {StoryFlow.PARAM_PAGE: 2}) as StoryCitadelScreen
	_ok(await _system_back(Routes.STORY_CITADEL) and citadel.current_page == 1, "Back on an intro page goes to the previous page")
	citadel.handle_back_request()
	await _tree.process_frame
	_ok(citadel.current_page == 0, "intro Back steps back to the first page")
	_ok(await _system_back(Routes.STORY_PROLOGUE) and (_tree.current_scene as StoryPrologueScreen).current_page == 2,
		"Back on the first intro page returns to the last prologue page")
	await _open(Routes.STORY_CITADEL, {StoryFlow.PARAM_VIEW: StoryFlow.VIEW_PREPARATION})
	_ok(await _system_back(Routes.STORY_CITADEL) and (_tree.current_scene as StoryCitadelScreen).view
		== StoryCitadelScreen.View.INTRO and (_tree.current_scene as StoryCitadelScreen).current_page == 2,
		"Back from preparation returns to the last intro page")
	await _open(Routes.PREBATTLE, StoryFlow.story_params())
	_ok(await _system_back(Routes.STORY_CITADEL) and (_tree.current_scene as StoryCitadelScreen).view
		== StoryCitadelScreen.View.PREPARATION, "Story Prebattle without history falls back to the story preparation")
	await _open(Routes.OPPONENT_SEARCH, {BattleLaunchConfig.PARAM_KEY: _story_config()})
	_ok(await _system_back(Routes.PREBATTLE) and (_tree.current_scene as PrebattleScreen).is_story(),
		"Opponent Search without history falls back to Story Prebattle")
	await _open(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.VICTORY,
		BattleLaunchConfig.PARAM_KEY: _story_config()})
	_ok(await _system_back(Routes.HISTORY) and (_tree.current_scene as HistoryShell).current_section
		== HistoryShell.CHRONICLES, "Back on Story Result returns to «ХРОНИКИ», never to the ordinary flow")
	await _open(Routes.STORY_AFTERMATH, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.DEFEAT,
		BattleLaunchConfig.PARAM_KEY: _story_config()})
	_ok(await _system_back(Routes.HISTORY) and SceneRouter.get_history_size() == 0,
		"Back on the aftermath returns to «ХРОНИКИ» and clears history")


## Two full narrative passes: no duplicated nodes/connections, no progress, no new saves.
func _test_repeat_without_progress() -> void:
	_use(_ready_profile())
	var profile_before := AppState.profile.duplicate(true)
	var save_before := FileAccess.get_file_as_string(TEST_SAVE)
	var connections_before := _connection_count()
	var node_counts: Array[int] = []
	for _pass in 2:
		var citadel := await _open(Routes.STORY_CITADEL, {StoryFlow.PARAM_VIEW: StoryFlow.VIEW_PREPARATION})
		node_counts.append(_node_count(citadel))
		citadel.start_trial()
		await _wait(Routes.PREBATTLE)
		await _open(Routes.STORY_AFTERMATH, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.VICTORY,
			BattleLaunchConfig.PARAM_KEY: _story_config()})
		_button(_tree.current_scene, "ChroniclesButton").pressed.emit()
		await _wait(Routes.HISTORY)
	_ok(node_counts.size() == 2 and node_counts[0] == node_counts[1],
		"re-entering the story builds the same node tree (%s)" % [node_counts])
	_ok(_connection_count() == connections_before, "re-entering the story adds no lingering signal connections")
	_ok(AppState.profile == profile_before and FileAccess.get_file_as_string(TEST_SAVE) == save_before,
		"replaying the chapter stores no progress, flags or rewards")
	_ok(not JSON.stringify(AppState.profile).contains("story") and not JSON.stringify(AppState.profile).contains("chapter"),
		"the profile has no story fields")


func _node_count(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _node_count(child)
	return total


func _connection_count() -> int:
	var total := 0
	for source: Object in [EventBus, SceneRouter, AppState, _tree, _tree.root]:
		for info: Dictionary in source.get_signal_list():
			total += source.get_signal_connection_list(StringName(info["name"])).size()
	return total


func _test_responsive() -> void:
	var original := _tree.root.size
	var screens := [
		["intro", Routes.STORY_CITADEL, {StoryFlow.PARAM_PAGE: 2}],
		["preparation", Routes.STORY_CITADEL, {StoryFlow.PARAM_VIEW: StoryFlow.VIEW_PREPARATION}],
		["story prebattle", Routes.PREBATTLE, StoryFlow.story_params()],
		["story result", Routes.RESULT, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.VICTORY,
			BattleLaunchConfig.PARAM_KEY: _story_config(V), "turns": 9}],
		["aftermath", Routes.STORY_AFTERMATH, {ResultScreen.PARAM_OUTCOME: MatchOutcome.Result.DEFEAT,
			BattleLaunchConfig.PARAM_KEY: _story_config(V)}],
	]
	_use(_ready_profile())
	for size: Vector2i in VIEWPORTS:
		_tree.root.size = size
		for entry: Array in screens:
			var screen: Node = await _open(entry[1], entry[2])
			await _tree.process_frame
			await _tree.process_frame
			var report := _layout_report(screen as Control)
			_ok((report["outside"] as Array).is_empty(), "%dx%d %s: interactive elements stay inside the viewport %s"
				% [size.x, size.y, entry[0], report["outside"]])
			_ok((report["small"] as Array).is_empty(), "%dx%d %s: touch targets ≥ 64 px %s" % [size.x, size.y, entry[0], report["small"]])
			_ok((report["clipped"] as Array).is_empty(), "%dx%d %s: texts fit %s" % [size.x, size.y, entry[0], report["clipped"]])
	_tree.root.size = original
	await _tree.process_frame


func _layout_report(root: Control) -> Dictionary:
	var viewport := root.get_viewport_rect().grow(1.0)
	var report := {"outside": [], "small": [], "clipped": []}
	_collect_layout(root, viewport, report)
	return report


func _collect_layout(node: Node, viewport: Rect2, report: Dictionary) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is ScrollContainer:
		if not viewport.encloses((node as Control).get_global_rect()):
			(report["outside"] as Array).append(String(node.name))
		return
	if node is Button:
		var button := node as Button
		if not viewport.encloses(button.get_global_rect()):
			(report["outside"] as Array).append(String(button.name))
		if button.size.y < VisualTokens.TOUCH_MIN.y or button.size.x < VisualTokens.TOUCH_MIN.x:
			(report["small"] as Array).append("%s %s" % [button.name, button.size])
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		if font != null and not button.text.is_empty() and button.text.find("\n") == -1:
			var needed := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if needed > button.size.x + 1.0:
				(report["clipped"] as Array).append(String(button.name))
	elif node is Label:
		var label := node as Label
		if not label.text.is_empty() and not viewport.encloses(label.get_global_rect()):
			(report["outside"] as Array).append(String(label.name))
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not label.clip_text \
				and label.get_minimum_size().x > label.size.x + 1.0:
			(report["clipped"] as Array).append(String(label.name))
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF and label.get_line_count() > label.get_visible_line_count():
			(report["clipped"] as Array).append(String(label.name))
	for child: Node in node.get_children():
		_collect_layout(child, viewport, report)
