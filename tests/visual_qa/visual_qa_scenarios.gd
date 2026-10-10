extends RefCounted
## QA-only screenshot scenarios. Each returns true when its state was prepared.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")
const GALLERY_IDS: Array[StringName] = [
	&"dumoryss_echo_leech", &"ashravael_warfiend", &"nerqathen_soulmonger", &"neutral_mireglass_wanderer",
	&"khevaruun_wallforged", &"nerqathen_second_burial", &"ashravael_furnace_sigil", &"neutral_vantrel_duskling",
]

var runner: Node
var _overlay: CanvasLayer


func _init(capture_runner: Node) -> void:
	runner = capture_runner


func all() -> Array:
	return [
		["emblems", emblems],
		["main_menu", main_menu],
		["hero_select", hero_select],
		["card_gallery", card_gallery],
		["card_detail", card_detail],
		["collection", collection],
		["collection-bottom", collection_bottom],
		["collection-search", collection_search],
		["deck_builder-cards", deck_builder_cards],
		["deck_builder-deck_ready", deck_builder_deck_ready],
		["deck_builder-deck_not_ready", deck_builder_deck_not_ready],
		["deck_builder-detail", deck_builder_detail],
		["deck_builder-rename", deck_builder_rename],
		["prebattle-ready", prebattle_ready],
		["prebattle-difficulty_toggles", prebattle_difficulty_toggles],
		["prebattle-no_deck", prebattle_no_deck],
		["search-activation", search_activation],
		["search-cycling", search_cycling],
		["search-found", search_found],
		["mulligan-first", mulligan_first],
		["mulligan-second", mulligan_second],
		["mulligan-replace", mulligan_replace],
		["battle-early", battle_early],
		["battle-hand10", battle_hand10],
		["battle-board", battle_board],
		["battle-targeting", battle_targeting],
		["battle-artifact_shards", battle_artifact_shards],
		["battle-opponent_turn", battle_opponent_turn],
		["battle-history", battle_history],
		["battle-detail", battle_detail],
		["result-victory", result_victory],
		["result-defeat", result_defeat],
		["result-draw", result_draw],
		["library-factions", library_factions],
		["library-heroes", library_heroes],
		["library-sealed", library_sealed],
		["boot-first", boot_first],
		["boot-mid", boot_mid],
		["boot-reveal", boot_reveal],
		["boot-failed", boot_failed],
		["symbols-svg", symbols_svg],
		["settings", settings_shell],
		["progress", progress_shell],
	]


func cleanup() -> void:
	_clear_overlay()


func qa_profile(with_ready_deck: bool = true) -> Dictionary:
	var profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	if with_ready_deck:
		var deck := UserDeck.create(HeroCatalog.KEZHARYN)
		deck.name = "Колода Кежарина"
		deck.card_ids.assign(BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase))
		profile = PlayerSetupData.upsert(profile, deck, CardDatabase)
	return profile


func _use_profile(profile: Dictionary) -> void:
	AppState.persist_profile(profile)


func main_menu() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.MAIN_MENU)


func hero_select() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.HERO_SELECT)


func card_gallery() -> bool:
	_clear_overlay()
	if not await runner.open_route(Routes.MAIN_MENU):
		return false
	var root := _overlay_root()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)
	for card_id: StringName in GALLERY_IDS:
		var view := FullCardView.new()
		grid.add_child(view)
		view.configure(CardDatabase.get_card(card_id))
	return true


