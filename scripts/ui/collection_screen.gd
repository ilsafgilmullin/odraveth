class_name CollectionScreen
extends SetupScreen
## Stage 7E read-only Archive of Nulmeris. Uses Stage 7D FullCard/CardDetail exclusively.

const TYPE_LABELS := {
	CardEnums.Type.CREATURE: "СУЩЕСТВА",
	CardEnums.Type.SPELL: "ЗАКЛИНАНИЯ",
	CardEnums.Type.ARTIFACT: "АРТЕФАКТЫ",
	CardEnums.Type.CURSE: "ПРОКЛЯТИЯ",
}
const RARITY_LABELS := {
	CardEnums.Rarity.COMMON: "ОБЫЧНЫЕ",
	CardEnums.Rarity.RARE: "РЕДКИЕ",
	CardEnums.Rarity.EPIC: "ЭПИЧЕСКИЕ",
	CardEnums.Rarity.LEGENDARY: "ЛЕГЕНДАРНЫЕ",
}

var filter_state := CollectionFilterState.new()
var search: LineEdit
var filter_toggle: Button
var filter_panel: PanelContainer
var filter_flow: HFlowContainer
var faction_filter: OptionButton
var type_filter: OptionButton
var rarity_filter: OptionButton
var cost_filter: OptionButton
var reset_button: Button
var active_summary: Label
var card_grid: GridContainer
var card_scroll: ScrollContainer
var empty_state: VBoxContainer
var detail: CardDetailOverlay
var visible_card_ids := PackedStringArray()

var _all_cards: Array[CardDefinition] = []
var _result_count_label: Label


func _route_id() -> StringName:
	return Routes.COLLECTION


func _build_content() -> void:
	UiKit.apply_root_theme(self)
	var backdrop := CollectionArchiveBackdrop.new()
	backdrop.name = "ArchiveBackdrop"
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)

	var back := find_child("BackButton", true, false) as Button
	var title := find_child("ScreenTitle", true, false) as Label
	if back != null:
		UiKit.style_button(back, UiKit.ButtonRole.SECONDARY)
	if title != null:
		title.text = "КОЛЛЕКЦИЯ"
		title.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	message.visible = false

	_build_toolbar()
	_build_filter_panel()

	card_scroll = ScrollContainer.new()
	card_scroll.name = "CardScroll"
	card_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	UiKit.prepare_scroll(card_scroll)
	content.add_child(card_scroll)

	var grid_wrap := MarginContainer.new()
	grid_wrap.name = "GridWrap"
	grid_wrap.size_flags_horizontal = SIZE_EXPAND_FILL
	grid_wrap.add_theme_constant_override("margin_top", VisualTokens.SPACE_2)
	grid_wrap.add_theme_constant_override("margin_bottom", VisualTokens.SPACE_3)
	card_scroll.add_child(grid_wrap)

	card_grid = GridContainer.new()
	card_grid.name = "CardGrid"
	card_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", VisualTokens.SPACE_3)
	card_grid.add_theme_constant_override("v_separation", VisualTokens.SPACE_4)
	grid_wrap.add_child(card_grid)

	empty_state = VBoxContainer.new()
	empty_state.name = "EmptyState"
	empty_state.visible = false
	empty_state.alignment = BoxContainer.ALIGNMENT_CENTER
	empty_state.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(empty_state)
	var empty_title := Label.new()
	empty_title.name = "EmptyStateTitle"
	empty_title.text = "КАРТЫ НЕ НАЙДЕНЫ"
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_title.add_theme_font_size_override("font_size", 38)
	empty_title.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	empty_state.add_child(empty_title)
	var empty_hint := Label.new()
	empty_hint.name = "EmptyStateHint"
	empty_hint.text = "Измените запрос или сбросьте фильтры."
	empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_hint.add_theme_font_size_override("font_size", 26)
	empty_hint.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	empty_state.add_child(empty_hint)

	detail = CardDetailOverlay.new()
	add_child(detail)

	_all_cards = CardDatabase.get_all_cards()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_layout()
	_refresh_cards()


