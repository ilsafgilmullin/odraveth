extends RefCounted
## Stage 7 Mulligan V1 + Battle V2 presentation contracts on the real BattleScene.
## Fixture state is white-box set-up only; every action goes through the scene.

const Fixture := preload("res://tests/engine/match_fixture.gd")
const PresentationAudit := preload("res://tests/visual_qa/presentation_audit.gd")
const BattleSceneResource := preload("res://scenes/battle/battle.tscn")
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL
const DUSKLING := &"neutral_vantrel_duskling"

var _check: Callable
var _tree: SceneTree


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	CardDatabase.load_directory()
	_test_mulligan_first_player()
	_test_mulligan_second_player()
	_test_battlefield_theme()
	_test_targeting_states()
	_test_hints_toggle_keeps_instructions()
	_test_history_hides_hidden_information()
	_test_history_drawer_and_back()
	_test_opponent_turn_presentation()
	_test_animations_off_same_state()
	_test_presentation_words()


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "battle V2: " + label)


func _deck(hero: StringName) -> Array:
	var deck: Array = []
	for id: String in Fixture.new(CardDatabase).deck_for(hero):
		deck.append(id)
	return deck


func _prefs(animations: bool = true, hints: bool = true) -> Dictionary:
	return {PlayerSetupData.ANIMATIONS: animations, PlayerSetupData.HINTS: hints, PlayerSetupData.FORECAST: true}


func _new_scene(seed_value: int, prefs: Dictionary = _prefs()) -> Control:
	var cfg := BattleLaunchConfig.create(K, _deck(K), V, _deck(V), AiDifficulty.Level.NOVICE, seed_value, prefs)
	var scene := BattleSceneResource.instantiate() as Control
	scene.apply_route_params({BattleLaunchConfig.PARAM_KEY: cfg})
	_tree.root.add_child(scene)
	return scene


func _scenario(prefs: Dictionary = _prefs()) -> Dictionary:
	var scene := _new_scene(901, prefs)
	var fixture := Fixture.new(CardDatabase)
	scene._session.engine = fixture.scenario(K, V)
	scene._session._last_event_seq = 0
	scene._mulligan_overlay.visible = false
	scene._hand_box.visible = true
	scene._set_state(scene.UIState.PLAYER_IDLE)
	scene._refresh_ui()
	return {"scene": scene, "fixture": fixture}


## A seed whose real setup makes the player go first (or second).
func _scene_with_order(first: bool) -> Control:
	for seed_value in range(1, 80):
		var scene := _new_scene(seed_value)
		var is_first: bool = int(scene._session.get_observation().get("first_player", -1)) == scene._session.player_index
		if is_first == first:
			return scene
		scene.free()
	return null


func _slot(scene: Control, index: int) -> MulliganCardSlot:
	return scene._mulligan_box.get_child(index) as MulliganCardSlot


func _test_mulligan_first_player() -> void:
	var scene := _scene_with_order(true)
	if scene == null:
		_ok(false, "a seed with the player going first exists")
		return
	var hand_ids: Array[int] = []
	for card: Dictionary in scene._session.get_observation()["own"]["hand"]:
		hand_ids.append(int(card["instance_id"]))
	_ok(scene._mulligan_overlay.visible and scene._mulligan_box.get_child_count() == GameRules.FIRST_PLAYER_STARTING_HAND
		and scene._mulligan_info.text == "Вы ходите первым · 3 карты" and not scene._mulligan_impulse.visible,
		"first player sees «СТАРТОВАЯ РУКА» with 3 cards and no Impulse note")
	_ok(scene.find_child("MulliganOverlay", false, false) != null
		and PresentationAudit.visible_texts(scene._mulligan_overlay).has("СТАРТОВАЯ РУКА"),
		"Mulligan header reads «СТАРТОВАЯ РУКА»")
	var opponent: String = HeroCatalog.HEROES[V]["name_ru"]
	_ok(scene._opponent_name.text == opponent.to_upper()
		and scene._opponent_faction.text == SetupUi.faction_name(HeroCatalog.faction_of(V)).to_upper()
		and scene._opponent_portrait.hero_id == V, "exact enemy hero is revealed in the Mulligan")
	var first := _slot(scene, 0)
	first.card_view.pressed.emit()
	_ok(first.marked and first.marker.visible and scene._mulligan_picks.size() == 1 and scene._mulligan_picks[0] == first.instance_id
		and scene._mulligan_count.text == "Отмечено для замены: 1 из 3",
		"tapping the whole card marks it for replacement with banner + hatching (not colour only)")
	first.card_view.pressed.emit()
	_ok(not first.marked and not first.marker.visible and scene._mulligan_picks.is_empty(),
		"tapping again keeps the card")
	var second := _slot(scene, 1)
	first.card_view.pressed.emit()
	second.card_view.pressed.emit()
	var replaced: Array[int] = [first.instance_id, second.instance_id]
	scene._mulligan_btn.pressed.emit()
	var after_ids: Array[int] = []
	for card: Dictionary in scene._session.get_observation()["own"]["hand"]:
		after_ids.append(int(card["instance_id"]))
	var reported: Array = []
	for event: Dictionary in scene._session.engine.get_events(0):
		if event.get("type") == MatchEvent.MULLIGAN_DONE and int(event.get("player", -1)) == scene._session.player_index:
			reported = event.get("replaced", [])
	var kept_ok := true
	for iid: int in hand_ids:
		if iid not in replaced:
			kept_ok = kept_ok and iid in after_ids
	reported.sort()
	replaced.sort()
	_ok(not scene._mulligan_overlay.visible and scene._hand_box.visible and kept_ok and reported == Array(replaced)
		and after_ids.size() >= hand_ids.size(),
		"«ПОДТВЕРДИТЬ РУКУ» replaces exactly the marked cards and keeps the rest")
	scene.free()