func _overlay_root(background_color: Color = Color("e8e2d7")) -> Control:
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	runner.get_tree().root.add_child(_overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_root_theme(root)
	_overlay.add_child(root)
	var background := ColorRect.new()
	background.color = background_color
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	return root


func emblems() -> bool:
	_clear_overlay()
	if not await runner.open_route(Routes.MAIN_MENU):
		return false
	var root := _overlay_root()
	var rows := VBoxContainer.new()
	rows.position = Vector2(60, 60)
	rows.add_theme_constant_override("separation", 28)
	root.add_child(rows)
	for edge: float in [48.0, 96.0, 200.0]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 36)
		rows.add_child(row)
		var views: Array[EmblemView] = [EmblemView.seal(), EmblemView.o_mark()]
		for faction: Faction.Id in [Faction.Id.ASHRAVAEL, Faction.Id.NERQATHEN, Faction.Id.DUMORYSS,
				Faction.Id.KHEVARUUN, Faction.Id.NEUTRAL]:
			views.append(EmblemView.for_faction(faction, Color("e8e2d7")))
		for view: EmblemView in views:
			view.custom_minimum_size = Vector2(edge, edge)
			row.add_child(view)
	var dark := HBoxContainer.new()
	dark.add_theme_constant_override("separation", 36)
	rows.add_child(dark)
	for faction: Faction.Id in [Faction.Id.ASHRAVAEL, Faction.Id.NERQATHEN, Faction.Id.DUMORYSS, Faction.Id.KHEVARUUN]:
		var tile := ColorRect.new()
		tile.color = VisualTokens.COLOR_STEEL_900
		tile.custom_minimum_size = Vector2(150, 150)
		dark.add_child(tile)
		var view := EmblemView.for_faction(faction, VisualTokens.COLOR_STEEL_900)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(view)
	return true


func card_detail() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	if not await runner.open_route(Routes.COLLECTION):
		return false
	var screen := runner.get_tree().current_scene as CollectionScreen
	return screen != null and screen.detail.open_card(&"dumoryss_echo_leech")


func collection() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.COLLECTION)


func collection_bottom() -> bool:
	if not await collection():
		return false
	var screen := runner.get_tree().current_scene as CollectionScreen
	await runner.settle(4)
	screen.card_scroll.scroll_vertical = int(screen.card_scroll.get_v_scroll_bar().max_value)
	return true


func collection_search() -> bool:
	if not await collection():
		return false
	var screen := runner.get_tree().current_scene as CollectionScreen
	screen.search.text = "стран"
	screen.search.text_changed.emit(screen.search.text)
	return true


func _deck_builder(card_count: int) -> DeckBuilderScreen:
	_clear_overlay()
	_use_profile(qa_profile())
	if not await runner.open_route(Routes.DECK_BUILDER):
		return null
	var screen := runner.get_tree().current_scene as DeckBuilderScreen
	if screen == null:
		return null
	var ids := BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase)
	screen.draft.card_ids.clear()
	for i in mini(card_count, ids.size()):
		screen.draft.card_ids.append(String(ids[i]))
	screen._after_deck_change()
	return screen


func deck_builder_cards() -> bool:
	var screen := await _deck_builder(18)
	return screen != null


func deck_builder_deck_ready() -> bool:
	var screen := await _deck_builder(30)
	if screen == null:
		return false
	screen.show_tab(DeckBuilderScreen.Tab.DECK)
	return screen.draft.is_ready(CardDatabase)


func deck_builder_deck_not_ready() -> bool:
	var screen := await _deck_builder(18)
	if screen == null:
		return false
	screen.show_tab(DeckBuilderScreen.Tab.DECK)
	return not screen.draft.is_ready(CardDatabase)


func deck_builder_detail() -> bool:
	var screen := await _deck_builder(18)
	return screen != null and screen.detail.open_card(&"ashravael_warfiend")


func deck_builder_rename() -> bool:
	var screen := await _deck_builder(30)
	if screen == null:
		return false
	screen.name_edit.grab_focus()
	screen.name_edit.text = "Пламя Нулмериса"
	screen.name_edit.text_changed.emit(screen.name_edit.text)
	screen.name_edit.caret_column = screen.name_edit.text.length()
	return true


func prebattle_ready() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.PREBATTLE)


func prebattle_difficulty_toggles() -> bool:
	if not await prebattle_ready():
		return false
	var screen := runner.get_tree().current_scene as PrebattleScreen
	(screen.difficulty_buttons["STRATEGIST"] as Button).button_pressed = true
	(screen.toggles[PlayerSetupData.FORECAST] as CheckButton).button_pressed = false
	return true


func prebattle_no_deck() -> bool:
	_clear_overlay()
	_use_profile(qa_profile(false))
	return await runner.open_route(Routes.PREBATTLE)


func qa_battle_config(opponent: StringName = HeroCatalog.VHORAZEL, seed_value: int = 20260707) -> BattleLaunchConfig:
	var config := BattleLaunchConfig.create(HeroCatalog.KEZHARYN,
		BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase), opponent,
		BattleLaunchConfig.technical_opponent_deck(opponent, CardDatabase), AiDifficulty.Level.TACTICIAN, seed_value,
		{PlayerSetupData.HINTS: true, PlayerSetupData.ANIMATIONS: true, PlayerSetupData.FORECAST: true})
	config.player_deck_name = "Колода Кежарина"
	return config


