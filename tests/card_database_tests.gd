extends RefCounted
## Stage 1 card tests: the 40 approved cards, data integrity and strict
## CardDatabase validation. Run by tests/smoke_test.gd with its check helpers.
##
## Negative fixtures are fictional "test_" cards built in memory and written to a
## temporary user:// directory; they never touch res://data/cards.

const CardDatabaseScript := preload("res://scripts/cards/card_database.gd")
const ApprovedCards := preload("res://tests/approved_cards.gd")
const FACTION_FILES: Array[String] = ["ashravael.json", "dumoryss.json", "khevaruun.json", "nerqathen.json", "neutral.json"]
const VANILLA_CARD_IDS: Array[String] = ["khevaruun_aegis_hound", "neutral_rivenshade_grazer", "neutral_vantrel_duskling"]
const PROVOKE_CARD_IDS: Array[String] = ["khevaruun_ironwarden", "khevaruun_wallforged", "nerqathen_mourning_husk"]
const SOUL_SHARD_IDENTIFIERS: Array[String] = [
	"GAIN_SOUL_SHARDS", "SPEND_SOUL_SHARDS", "OWN_SOUL_SHARDS_AT_LEAST", "SOUL_SHARDS_SPENT_EQUALS",
]
## Timing of every event-triggered ability, transcribed from the approved texts:
## «после» / «после того как» -> AFTER; «когда» or no wording (cost and play
## moments) -> WHEN (docs/PRODUCT_BASELINE.md section 6.7).
const EXPECTED_TIMINGS := {
	"ashravael_cinderclaw/frenzy": "AFTER",
	"ashravael_emberbound/hero_damaged_attack_bonus": "AFTER",
	"ashravael_warfiend/second_attack": "AFTER",
	"ashravael_furnace_sigil/furnace": "WHEN",
	"nerqathen_bone_cantor/ally_death_attack": "AFTER",
	"nerqathen_ossuary_bell/toll": "WHEN",
	"dumoryss_veilbreaker/taxed_card_attack": "WHEN",
	"dumoryss_null_seer/increased_cost_paid": "WHEN",
	"dumoryss_echo_leech/echo": "AFTER",
	"dumoryss_nullglass/nullglass": "WHEN",
	"khevaruun_shieldroot/armor_broken_attack": "WHEN",
	"khevaruun_wallforged/armor_reforge": "WHEN",
	"khevaruun_bastion_core/first_creature_armor": "WHEN",
	"neutral_sablequill_nomad/survivor_health": "AFTER",
}

var _check: Callable
var _expect_errors: Callable
var _temp_dir: String
var _database: Node


func _init(check: Callable, expect_errors: Callable, temp_dir: String) -> void:
	_check = check
	_expect_errors = expect_errors
	_temp_dir = temp_dir


func run() -> void:
	_database = CardDatabaseScript.new()
	_test_project_data_loads()
	_test_approved_values()
	_test_baseline_catalog()
	_test_distribution()
	_test_integrity()
	_test_effect_data()
	_test_vocabulary_is_used()
	_test_copies_are_isolated()
	_test_determinism()
	_test_invalid_fixtures()
	_test_partial_load()
	_database.free()


# --- Approved data -----------------------------------------------------------

func _test_project_data_loads() -> void:
	var files := Array(DirAccess.get_files_at(CardDatabaseScript.DEFAULT_CARDS_DIR)).filter(
		func(file_name: String) -> bool: return file_name.get_extension() == "json")
	files.sort()
	_ok(files == FACTION_FILES, "res://data/cards has exactly the five faction files: %s" % [files])
	_ok(_database.load_directory() == OK and _database.get_last_load_problems().is_empty(),
		"CardDatabase loads res://data/cards without problems")
	_ok(_database.get_card_count() == 40, "exactly 40 cards (%d)" % _database.get_card_count())

	for file_name in FACTION_FILES:
		var single_dir := _fresh_dir("single")
		_write(single_dir.path_join(file_name), FileAccess.get_file_as_string(
			CardDatabaseScript.DEFAULT_CARDS_DIR.path_join(file_name)))
		var single: Node = CardDatabaseScript.new()
		_ok(single.load_directory(single_dir) == OK and single.get_card_count() == 8,
			"%s loads on its own with 8 cards" % file_name)
		single.free()