func _build_toolbar() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.name = "ArchiveToolbar"
	toolbar.custom_minimum_size.y = 72
	toolbar.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	content.add_child(toolbar)

	var archive_label := Label.new()
	archive_label.name = "ArchiveLabel"
	archive_label.text = "АРХИВ НУЛМЕРИСА"
	archive_label.add_theme_font_size_override("font_size", 24)
	archive_label.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_700)
	toolbar.add_child(archive_label)

	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Поиск по русскому или английскому названию"
	search.clear_button_enabled = true
	search.size_flags_horizontal = SIZE_EXPAND_FILL
	search.custom_minimum_size.x = 460
	UiKit.prepare_text_field(search)
	search.text_changed.connect(_on_search_changed)
	toolbar.add_child(search)

	filter_toggle = UiKit.make_filter_chip("ФИЛЬТРЫ", true)
	filter_toggle.name = "FilterToggle"
	filter_toggle.custom_minimum_size.x = 190
	filter_toggle.toggled.connect(_on_filter_panel_toggled)
	toolbar.add_child(filter_toggle)

	active_summary = Label.new()
	active_summary.name = "ActiveFilterSummary"
	active_summary.custom_minimum_size.x = 210
	active_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	active_summary.add_theme_font_size_override("font_size", 22)
	active_summary.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	toolbar.add_child(active_summary)

	_result_count_label = Label.new()
	_result_count_label.name = "ResultCount"
	_result_count_label.custom_minimum_size.x = 150
	_result_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_result_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_count_label.add_theme_font_size_override("font_size", 22)
	_result_count_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_700)
	toolbar.add_child(_result_count_label)


func _build_filter_panel() -> void:
	filter_panel = UiKit.make_panel(false)
	filter_panel.name = "FilterPanel"
	content.add_child(filter_panel)

	filter_flow = HFlowContainer.new()
	filter_flow.name = "FilterFlow"
	filter_flow.size_flags_horizontal = SIZE_EXPAND_FILL
	filter_flow.add_theme_constant_override("h_separation", VisualTokens.SPACE_3)
	filter_flow.add_theme_constant_override("v_separation", VisualTokens.SPACE_2)
	filter_panel.add_child(filter_flow)

	faction_filter = _make_filter_select("FactionFilter", "ФРАКЦИЯ")
	_add_option(faction_filter, "ВСЕ", CollectionFilterState.ALL)
	for faction: Faction.Id in [
		Faction.Id.ASHRAVAEL, Faction.Id.NERQATHEN, Faction.Id.DUMORYSS,
		Faction.Id.KHEVARUUN, Faction.Id.NEUTRAL,
	]:
		_add_option(faction_filter, SetupUi.faction_name(faction).to_upper(), faction)
	faction_filter.item_selected.connect(_on_filters_changed)

	type_filter = _make_filter_select("TypeFilter", "ТИП")
	_add_option(type_filter, "ВСЕ", CollectionFilterState.ALL)
	var present_types := {}
	for card: CardDefinition in CardDatabase.get_all_cards():
		present_types[card.card_type] = true
	for card_type: CardEnums.Type in [
		CardEnums.Type.CREATURE, CardEnums.Type.SPELL, CardEnums.Type.ARTIFACT, CardEnums.Type.CURSE,
	]:
		if present_types.has(card_type):
			_add_option(type_filter, TYPE_LABELS[card_type], card_type)
	type_filter.item_selected.connect(_on_filters_changed)

	rarity_filter = _make_filter_select("RarityFilter", "РЕДКОСТЬ")
	_add_option(rarity_filter, "ВСЕ", CollectionFilterState.ALL)
	for rarity: CardEnums.Rarity in [
		CardEnums.Rarity.COMMON, CardEnums.Rarity.RARE,
		CardEnums.Rarity.EPIC, CardEnums.Rarity.LEGENDARY,
	]:
		_add_option(rarity_filter, RARITY_LABELS[rarity], rarity)
	rarity_filter.item_selected.connect(_on_filters_changed)

	cost_filter = _make_filter_select("CostFilter", "СТОИМОСТЬ")
	for row: Array in [
		["ВСЕ", CollectionFilterState.COST_ALL],
		["0–1", CollectionFilterState.COST_0_1],
		["2", CollectionFilterState.COST_2],
		["3", CollectionFilterState.COST_3],
		["4", CollectionFilterState.COST_4],
		["5", CollectionFilterState.COST_5],
		["6", CollectionFilterState.COST_6],
		["7+", CollectionFilterState.COST_7_PLUS],
	]:
		_add_option(cost_filter, row[0], row[1])
	cost_filter.item_selected.connect(_on_filters_changed)

	var reset_wrap := VBoxContainer.new()
	reset_wrap.name = "ResetFilterWrap"
	reset_wrap.custom_minimum_size.x = 190
	filter_flow.add_child(reset_wrap)
	var reset_label := Label.new()
	reset_label.text = "ФИЛЬТРЫ"
	reset_label.add_theme_font_size_override("font_size", 18)
	reset_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	reset_wrap.add_child(reset_label)
	reset_button = UiKit.make_button("СБРОСИТЬ", UiKit.ButtonRole.SUBTLE)
	reset_button.name = "ResetFilters"
	reset_button.pressed.connect(_reset_filters)
	reset_wrap.add_child(reset_button)


