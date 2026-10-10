extends RefCounted
## Real BattleScene interactions. White-box fixture setup is confined to tests;
## the actions themselves go through BattleScene -> BattleSession -> MatchEngine.

const Fixture := preload("res://tests/engine/match_fixture.gd")
const BattleSceneResource := preload("res://scenes/battle/battle.tscn")
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL
const T := HeroCatalog.TAZHYRION
const S := HeroCatalog.SYRRAVETH

var _check: Callable
var _cards: Node
var _tree: SceneTree


func _init(check: Callable, _expect_errors: Callable, cards: Node, tree: SceneTree) -> void:
	_check = check
	_cards = cards
	_tree = tree


func run() -> void:
	_test_launch_and_mulligan()
	_test_card_play_and_detail()
	_test_attack_and_targeted_play()
	_test_hero_powers()
	_test_impulse()
	_test_shard_and_choice()
	_test_ai_steps_and_lock()
	_test_safe_battle_exit()
	await _test_responsive_structure()


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "battle UI: " + label)


func _deck(hero: StringName) -> Array:
	var deck: Array = []
	for id: String in Fixture.new(_cards).deck_for(hero):
		deck.append(id)
	return deck


func _new_scene(hero: StringName = K) -> Control:
	var cfg := BattleLaunchConfig.create(hero, _deck(hero), V, _deck(V), AiDifficulty.Level.NOVICE, 901)
	var scene := BattleSceneResource.instantiate() as Control
	scene.apply_route_params({BattleLaunchConfig.PARAM_KEY: cfg})
	_tree.root.add_child(scene)
	return scene


func _scenario(hero: StringName = K) -> Dictionary:
	var scene := _new_scene(hero)
	var fixture := Fixture.new(_cards)
	scene._session.engine = fixture.scenario(hero, V)
	scene._session._last_event_seq = 0
	scene._mulligan_overlay.visible = false
	scene._set_state(scene.UIState.PLAYER_IDLE)
	scene._refresh_ui()
	return {"scene": scene, "fixture": fixture}


func _drain(scene: Control) -> void:
	for _i in 30:
		if scene._ui_state != scene.UIState.RESOLVING:
			break
		scene._tick_events(100.0)


func _hand_card(scene: Control, iid: int) -> BattleCardView:
	return scene._hand_box.get_node_or_null("HandCard_%d" % iid) as BattleCardView


func _test_launch_and_mulligan() -> void:
	var scene := _new_scene()
	_ok(scene._ui_state == scene.UIState.MULLIGAN and scene._mulligan_overlay.visible,
		"route config instantiates a real match in MULLIGAN")
	var detail_btn := scene._mulligan_box.get_child(0).get_child(1) as Button
	detail_btn.pressed.emit()
	_ok(scene._detail_overlay.visible and not scene._detail_text.text.is_empty(), "mulligan card info opens read-only detail")
	scene._detail_overlay.visible = false
	scene._mulligan_btn.pressed.emit()
	_ok(not scene._session.is_mulligan_phase() and not scene._mulligan_overlay.visible,
		"mulligan confirmation submits through the live UI")
	scene.free()