func _test_approved_values() -> void:
	var expected_ids := PackedStringArray(ApprovedCards.CARDS.map(func(row: Array) -> String: return row[0]))
	expected_ids.sort()
	_ok(_database.get_card_ids() == expected_ids, "card ids are exactly the 40 approved ids")
	for index in ApprovedCards.CARDS.size():
		var row: Array = ApprovedCards.CARDS[index]
		var card: CardDefinition = _database.get_card(row[0])
		var mismatches := _approved_mismatches(card, row)
		_ok(mismatches.is_empty(), "%02d %s matches the approved values%s" % [
			index + 1, row[0], "" if mismatches.is_empty() else ": " + ", ".join(mismatches)])


func _approved_mismatches(card: CardDefinition, row: Array) -> PackedStringArray:
	if card == null:
		return PackedStringArray(["card missing"])
	var actual := [
		String(card.id), card.name_en, card.name_ru, Faction.Id.find_key(card.faction),
		CardEnums.Type.find_key(card.card_type), CardEnums.Rarity.find_key(card.rarity), card.cost,
		card.attack, card.health, card.armor, card.charges, card.deck_limit, card.rules_text_ru,
	]
	var fields := ["id", "name_en", "name_ru", "faction", "type", "rarity", "cost", "attack", "health",
		"armor", "charges", "deck_limit", "rules_text_ru"]
	var mismatches := PackedStringArray()
	for field_index in fields.size():
		if typeof(actual[field_index]) != typeof(row[field_index]) or actual[field_index] != row[field_index]:
			mismatches.append("%s is %s, approved %s" % [fields[field_index], actual[field_index], row[field_index]])
	return mismatches


## docs/PRODUCT_BASELINE.md section 6.6 must list every approved card with the same values.
func _test_baseline_catalog() -> void:
	var baseline := FileAccess.get_file_as_string("res://docs/PRODUCT_BASELINE.md")
	var missing := PackedStringArray()
	for index in ApprovedCards.CARDS.size():
		var row: Array = ApprovedCards.CARDS[index]
		var stats := "%d / %d / %d" % [row[7], row[8], row[9]] if row[4] == "CREATURE" else "—"
		var line := "| %02d | `%s` | %s | %s | %s | %s | %d | %s | %s | %d | %s |" % [index + 1, row[0], row[2], row[1],
			row[4], row[5], row[6], stats, str(row[10]) if row[10] > 0 else "—", row[11],
			row[12] if not row[12].is_empty() else "нет способности"]
		if not baseline.contains(line):
			missing.append(row[0])
	_ok(not baseline.is_empty() and missing.is_empty(),
		"PRODUCT_BASELINE card catalog matches the approved values %s" % [missing])


func _test_distribution() -> void:
	var cards: Array[CardDefinition] = _database.get_all_cards()
	var by_faction := _count(cards, func(card: CardDefinition) -> String: return Faction.Id.find_key(card.faction))
	var by_type := _count(cards, func(card: CardDefinition) -> String: return CardEnums.Type.find_key(card.card_type))
	var by_rarity := _count(cards, func(card: CardDefinition) -> String: return CardEnums.Rarity.find_key(card.rarity))
	_ok(by_faction == {"ASHRAVAEL": 8, "NERQATHEN": 8, "DUMORYSS": 8, "KHEVARUUN": 8, "NEUTRAL": 8},
		"8 cards per faction: %s" % by_faction)
	_ok(by_type == {"CREATURE": 27, "SPELL": 9, "ARTIFACT": 4}, "27 CREATURE, 9 SPELL, 4 ARTIFACT, 0 CURSE: %s" % by_type)
	_ok(CardEnums.Type.has("CURSE"), "CURSE stays a supported card type")
	_ok(by_rarity == {"COMMON": 16, "RARE": 13, "EPIC": 7, "LEGENDARY": 4}, "rarities 16 / 13 / 7 / 4: %s" % by_rarity)


