class_name CardFilterBar
extends HBoxContainer
## Shared local, read-only filtering of the 40 approved definitions.

signal filters_changed
const ALL := -100

var allowed_factions: Array[int] = []
var search: LineEdit
var faction: OptionButton
var card_type: OptionButton
var rarity: OptionButton
var cost: OptionButton


func _ready() -> void:
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Поиск: русское или английское название"
	search.custom_minimum_size.x = 320
	search.size_flags_horizontal = SIZE_EXPAND_FILL
	search.text_changed.connect(func(_value: String) -> void: filters_changed.emit())
	add_child(search)
	faction = _option("FactionFilter")
	faction.add_item("Все", ALL)
	for id: int in Faction.Id.values():
		if allowed_factions.is_empty() or id in allowed_factions:
			faction.add_item(SetupUi.faction_name(id as Faction.Id), id)
	card_type = _option("TypeFilter")
	card_type.add_item("Все типы", ALL)
	for id: int in CardEnums.Type.values():
		card_type.add_item(SetupUi.TYPE_NAMES[id], id)
	rarity = _option("RarityFilter")
	rarity.add_item("Все редкости", ALL)
	for id: int in CardEnums.Rarity.values():
		rarity.add_item(SetupUi.RARITY_NAMES[id], id)
	cost = _option("CostFilter")
	cost.add_item("Любая стоимость", ALL)
	for value: int in range(11):
		cost.add_item(str(value), value)


func _option(node_name: String) -> OptionButton:
	var control := OptionButton.new()
	control.name = node_name
	control.custom_minimum_size = Vector2(190, 64)
	control.item_selected.connect(func(_index: int) -> void: filters_changed.emit())
	add_child(control)
	return control


func matches(card: CardDefinition) -> bool:
	if not allowed_factions.is_empty() and card.faction not in allowed_factions:
		return false
	var query := search.text.strip_edges().to_lower()
	return (query.is_empty() or query in card.name_ru.to_lower() or query in card.name_en.to_lower()) \
		and (faction.get_selected_id() == ALL or card.faction == faction.get_selected_id()) \
		and (card_type.get_selected_id() == ALL or card.card_type == card_type.get_selected_id()) \
		and (rarity.get_selected_id() == ALL or card.rarity == rarity.get_selected_id()) \
		and (cost.get_selected_id() == ALL or card.cost == cost.get_selected_id())
