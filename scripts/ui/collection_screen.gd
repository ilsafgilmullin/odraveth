class_name CollectionScreen
extends SetupScreen
## All 40 starter cards are available; no ownership or unlock economy.

var filter_bar: CardFilterBar
var card_grid: GridContainer
var card_scroll: ScrollContainer
var detail: CardDetailOverlay


func _route_id() -> StringName:
	return Routes.COLLECTION


func _build_content() -> void:
	filter_bar = CardFilterBar.new()
	filter_bar.name = "Filters"
	content.add_child(filter_bar)
	filter_bar.filters_changed.connect(_refresh_cards)
	card_scroll = ScrollContainer.new()
	card_scroll.name = "CardScroll"
	card_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(card_scroll)
	card_grid = GridContainer.new()
	card_grid.name = "CardGrid"
	card_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 12)
	card_scroll.add_child(card_grid)
	detail = CardDetailOverlay.new()
	add_child(detail)
	get_viewport().size_changed.connect(_update_columns)
	_update_columns()
	_refresh_cards()


func _update_columns() -> void:
	if card_grid != null:
		card_grid.columns = clampi(int(get_viewport_rect().size.x / 420.0), 4, 7)


func _refresh_cards() -> void:
	for child: Node in card_grid.get_children():
		card_grid.remove_child(child)
		child.queue_free()
	var visible_count := 0
	for card: CardDefinition in CardDatabase.get_all_cards():
		if not filter_bar.matches(card):
			continue
		var tile := SetupUi.card_tile(card)
		tile.custom_minimum_size = Vector2(350, 152)
		tile.size_flags_horizontal = SIZE_EXPAND_FILL
		tile.pressed.connect(detail.show_card.bind(card))
		card_grid.add_child(tile)
		visible_count += 1
	show_message("%d из 40 карт · все доступны" % visible_count)