func _test_integrity() -> void:
	var cards: Array[CardDefinition] = _database.get_all_cards()
	for field in ["id", "name_en", "name_ru"]:
		var values := {}
		for card in cards:
			values[str(card.get(field)).to_lower()] = true
		_ok(values.size() == 40, "all 40 %s values are unique" % field)

	_ok(cards.all(func(card: CardDefinition) -> bool: return card.deck_limit == GameRules.max_copies_in_deck(card.rarity)),
		"deck_limit matches rarity for every card")
	_ok(cards.filter(func(card: CardDefinition) -> bool: return card.rarity == CardEnums.Rarity.LEGENDARY)
		.all(func(card: CardDefinition) -> bool: return card.deck_limit == 1), "every legendary card has deck_limit 1")
	_ok(cards.all(func(card: CardDefinition) -> bool:
			return String(card.id).begins_with(str(Faction.Id.find_key(card.faction)).to_lower() + "_")),
		"every id starts with its faction")

	var misplaced := PackedStringArray()
	for file_name in FACTION_FILES:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			CardDatabaseScript.DEFAULT_CARDS_DIR.path_join(file_name)))
		for entry: Dictionary in data["cards"]:
			if str(entry["faction"]).to_lower() != file_name.get_basename():
				misplaced.append("%s in %s" % [entry["id"], file_name])
	_ok(misplaced.is_empty(), "every faction file holds only its own faction %s" % [misplaced])

	var forbidden := cards.filter(func(card: CardDefinition) -> bool:
		return card.name_ru in ApprovedCards.FORBIDDEN_CARD_NAMES_RU or card.name_en in ApprovedCards.FORBIDDEN_CARD_NAMES_EN \
			or String(card.id).contains("soul_shard") or String(card.id).contains("impulse"))
	_ok(forbidden.is_empty(), "Soul Shard, Impulse Shard, heroes and hero abilities are not cards")

	var shard_users := cards.filter(func(card: CardDefinition) -> bool: return _uses_any(card, SOUL_SHARD_IDENTIFIERS))
	_ok(not shard_users.is_empty() and shard_users.all(
			func(card: CardDefinition) -> bool: return card.faction == Faction.Id.NERQATHEN),
		"Soul Shard effects appear only on Nerqathen cards (%d)" % shard_users.size())

	var vanilla := PackedStringArray(cards.filter(func(card: CardDefinition) -> bool: return card.effects.is_empty())
		.map(func(card: CardDefinition) -> String: return String(card.id)))
	_ok(vanilla == PackedStringArray(VANILLA_CARD_IDS), "only the approved vanilla creatures have no effects: %s" % [vanilla])

	for faction: String in ["ASHRAVAEL", "NERQATHEN", "DUMORYSS", "KHEVARUUN"]:
		var copies := 0
		for card in cards:
			if Faction.Id.find_key(card.faction) in [faction, "NEUTRAL"]:
				copies += card.deck_limit
		_ok(copies >= GameRules.DECK_SIZE, "a %d-card %s deck can be built (%d copies available)" % [
			GameRules.DECK_SIZE, faction, copies])


