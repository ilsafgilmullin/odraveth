extends RefCounted
## Disk round-trip and failed-write protection of the real Deck Builder controls.

var _check: Callable
var _tree: SceneTree
var _expect_errors: Callable

class FailingSaveManager extends SaveManager:
	var fail := true

	func write_data(data: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if fail else super.write_data(data)


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func set_expect_errors(callback: Callable) -> void:
	_expect_errors = callback


func _ok(value: bool, label: String) -> void:
	_check.call(value, "recovered autosave: " + label)


func _expecting(value: bool) -> void:
	if _expect_errors.is_valid():
		_expect_errors.call(value)


func _open() -> DeckBuilderScreen:
	var scene := load(Routes.scene_path(Routes.DECK_BUILDER)).instantiate() as DeckBuilderScreen
	_tree.root.add_child(scene)
	return scene


func run() -> void:
	CardDatabase.load_directory()
	var previous_profile: Dictionary = AppState.profile
	var previous_manager: SaveManager = AppState._save_manager
	var path := "user://odraveth_smoke_test/recovered_autosave.json"
	AppState._save_manager = SaveManager.new(path)
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	var scene := _open()
	var first_id := scene.draft.id
	_ok(scene.find_child("SaveDeckButton", true, false) == null, "no manual Save button")
	_ok(PlayerSetupData.decks_for(SaveManager.new(path).load_data(), HeroCatalog.KEZHARYN).size() == 1,
		"new empty deck is immediately persisted to disk")
	scene._add_card("ashravael_cinderclaw")
	scene.name_edit.text = "Пепельная проба"
	scene.name_edit.text_changed.emit(scene.name_edit.text)
	var stored := PlayerSetupData.decks_for(SaveManager.new(path).load_data(), HeroCatalog.KEZHARYN)[0]
	_ok(stored.id == first_id and stored.name == "Пепельная проба" and stored.card_ids == ["ashravael_cinderclaw"],
		"card and Cyrillic rename survive disk round-trip without Save")
	scene.name_edit.text = ""
	scene.name_edit.text_changed.emit("")
	stored = PlayerSetupData.decks_for(SaveManager.new(path).load_data(), HeroCatalog.KEZHARYN)[0]
	_ok(stored.name.is_empty() and not stored.is_ready(CardDatabase), "blank name is a preserved draft, never playable")
	scene.name_edit.text = "Пепельная проба"
	scene.name_edit.text_changed.emit(scene.name_edit.text)
	scene._ask_clear()
	scene.clear_dialog.cancel()
	_ok(scene.draft.card_ids.size() == 1, "cancel clear preserves cards")
	scene._ask_clear()
	scene.clear_dialog._accept()
	stored = PlayerSetupData.decks_for(SaveManager.new(path).load_data(), HeroCatalog.KEZHARYN)[0]
	_ok(stored.card_ids.is_empty(), "confirmed clear persists empty draft")
	scene._add_card("ashravael_cinderclaw")
	scene._new_deck()
	var second_id := scene.draft.id
	_ok(second_id != first_id and AppState.profile["user_decks"].size() == 2, "new deck creates one distinct saved ID")
	scene._open_deck_id(first_id)
	_ok(scene.draft.card_ids == ["ashravael_cinderclaw"] and scene.draft.name == "Пепельная проба",
		"switching restores first deck without losing edits")
	scene.free()
	AppState.profile = SaveManager.new(path).load_data()
	scene = _open()
	_ok(scene.draft.id == first_id and scene.draft.card_ids == ["ashravael_cinderclaw"],
		"reopened editor restores saved draft")

	var fail_manager := FailingSaveManager.new(path)
	AppState._save_manager = fail_manager
	var profile_before := AppState.profile.duplicate(true)
	var disk_before := FileAccess.get_file_as_string(path)
	_expecting(true)
	scene._remove_card("ashravael_cinderclaw")
	_ok(scene.has_unsaved_changes() and scene.draft.card_ids.is_empty(), "failed write retains draft on screen")
	_ok(AppState.profile == profile_before and FileAccess.get_file_as_string(path) == disk_before,
		"failed write preserves old in-memory and on-disk profile")
	scene._new_deck()
	_ok(scene.save_error_dialog.visible and scene.draft.id == first_id, "failed write blocks new deck")
	scene.save_error_dialog.cancel()
	_ok(scene.handle_back_request() and scene.save_error_dialog.visible, "failed write blocks Back with retry dialog")
	scene.save_error_dialog.cancel()
	var second_index := -1
	for i in scene.deck_select.item_count:
		if String(scene.deck_select.get_item_metadata(i)) == second_id:
			second_index = i
	scene._open_selected(second_index)
	_ok(scene.save_error_dialog.visible and scene.draft.id == first_id, "failed write blocks switching and restores selector")
	_expecting(false)
	fail_manager.fail = false
	scene.save_error_dialog._accept()
	stored = PlayerSetupData.decks_for(SaveManager.new(path).load_data(), HeroCatalog.KEZHARYN)[0]
	_ok(stored.id == first_id and stored.card_ids.is_empty() and scene.draft.id == second_id,
		"retry saves retained edit, then performs requested switch")
	_ok(AppState.profile["user_decks"].size() == 2 and not scene.has_unsaved_changes(), "retry creates no duplicate deck")
	scene.free()
	AppState.profile = previous_profile
	AppState._save_manager = previous_manager
	await _tree.process_frame