func _search_at(time: float) -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	if not await runner.open_route(Routes.OPPONENT_SEARCH, {BattleLaunchConfig.PARAM_KEY: qa_battle_config()}):
		return false
	var screen := runner.get_tree().current_scene as OpponentSearchScreen
	screen.set_process(false)
	var t := 0.0
	while t < time:
		screen._process(0.05)
		t += 0.05
	return true


func search_activation() -> bool:
	return await _search_at(0.55)


func search_cycling() -> bool:
	return await _search_at(2.2)


func search_found() -> bool:
	return await _search_at(4.6)


## Opens the real Battle route; [param first] picks a seed where the player goes first/second.
func _open_battle(first: bool, player_hero: StringName = HeroCatalog.KEZHARYN) -> Control:
	_clear_overlay()
	_use_profile(qa_profile())
	for seed_value in range(20260707, 20260787):
		var config := qa_battle_config(HeroCatalog.VHORAZEL, seed_value)
		if player_hero != HeroCatalog.KEZHARYN:
			config.player_hero = player_hero
			config.player_deck = BattleLaunchConfig.technical_opponent_deck(player_hero, CardDatabase)
		var probe := BattleSession.new(config)
		probe.start()
		if (int(probe.get_observation().get("first_player", -1)) == 0) != first:
			continue
		if not await runner.open_route(Routes.BATTLE, {BattleLaunchConfig.PARAM_KEY: config}):
			return null
		return runner.get_tree().current_scene as Control
	return null


func mulligan_first() -> bool:
	return await _open_battle(true) != null


func mulligan_second() -> bool:
	return await _open_battle(false) != null


func mulligan_replace() -> bool:
	var scene := await _open_battle(false)
	if scene == null:
		return false
	for index: int in [0, 2]:
		(scene._mulligan_box.get_child(index) as MulliganCardSlot).card_view.pressed.emit()
	return true


func battle_early() -> bool:
	var scene := await _open_battle(true)
	if scene == null:
		return false
	scene._mulligan_btn.pressed.emit()
	for _i in 40:
		if scene._ui_state == scene.UIState.PLAYER_IDLE:
			break
		scene._tick_events(100.0)
	await _settle_effects(scene)
	return scene._ui_state == scene.UIState.PLAYER_IDLE


## Real Battle scene with a fixture position (white-box set-up for screenshots only).
func _fixture_battle(player_hero: StringName = HeroCatalog.KEZHARYN) -> Array:
	var scene := await _open_battle(true, player_hero)
	if scene == null:
		return []
	var fixture := MatchFixture.new(CardDatabase)
	scene._session.engine = fixture.scenario(player_hero, HeroCatalog.VHORAZEL)
	scene._session._last_event_seq = 0
	scene._mulligan_overlay.visible = false
	scene._hand_box.visible = true
	scene._hand_seen = true
	scene._set_state(scene.UIState.PLAYER_IDLE)
	fixture.engine.state.turn_number = 7
	for side in fixture.engine.state.players:
		side.energy_max = 7
		side.energy_current = 5
	return [scene, fixture]


func _cards_of(faction: Faction.Id, card_type: CardEnums.Type) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardDefinition in CardDatabase.get_all_cards():
		if card.faction == faction and card.card_type == card_type:
			ids.append(card.id)
	return ids


func _fill_board(fixture: RefCounted, owner: int, count: int, faction: Faction.Id) -> Array[int]:
	var pool := _cards_of(faction, CardEnums.Type.CREATURE)
	pool.append_array(_cards_of(Faction.Id.NEUTRAL, CardEnums.Type.CREATURE))
	var ids: Array[int] = []
	for i in count:
		ids.append(fixture.board(owner, pool[i % pool.size()], i % 3 != 2))
	return ids


func _fill_hand(fixture: RefCounted, count: int) -> void:
	var pool: Array[StringName] = []
	for card_id: Variant in BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase):
		if StringName(str(card_id)) not in pool:
			pool.append(StringName(str(card_id)))
	for i in count:
		fixture.hand(0, pool[(i * 3) % pool.size()])


