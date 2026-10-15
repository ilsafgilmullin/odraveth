extends RefCounted
## Real command transitions -> public observation -> board/detail presentation.

const Fixture := preload("res://tests/engine/match_fixture.gd")
var _check: Callable
var _tree: SceneTree
var f: RefCounted


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func _ok(value: bool, label: String) -> void:
	_check.call(value, "combat readability: " + label)


func _view(engine: MatchEngine, id: int, viewer: int = 0) -> Dictionary:
	var observation := engine.get_observation(viewer)
	for side: String in ["own", "opponent"]:
		for creature: Dictionary in observation[side]["board"]:
			if int(creature["instance_id"]) == id:
				return creature
	return {}


func _states(engine: MatchEngine, id: int) -> Array[Dictionary]:
	var ready := not engine.get_valid_attack_targets(0, id).is_empty()
	return CardCombatReadability.states(_view(engine, id), int(engine.get_observation(0)["turn_number"]), ready)


func _has(states: Array[Dictionary], id: String) -> bool:
	return states.any(func(item: Dictionary) -> bool: return item["id"] == id)


func run() -> void:
	CardDatabase.load_directory()
	f = Fixture.new(CardDatabase)
	_test_deferral()
	_test_frenzy()
	_test_onslaught_and_expiry()
	await _test_view_reuse_and_detail()


func _test_deferral() -> void:
	var engine: MatchEngine = f.scenario(HeroCatalog.SYRRAVETH, HeroCatalog.TAZHYRION)
	var target: int = f.board(1, &"neutral_rivenshade_grazer")
	var moment: int = f.hand(0, &"dumoryss_fractured_moment")
	_ok(engine.play_card(0, moment, target).ok, "real Deferral play accepted")
	_ok(_has(_states(engine, target), "deferral_pending") and not _has(_states(engine, target), "deferral_active"),
		"waiting Deferral is a clock, not an active attack ban")
	engine.end_turn(0)
	_ok(not _has(_states(engine, target), "deferral_pending") and _has(_states(engine, target), "deferral_active")
		and engine.get_valid_attack_targets(1, target).is_empty(), "owner turn activates lock matching legal attacks")
	engine.end_turn(1)
	_ok(not _has(_states(engine, target), "deferral_active") and not _has(_states(engine, target), "deferral_pending"),
		"Deferral signs disappear when owner turn ends")


func _test_frenzy() -> void:
	var engine: MatchEngine = f.scenario()
	var claw: int = f.board(0, &"ashravael_cinderclaw")
	var enemy: int = f.board(1, &"nerqathen_gravewisp")
	_ok(_has(_states(engine, claw), "frenzy_available"), "Frenzy shown despite being a trigger, not a STATIC keyword")
	_ok(engine.attack(0, claw, enemy).ok and _has(_states(engine, claw), "frenzy_used")
		and not _has(_states(engine, claw), "frenzy_available"), "real damage marks Frenzy used")
	var attack: int = f.creature(claw).get_attack()
	engine.end_turn(0)
	_ok(_has(_states(engine, claw), "frenzy_available") and f.creature(claw).get_attack() == attack,
		"next global turn resets Frenzy availability and keeps permanent bonus")
	var visible := _view(engine, claw)
	visible["temporary_attack"].append({"amount": 99, "expires_turn": 99})
	_ok(f.creature(claw).temporary_attack.is_empty(), "observation copies never mutate runtime buffs")
	_ok(not engine.get_observation(0)["opponent"].has("hand"), "public counters do not expose opponent hand")


func _test_onslaught_and_expiry() -> void:
	var engine: MatchEngine = f.scenario()
	var warfiend: int = f.board(0, &"ashravael_warfiend", false)
	f.board(1, &"neutral_rivenshade_grazer")
	_ok(_has(_states(engine, warfiend), "onslaught_conditional") and not _has(_states(engine, warfiend), "attack_ready"),
		"conditional Onslaught does not imply readiness while health condition fails")
	f.player(0).hero_health = 15
	f.refresh()
	_ok(_has(_states(engine, warfiend), "onslaught") and _has(_states(engine, warfiend), "attack_ready")
		and f.hero_id(1) not in engine.get_valid_attack_targets(0, warfiend), "active Onslaught shows legal creature readiness, no hero promise")
	var oath: int = f.hand(0, &"ashravael_cinder_oath")
	_ok(engine.play_card(0, oath, warfiend).ok and _has(_states(engine, warfiend), "temporary_attack"),
		"temporary attack follows real granted bonus")
	engine.end_turn(0)
	_ok(not _has(_states(engine, warfiend), "temporary_attack"), "temporary bonus marker expires with engine")


func _test_view_reuse_and_detail() -> void:
	var engine: MatchEngine = f.scenario()
	var provoke: int = f.board(0, &"khevaruun_ironwarden")
	var plain: int = f.board(0, &"neutral_rivenshade_grazer")
	var piece := BoardPieceView.new()
	_tree.root.add_child(piece)
	piece.configure(_view(engine, provoke), true, BoardPieceView.TargetState.SELECTED, 1)
	_ok(_has(piece.combat_states, "provoke") and piece.tooltip_text.contains("Провокация"), "board defensive contour has readable explanation")
	piece.configure(_view(engine, plain), false, BoardPieceView.TargetState.NONE, 2)
	_ok(not _has(piece.combat_states, "provoke") and not _has(piece.combat_states, "attack_ready"),
		"reused piece clears previous abilities and readiness")
	var overlay := CardDetailOverlay.new()
	_tree.root.add_child(overlay)
	var hand_card := BattleCardView.new()
	_tree.root.add_child(hand_card)
	hand_card.custom_minimum_size = BattleCardView.BASE_SIZE * 0.92
	hand_card.size = BattleCardView.BASE_SIZE * 0.92
	for card: CardDefinition in CardDatabase.get_all_cards():
		hand_card.configure({"instance_id": 1, "card_id": card.id}, true, false)
		for width: float in [88.0, 100.0, 174.8]:
			hand_card.set_exposed_width(width)
			await _tree.process_frame
			await _tree.process_frame
			var title := hand_card.get_node("Visual/CardName") as Label
			_ok(title.text == card.name_ru and title.position.y + title.size.y <= hand_card.size.y * 0.86
				and title.position.x + title.size.x <= width,
				"%s complete name fits uncovered %.0fpx hand strip above stats" % [card.id, width])
		overlay.show_card(card)
		_ok((card.rules_text_ru.is_empty() or overlay.body_text.text.contains(card.rules_text_ru)) and overlay.current_card_id == card.id,
			"%s full approved rules preserved" % card.id)
		overlay.append_context("Временная атака +3")
		overlay.show_card(card)
		_ok(not overlay.body_text.text.contains("ТЕКУЩЕЕ СОСТОЯНИЕ"), "%s new detail clears stale runtime context" % card.id)
	piece.free()
	overlay.free()
	hand_card.free()
	await _tree.process_frame
