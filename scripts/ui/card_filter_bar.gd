class_name CardFilterBar
extends HBoxContainer
## Deck Builder card filter toolbar. Reuses the Collection filter predicates and
## additionally restricts results to [member allowed_factions].

signal filters_changed

var allowed_factions: Array[int] = []
var filter_state := CollectionFilterState.new()
var search: LineEdit
var faction_buttons: Dictionary = {}
var card_type: OptionButton
var cost: OptionButton

var _faction_group := ButtonGroup.new()


func _ready() -> void:
	add_theme_constant_override("separation", VisualTokens.SPACE_2)
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Поиск"
	search.clear_button_enabled = true
	search.custom_minimum_size.x = 220
	search.size_flags_horizontal = SIZE_EXPAND_FILL
	UiKit.prepare_text_field(search)
	search.text_changed.connect(_on_search_changed)
	add_child(search)

	var factions := HBoxContainer.new()
	factions.name = "FactionChips"
	factions.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	add_child(factions)
	var choices: Array[int] = [CollectionFilterState.ALL]
	choices.append_array(allowed_factions)
	for id: int in choices:
		var label_text := "ВСЕ" if id == CollectionFilterState.ALL else SetupUi.faction_name(id as Faction.Id).to_upper()
		var chip := UiKit.make_filter_chip(label_text, id == CollectionFilterState.ALL)
		chip.add_theme_font_size_override("font_size", 26)
		chip.name = "Faction_%s" % ("ALL" if id == CollectionFilterState.ALL else str(Faction.Id.find_key(id)))
		chip.button_group = _faction_group
		chip.toggled.connect(_on_faction_toggled.bind(id))
		factions.add_child(chip)
		faction_buttons[id] = chip

	card_type = _select("TypeFilter")
	card_type.add_item("ВСЕ ТИПЫ", CollectionFilterState.ALL)
	var present := {}
	for card: CardDefinition in CardDatabase.get_all_cards():
		present[card.card_type] = true
	for id: CardEnums.Type in [CardEnums.Type.CREATURE, CardEnums.Type.SPELL, CardEnums.Type.ARTIFACT, CardEnums.Type.CURSE]:
		if present.has(id):
			card_type.add_item(CollectionScreen.TYPE_LABELS[id], id)
	cost = _select("CostFilter")
	for row: Array in [
		["ВСЕ ЦЕНЫ", CollectionFilterState.COST_ALL], ["0–1", CollectionFilterState.COST_0_1],
		["2", CollectionFilterState.COST_2], ["3", CollectionFilterState.COST_3], ["4", CollectionFilterState.COST_4],
		["5", CollectionFilterState.COST_5], ["6", CollectionFilterState.COST_6], ["7+", CollectionFilterState.COST_7_PLUS],
	]:
		cost.add_item(row[0], row[1])


func matches(card: CardDefinition) -> bool:
	if card == null:
		return false
	if not allowed_factions.is_empty() and card.faction not in allowed_factions:
		return false
	return filter_state.matches(card)


func _select(node_name: String) -> OptionButton:
	var control := OptionButton.new()
	control.name = node_name
	control.custom_minimum_size = Vector2(196, 64)
	control.fit_to_longest_item = false
	control.clip_text = true
	UiKit.prepare_select(control)
	control.add_theme_font_size_override("font_size", 22)
	control.item_selected.connect(_on_select_changed)
	add_child(control)
	return control


func _on_search_changed(value: String) -> void:
	filter_state.query = value
	filters_changed.emit()


func _on_faction_toggled(pressed: bool, id: int) -> void:
	if not pressed:
		return
	filter_state.faction_id = id
	filters_changed.emit()


func _on_select_changed(_index: int) -> void:
	filter_state.type_id = card_type.get_selected_id()
	filter_state.cost_bucket = cost.get_selected_id()
	filters_changed.emit()
