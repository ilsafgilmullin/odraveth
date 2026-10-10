class_name CollectionFilterState
extends RefCounted
## Pure read-only Collection filtering over authoritative CardDefinition values.

const ALL := -100
const COST_ALL := -100
const COST_0_1 := 1
const COST_2 := 2
const COST_3 := 3
const COST_4 := 4
const COST_5 := 5
const COST_6 := 6
const COST_7_PLUS := 7

var query := ""
var faction_id := ALL
var type_id := ALL
var rarity_id := ALL
var cost_bucket := COST_ALL


func normalized_query() -> String:
	return query.strip_edges().to_lower()


func matches(card: CardDefinition) -> bool:
	if card == null:
		return false
	var needle := normalized_query()
	if not needle.is_empty() 			and not card.name_ru.to_lower().contains(needle) 			and not card.name_en.to_lower().contains(needle):
		return false
	if faction_id != ALL and card.faction != faction_id:
		return false
	if type_id != ALL and card.card_type != type_id:
		return false
	if rarity_id != ALL and card.rarity != rarity_id:
		return false
	return _matches_cost(card.cost)


func filter(cards: Array[CardDefinition]) -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	for card: CardDefinition in cards:
		if matches(card):
			result.append(card)
	return result


func reset_filters() -> void:
	faction_id = ALL
	type_id = ALL
	rarity_id = ALL
	cost_bucket = COST_ALL


func active_filter_count() -> int:
	var count := 0
	if faction_id != ALL:
		count += 1
	if type_id != ALL:
		count += 1
	if rarity_id != ALL:
		count += 1
	if cost_bucket != COST_ALL:
		count += 1
	return count


func _matches_cost(cost: int) -> bool:
	match cost_bucket:
		COST_ALL:
			return true
		COST_0_1:
			return cost <= 1
		COST_2, COST_3, COST_4, COST_5, COST_6:
			return cost == cost_bucket
		COST_7_PLUS:
			return cost >= 7
	return true
