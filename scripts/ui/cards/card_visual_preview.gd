class_name CardVisualPreview
extends Control
## Development/test preview only. Not a product Collection screen.

var card_views: Array[FullCardView] = []
var representative_ids := PackedStringArray()


func _ready() -> void:
	UiKit.apply_root_theme(self)
	CardDatabase.load_directory()
	var selected := _representatives(CardDatabase.get_all_cards())
	representative_ids = PackedStringArray(selected.map(func(card: CardDefinition) -> String: return String(card.id)))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var pad := ResponsiveLayout.outer_margin(get_viewport_rect().size.x)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, pad)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "PreviewGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for card: CardDefinition in selected:
		var view := FullCardView.new()
		view.name = "Preview_%s" % card.id
		view.configure(card)
		grid.add_child(view)
		card_views.append(view)


func _representatives(cards: Array[CardDefinition]) -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	_add_unique(result, cards.filter(func(c: CardDefinition) -> bool: return c.card_type == CardEnums.Type.CREATURE)[0])
	_add_unique(result, cards.filter(func(c: CardDefinition) -> bool: return c.card_type == CardEnums.Type.SPELL)[0])
	_add_unique(result, cards.filter(func(c: CardDefinition) -> bool: return c.card_type == CardEnums.Type.ARTIFACT)[0])
	_add_unique(result, cards.filter(func(c: CardDefinition) -> bool: return c.rarity == CardEnums.Rarity.LEGENDARY)[0])
	_add_unique(result, cards.filter(func(c: CardDefinition) -> bool: return c.faction == Faction.Id.NEUTRAL)[0])
	_add_unique(result, cards.filter(func(c: CardDefinition) -> bool: return c.card_type == CardEnums.Type.CREATURE and c.armor > 0)[0])

	var longest_name: CardDefinition = cards[0]
	var longest_rules: CardDefinition = cards[0]
	for card: CardDefinition in cards:
		if card.name_ru.length() > longest_name.name_ru.length():
			longest_name = card
		if card.rules_text_ru.length() > longest_rules.rules_text_ru.length():
			longest_rules = card
	_add_unique(result, longest_name)
	_add_unique(result, longest_rules)
	return result


func _add_unique(items: Array[CardDefinition], card: CardDefinition) -> void:
	if card == null:
		return
	if items.any(func(existing: CardDefinition) -> bool: return existing.id == card.id):
		return
	items.append(card)
