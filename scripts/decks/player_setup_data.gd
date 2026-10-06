class_name PlayerSetupData
extends RefCounted
## Sanitized local profile fields for Stage 5. Other save fields are preserved.

const HINTS := "hints_enabled"
const ANIMATIONS := "animations_enabled"
const FORECAST := "damage_forecast_enabled"
const HERO_IDS: Array[StringName] = [HeroCatalog.KEZHARYN, HeroCatalog.VHORAZEL,
	HeroCatalog.SYRRAVETH, HeroCatalog.TAZHYRION]


static func normalized(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var hero: Variant = result.get("selected_hero_id", "")
	result["selected_hero_id"] = String(hero) if typeof(hero) == TYPE_STRING and HeroCatalog.has_hero(StringName(hero)) else ""
	var selected: Variant = result.get("selected_deck_id", "")
	result["selected_deck_id"] = selected if typeof(selected) == TYPE_STRING else ""
	var records: Array = []
	var seen: Dictionary = {}
	if typeof(result.get("user_decks")) == TYPE_ARRAY:
		for raw: Variant in result["user_decks"]:
			var deck := UserDeck.from_data(raw)
			if deck != null and not seen.has(deck.id):
				records.append(deck.to_data())
				seen[deck.id] = true
	result["user_decks"] = records
	var prefs: Variant = result.get("prebattle", {})
	var safe: Dictionary = prefs if typeof(prefs) == TYPE_DICTIONARY else {}
	for key: String in [HINTS, ANIMATIONS, FORECAST]:
		safe[key] = safe[key] if typeof(safe.get(key)) == TYPE_BOOL else true
	var opponent: Variant = safe.get("opponent_hero_id", "")
	safe["opponent_hero_id"] = String(opponent) if typeof(opponent) == TYPE_STRING and HeroCatalog.has_hero(StringName(opponent)) else String(HeroCatalog.VHORAZEL)
	var difficulty: Variant = safe.get("ai_difficulty", "NOVICE")
	safe["ai_difficulty"] = difficulty if typeof(difficulty) == TYPE_STRING and difficulty in ["NOVICE", "TACTICIAN", "STRATEGIST"] else "NOVICE"
	result["prebattle"] = safe
	return result


static func selected_deck(profile: Dictionary, cards: Object) -> UserDeck:
	var hero := StringName(str(profile.get("selected_hero_id", "")))
	var id := str(profile.get("selected_deck_id", ""))
	for deck in decks_for(profile, hero):
		if deck.id == id and deck.is_ready(cards):
			return deck
	return null


static func decks_for(profile: Dictionary, hero: StringName) -> Array[UserDeck]:
	var decks: Array[UserDeck] = []
	for record: Variant in profile.get("user_decks", []):
		var deck := UserDeck.from_data(record)
		if deck != null and deck.hero_id == hero:
			decks.append(deck)
	return decks


static func upsert(profile: Dictionary, deck: UserDeck, cards: Object) -> Dictionary:
	var next := normalized(profile)
	var records: Array = next["user_decks"]
	var found := false
	for i in records.size():
		if records[i]["id"] == deck.id:
			records[i] = deck.to_data()
			found = true
			break
	if not found:
		records.append(deck.to_data())
	if next["selected_deck_id"] == deck.id and not deck.is_ready(cards):
		next["selected_deck_id"] = ""
	if next["selected_deck_id"] == "" and deck.hero_id == StringName(next["selected_hero_id"]) and deck.is_ready(cards):
		next["selected_deck_id"] = deck.id
	return next


static func select_hero(profile: Dictionary, hero: StringName) -> Dictionary:
	var next := normalized(profile)
	if not HeroCatalog.has_hero(hero):
		return next
	if next["selected_hero_id"] != String(hero):
		next["selected_hero_id"] = String(hero)
		next["selected_deck_id"] = ""
	return next
