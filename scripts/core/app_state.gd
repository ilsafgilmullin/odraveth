extends Node
## Application-level state that must survive screen changes (autoload "AppState").
##
## Holds the locally persisted profile and the boot status. It deliberately does
## NOT hold match runtime state: a match belongs to the battle screen (a
## MatchEngine instance) and is handed between screens through SceneRouter params.

var is_initialized := false
## Persistent player data as loaded from / written to the local save.
var profile: Dictionary = {}

var _save_manager := SaveManager.new()


## Loads the local save once. Called by the boot screen.
func initialize() -> void:
	if is_initialized:
		return
	profile = _save_manager.load_data()
	match _save_manager.last_load_status:
		SaveManager.LoadStatus.CORRUPTED:
			EventBus.save_error.emit("Save file was unreadable; a copy was kept and defaults are used.")
		SaveManager.LoadStatus.READ_FAILED:
			EventBus.save_error.emit("Save file cannot be opened; saving is disabled for this session.")
		SaveManager.LoadStatus.UNSUPPORTED_VERSION:
			EventBus.save_error.emit("Save file is from a newer game version; saving is disabled for this session.")
	is_initialized = true


## Writes [member profile] to the local save.
func save_profile() -> Error:
	var error := _save_manager.write_data(profile)
	if error != OK:
		EventBus.save_error.emit("Failed to write the save file: %s." % error_string(error))
	return error


## Transactional profile update: a failed save does not replace in-memory data.
func persist_profile(next: Dictionary) -> Error:
	var safe := PlayerSetupData.normalized(next)
	var error := _save_manager.write_data(safe)
	if error == OK:
		profile = safe
	else:
		EventBus.save_error.emit("Не удалось сохранить данные: %s" % error_string(error))
		push_error("AppState: profile write failed: %s" % error_string(error))
	return error
