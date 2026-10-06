class_name UserDeck
extends RefCounted
## Plain-data user deck. It never contains CardDefinition or runtime instances.

const MAX_NAME_LENGTH := 40
static var _next_id: int = 0

var id: String = ""
var name: String = "Новая колода"
var hero_id: StringName = &""
var card_ids: Array[String] = []


static func create(hero: StringName) -> UserDeck:
	var deck := UserDeck.new()
	_next_id += 1
	deck.id = "deck_%d_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), _next_id]
	deck.hero_id = hero
	return deck


static func from_data(data: Variant) -> UserDeck:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var record: Dictionary = data
	if typeof(record.get("id")) != TYPE_STRING or String(record["id"]).is_empty() \
			or typeof(record.get("name")) != TYPE_STRING \
			or typeof(record.get("hero_id")) != TYPE_STRING \
			or typeof(record.get("card_ids")) != TYPE_ARRAY:
		return null
	var hero := StringName(record["hero_id"])
	if not HeroCatalog.has_hero(hero):
		return null
	var cards: Array[String] = []
	for value: Variant in record["card_ids"]:
		if typeof(value) != TYPE_STRING or String(value).is_empty():
			return null
		cards.append(value)
	var deck := UserDeck.new()
	deck.id = record["id"]
	deck.name = record["name"]
	deck.hero_id = hero
	deck.card_ids = cards
	return deck


func to_data() -> Dictionary:
	return {"id": id, "name": name, "hero_id": String(hero_id), "card_ids": card_ids.duplicate()}


func name_problem() -> String:
	if name.strip_edges().is_empty():
		return "Введите название колоды"
	if name.strip_edges().length() > MAX_NAME_LENGTH:
		return "Название должно быть не длиннее %d символов" % MAX_NAME_LENGTH
	return ""


func problems(card_source: Object) -> PackedStringArray:
	return DeckValidator.validate(hero_id, card_ids, card_source)


func is_ready(card_source: Object) -> bool:
	return name_problem().is_empty() and problems(card_source).is_empty()