func _test_effect_data() -> void:
	var cinderclaw: CardDefinition = _database.get_card(&"ashravael_cinderclaw")
	var frenzy := cinderclaw.effects[0]
	_ok(cinderclaw.effects.size() == 1 and frenzy.keyword == &"FRENZY" and frenzy.trigger == &"SELF_DAMAGED"
		and frenzy.limits == {"per_turn": 1}, "Cinderclaw: Frenzy reacts to damage to the creature itself, once per turn")

	var wayfarer: CardDefinition = _database.get_card(&"neutral_orryxian_wayfarer")
	_ok(wayfarer.effects.size() == 1 and wayfarer.effects[0].trigger == &"STATIC",
		"Orryxian Wayfarer: constant condition, not Enter Battle")

	var soulmonger: CardDefinition = _database.get_card(&"nerqathen_soulmonger")
	var feast := soulmonger.effects[0].actions
	_ok(feast[0] == {"type": "SPEND_SOUL_SHARDS", "up_to": 3} and feast[1].get("multiplier") == "SOUL_SHARDS_SPENT"
		and feast[2]["conditions"] == [{"type": "SOUL_SHARDS_SPENT_EQUALS", "value": 3}],
		"Soulmonger: optional spend of up to 3 shards, per-shard bonus, armor at exactly 3")

	var binder: CardDefinition = _database.get_card(&"nerqathen_pale_binder")
	_ok(binder.effects[0].conditions == [{"type": "OWN_SOUL_SHARDS_AT_LEAST", "value": 1}]
		and not _uses_any(binder, ["SPEND_SOUL_SHARDS"]), "Pale Binder: needs 1 shard and does not spend it")

	var echo := _database.get_card(&"dumoryss_echo_leech").effects[0] as CardEffectSpec
	_ok(echo.actions == [{"type": "CREATE_ECHO_IN_HAND", "min_cost": 1, "expires": "END_OF_YOUR_NEXT_TURN"}]
		and echo.conditions == [{"type": "PLAYED_CARD_TYPE", "card_type": "SPELL"}] and echo.limits == {"per_turn": 1},
		"Echo Leech: first opponent spell per turn, Echo cost at least 1, no other cost rules")

	var nullglass := _database.get_card(&"dumoryss_nullglass").effects[0] as CardEffectSpec
	_ok(nullglass.actions == [{"type": "INCREASE_PLAYED_CARD_COST", "amount": 1}, {"type": "SPEND_CHARGES", "amount": 1}]
		and nullglass.conditions == [{"type": "PLAYED_CARD_COST_AT_LEAST", "value": 4}] and nullglass.limits == {"per_turn": 1},
		"Nullglass: +1 cost to the first opponent card costing 4+, then 1 charge")

	var burial := _database.get_card(&"nerqathen_second_burial").effects[0] as CardEffectSpec
	_ok(burial.actions == [{"type": "RETURN_TO_BOARD", "target": "LAST_DIED_ALLY_CREATURE", "set_health": 1,
		"enter_battle_triggers": false}], "Second Burial: returns with 1 health, Enter Battle does not repeat")

	var artifacts: Array = _database.get_all_cards().filter(
		func(card: CardDefinition) -> bool: return card.card_type == CardEnums.Type.ARTIFACT)
	_ok(artifacts.size() == 4 and artifacts.all(func(card: CardDefinition) -> bool:
			return (card.charges > 0 and card.effects.size() == 1
				and card.effects[0].actions.count({"type": "SPEND_CHARGES", "amount": 1}) == 1)),
		"each artifact has approved charges and spends 1 charge per trigger")

	_ok(PROVOKE_CARD_IDS.all(func(id: String) -> bool:
			return _database.get_card(StringName(id)).effects.any(
				func(effect: CardEffectSpec) -> bool: return effect.keyword == &"PROVOKE")),
		"Provocation cards carry the PROVOKE keyword")

	var timings := {}
	for card: CardDefinition in _database.get_all_cards():
		for effect in card.effects:
			if not effect.timing.is_empty():
				timings["%s/%s" % [card.id, effect.effect_id]] = String(effect.timing)
	_ok(timings == EXPECTED_TIMINGS, "event abilities have the timing of their text («когда» / «после») %s" % [timings])

	var floats := PackedStringArray()
	for card: CardDefinition in _database.get_all_cards():
		for effect in card.effects:
			if _contains_float([effect.conditions, effect.actions, effect.limits]):
				floats.append(String(card.id))
	_ok(floats.is_empty(), "effect numbers are integers after loading %s" % [floats])


func _test_vocabulary_is_used() -> void:
	var used := {}
	for card: CardDefinition in _database.get_all_cards():
		for effect in card.effects:
			used[String(effect.trigger)] = true
			used[String(effect.keyword)] = true
			used[String(effect.timing)] = true
			for key: String in effect.limits:
				used[key] = true
			_collect_identifiers(effect.conditions, used)
			_collect_identifiers(effect.actions, used)
	var vocabulary: Array = []
	vocabulary.append_array(EffectVocabulary.TRIGGERS.keys())
	vocabulary.append_array(EffectVocabulary.CONDITIONS.keys())
	vocabulary.append_array(EffectVocabulary.ACTIONS.keys())
	vocabulary.append_array(EffectVocabulary.LIMITS.keys())
	for list: Array in [EffectVocabulary.TARGETS, EffectVocabulary.DURATIONS, EffectVocabulary.KEYWORDS,
			EffectVocabulary.DELAYS, EffectVocabulary.MULTIPLIERS, EffectVocabulary.TIMINGS]:
		vocabulary.append_array(list)
	var unused := vocabulary.filter(func(identifier: String) -> bool: return not used.has(identifier))
	_ok(unused.is_empty(), "every effect vocabulary identifier is used by an approved card %s" % [unused])