func _test_mulligan_second_player() -> void:
	var scene := _scene_with_order(false)
	if scene == null:
		_ok(false, "a seed with the player going second exists")
		return
	_ok(scene._mulligan_box.get_child_count() == GameRules.SECOND_PLAYER_STARTING_HAND
		and scene._mulligan_info.text == "Вы ходите вторым · 4 карты и «Осколок импульса»"
		and scene._mulligan_impulse.visible,
		"second player sees 4 cards; Impulse Shard is a note, not a mulligan card")
	for i in scene._mulligan_box.get_child_count():
		_slot(scene, i).card_view.pressed.emit()
	_ok(scene._mulligan_count.text == "Отмечено для замены: 4 из 4", "the whole hand can be marked")
	scene._mulligan_btn.pressed.emit()
	_ok(not scene._session.is_mulligan_phase() or scene._ui_state != scene.UIState.MULLIGAN,
		"replacing the whole hand is accepted")
	scene.free()


func _test_battlefield_theme() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var theme_layer: BattlefieldTheme = scene._battlefield
	_ok(theme_layer is CitadelBattlefield and theme_layer.theme_id == &"citadel_of_nulmeris"
		and theme_layer.display_name == "ЦИТАДЕЛЬ НУЛМЕРИСА" and theme_layer.ambient_enabled
		and theme_layer.get_parent() == scene and theme_layer.get_index() == 0,
		"«ЦИТАДЕЛЬ НУЛМЕРИСА» battlefield theme is a separate layer behind the HUD")
	scene.free()
	case = _scenario(_prefs(false, true))
	scene = case.scene
	_ok(not scene._battlefield.ambient_enabled and not scene._battlefield.is_processing(),
		"animations OFF also stops ambient theme motion")
	scene.free()


func _test_targeting_states() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	var attacker: int = f.board(0, DUSKLING)
	var other: int = f.board(0, DUSKLING, false)
	var enemy: int = f.board(1, DUSKLING)
	scene._refresh_ui()
	var attacker_piece: BoardPieceView = scene._find_piece(attacker)
	_ok(attacker_piece.can_attack and not scene._find_piece(other).can_attack,
		"only engine-legal attackers are marked ready")
	scene._on_own_creature_tapped(attacker)
	var legal: Array[int] = scene._session.get_valid_attack_targets(attacker)
	_ok(scene._find_piece(attacker).target_state == BoardPieceView.TargetState.SELECTED
		and scene._find_piece(enemy).target_state == BoardPieceView.TargetState.LEGAL
		and scene._find_piece(other).target_state == BoardPieceView.TargetState.DIMMED
		and (scene._opp_hero.target_state == HeroClusterView.TargetState.LEGAL) == (scene._opp_hero.hero_instance_id() in legal),
		"targets come from BattleSession: legal highlighted, the rest dimmed")
	_ok(scene._pill.visible and scene._status_lbl.text == "Выберите цель атаки", "mandatory target instruction is shown")
	scene._pointer = scene._effects.get_global_transform().affine_inverse() * scene._find_piece(enemy).get_global_rect().get_center()
	scene._effects.queue_redraw()
	_ok(scene._is_targeting(), "targeting arc is drawn while a source is selected")
	scene.handle_back_request()
	_ok(scene._ui_state == scene.UIState.PLAYER_IDLE and not scene._exit_dialog.visible
		and scene._find_piece(enemy).target_state == BoardPieceView.TargetState.NONE,
		"Back cancels a pending selection before offering exit")
	scene.free()


func _test_hints_toggle_keeps_instructions() -> void:
	var case := _scenario(_prefs(true, false))
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	var attacker: int = f.board(0, DUSKLING)
	f.board(1, DUSKLING)
	scene._refresh_ui()
	scene._on_own_creature_tapped(attacker)
	_ok(scene._hint_lbl.text.is_empty() and scene._status_lbl.text == "Выберите цель атаки" and scene._pill.visible,
		"«Подсказки» OFF hides optional hints but keeps mandatory target instructions")
	scene.free()


