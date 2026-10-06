extends Node
## Read-only registry of the approved card definitions (autoload "CardDatabase").
##
## Pipeline: res://data/cards/*.json -> CardSchema validation -> CardDefinition.
## Loading is all-or-nothing: if any file or card is invalid, nothing is replaced.
## Callers only ever receive copies, never the registry's own instances.
##
## File format: {"cards": [ {card}, ... ]}, one file per faction
## (docs/ARCHITECTURE.md section 8).

const DEFAULT_CARDS_DIR := "res://data/cards"
const CARDS_KEY := "cards"
## Card fields that must be unique across the whole database (names case-insensitively).
const UNIQUE_FIELDS: Array[String] = ["id", "name_en", "name_ru"]

var _cards: Dictionary = {}
var _sorted_ids := PackedStringArray()
var _last_load_problems := PackedStringArray()


## Replaces the contents with every card found in [param dir_path].
## On failure the previous contents stay untouched and
## [method get_last_load_problems] lists every problem found.
func load_directory(dir_path: String = DEFAULT_CARDS_DIR) -> Error:
	var problems := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir_path):
		problems.append("directory '%s' not found" % dir_path)
		return _fail(ERR_FILE_NOT_FOUND, problems)
	var file_names := Array(DirAccess.get_files_at(dir_path)).filter(
		func(file_name: String) -> bool: return file_name.get_extension() == "json")
	file_names.sort()
	if file_names.is_empty():
		problems.append("no *.json card files in '%s'" % dir_path)
		return _fail(ERR_FILE_NOT_FOUND, problems)

	var loaded := {}
	var seen := {}
	for field in UNIQUE_FIELDS:
		seen[field] = {}
	var parse_failed := false
	for file_name: String in file_names:
		var path := dir_path.path_join(file_name)
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			problems.append("%s:%d: invalid JSON: %s" % [path, json.get_error_line(), json.get_error_message()])
			parse_failed = true
			continue
		var data: Variant = json.data
		if typeof(data) != TYPE_DICTIONARY or data.keys() != [CARDS_KEY] or typeof(data[CARDS_KEY]) != TYPE_ARRAY:
			problems.append("%s: expected an object with only a \"%s\" array" % [path, CARDS_KEY])
			continue
		var entries: Array = data[CARDS_KEY]
		for index in entries.size():
			var where := "%s: cards[%d]" % [path, index]
			var entry: Variant = entries[index]
			if typeof(entry) != TYPE_DICTIONARY:
				problems.append("%s: must be an object" % where)
				continue
			var card_problems := CardSchema.validate(entry)
			if not card_problems.is_empty():
				for problem in card_problems:
					problems.append("%s (%s): %s" % [where, entry.get("id", "?"), problem])
				continue
			if _register_unique_fields(entry, where, seen, problems):
				loaded[StringName(entry["id"])] = CardSchema.build(entry)

	if not problems.is_empty():
		return _fail(ERR_PARSE_ERROR if parse_failed else ERR_INVALID_DATA, problems)
	_cards = loaded
	_sorted_ids = PackedStringArray(loaded.keys())
	_sorted_ids.sort()
	_last_load_problems = PackedStringArray()
	return OK


## Problems of the last failed [method load_directory] call; empty after success.
func get_last_load_problems() -> PackedStringArray:
	return _last_load_problems.duplicate()


func has_card(id: StringName) -> bool:
	return _cards.has(id)


## Returns a copy of the definition, or null for an unknown id.
func get_card(id: StringName) -> CardDefinition:
	var card: CardDefinition = _cards.get(id)
	return card.copy() if card != null else null


## Card ids in ascending order.
func get_card_ids() -> PackedStringArray:
	return _sorted_ids.duplicate()


func get_card_count() -> int:
	return _cards.size()


## Copies of every definition, ordered by id.
func get_all_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for id in _sorted_ids:
		cards.append(_cards[StringName(id)].copy())
	return cards


func _register_unique_fields(entry: Dictionary, where: String, seen: Dictionary, problems: PackedStringArray) -> bool:
	var unique := true
	for field in UNIQUE_FIELDS:
		var value: String = entry[field]
		var key := value if field == "id" else value.strip_edges().to_lower()
		if seen[field].has(key):
			problems.append("%s: duplicate %s '%s' (first in %s)" % [where, field, value, seen[field][key]])
			unique = false
		else:
			seen[field][key] = where
	return unique


func _fail(error: Error, problems: PackedStringArray) -> Error:
	_last_load_problems = problems
	for problem in problems:
		push_error("CardDatabase: %s." % problem)
	return error