# --- Database behaviour -------------------------------------------------------

func _test_copies_are_isolated() -> void:
	var first: CardDefinition = _database.get_card(&"ashravael_gorebrand")
	_ok(first != _database.get_card(&"ashravael_gorebrand"), "get_card returns a new copy on every call")
	first.cost = 99
	first.name_ru = "Изменено"
	first.effects[0].actions[0]["amount"] = 99
	first.effects[0].conditions.append({"type": "IS_OWN_TURN"})
	first.effects.clear()
	var fresh: CardDefinition = _database.get_card(&"ashravael_gorebrand")
	_ok(fresh.cost == 4 and fresh.name_ru == "Клеймённый кровью" and fresh.effects.size() == 1
		and fresh.effects[0].actions[0]["amount"] == 1 and fresh.effects[0].conditions.is_empty(),
		"changing a returned card does not change CardDatabase")

	var ids: PackedStringArray = _database.get_card_ids()
	ids.append("test_extra")
	var all_cards: Array[CardDefinition] = _database.get_all_cards()
	all_cards[0].attack = 99
	all_cards.clear()
	_ok(_database.get_card_ids().size() == 40 and _database.get_all_cards()[0].attack != 99,
		"changing returned id and card lists does not change CardDatabase")
	_ok(_database.get_card(&"missing_card") == null and not _database.has_card(&"missing_card"),
		"unknown id returns null")


func _test_determinism() -> void:
	var before := JSON.stringify(_snapshot(_database))
	_ok(_database.load_directory() == OK and JSON.stringify(_snapshot(_database)) == before,
		"reloading gives identical definitions")
	var other: Node = CardDatabaseScript.new()
	_ok(other.load_directory() == OK and JSON.stringify(_snapshot(other)) == before,
		"a second CardDatabase instance loads identical definitions")
	other.free()
	var ids: PackedStringArray = _database.get_card_ids()
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	_ok(ids == sorted_ids, "card ids are returned in ascending order")