func _test_card_play_and_detail() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	var card: int = f.hand(0, &"neutral_vantrel_duskling")
	var unavailable: int = f.hand(0, &"ashravael_gorebrand")
	scene._refresh_ui()
	var hand_view := _hand_card(scene, card)
	var unavailable_view := _hand_card(scene, unavailable)
	_ok(hand_view != null and unavailable_view != null and not hand_view.disabled and unavailable_view.disabled,
		"playable card enabled, mandatory-target card unavailable")
	unavailable_view.detail_requested.emit(unavailable)
	_ok(scene._detail_overlay.visible and scene._detail_text.text.contains("Стоимость:")
		and scene._detail_text.text.contains("Фракция:") and scene._detail_text.text.contains("Редкость:")
		and scene._detail_text.text.contains("Тип:"), "disabled card still exposes complete detail")
	(scene.find_child("CardDetailCloseButton", true, false) as Button).pressed.emit()
	_ok(not scene._detail_overlay.visible and f.player(0).hand.size() == 2, "detail closes without mutating match")
	scene._on_hand_card_tapped(card)
	_ok(scene._ui_state == scene.UIState.CARD_SELECTED and f.player(0).hand.size() == 2
		and _hand_card(scene, card).selected and scene._play_btn.is_visible_in_tree(),
		"first tap selects (lifts) a targetless card without playing it")
	scene._on_hand_card_tapped(card)
	_ok(f.player(0).hand.size() == 1 and f.player(0).board.size() == 1,
		"second tap plays the targetless card via UI action")
	_ok(scene._ui_state == scene.UIState.RESOLVING, "accepted play locks input during event resolution")
	scene._on_hand_card_tapped(unavailable)
	_ok(f.player(0).hand.size() == 1, "locked/disabled card cannot execute twice")
	scene.free()


func _test_attack_and_targeted_play() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	var enemy: int = f.board(1, &"neutral_vantrel_duskling")
	var own: int = f.board(0, &"neutral_vantrel_duskling")
	var gorebrand: int = f.hand(0, &"ashravael_gorebrand")
	scene._refresh_ui()
	scene._on_hand_card_tapped(gorebrand)
	_ok(scene._ui_state == scene.UIState.CARD_SELECTED and enemy in scene._valid_targets,
		"targeted card prompts for an engine-legal target")
	scene._on_enemy_creature_tapped(enemy)
	_ok(f.player(0).hand.is_empty(), "targeted play executes with chosen enemy")
	_drain(scene)
	if scene._ui_state == scene.UIState.PLAYER_IDLE:
		scene._on_own_creature_tapped(own)
		_ok(scene._ui_state == scene.UIState.ATTACKER_SELECTED, "own creature enters attack selection")
		scene._on_hero_tapped(false)
		_ok(f.creature(own).attacks_this_turn == 1, "creature attack executes via hero target tap")
	else:
		_ok(false, "own creature enters attack selection")
		_ok(false, "creature attack executes via hero target tap")
	scene.free()


func _test_hero_powers() -> void:
	for hero: StringName in [K, T]:
		var case := _scenario(hero)
		var scene: Control = case.scene
		var f: RefCounted = case.fixture
		_ok(scene._session.get_valid_hero_power_targets().is_empty() and scene._hero_power_btn.disabled,
			"%s power unavailable without legal friendly target" % hero)
		var ally: int = f.board(0, &"neutral_vantrel_duskling")
		scene._refresh_ui()
		_ok(not scene._hero_power_btn.disabled, "%s power enabled with legal target" % hero)
		scene._on_hero_power_pressed()
		_ok(scene._ui_state == scene.UIState.HERO_POWER_TARGET and ally in scene._valid_targets,
			"%s highlights exactly the legal target" % hero)
		scene._on_own_creature_tapped(ally)
		_ok(f.player(0).hero_power_used_this_turn, "%s targeted power executes" % hero)
		scene.free()
	for hero: StringName in [V, S]:
		var case := _scenario(hero)
		var scene: Control = case.scene
		var f: RefCounted = case.fixture
		_ok(0 in scene._session.get_valid_hero_power_targets() and not scene._hero_power_btn.disabled,
			"%s targetless power is legal" % hero)
		scene._on_hero_power_pressed()
		_ok(f.player(0).hero_power_used_this_turn, "%s targetless power executes via UI" % hero)
		scene.free()


