class_name DeckValidator
extends RefCounted
## Deck rules (docs/PRODUCT_BASELINE.md section 6): exactly GameRules.DECK_SIZE
## cards, only the hero's faction and NEUTRAL, at most deck_limit copies of a card.


## Returns every problem; empty means the deck is valid. [param card_source] is
## any object with get_card(id) -> CardDefinition (CardDatabase).
static func validate(hero_id: StringName, card_ids: Array, card_source: Object) -> PackedStringArray:
	var problems := PackedStringArray()
	if not HeroCatalog.has_hero(hero_id):
		problems.append("unknown hero '%s'" % hero_id)
		return problems
	if card_ids.size() != GameRules.DECK_SIZE:
		problems.append("deck has %d cards, needs exactly %d" % [card_ids.size(), GameRules.DECK_SIZE])
	var hero_faction := HeroCatalog.faction_of(hero_id)
	var copies := {}
	for card_id: Variant in card_ids:
		var definition: CardDefinition = card_source.get_card(StringName(str(card_id)))
		if definition == null:
			problems.append("unknown card '%s'" % card_id)
			continue
		if definition.faction != hero_faction and definition.faction != Faction.Id.NEUTRAL \
				and not copies.has(definition.id):
			problems.append("card '%s' belongs to %s, not to %s or NEUTRAL" % [
				card_id, Faction.Id.find_key(definition.faction), Faction.Id.find_key(hero_faction)])
		copies[definition.id] = copies.get(definition.id, 0) + 1
		if copies[definition.id] == definition.deck_limit + 1:
			problems.append("card '%s' exceeds its deck limit of %d" % [card_id, definition.deck_limit])
	return problems