func _test_invalid_fixtures() -> void:
	var valid_dir := _fresh_dir("valid")
	_write(valid_dir.path_join("cards.json"), JSON.stringify({"cards": [_creature(), _spell(), _artifact(), _curse()]}))
	var fixture_db: Node = CardDatabaseScript.new()
	_ok(fixture_db.load_directory(valid_dir) == OK and fixture_db.get_card_count() == 4,
		"valid fixtures (creature, spell, artifact, curse) load")
	fixture_db.free()

	var spell_with_effect := func(effect: Dictionary) -> Dictionary: return _with(_spell(), {"effects": [effect]})
	var cases := [
		["corrupted JSON", '{"cards": [', "invalid JSON"],
		["root without a cards array", '{"cards": {}}', "only a \"cards\" array"],
		["extra root key", '{"cards": [], "lore": "x"}', "only a \"cards\" array"],
		["card entry that is not an object", [1], "must be an object"],
		["duplicate id", [_creature(), _with(_spell(), {"id": "test_creature"})], "duplicate id"],
		["duplicate name_en", [_creature(), _with(_spell(), {"name_en": "Test Creature"})], "duplicate name_en"],
		["duplicate name_en in other case", [_creature(), _with(_spell(), {"name_en": "test creature"})], "duplicate name_en"],
		["duplicate name_ru", [_creature(), _with(_spell(), {"name_ru": "Тестовое существо"})], "duplicate name_ru"],
		["unknown faction", [_with(_creature(), {"faction": "VOIDBORN"})], "'faction'"],
		["unknown type", [_with(_creature(), {"type": "HERO"})], "'type'"],
		["wrong rarity", [_with(_creature(), {"rarity": "MYTHIC"})], "'rarity'"],
		["negative cost", [_with(_creature(), {"cost": -1})], "'cost'"],
		["fractional cost", [_with(_creature(), {"cost": 1.5})], "'cost'"],
		["cost as text", [_with(_creature(), {"cost": "1"})], "'cost'"],
		["deck_limit 3", [_with(_creature(), {"deck_limit": 3})], "'deck_limit' must be 2"],
		["deck_limit as text", [_with(_creature(), {"deck_limit": "2"})], "'deck_limit' must be 2"],
		["LEGENDARY with deck_limit 2", [_with(_creature(), {"rarity": "LEGENDARY"})], "'deck_limit' must be 1"],
		["COMMON with deck_limit 1", [_with(_creature(), {"deck_limit": 1})], "'deck_limit' must be 2"],
		["creature without attack", [_without(_creature(), "attack")], "creature needs 'attack'"],
		["creature without health", [_without(_creature(), "health")], "creature needs 'health'"],
		["creature without armor", [_without(_creature(), "armor")], "creature needs 'armor'"],
		["creature with health 0", [_with(_creature(), {"health": 0})], "'health'"],
		["creature with negative attack", [_with(_creature(), {"attack": -1})], "'attack'"],
		["creature with negative armor", [_with(_creature(), {"armor": -1})], "'armor'"],
		["spell with creature stats", [_with(_spell(), {"attack": 1})], "must not have creature stat"],
		["artifact without charges", [_without(_artifact(), "charges")], "has no 'charges'"],
		["artifact with 0 charges", [_with(_artifact(), {"charges": 0})], "'charges' must be"],
		["artifact with fractional charges", [_with(_artifact(), {"charges": 1.5})], "'charges' must be"],
		["charges on a creature", [_with(_creature(), {"charges": 1})], "only ARTIFACT"],
		["charges that no effect spends", [_with(_artifact(), {"effects": [{"effect_id": "hit", "trigger": "OWN_HERO_DAMAGED",
			"timing": "WHEN", "actions": [{"type": "DRAW_CARDS", "amount": 1}]}]})], "no effect spends charges"],
		["event trigger without timing", [_with(_artifact(), {"effects": [{"effect_id": "charge",
			"trigger": "OWN_HERO_DAMAGED", "actions": [{"type": "SPEND_CHARGES", "amount": 1}]}]})], "needs 'timing'"],
		["unknown timing", [_with(_artifact(), {"effects": [{"effect_id": "charge", "trigger": "OWN_HERO_DAMAGED",
			"timing": "LATER", "actions": [{"type": "SPEND_CHARGES", "amount": 1}]}]})], "timing: must be one of"],
		["timing on an untimed trigger", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_PLAY", "timing": "WHEN",
			"actions": [{"type": "DRAW_CARDS", "amount": 1}]})], "takes no 'timing'"],
		["unknown trigger", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_SUMMON",
			"actions": [{"type": "DRAW_CARDS", "amount": 1}]})], "unknown trigger"],
		["unknown action id", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_PLAY",
			"actions": [{"type": "DOUBLE_DAMAGE", "amount": 1}]})], "unknown action"],
		["unknown condition id", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_PLAY",
			"conditions": [{"type": "MOON_IS_FULL"}], "actions": [{"type": "DRAW_CARDS", "amount": 1}]})], "unknown condition"],
		["unknown keyword", [spell_with_effect.call({"effect_id": "x", "keyword": "LIFESTEAL", "trigger": "ON_PLAY",
			"actions": [{"type": "DRAW_CARDS", "amount": 1}]})], "keyword: must be one of"],
		["unknown action parameter", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_PLAY",
			"actions": [{"type": "DRAW_CARDS", "amount": 1, "from": "GRAVEYARD"}]})], "unknown parameter 'from'"],
		["missing action parameter", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_PLAY",
			"actions": [{"type": "DRAW_CARDS"}]})], "missing parameter 'amount'"],
		["unknown limit", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_PLAY", "limits": {"per_match": 1},
			"actions": [{"type": "DRAW_CARDS", "amount": 1}]})], "unknown parameter 'per_match'"],
		["unknown effect field", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_PLAY", "notes": "x",
			"actions": [{"type": "DRAW_CARDS", "amount": 1}]})], "unknown field 'notes'"],
		["trigger not allowed for the card type", [_with(_creature(), {"rules_text_ru": "Тест.", "effects": [{"effect_id": "x",
			"trigger": "ON_PLAY", "actions": [{"type": "DRAW_CARDS", "amount": 1}]}]})], "not allowed for CREATURE"],
		["duplicate effect_id", [_with(_spell(), {"effects": [_spell()["effects"][0], _spell()["effects"][0]]})],
			"duplicate effect_id"],
		["soul shard spend with amount and up_to", [spell_with_effect.call({"effect_id": "x", "trigger": "ON_PLAY",
			"actions": [{"type": "SPEND_SOUL_SHARDS", "amount": 1, "up_to": 2}]})], "exactly one of"],
		["keyword-only effect outside STATIC", [_with(_creature(), {"rules_text_ru": "Провокация.", "effects": [{"effect_id": "x",
			"keyword": "PROVOKE", "trigger": "ENTER_BATTLE", "actions": []}]})], "may be empty only"],
		["empty name_en", [_with(_creature(), {"name_en": ""})], "'name_en'"],
		["empty name_ru", [_with(_creature(), {"name_ru": " "})], "'name_ru'"],
		["missing name_ru", [_without(_creature(), "name_ru")], "missing field 'name_ru'"],
		["name_ru in Latin letters", [_with(_creature(), {"name_ru": "Test Creature"})], "'name_ru'"],
		["invalid id", [_with(_creature(), {"id": "Test Creature"})], "'id'"],
		["unknown card field", [_with(_creature(), {"lore": "Выдуманная история."})], "unknown field 'lore'"],
		["rules text without effects", [_with(_creature(), {"rules_text_ru": "Провокация."})], "both empty"],
		["effects without rules text", [_with(_spell(), {"rules_text_ru": ""})], "both empty"],
	]

	_expect_errors.call(true)
	var case_dir := _fresh_dir("invalid")
	for test_case: Array in cases:
		var content: Variant = test_case[1]
		_write(case_dir.path_join("cards.json"), content if content is String else JSON.stringify({"cards": content}))
		var error: Error = _database.load_directory(case_dir)
		var problems := "\n".join(_database.get_last_load_problems())
		var expected_error := ERR_PARSE_ERROR if test_case[0] == "corrupted JSON" else ERR_INVALID_DATA
		_ok(error == expected_error and problems.contains(test_case[2]) and _database.get_card_count() == 40
			and not _database.has_card(&"test_creature"),
			"rejects %s%s" % [test_case[0], "" if problems.contains(test_case[2]) else " (problems: %s)" % problems])
	_ok(_database.load_directory(_temp_dir.path_join("missing")) == ERR_FILE_NOT_FOUND, "missing directory is reported")
	_ok(_database.load_directory(_fresh_dir("empty")) == ERR_FILE_NOT_FOUND, "directory without card files is reported")
	_expect_errors.call(false)


