extends RefCounted
## Text animation, input transparency and lifecycle at real control sizes.

var _check: Callable
var _tree: SceneTree


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func _ok(value: bool, label: String) -> void:
	_check.call(value, "recovered menu: " + label)


func run() -> void:
	var saved: Dictionary = AppState.profile
	var previous_size := _tree.root.size
	for dimensions: Vector2i in [Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(2800, 1752)]:
		_tree.root.size = dimensions
		AppState.profile = SaveManager.create_default_data()
		var menu := load(Routes.scene_path(Routes.MAIN_MENU)).instantiate() as MainMenuV2
		_tree.root.add_child(menu)
		await _tree.process_frame
		await _tree.process_frame
		menu.speech.finish_typing()
		_ok(menu.speech.position.x > menu.guardian_region.size.x * 0.45 and menu.speech.position.y > 0,
			"%s: speech follows settled character region, not initial zero size" % dimensions)
		_ok(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(menu.speech.get_global_rect())
			and menu.speech.get_global_rect().end.x < menu.right_region.get_global_rect().position.x,
			"%s: full speech fits viewport and leaves navigation clear" % dimensions)
		_ok(menu.speech.size.y < menu.guardian_region.size.y * 0.35,
			"%s: speech shrinks to text content after initial narrow layout" % dimensions)
		_ok(menu.speech.message_label.text == "С возвращением. Врата Нулмериса открыты."
			and not menu.speech.is_processing() and menu.speech.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s: complete Russian greeting without input interception or endless processing" % dimensions)
		menu.atmosphere.set_enabled(false)
		_ok(not menu.atmosphere.is_processing(), "%s: animations OFF stops atmosphere" % dimensions)
		menu.atmosphere.set_enabled(true)
		menu.atmosphere._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		_ok(not menu.atmosphere.is_processing(), "%s: focus loss stops redraw" % dimensions)
		menu.atmosphere._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		_ok(menu.atmosphere.is_processing(), "%s: focus regain resumes enabled atmosphere" % dimensions)
		menu.atmosphere.hide()
		_ok(not menu.atmosphere.is_processing(), "%s: hidden atmosphere stops redraw" % dimensions)
		menu.free()
		await _tree.process_frame
	var speech := CharacterSpeech.new()
	_tree.root.add_child(speech)
	speech.speak("Герой", "Проверка", true)
	speech._process(0.10)
	_ok(speech.message_label.visible_characters > 0 and speech.message_label.visible_characters < "Проверка".length(),
		"typewriter reveals intermediate Cyrillic text")
	speech.speak("Герой", "Полная реплика", false)
	_ok(speech.message_label.visible_characters == -1 and not speech.is_processing(), "animations OFF shows full line immediately")
	speech.free()
	AppState.profile = saved
	_tree.root.size = previous_size
	await _tree.process_frame