func _test_shard_and_choice() -> void:
	var case := _scenario(V)
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	f.player(0).soul_shards = 3
	var soulmonger: int = f.hand(0, &"nerqathen_soulmonger")
	scene._refresh_ui()
	scene._on_hand_card_tapped(soulmonger)
	_ok(scene._ui_state == scene.UIState.SOUL_SHARD_CHOICE and scene._shard_overlay.visible,
		"Soulmonger opens soul-shard choice modal")
	scene._shard_adjust(3)
	scene._confirm_shard()
	_ok(f.player(0).soul_shards == 0 and not scene._shard_overlay.visible,
		"Soulmonger spends selected amount through modal")
	scene.free()
	case = _scenario()
	scene = case.scene
	f = case.fixture
	var cartographer: int = f.hand(0, &"neutral_threnic_cartographer")
	scene._refresh_ui()
	scene._on_hand_card_tapped(cartographer)
	_drain(scene)
	_ok(scene._ui_state == scene.UIState.CHOICE_MODAL and scene._choice_overlay.visible,
		"Cartographer opens CHOOSE modal after play resolves")
	if scene._choice_box.get_child_count() > 0:
		var option := scene._choice_box.get_child(0) as Button
		option.pressed.emit()
		_ok(not scene._choice_overlay.visible, "Cartographer choice submits through modal")
	else:
		_ok(false, "Cartographer choice submits through modal")
	scene.free()


func _test_impulse() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	f.player(0).impulse_shard_available = true
	scene._refresh_ui()
	_ok(not scene._impulse_btn.disabled and scene._impulse_btn.visible,
		"Impulse Shard is offered when legal")
	var before: int = f.player(0).energy_current
	scene._impulse_btn.pressed.emit()
	_ok(f.player(0).energy_current == before + 1 and not f.player(0).impulse_shard_available,
		"Impulse Shard UI action executes once through BattleSession")
	scene._impulse_btn.pressed.emit()
	_ok(f.player(0).energy_current == before + 1,
		"locked Impulse Shard button cannot execute twice")
	scene.free()


func _test_ai_steps_and_lock() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	f.hand(1, &"neutral_vantrel_duskling")
	var before: Dictionary = scene._session.get_observation()
	scene._on_end_turn_pressed()
	var turn_after_first: int = scene._session.turn_count
	scene._on_end_turn_pressed()
	_ok(scene._session.turn_count == turn_after_first, "double End Turn is ignored while input is locked")
	_drain(scene)
	_ok(scene._ui_state == scene.UIState.AI_TURN and scene._ai_steps.size() >= 2,
		"AI turn yields multiple ordered presentation steps")
	if scene._ai_steps.size() >= 2:
		var first: Dictionary = scene._ai_steps[0]
		var last: Dictionary = scene._ai_steps[-1]
		_ok(first.has("command") and first.has("events") and first.has("observation_after_command")
			and first["observation_after_command"] != last["observation_after_command"],
			"intermediate public observations differ; commands/events are ordered")
		_ok(not first["observation_after_command"]["opponent"].has("hand")
			and not first["observation_after_command"].has("rng_state"), "presentation never exposes hidden AI data")
	else:
		_ok(false, "intermediate public observations differ; commands/events are ordered")
		_ok(false, "presentation never exposes hidden AI data")
	_ok(scene._presentation_observation != scene._session.get_observation()
		and scene._presentation_observation["turn_number"] == before["turn_number"] + 1,
		"first AI event does not reveal the completed turn state")
	var ai_commands: int = scene._ai_steps.size()
	scene._on_end_turn_pressed()
	_ok(scene._ai_steps.size() == ai_commands, "AI input lock ignores player actions")
	for _i in 100:
		if scene._ui_state != scene.UIState.AI_TURN:
			break
		scene._tick_events(100.0)
	_ok(scene._ai_step_index == ai_commands and scene._presentation_observation.is_empty(),
		"UI presents every AI command before releasing final state")
	_ok(scene._session.turn_count == int(scene._session.get_observation()["turn_number"])
		and scene._session.turn_count > 1, "turn count is authoritative across player and AI turns")
	scene.free()


