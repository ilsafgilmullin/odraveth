extends RefCounted
## Real public commands through the restored mouse/native-touch drag path.

const Fixture := preload("res://tests/engine/match_fixture.gd")
const Scene := preload("res://scenes/battle/battle.tscn")
var _check: Callable
var _tree: SceneTree


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func _ok(value: bool, label: String) -> void:
	_check.call(value, "restored drag: " + label)


func _new() -> Dictionary:
	var fixture := Fixture.new(CardDatabase)
	var config := BattleLaunchConfig.create(HeroCatalog.KEZHARYN, fixture.deck_for(HeroCatalog.KEZHARYN),
		HeroCatalog.VHORAZEL, fixture.deck_for(HeroCatalog.VHORAZEL), AiDifficulty.Level.NOVICE, 7101,
		{PlayerSetupData.ANIMATIONS: false})
	var scene := Scene.instantiate() as Control
	scene.apply_route_params({BattleLaunchConfig.PARAM_KEY: config})
	_tree.root.add_child(scene)
	scene._session.engine = fixture.scenario(HeroCatalog.KEZHARYN, HeroCatalog.VHORAZEL)
	scene._session._last_event_seq = 0
	scene._mulligan_overlay.visible = false
	scene._hand_box.visible = true
	scene._set_state(scene.UIState.PLAYER_IDLE)
	return {"scene": scene, "fixture": fixture}


func _at(scene: Control, id: int) -> Vector2:
	var card := scene._hand_box.get_node("HandCard_%d" % id) as BattleCardView
	return card.get_global_transform() * (card.size * Vector2(0.3, 0.2))


func _mouse(scene: Control, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	scene._input(event)


func _move(scene: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	scene._input(event)


func run() -> void:
	CardDatabase.load_directory()
	var previous_size := _tree.root.size
	for dimensions: Vector2i in [Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2400, 1080)]:
		_tree.root.size = dimensions
		var pair := _new()
		var scene: Control = pair["scene"]
		var f: RefCounted = pair["fixture"]
		var card: int = f.hand(0, &"neutral_vantrel_duskling")
		scene._refresh_ui()
		await _tree.process_frame
		scene._layout_hud()
		var origin := _at(scene, card)
		var invalid := Vector2(12, 12)
		var before: Dictionary = scene._session.engine.snapshot()
		_mouse(scene, origin, true)
		_move(scene, origin + Vector2(4, 0))
		_ok(not scene._drag_active and scene._session.engine.snapshot() == before,
			"%s: small motion is a tap, no gameplay command" % dimensions)
		_move(scene, invalid)
		_ok(scene._drag_active, "%s: threshold starts drag and selects the real hand card" % dimensions)
		_mouse(scene, invalid, false)
		_ok(scene._session.engine.snapshot() == before and not scene._drag_active and scene._selected_card_id == 0,
			"%s: invalid drop restores hand and changes no match state" % dimensions)
		var drop: Vector2 = scene._hud.get_global_transform() * Vector2(scene._field_rect.get_center().x,
			scene._center_y + scene._field_rect.size.y * 0.20)
		_mouse(scene, origin, true)
		_move(scene, drop)
		_mouse(scene, drop, false)
		_ok(f.player(0).board.size() == 1 and f.player(0).hand.is_empty() and not scene._drag_active,
			"%s: legal creature drop plays exactly one card" % dimensions)
		scene.free()
		await _tree.process_frame

	var pair := _new()
	var scene: Control = pair["scene"]
	var f: RefCounted = pair["fixture"]
	var gorebrand: int = f.hand(0, &"ashravael_gorebrand")
	var victim: int = f.board(1, &"neutral_rivenshade_grazer")
	scene._refresh_ui()
	await _tree.process_frame
	scene._layout_hud()
	var start := InputEventScreenTouch.new()
	start.index = 3
	start.pressed = true
	start.position = _at(scene, gorebrand)
	scene._input(start)
	var movement := InputEventScreenDrag.new()
	movement.index = 3
	movement.position = scene._find_piece(victim).get_global_rect().get_center()
	scene._input(movement)
	_ok(scene._drag_active and victim in scene._valid_targets, "native touch selects engine-legal target")
	var other_touch := InputEventScreenTouch.new()
	other_touch.index = 4
	other_touch.position = movement.position
	other_touch.pressed = false
	scene._input(other_touch)
	_ok(scene._drag_active and f.player(0).hand.size() == 1, "second pointer cannot release active drag")
	var release := InputEventScreenTouch.new()
	release.index = 3
	release.position = movement.position
	release.pressed = false
	scene._input(release)
	_ok(f.player(0).hand.is_empty() and f.creature(victim).health == 4 and f.player(0).hero_health == 29,
		"native touch release applies approved target effect and self-health cost once")
	scene.free()
	await _tree.process_frame
	pair = _new()
	scene = pair["scene"]
	f = pair["fixture"]
	var card: int = f.hand(0, &"neutral_vantrel_duskling")
	scene._refresh_ui()
	await _tree.process_frame
	scene._layout_hud()
	var origin := _at(scene, card)
	_mouse(scene, origin, true)
	_move(scene, origin - Vector2(0, 80))
	_ok(scene.handle_back_request() and not scene._drag_active and f.player(0).hand.size() == 1,
		"Back cancels drag before exit and keeps card")
	_mouse(scene, origin, true)
	_move(scene, origin - Vector2(0, 80))
	scene._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_ok(not scene._drag_active and f.player(0).hand.size() == 1, "focus loss cancels drag without a command")
	scene.free()
	_tree.root.size = previous_size
	await _tree.process_frame