func battle_hand10() -> bool:
	var pair := await _fixture_battle()
	if pair.is_empty():
		return false
	_fill_board(pair[1], 0, 2, Faction.Id.ASHRAVAEL)
	_fill_board(pair[1], 1, 2, Faction.Id.NERQATHEN)
	_fill_hand(pair[1], 10)
	pair[0]._refresh_ui()
	return true


func battle_board() -> bool:
	var pair := await _fixture_battle()
	if pair.is_empty():
		return false
	var fixture: RefCounted = pair[1]
	var own := _fill_board(fixture, 0, 7, Faction.Id.ASHRAVAEL)
	var enemy := _fill_board(fixture, 1, 7, Faction.Id.NERQATHEN)
	fixture.creature(own[1]).health = maxi(1, fixture.creature(own[1]).health - 1)
	fixture.creature(enemy[3]).armor = 2
	fixture.player(0).hero_health = 23
	fixture.player(1).hero_health = 17
	_fill_hand(fixture, 5)
	pair[0]._refresh_ui()
	return true


func battle_targeting() -> bool:
	var pair := await _fixture_battle()
	if pair.is_empty():
		return false
	var scene: Control = pair[0]
	var own := _fill_board(pair[1], 0, 4, Faction.Id.ASHRAVAEL)
	var enemy := _fill_board(pair[1], 1, 4, Faction.Id.NERQATHEN)
	_fill_hand(pair[1], 4)
	scene._refresh_ui()
	await runner.settle(4)
	scene._on_own_creature_tapped(own[0])
	var target: Control = scene._find_piece(scene._valid_targets[0] if not scene._valid_targets.is_empty() else enemy[1])
	if target != null:
		scene._pointer = scene._effects.get_global_transform().affine_inverse() * target.get_global_rect().get_center()
		scene._effects.queue_redraw()
	return scene._ui_state == scene.UIState.ATTACKER_SELECTED


func battle_artifact_shards() -> bool:
	var pair := await _fixture_battle(HeroCatalog.VHORAZEL)
	if pair.is_empty():
		return false
	var fixture: RefCounted = pair[1]
	var artifacts := _cards_of(Faction.Id.NERQATHEN, CardEnums.Type.ARTIFACT)
	artifacts.append_array(_cards_of(Faction.Id.NEUTRAL, CardEnums.Type.ARTIFACT))
	if not artifacts.is_empty():
		fixture.artifact(0, artifacts[0])
		fixture.artifact(1, artifacts[artifacts.size() - 1])
	fixture.player(0).soul_shards = 4
	fixture.player(1).soul_shards = 2
	_fill_board(fixture, 0, 3, Faction.Id.NERQATHEN)
	_fill_board(fixture, 1, 3, Faction.Id.NERQATHEN)
	fixture.hand(0, &"nerqathen_soulmonger")
	_fill_hand(fixture, 3)
	pair[0]._refresh_ui()
	return true


func battle_opponent_turn() -> bool:
	var pair := await _fixture_battle()
	if pair.is_empty():
		return false
	var scene: Control = pair[0]
	var fixture: RefCounted = pair[1]
	_fill_board(fixture, 0, 3, Faction.Id.ASHRAVAEL)
	_fill_board(fixture, 1, 2, Faction.Id.NERQATHEN)
	for card_id: StringName in _cards_of(Faction.Id.NERQATHEN, CardEnums.Type.CREATURE).slice(0, 3):
		fixture.hand(1, card_id)
	_fill_hand(fixture, 5)
	scene._refresh_ui()
	scene._on_end_turn_pressed()
	for _i in 200:
		if scene._ui_state == scene.UIState.AI_TURN and scene._play_preview.visible:
			break
		if scene._ui_state == scene.UIState.PLAYER_IDLE:
			break
		scene._tick_events(100.0)
	scene.set_process(false)
	await _settle_effects(scene)
	return scene._ui_state == scene.UIState.AI_TURN