func _make_filter_select(node_name: String, label_text: String) -> OptionButton:
	var wrap := VBoxContainer.new()
	wrap.name = "%sWrap" % node_name
	wrap.custom_minimum_size.x = 220
	filter_flow.add_child(wrap)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	wrap.add_child(label)
	var select := OptionButton.new()
	select.name = node_name
	select.custom_minimum_size.x = 220
	UiKit.prepare_select(select)
	wrap.add_child(select)
	return select


func _add_option(control: OptionButton, label: String, id: int) -> void:
	control.add_item(label, id)


func _on_search_changed(value: String) -> void:
	filter_state.query = value
	_refresh_cards()


func _on_filters_changed(_index: int) -> void:
	filter_state.faction_id = faction_filter.get_selected_id()
	filter_state.type_id = type_filter.get_selected_id()
	filter_state.rarity_id = rarity_filter.get_selected_id()
	filter_state.cost_bucket = cost_filter.get_selected_id()
	_refresh_cards()


func _reset_filters() -> void:
	filter_state.reset_filters()
	_select_id(faction_filter, CollectionFilterState.ALL)
	_select_id(type_filter, CollectionFilterState.ALL)
	_select_id(rarity_filter, CollectionFilterState.ALL)
	_select_id(cost_filter, CollectionFilterState.COST_ALL)
	_refresh_cards()


func _select_id(control: OptionButton, id: int) -> void:
	for index in control.item_count:
		if control.get_item_id(index) == id:
			control.select(index)
			return


func _on_filter_panel_toggled(open: bool) -> void:
	filter_panel.visible = open


func _refresh_cards() -> void:
	if card_grid == null:
		return
	for child: Node in card_grid.get_children():
		card_grid.remove_child(child)
		child.queue_free()

	var cards := filter_state.filter(_all_cards)
	visible_card_ids = PackedStringArray(cards.map(func(card: CardDefinition) -> String: return String(card.id)))
	for card: CardDefinition in cards:
		var cell := CenterContainer.new()
		cell.name = "Cell_%s" % card.id
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		card_grid.add_child(cell)

		var card_view := FullCardView.new()
		card_view.configure(card)
		card_view.name = "Card_%s" % card.id
		card_view.card_activated.connect(_open_detail)
		cell.add_child(card_view)

	var has_cards := not cards.is_empty()
	card_scroll.visible = has_cards
	empty_state.visible = not has_cards
	_result_count_label.text = "%d / %d КАРТ" % [cards.size(), _all_cards.size()]
	var active := filter_state.active_filter_count()
	active_summary.text = "БЕЗ ФИЛЬТРОВ" if active == 0 else "АКТИВНО: %d" % active
	reset_button.disabled = active == 0


func _open_detail(card_id: StringName) -> void:
	detail.open_card(card_id)


func _on_viewport_size_changed() -> void:
	_apply_layout()


func _apply_layout() -> void:
	if card_grid == null:
		return
	var viewport_size := get_viewport_rect().size
	card_grid.columns = ResponsiveLayout.collection_columns_for_size(viewport_size)
	var narrow := card_grid.columns == 4
	if search != null:
		search.custom_minimum_size.x = 360 if narrow else 460
	if active_summary != null:
		active_summary.custom_minimum_size.x = 170 if narrow else 210


func handle_back_request() -> bool:
	if detail != null and detail.visible:
		detail.close_detail()
		return true
	if search != null and search.has_focus():
		search.release_focus()
		DisplayServer.virtual_keyboard_hide()
		return true
	return false