func _test_history_hides_hidden_information() -> void:
	var history := BattleHistory.new(0)
	var secret: String = CardDatabase.get_card(&"nerqathen_soulmonger").name_ru
	var opponent_draw := history.describe({"type": MatchEvent.CARD_DRAWN, "player": 1, "card": "nerqathen_soulmonger"})
	var opponent_burn := history.describe({"type": MatchEvent.CARD_BURNED, "player": 1, "card": "nerqathen_soulmonger"})
	var opponent_choice := history.describe({"type": MatchEvent.CHOICE_MADE, "player": 1, "kept_on_top": 5})
	_ok(opponent_draw == "Соперник взял карту" and not opponent_burn.contains(secret) and opponent_choice.is_empty(),
		"history never names opponent drawn, burned or chosen cards")
	_ok(history.describe({"type": MatchEvent.CARD_DRAWN, "player": 0, "card": "nerqathen_soulmonger"}).contains(secret)
		and history.describe({"type": MatchEvent.CARD_PLAYED, "player": 1, "card_id": "nerqathen_soulmonger",
			"card_instance_id": 9}).contains(secret),
		"own draws and publicly played cards are named")


func _test_history_drawer_and_back() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	scene._on_hand_card_tapped(f.hand(0, DUSKLING))
	scene._on_hand_card_tapped(scene._selected_card_id)
	for _i in 30:
		if scene._ui_state != scene.UIState.RESOLVING:
			break
		scene._tick_events(100.0)
	_ok(not scene._history_panel.visible and scene._log_text.get_parent() != null, "history is a closed drawer, not a permanent log")
	scene._history_btn.pressed.emit()
	_ok(scene._history_panel.visible and scene._log_text.get_parsed_text().contains("Вы разыграли «%s»"
		% CardDatabase.get_card(DUSKLING).name_ru), "ИСТОРИЯ opens the drawer with authoritative events")
	_ok(scene.handle_back_request() and not scene._history_panel.visible and not scene._exit_dialog.visible,
		"Back closes the history drawer first")
	_ok(scene.handle_back_request() and scene._exit_dialog.visible, "next Back asks to leave the battle")
	scene.free()


func _run_ai_turn(scene: Control) -> Array[StringName]:
	var seen: Array[StringName] = []
	scene._on_end_turn_pressed()
	for _i in 400:
		if scene._ui_state in [scene.UIState.PLAYER_IDLE, scene.UIState.MATCH_ENDED, scene.UIState.CHOICE_MODAL]:
			break
		if scene._ui_state == scene.UIState.AI_TURN:
			if scene._end_turn_btn.text == "ХОД СОПЕРНИКА" and scene._end_turn_btn.disabled:
				seen.append(&"locked")
			if scene._play_preview.visible:
				seen.append(scene._play_preview.card_id)
		scene._tick_events(100.0)
	return seen


func _test_opponent_turn_presentation() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	f.hand(1, DUSKLING)
	var seen := _run_ai_turn(scene)
	var played := false
	for line: String in scene._history.lines:
		played = played or line.begins_with("Соперник разыграл")
	_ok(seen.has(&"locked"), "during the AI turn the button reads «ХОД СОПЕРНИКА» and is locked")
	_ok(not played or seen.has(DUSKLING), "a card the opponent plays is previewed while its step is presented")
	_ok(scene._ui_state == scene.UIState.PLAYER_IDLE and scene._end_turn_btn.text == "ЗАВЕРШИТЬ ХОД"
		and not scene._play_preview.visible, "control returns with «ЗАВЕРШИТЬ ХОД» after the opponent's turn")
	scene.free()


func _test_animations_off_same_state() -> void:
	var results: Array[Dictionary] = []
	for animations: bool in [true, false]:
		var case := _scenario(_prefs(animations, true))
		var scene: Control = case.scene
		var f: RefCounted = case.fixture
		var attacker: int = f.board(0, DUSKLING)
		var enemy: int = f.board(1, DUSKLING)
		f.hand(1, DUSKLING)
		scene._refresh_ui()
		scene._on_own_creature_tapped(attacker)
		scene._on_enemy_creature_tapped(enemy)
		for _i in 30:
			if scene._ui_state != scene.UIState.RESOLVING:
				break
			scene._tick_events(100.0)
		_run_ai_turn(scene)
		results.append({"snapshot": scene._session.engine.snapshot(), "history": scene._history.lines.duplicate(),
			"effects": scene._effects.get_child_count()})
		scene.free()
	_ok(results[0]["snapshot"] == results[1]["snapshot"] and results[0]["history"] == results[1]["history"]
		and not (results[0]["history"] as PackedStringArray).is_empty(),
		"animations ON/OFF produce the same match state and event order")
	_ok(int(results[1]["effects"]) == 0, "animations OFF spawns no presentation effects")


func _test_presentation_words() -> void:
	var case := _scenario()
	var scene: Control = case.scene
	var f: RefCounted = case.fixture
	f.hand(0, DUSKLING)
	f.board(0, DUSKLING)
	f.board(1, DUSKLING)
	scene._refresh_ui()
	_ok(not PresentationAudit.has_developer_words(scene), "battle screen shows no developer/placeholder words")
	scene.free()