func _test_safe_battle_exit() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var snapshot: Dictionary = scene._session.engine.snapshot()
	_ok(scene.handle_back_request() and scene._exit_dialog.visible,
		"Android Back opens exit confirmation during a live match")
	_ok(scene._session.engine.snapshot() == snapshot,
		"exit request does not mutate or destroy the live match")
	_ok(scene.handle_back_request() and not scene._exit_dialog.visible,
		"second Back dismisses exit confirmation without leaving")
	(scene._detail_overlay as CardDetailOverlay).show_card(_cards.get_card(&"neutral_vantrel_duskling"))
	_ok(scene.handle_back_request() and not scene._detail_overlay.visible and not scene._exit_dialog.visible,
		"Back closes card detail before offering battle exit")
	(scene.find_child("MainMenuButton", true, false) as Button).pressed.emit()
	_ok(scene._exit_dialog.visible and scene._session.engine.snapshot() == snapshot,
		"battle Menu button uses the same safe confirmation")
	scene.free()


func _test_responsive_structure() -> void:
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(2400, 1080), Vector2i(2800, 1752)]:
		_tree.root.size = dimensions
		var case := _scenario()
		var scene: Control = case.scene
		var f: RefCounted = case.fixture
		for _i in 7:
			f.board(0, &"neutral_vantrel_duskling")
			f.board(1, &"neutral_vantrel_duskling")
		for _i in 10:
			f.hand(0, &"neutral_vantrel_duskling")
		scene._refresh_ui()
		await _tree.process_frame
		await _tree.process_frame
		var safe := scene.get_node("SafeArea") as Control
		var viewport := scene.get_viewport_rect().grow(1.0)
		var label := "%dx%d" % [dimensions.x, dimensions.y]
		_ok(scene._plr_board.get_child_count() == 7 and scene._opp_board.get_child_count() == 7,
			"%s: seven creatures fit in each board" % label)
		var pieces_ok := true
		for row: HBoxContainer in [scene._plr_board, scene._opp_board]:
			for piece: Control in row.get_children():
				pieces_ok = pieces_ok and viewport.encloses(piece.get_global_rect()) and piece.size.x >= 110.0
		_ok(pieces_ok and scene._plr_board.get_child(6).get_global_rect().end.x <= safe.get_global_rect().end.x
			and scene._opp_board.get_child(6).get_global_rect().end.x <= safe.get_global_rect().end.x,
			"%s: 7+7 board pieces stay readable inside the safe width" % label)
		var hand_ok := scene._hand_box.get_child_count() == 10 and scene.find_child("HandScroll", true, false) == null
		var board_bottom: float = scene._plr_board.get_global_rect().end.y
		for card: Control in scene._hand_box.get_children():
			var rect := card.get_global_rect()
			var plate := Rect2(rect.position, Vector2(rect.size.x * 0.3, rect.size.y * 0.3))
			hand_ok = hand_ok and viewport.encloses(plate) and rect.position.y >= board_bottom - 2.0
		_ok(hand_ok, "%s: ten hand cards fan without scrolling; every cost plate visible below the board" % label)
		var visible_rects: Array[Rect2] = []
		for control: Control in [scene._end_turn_btn, scene._hero_power_btn, scene._history_btn, scene._menu_btn,
				scene._plr_hero, scene._opp_hero]:
			visible_rects.append(control.get_global_rect())
		var controls_ok := true
		for rect: Rect2 in visible_rects:
			controls_ok = controls_ok and viewport.encloses(rect)
		_ok(controls_ok and scene._end_turn_btn.is_visible_in_tree() and scene._hero_power_btn.is_visible_in_tree(),
			"%s: end turn, hero power, history, menu and hero clusters remain in viewport" % label)
		var field: Rect2 = scene._field_rect
		_ok(not field.intersects(scene._plr_hero.get_rect()) and not field.intersects(scene._opp_hero.get_rect())
			and not field.intersects(scene._end_turn_btn.get_rect()),
			"%s: HUD sits on the edges; the field centre stays clean" % label)
		_ok(viewport.encloses(scene._mulligan_overlay.get_global_rect())
			and viewport.encloses(scene._detail_overlay.get_global_rect())
			and viewport.encloses(scene._choice_overlay.get_global_rect()),
			"%s: modal overlays remain visible" % label)
		scene.free()
	_tree.root.size = Vector2i(1920, 1080)