func battle_history() -> bool:
	var pair := await _fixture_battle()
	if pair.is_empty():
		return false
	var scene: Control = pair[0]
	var fixture: RefCounted = pair[1]
	var own := _fill_board(fixture, 0, 3, Faction.Id.ASHRAVAEL)
	var enemy := _fill_board(fixture, 1, 2, Faction.Id.NERQATHEN)
	fixture.hand(1, &"neutral_vantrel_duskling")
	_fill_hand(fixture, 4)
	scene._refresh_ui()
	scene._on_own_creature_tapped(own[0])
	scene._on_enemy_creature_tapped(enemy[0])
	for _i in 30:
		if scene._ui_state != scene.UIState.RESOLVING:
			break
		scene._tick_events(100.0)
	scene._on_end_turn_pressed()
	for _i in 300:
		if scene._ui_state == scene.UIState.PLAYER_IDLE:
			break
		scene._tick_events(100.0)
	await _settle_effects(scene)
	scene._history_btn.pressed.emit()
	return scene._history_panel.visible


func battle_detail() -> bool:
	var pair := await _fixture_battle()
	if pair.is_empty():
		return false
	var scene: Control = pair[0]
	_fill_board(pair[1], 0, 3, Faction.Id.ASHRAVAEL)
	_fill_hand(pair[1], 6)
	scene._refresh_ui()
	var first := scene._hand_box.get_child(0) as BattleCardView
	scene._show_hand_detail(first.instance_id)
	return scene._detail_overlay.visible


func _result(outcome: MatchOutcome.Result) -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: outcome,
		BattleLaunchConfig.PARAM_KEY: qa_battle_config(), "turns": 11, "cards_player": 9, "cards_ai": 8})


func result_victory() -> bool:
	return await _result(MatchOutcome.Result.VICTORY)


func result_defeat() -> bool:
	return await _result(MatchOutcome.Result.DEFEAT)


func result_draw() -> bool:
	return await _result(MatchOutcome.Result.DRAW)


func _library(section: String) -> bool:
	_clear_overlay()
	if not await runner.open_route(Routes.HISTORY):
		return false
	(runner.get_tree().current_scene as HistoryShell).show_section(section)
	return true


func library_factions() -> bool:
	return await _library("ФРАКЦИИ")


func library_heroes() -> bool:
	return await _library("ГЕРОИ")


func library_sealed() -> bool:
	return await _library("ХРОНИКИ")


## Boot frames are posed on an overlay so the capture run keeps its own route.
func _boot(progress: float, status_text: String, opening: float = 0.0, failed: bool = false) -> bool:
	_clear_overlay()
	var root := _overlay_root()
	var boot := (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate() as BootScreen
	boot.autostart = false
	boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(boot)
	boot.progress = progress
	boot.fast = true
	boot.status_label.text = status_text
	boot.gates.opening = opening
	boot.gates.failed = failed
	if opening > 0.5:
		boot.wordmark.modulate = Color.WHITE
	if failed:
		boot._fail(&"cards", ERR_FILE_NOT_FOUND)
	return true


func boot_first() -> bool:
	return _boot(0.0, "Пробуждение Цитадели…")


func boot_mid() -> bool:
	return _boot(0.55, "Загрузка карт Нулмериса…")


func boot_reveal() -> bool:
	return _boot(1.0, "", 0.85)


func boot_failed() -> bool:
	return _boot(0.33, "", 0.0, true)


## The candidate SVG files themselves (O-mark, Seal, four factions), monochrome and
## large/small, to check the silhouettes read without colour.
func symbols_svg() -> bool:
	_clear_overlay()
	var root := _overlay_root(Color("efe9dd"))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(col)
	for size_px: int in [240, 72]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 40)
		col.add_child(row)
		for path: String in ["res://assets/ui/brand/odraveth_o_mark.svg", "res://assets/ui/world/seal_of_nulmeris.svg",
				"res://assets/ui/factions/ashravael.svg", "res://assets/ui/factions/nerqathen.svg",
				"res://assets/ui/factions/dumoryss.svg", "res://assets/ui/factions/khevaruun.svg"]:
			var rect := TextureRect.new()
			rect.texture = load(path) as Texture2D
			rect.custom_minimum_size = Vector2(size_px, size_px)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(rect)
	return true


func settings_shell() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.SETTINGS)


func progress_shell() -> bool:
	_clear_overlay()
	return await runner.open_route(Routes.PROGRESS)


## Synchronous QA ticks never advance tweens; drop transient effects before a shot.
func _settle_effects(scene: Control) -> void:
	await runner.settle(2)
	for child: Node in scene._effects.get_children():
		child.queue_free()
	scene._event_banner.visible = false


func _clear_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