func _test_partial_load() -> void:
	var approved_ids: PackedStringArray = _database.get_card_ids()
	var partial_dir := _fresh_dir("partial")
	_write(partial_dir.path_join("a_valid.json"), JSON.stringify({"cards": [_creature(), _spell()]}))
	_write(partial_dir.path_join("b_invalid.json"), JSON.stringify({"cards": [_with(_artifact(), {"rarity": "MYTHIC"})]}))
	_expect_errors.call(true)
	var error: Error = _database.load_directory(partial_dir)
	_expect_errors.call(false)
	_ok(error == ERR_INVALID_DATA and _database.get_card_ids() == approved_ids and not _database.has_card(&"test_creature"),
		"a failed load keeps the previous 40 cards; no partial replacement")

	var split_dir := _fresh_dir("duplicate_across_files")
	_write(split_dir.path_join("a.json"), JSON.stringify({"cards": [_creature()]}))
	_write(split_dir.path_join("b.json"), JSON.stringify({"cards": [_with(_spell(), {"id": "test_creature"})]}))
	_expect_errors.call(true)
	error = _database.load_directory(split_dir)
	_expect_errors.call(false)
	_ok(error == ERR_INVALID_DATA and "\n".join(_database.get_last_load_problems()).contains("duplicate id")
		and _database.get_card_ids() == approved_ids, "duplicate id across files is rejected")


