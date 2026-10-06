class_name CardSchema
extends RefCounted
## Strict validation of one card JSON object and its conversion to CardDefinition
## (format: docs/ARCHITECTURE.md section 8).
##
## Every problem makes the card invalid; nothing is corrected silently. The only
## conversion is JSON's integral floats (1.0) to int after validation.

const REQUIRED_FIELDS: Array[String] = [
	"id", "name_en", "name_ru", "faction", "type", "rarity", "cost", "deck_limit", "rules_text_ru", "effects",
]
const CREATURE_STAT_FIELDS: Array[String] = ["attack", "health", "armor"]
const CHARGES_FIELD := "charges"
const EFFECT_REQUIRED_FIELDS: Array[String] = ["effect_id", "trigger", "actions"]
const EFFECT_OPTIONAL_FIELDS: Array[String] = ["keyword", "conditions", "limits"]
const KEYWORD_ONLY_TRIGGER := "STATIC"

static var _identifier_regex := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
static var _english_name_regex := RegEx.create_from_string("^[A-Za-z]+([ '-][A-Za-z]+)*$")
static var _cyrillic_regex := RegEx.create_from_string("[А-Яа-яЁё]")
static var _latin_regex := RegEx.create_from_string("[A-Za-z]")


## Returns every problem found in [param data]; empty means the card is valid.
static func validate(data: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	for key: Variant in data.keys():
		if not (str(key) in REQUIRED_FIELDS or str(key) in CREATURE_STAT_FIELDS or str(key) == CHARGES_FIELD):
			problems.append("unknown field '%s'" % key)
	for field in REQUIRED_FIELDS:
		if not data.has(field):
			problems.append("missing field '%s'" % field)
	if not problems.is_empty():
		return problems

	if not _is_identifier(data["id"]):
		problems.append("'id' must be a snake_case identifier")
	if typeof(data["name_en"]) != TYPE_STRING or _english_name_regex.search(data["name_en"]) == null:
		problems.append("'name_en' must be a non-empty English name")
	if not _is_russian_text(data["name_ru"]):
		problems.append("'name_ru' must be a non-empty Russian name")
	if not _is_enum_key(Faction.Id, data["faction"]):
		problems.append("'faction' must be one of %s" % [Faction.Id.keys()])
	var type_known := _is_enum_key(CardEnums.Type, data["type"])
	if not type_known:
		problems.append("'type' must be one of %s" % [CardEnums.Type.keys()])
	if not _is_integer_at_least(data["cost"], 0):
		problems.append("'cost' must be an integer >= 0")
	if _is_enum_key(CardEnums.Rarity, data["rarity"]):
		var expected_limit := GameRules.max_copies_in_deck(CardEnums.Rarity[data["rarity"]] as CardEnums.Rarity)
		if not _is_integral(data["deck_limit"]) or roundi(data["deck_limit"]) != expected_limit:
			problems.append("'deck_limit' must be %d for %s" % [expected_limit, data["rarity"]])
	else:
		problems.append("'rarity' must be one of %s" % [CardEnums.Rarity.keys()])
	if type_known:
		_check_type_fields(data, problems)
		_check_effects(data, problems)
	return problems


## Builds the definition from data that passed [method validate].
static func build(data: Dictionary) -> CardDefinition:
	var card := CardDefinition.new()
	card.id = StringName(data["id"])
	card.name_en = data["name_en"]
	card.name_ru = data["name_ru"]
	card.faction = Faction.Id[data["faction"]] as Faction.Id
	card.card_type = CardEnums.Type[data["type"]] as CardEnums.Type
	card.rarity = CardEnums.Rarity[data["rarity"]] as CardEnums.Rarity
	card.cost = roundi(data["cost"])
	card.deck_limit = roundi(data["deck_limit"])
	card.rules_text_ru = data["rules_text_ru"]
	card.attack = roundi(data.get("attack", 0))
	card.health = roundi(data.get("health", 0))
	card.armor = roundi(data.get("armor", 0))
	card.charges = roundi(data.get(CHARGES_FIELD, 0))
	for effect_data: Dictionary in data["effects"]:
		var effect := CardEffectSpec.new()
		effect.effect_id = StringName(effect_data["effect_id"])
		effect.keyword = StringName(effect_data.get("keyword", ""))
		effect.trigger = StringName(effect_data["trigger"])
		effect.conditions.assign(_with_int_numbers(effect_data.get("conditions", [])))
		effect.actions.assign(_with_int_numbers(effect_data["actions"]))
		effect.limits = _with_int_numbers(effect_data.get("limits", {}))
		card.effects.append(effect)
	return card


static func _check_type_fields(data: Dictionary, problems: PackedStringArray) -> void:
	var card_type: String = data["type"]
	if card_type == "CREATURE":
		for stat in CREATURE_STAT_FIELDS:
			if not data.has(stat):
				problems.append("creature needs '%s'" % stat)
		if data.has("attack") and not _is_integer_at_least(data["attack"], 0):
			problems.append("'attack' must be an integer >= 0")
		if data.has("health") and not _is_integer_at_least(data["health"], 1):
			problems.append("'health' must be an integer >= 1")
		if data.has("armor") and not _is_integer_at_least(data["armor"], 0):
			problems.append("'armor' must be an integer >= 0")
	else:
		for stat in CREATURE_STAT_FIELDS:
			if data.has(stat):
				problems.append("%s must not have creature stat '%s'" % [card_type, stat])
	if data.has(CHARGES_FIELD):
		if card_type != "ARTIFACT":
			problems.append("only ARTIFACT cards can have 'charges'")
		elif not _is_integer_at_least(data[CHARGES_FIELD], 1):
			problems.append("'charges' must be an integer >= 1")


static func _check_effects(data: Dictionary, problems: PackedStringArray) -> void:
	var rules_text: Variant = data["rules_text_ru"]
	var effects: Variant = data["effects"]
	if typeof(rules_text) != TYPE_STRING:
		problems.append("'rules_text_ru' must be a string")
		return
	if typeof(effects) != TYPE_ARRAY:
		problems.append("'effects' must be an array")
		return
	if rules_text.is_empty() != effects.is_empty():
		problems.append("'rules_text_ru' and 'effects' must be both empty or both present")
	if not rules_text.is_empty() and (rules_text != rules_text.strip_edges() or not _is_russian_text(rules_text)):
		problems.append("'rules_text_ru' must be Russian text without surrounding spaces")

	var effect_ids := {}
	var spends_charges := false
	for index in effects.size():
		var path := "effects[%d]" % index
		var effect: Variant = effects[index]
		if typeof(effect) != TYPE_DICTIONARY:
			problems.append("%s must be an object" % path)
			continue
		_check_effect(effect, data["type"], path, problems)
		var effect_id: Variant = effect.get("effect_id")
		if effect_ids.has(effect_id):
			problems.append("%s: duplicate effect_id '%s'" % [path, effect_id])
		effect_ids[effect_id] = true
		for action: Variant in effect.get("actions", []):
			if typeof(action) == TYPE_DICTIONARY and action.get("type") == "SPEND_CHARGES":
				spends_charges = true

	if spends_charges and not data.has(CHARGES_FIELD):
		problems.append("effects spend charges, but the card has no 'charges'")
	if data.has(CHARGES_FIELD) and not spends_charges:
		problems.append("'charges' is set, but no effect spends charges")


static func _check_effect(effect: Dictionary, card_type: String, path: String, problems: PackedStringArray) -> void:
	for key: Variant in effect.keys():
		if not (str(key) in EFFECT_REQUIRED_FIELDS or str(key) in EFFECT_OPTIONAL_FIELDS):
			problems.append("%s: unknown field '%s'" % [path, key])
	for field in EFFECT_REQUIRED_FIELDS:
		if not effect.has(field):
			problems.append("%s: missing field '%s'" % [path, field])
	if not effect.has_all(EFFECT_REQUIRED_FIELDS):
		return

	if not _is_identifier(effect["effect_id"]):
		problems.append("%s: 'effect_id' must be a snake_case identifier" % path)
	var trigger: Variant = effect["trigger"]
	if not (typeof(trigger) == TYPE_STRING and EffectVocabulary.TRIGGERS.has(trigger)):
		problems.append("%s: unknown trigger '%s'" % [path, trigger])
	elif card_type not in EffectVocabulary.TRIGGERS[trigger]:
		problems.append("%s: trigger %s is not allowed for %s cards" % [path, trigger, card_type])
	if effect.has("keyword"):
		var problem := _kind_problem("keyword", effect["keyword"])
		if not problem.is_empty():
			problems.append("%s.keyword: %s" % [path, problem])
	if effect.has("conditions"):
		_check_conditions(effect["conditions"], "%s.conditions" % path, problems)
	if effect.has("limits"):
		_check_limits(effect["limits"], "%s.limits" % path, problems)

	var actions: Variant = effect["actions"]
	if typeof(actions) != TYPE_ARRAY:
		problems.append("%s: 'actions' must be an array" % path)
		return
	if actions.is_empty() and not (effect.has("keyword") and trigger == KEYWORD_ONLY_TRIGGER):
		problems.append("%s: 'actions' may be empty only for a %s keyword ability" % [path, KEYWORD_ONLY_TRIGGER])
	for index in actions.size():
		_check_action(actions[index], "%s.actions[%d]" % [path, index], problems)


static func _check_conditions(conditions: Variant, path: String, problems: PackedStringArray) -> void:
	if typeof(conditions) != TYPE_ARRAY:
		problems.append("%s must be an array" % path)
		return
	for index in conditions.size():
		var item_path := "%s[%d]" % [path, index]
		var condition: Variant = conditions[index]
		if typeof(condition) != TYPE_DICTIONARY or not EffectVocabulary.CONDITIONS.has(condition.get("type")):
			problems.append("%s: unknown condition %s" % [item_path, condition])
			continue
		_check_parameters(EffectVocabulary.CONDITIONS[condition["type"]], condition, item_path, problems)


static func _check_action(action: Variant, path: String, problems: PackedStringArray) -> void:
	if typeof(action) != TYPE_DICTIONARY or not EffectVocabulary.ACTIONS.has(action.get("type")):
		problems.append("%s: unknown action %s" % [path, action])
		return
	var action_type: String = action["type"]
	var spec: Dictionary = EffectVocabulary.ACTIONS[action_type].duplicate()
	spec["conditions"] = "?conditions"
	_check_parameters(spec, action, path, problems)
	if EffectVocabulary.EXACTLY_ONE_OF.has(action_type):
		var options: Array = EffectVocabulary.EXACTLY_ONE_OF[action_type]
		if options.filter(func(option: String) -> bool: return action.has(option)).size() != 1:
			problems.append("%s: %s needs exactly one of %s" % [path, action_type, options])
	if EffectVocabulary.AT_LEAST_ONE_OF.has(action_type):
		var options: Array = EffectVocabulary.AT_LEAST_ONE_OF[action_type]
		if not options.any(func(option: String) -> bool: return action.has(option)):
			problems.append("%s: %s needs at least one of %s" % [path, action_type, options])


static func _check_limits(limits: Variant, path: String, problems: PackedStringArray) -> void:
	if typeof(limits) != TYPE_DICTIONARY:
		problems.append("%s must be an object" % path)
		return
	_check_parameters(EffectVocabulary.LIMITS, limits, path, problems, false)


## Checks [param data] against [param spec] (parameter -> kind). "type" is the
## identifier itself and is skipped when [param has_type] is true.
static func _check_parameters(spec: Dictionary, data: Dictionary, path: String, problems: PackedStringArray, has_type: bool = true) -> void:
	for key: Variant in data.keys():
		if has_type and str(key) == "type":
			continue
		if not spec.has(str(key)):
			problems.append("%s: unknown parameter '%s'" % [path, key])
	for parameter: String in spec:
		var kind: String = spec[parameter]
		var optional := kind.begins_with("?")
		kind = kind.trim_prefix("?")
		if not data.has(parameter):
			if not optional:
				problems.append("%s: missing parameter '%s'" % [path, parameter])
			continue
		if kind == "conditions":
			_check_conditions(data[parameter], "%s.%s" % [path, parameter], problems)
			continue
		var problem := _kind_problem(kind, data[parameter])
		if not problem.is_empty():
			problems.append("%s.%s: %s" % [path, parameter, problem])


## Returns a problem description, or an empty string when [param value] fits [param kind].
static func _kind_problem(kind: String, value: Variant) -> String:
	match kind:
		"int+":
			return "" if _is_integer_at_least(value, 1) else "must be an integer >= 1"
		"int0":
			return "" if _is_integer_at_least(value, 0) else "must be an integer >= 0"
		"bool":
			return "" if typeof(value) == TYPE_BOOL else "must be true or false"
		"true":
			return "" if typeof(value) == TYPE_BOOL and value else "must be true"
		"target":
			return _one_of(value, EffectVocabulary.TARGETS)
		"duration":
			return _one_of(value, EffectVocabulary.DURATIONS)
		"keyword":
			return _one_of(value, EffectVocabulary.KEYWORDS)
		"delay":
			return _one_of(value, EffectVocabulary.DELAYS)
		"multiplier":
			return _one_of(value, EffectVocabulary.MULTIPLIERS)
		"card_type":
			return "" if _is_enum_key(CardEnums.Type, value) else "must be one of %s" % [CardEnums.Type.keys()]
	return "unknown parameter kind '%s'" % kind


static func _one_of(value: Variant, allowed: Array[String]) -> String:
	return "" if typeof(value) == TYPE_STRING and value in allowed else "must be one of %s" % [allowed]


## Deep copy of JSON data with integral floats converted to int.
static func _with_int_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return roundi(value)
		TYPE_ARRAY:
			return value.map(_with_int_numbers)
		TYPE_DICTIONARY:
			var result := {}
			for key: Variant in value:
				result[key] = _with_int_numbers(value[key])
			return result
	return value


static func _is_identifier(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and _identifier_regex.search(value) != null


static func _is_russian_text(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty() \
		and _cyrillic_regex.search(value) != null and _latin_regex.search(value) == null


static func _is_enum_key(enum_values: Dictionary, value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and enum_values.has(value)


static func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value))


static func _is_integer_at_least(value: Variant, minimum: int) -> bool:
	return _is_integral(value) and roundi(value) >= minimum
