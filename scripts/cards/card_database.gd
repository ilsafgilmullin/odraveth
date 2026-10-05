extends Node
## Read-only registry of card definitions (autoload "CardDatabase").
##
## Stage 0 skeleton: loading, validation of the approved taxonomy and lookup.
## The approved card set and the final card schema are added in Stage 1; this
## script must not invent cards or mechanics.
##
## Data format (preliminary, to be confirmed in Stage 1): every *.json file in
## [constant DEFAULT_CARDS_DIR] contains [code]{"cards": [ {...}, ... ]}[/code].
## Fields checked now: id, type, rarity, faction, cost; attack, health, armor
## for creatures; optional charges for artifacts. Other fields are kept as-is.

const DEFAULT_CARDS_DIR := "res://data/cards"
const _INTEGER_FIELDS: Array[String] = ["cost", "attack", "health", "armor", "charges"]

var _cards: Dictionary = {}


## Replaces the contents with every card found in [param dir_path].
## All-or-nothing: on any error the previous contents stay untouched.
func load_directory(dir_path: String = DEFAULT_CARDS_DIR) -> Error:
	if not DirAccess.dir_exists_absolute(dir_path):
		push_error("CardDatabase: directory '%s' not found." % dir_path)
		return ERR_FILE_NOT_FOUND
	var file_names := Array(DirAccess.get_files_at(dir_path)).filter(
		func(file_name: String) -> bool: return file_name.get_extension() == "json")
	file_names.sort()

	var loaded := {}
	for file_name: String in file_names:
		var error := _load_file(dir_path.path_join(file_name), loaded)
		if error != OK:
			return error
	_cards = loaded
	return OK


## Adds one definition after validation. Returns [constant ERR_INVALID_DATA] or
## [constant ERR_ALREADY_EXISTS] when the card is rejected.
func register_card(definition: Dictionary) -> Error:
	return _add_card(definition, _cards, "register_card")


func has_card(id: String) -> bool:
	return _cards.has(id)


## Returns a copy of the definition, or an empty Dictionary for an unknown id.
func get_card(id: String) -> Dictionary:
	var definition: Dictionary = _cards.get(id, {})
	return definition.duplicate(true)


func get_card_ids() -> PackedStringArray:
	var ids := PackedStringArray(_cards.keys())
	ids.sort()
	return ids


func get_card_count() -> int:
	return _cards.size()


func clear() -> void:
	_cards.clear()


## Returns the list of problems in [param definition]; empty means valid.
static func validate_card(definition: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var id: Variant = definition.get("id")
	if typeof(id) != TYPE_STRING or (id as String).strip_edges().is_empty():
		problems.append("'id' must be a non-empty string")
	if not _is_enum_key(CardEnums.Type, definition.get("type")):
		problems.append("'type' must be one of %s" % [CardEnums.Type.keys()])
	if not _is_enum_key(CardEnums.Rarity, definition.get("rarity")):
		problems.append("'rarity' must be one of %s" % [CardEnums.Rarity.keys()])
	if not _is_enum_key(Faction.Id, definition.get("faction")):
		problems.append("'faction' must be one of %s" % [Faction.Id.keys()])
	if not _is_integer_at_least(definition.get("cost"), 0):
		problems.append("'cost' must be an integer >= 0")

	match definition.get("type"):
		"CREATURE":
			if not _is_integer_at_least(definition.get("attack"), 0):
				problems.append("creature 'attack' must be an integer >= 0")
			if not _is_integer_at_least(definition.get("health"), 1):
				problems.append("creature 'health' must be an integer >= 1")
			if not _is_integer_at_least(definition.get("armor"), 0):
				problems.append("creature 'armor' must be an integer >= 0")
		"ARTIFACT":
			if definition.has("charges") and not _is_integer_at_least(definition.get("charges"), 1):
				problems.append("artifact 'charges' must be an integer >= 1 when present")
	return problems


func _load_file(path: String, into: Dictionary) -> Error:
	var json := JSON.new()
	var error := json.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		push_error("CardDatabase: %s:%d: %s." % [path, json.get_error_line(), json.get_error_message()])
		return ERR_PARSE_ERROR
	var cards: Variant = json.data.get("cards") if typeof(json.data) == TYPE_DICTIONARY else null
	if typeof(cards) != TYPE_ARRAY:
		push_error("CardDatabase: %s: expected an object with a \"cards\" array." % path)
		return ERR_INVALID_DATA
	for definition: Variant in cards:
		if typeof(definition) != TYPE_DICTIONARY:
			push_error("CardDatabase: %s: every entry of \"cards\" must be an object." % path)
			return ERR_INVALID_DATA
		error = _add_card(definition, into, path)
		if error != OK:
			return error
	return OK


func _add_card(definition: Dictionary, into: Dictionary, source: String) -> Error:
	var problems := validate_card(definition)
	if not problems.is_empty():
		push_error("CardDatabase: %s: invalid card %s: %s." % [source, definition.get("id", "<no id>"), "; ".join(problems)])
		return ERR_INVALID_DATA
	var id: String = definition.id
	if into.has(id):
		push_error("CardDatabase: %s: duplicate card id '%s'." % [source, id])
		return ERR_ALREADY_EXISTS
	var stored := definition.duplicate(true)
	# JSON numbers arrive as floats; keep validated integer fields as int.
	for field in _INTEGER_FIELDS:
		if _is_integral(stored.get(field)):
			stored[field] = roundi(stored[field])
	stored.make_read_only()
	into[id] = stored
	return OK


static func _is_enum_key(enum_values: Dictionary, value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and enum_values.has(value)


static func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value))


static func _is_integer_at_least(value: Variant, minimum: int) -> bool:
	return _is_integral(value) and roundi(value) >= minimum