# --- Helpers ------------------------------------------------------------------

func _ok(condition: bool, description: String) -> void:
	_check.call(condition, description)


func _creature() -> Dictionary:
	return {"id": "test_creature", "name_en": "Test Creature", "name_ru": "Тестовое существо", "faction": "NEUTRAL",
		"type": "CREATURE", "rarity": "COMMON", "cost": 1, "deck_limit": 2, "attack": 1, "health": 1, "armor": 0,
		"rules_text_ru": "", "effects": []}


func _spell() -> Dictionary:
	return {"id": "test_spell", "name_en": "Test Spell", "name_ru": "Тестовое заклинание", "faction": "NEUTRAL",
		"type": "SPELL", "rarity": "COMMON", "cost": 1, "deck_limit": 2, "rules_text_ru": "Тестовый текст.",
		"effects": [{"effect_id": "draw", "trigger": "ON_PLAY", "actions": [{"type": "DRAW_CARDS", "amount": 1}]}]}


func _artifact() -> Dictionary:
	return {"id": "test_artifact", "name_en": "Test Artifact", "name_ru": "Тестовый артефакт", "faction": "NEUTRAL",
		"type": "ARTIFACT", "rarity": "EPIC", "cost": 1, "deck_limit": 2, "charges": 2, "rules_text_ru": "Тестовый текст.",
		"effects": [{"effect_id": "charge", "trigger": "OWN_HERO_DAMAGED", "timing": "WHEN",
			"actions": [{"type": "SPEND_CHARGES", "amount": 1}]}]}


func _curse() -> Dictionary:
	return {"id": "test_curse", "name_en": "Test Curse", "name_ru": "Тестовое проклятие", "faction": "NEUTRAL",
		"type": "CURSE", "rarity": "RARE", "cost": 1, "deck_limit": 2, "rules_text_ru": "", "effects": []}


func _with(card: Dictionary, changes: Dictionary) -> Dictionary:
	var result := card.duplicate(true)
	result.merge(changes, true)
	return result


func _without(card: Dictionary, field: String) -> Dictionary:
	var result := card.duplicate(true)
	result.erase(field)
	return result


func _count(cards: Array[CardDefinition], key_of: Callable) -> Dictionary:
	var counts := {}
	for card in cards:
		var key: String = key_of.call(card)
		counts[key] = counts.get(key, 0) + 1
	return counts


func _uses_any(card: CardDefinition, identifiers: Array[String]) -> bool:
	var used := {}
	for effect in card.effects:
		_collect_identifiers(effect.conditions, used)
		_collect_identifiers(effect.actions, used)
	return identifiers.any(func(identifier: String) -> bool: return used.has(identifier))


## Adds every string identifier found in condition / action dictionaries.
func _collect_identifiers(items: Array, used: Dictionary) -> void:
	for item: Dictionary in items:
		for key: String in item:
			var value: Variant = item[key]
			if key == "conditions":
				_collect_identifiers(value, used)
			elif typeof(value) == TYPE_STRING:
				used[value] = true


func _contains_float(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return true
		TYPE_ARRAY:
			return value.any(_contains_float)
		TYPE_DICTIONARY:
			return value.values().any(_contains_float)
	return false


func _snapshot(database: Node) -> Array:
	var snapshot := []
	for card: CardDefinition in database.get_all_cards():
		var effects := []
		for effect in card.effects:
			effects.append([effect.effect_id, effect.keyword, effect.trigger, effect.conditions, effect.actions, effect.limits])
		snapshot.append([card.id, card.name_en, card.name_ru, card.faction, card.card_type, card.rarity, card.cost,
			card.deck_limit, card.rules_text_ru, card.attack, card.health, card.armor, card.charges, effects])
	return snapshot


func _fresh_dir(name: String) -> String:
	var path := _temp_dir.path_join(name)
	DirAccess.make_dir_recursive_absolute(path)
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	return path


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
