extends Node
## Screen navigation service (autoload "SceneRouter").
##
## Owns the history stack, swaps the current scene and handles the Android
## system "back" request. Screens never change scenes themselves.
##
## Route parameters: if the new screen defines
## [code]apply_route_params(params: Dictionary)[/code], it receives a deep copy of
## the params before it enters the tree. Short-lived data (for example a battle
## outcome) moves between screens this way instead of living in a global singleton.

const PARAMS_METHOD := &"apply_route_params"
const BACK_HANDLER_METHOD := &"handle_back_request"

enum _HistoryMode { PUSH, KEEP, CLEAR }

## Route of the current screen (or of the screen that is being opened).
## Empty until the first navigation.
var current_route: StringName = &""

var _current_params: Dictionary = {}
var _history: Array[Dictionary] = []
var _is_changing := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Deferred: the notification is propagated through the tree, and the
		# current scene cannot be removed from the root while that is in progress.
		_on_back_requested.call_deferred()


## Opens [param route_id]; the current screen is pushed to the history.
func go_to(route_id: StringName, params: Dictionary = {}) -> Error:
	return _navigate(route_id, params, _HistoryMode.PUSH)


## Opens [param route_id] in place of the current screen; history is unchanged.
func replace_with(route_id: StringName, params: Dictionary = {}) -> Error:
	return _navigate(route_id, params, _HistoryMode.KEEP)


## Opens [param route_id] and clears the history (for example, back to the main menu).
func reset_to(route_id: StringName, params: Dictionary = {}) -> Error:
	return _navigate(route_id, params, _HistoryMode.CLEAR)


## Returns to the previous screen with the params it was opened with.
func go_back() -> Error:
	if _history.is_empty():
		return ERR_DOES_NOT_EXIST
	if _is_changing:
		return ERR_BUSY
	var entry: Dictionary = _history.pop_back()
	var error := _navigate(entry.route, entry.params, _HistoryMode.KEEP)
	if error != OK:
		_history.push_back(entry)
	return error


func can_go_back() -> bool:
	return not _history.is_empty()


func get_history_size() -> int:
	return _history.size()


## True between a successful navigation call and the moment the new screen is current.
func is_changing() -> bool:
	return _is_changing


func _navigate(route_id: StringName, params: Dictionary, history_mode: _HistoryMode) -> Error:
	if _is_changing:
		push_warning("SceneRouter: navigation to '%s' ignored, a scene change is in progress." % route_id)
		return ERR_BUSY
	if not Routes.has_route(route_id):
		push_error("SceneRouter: unknown route '%s'." % route_id)
		return ERR_DOES_NOT_EXIST

	var packed := load(Routes.scene_path(route_id)) as PackedScene
	if packed == null:
		push_error("SceneRouter: cannot load scene '%s' for route '%s'." % [Routes.scene_path(route_id), route_id])
		return ERR_CANT_OPEN
	var screen := packed.instantiate()
	if screen == null:
		push_error("SceneRouter: cannot instantiate scene for route '%s'." % route_id)
		return ERR_CANT_CREATE
	if screen.has_method(PARAMS_METHOD):
		screen.call(PARAMS_METHOD, params.duplicate(true))

	var error := get_tree().change_scene_to_node(screen)
	if error != OK:
		screen.free()
		push_error("SceneRouter: scene change to '%s' failed: %s." % [route_id, error_string(error)])
		return error

	match history_mode:
		_HistoryMode.PUSH:
			if current_route != &"":
				_history.push_back({"route": current_route, "params": _current_params})
		_HistoryMode.CLEAR:
			_history.clear()
	current_route = route_id
	_current_params = params.duplicate(true)
	_is_changing = true
	get_tree().scene_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)
	return OK


func _on_scene_changed() -> void:
	_is_changing = false
	print_verbose("SceneRouter: opened '%s'." % current_route)
	EventBus.route_changed.emit(current_route)


func _on_back_requested() -> void:
	if _is_changing:
		return
	var screen := get_tree().current_scene
	if screen != null and screen.has_method(BACK_HANDLER_METHOD) \
			and bool(screen.call(BACK_HANDLER_METHOD)):
		return
	if can_go_back():
		go_back()
	else:
		# Root screen: follow the Android convention and leave the app.
		get_tree().quit()
