class_name SaveManager
extends RefCounted
## Local, offline persistence of the player profile as versioned JSON.
##
## - The file lives under user:// (app-private storage on Android). No cloud, no network.
## - Every save carries [constant VERSION_KEY] so later formats can be migrated.
## - Writes are atomic (temporary file + rename): a crash cannot leave a half-written save.
## - A save written by a newer game version is never overwritten.
## - An unparseable save is copied aside before defaults are used.
##
## Not an autoload: AppState owns the game instance; tests create their own
## instance with a temporary path.
##
## JSON stores every number as a float. Code reading values from the loaded
## data must convert them to the expected type explicitly.

enum LoadStatus {
	NOT_LOADED, ## [method load_data] has not been called yet.
	OK, ## Save loaded (and migrated if it was older).
	NOT_FOUND, ## No save yet (first launch); defaults returned.
	CORRUPTED, ## Save could not be parsed; a copy was kept, defaults returned.
	READ_FAILED, ## Save exists but cannot be opened; defaults returned, writing blocked.
	UNSUPPORTED_VERSION, ## Save is from a newer game version; defaults returned, writing blocked.
}

const CURRENT_SAVE_VERSION := 1
const VERSION_KEY := "save_version"
const DEFAULT_SAVE_PATH := "user://odraveth_save.json"
const TEMP_SUFFIX := ".tmp"
const CORRUPTED_SUFFIX := ".corrupted"

var save_path: String
var last_load_status := LoadStatus.NOT_LOADED

var _writes_blocked := false


func _init(path: String = DEFAULT_SAVE_PATH) -> void:
	save_path = path


static func create_default_data() -> Dictionary:
	return {VERSION_KEY: CURRENT_SAVE_VERSION}


## Reads the save. Always returns usable data: the stored profile (migrated to
## [constant CURRENT_SAVE_VERSION]) or defaults; see [member last_load_status].
func load_data() -> Dictionary:
	_writes_blocked = false
	if not FileAccess.file_exists(save_path):
		last_load_status = LoadStatus.NOT_FOUND
		return create_default_data()

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot open '%s': %s." % [save_path, error_string(FileAccess.get_open_error())])
		_writes_blocked = true
		last_load_status = LoadStatus.READ_FAILED
		return create_default_data()
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var version := -1
	if json.parse(text) == OK:
		version = _read_version(json.data)
	if version < 1:
		push_warning("SaveManager: '%s' is not a valid save; keeping a copy and using defaults." % save_path)
		_keep_corrupted_copy()
		last_load_status = LoadStatus.CORRUPTED
		return create_default_data()
	if version > CURRENT_SAVE_VERSION:
		push_warning("SaveManager: save version %d is newer than supported %d; it will not be overwritten." % [version, CURRENT_SAVE_VERSION])
		_writes_blocked = true
		last_load_status = LoadStatus.UNSUPPORTED_VERSION
		return create_default_data()

	var data := migrate(json.data, version)
	if data.is_empty():
		_keep_corrupted_copy()
		last_load_status = LoadStatus.CORRUPTED
		return create_default_data()
	last_load_status = LoadStatus.OK
	return data


## Writes [param data] atomically, stamped with [constant CURRENT_SAVE_VERSION].
## Returns [constant ERR_LOCKED] if the loaded save must be protected.
func write_data(data: Dictionary) -> Error:
	if _writes_blocked:
		push_warning("SaveManager: writing '%s' is blocked to protect the existing save." % save_path)
		return ERR_LOCKED
	var payload := data.duplicate(true)
	payload[VERSION_KEY] = CURRENT_SAVE_VERSION

	var directory_error := DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var temp_path := save_path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	if not stored:
		DirAccess.remove_absolute(temp_path)
		return ERR_FILE_CANT_WRITE
	return DirAccess.rename_absolute(temp_path, save_path)


## Upgrades [param data] from [param from_version] to [param to_version] one step
## at a time. The step from version N to N+1 is a method
## [code]_migrate_from_vN(data: Dictionary) -> Dictionary[/code].
## There are no steps yet: save_version 1 is the first format.
## Returns an empty Dictionary if a step is missing.
func migrate(data: Dictionary, from_version: int, to_version: int = CURRENT_SAVE_VERSION) -> Dictionary:
	var result := data.duplicate(true)
	var version := from_version
	while version < to_version:
		var step := "_migrate_from_v%d" % version
		if not has_method(step):
			push_error("SaveManager: missing migration step '%s'." % step)
			return {}
		result = call(step, result)
		version += 1
	result[VERSION_KEY] = version
	return result


func _read_version(parsed: Variant) -> int:
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	var value: Variant = parsed.get(VERSION_KEY)
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value)):
		return roundi(value)
	return -1


func _keep_corrupted_copy() -> void:
	var error := DirAccess.copy_absolute(save_path, save_path + CORRUPTED_SUFFIX)
	if error != OK:
		# Without a backup, never overwrite the only copy of the player's data.
		push_error("SaveManager: cannot back up '%s': %s; writing blocked." % [save_path, error_string(error)])
		_writes_blocked = true
