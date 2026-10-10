class_name DeckBuilderScreen
extends SetupScreen
## Stage 7 Deck Builder V1: КАРТЫ | КОЛОДА tabs under a common hero/deck header.
## DeckValidator (through UserDeck.is_ready/problems) is the only readiness authority;
## copy/size limits only pre-disable buttons and are re-checked by the validator.

enum Tab { CARDS, DECK }

var draft: UserDeck
var hero: StringName = &""
var filter_bar: CardFilterBar
var grid: GridContainer
var deck_list: VBoxContainer
var deck_select: OptionButton
var name_edit: LineEdit
var count_label: Label
var ready_label: Label
var ready_marker: PanelContainer
var selected_marker: Label
var detail: CardDetailOverlay
var clear_dialog: ConfirmModal
var cards_tab_button: Button
var deck_tab_button: Button
var active_tab: Tab = Tab.CARDS
var cards_page: Control
var deck_page: Control
var curve_view: DeckCurveView
var composition_label: Label
var guidance_label: Label
var status_label: Label
var empty_deck_hint: Label
var deck_hint: Label

var _cells: Dictionary = {}
var _tab_group := ButtonGroup.new()


func _route_id() -> StringName:
	return Routes.DECK_BUILDER


func _build_content() -> void:
	var backdrop := CollectionArchiveBackdrop.new()
	backdrop.art_slot = &"deck_hall"
	backdrop.name = "ArchiveBackdrop"
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)
	message.visible = false
	hero = StringName(str(AppState.profile.get("selected_hero_id", "")))
	if not HeroCatalog.has_hero(hero):
		_build_no_hero_state()
		return

	_build_identity_bar()
	_build_tab_row()
	var body := Control.new()
	body.name = "DeckBody"
	body.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(body)
	_build_cards_page(body)
	_build_deck_page(body)
	_build_footer()

	detail = CardDetailOverlay.new()
	add_child(detail)
	clear_dialog = ConfirmModal.create("ОЧИСТИТЬ КОЛОДУ?",
		"Все карты будут убраны из текущей колоды. Сохранённые колоды не изменятся, пока вы не нажмёте «Сохранить».",
		"ОЧИСТИТЬ")
	clear_dialog.name = "ClearConfirmation"
	clear_dialog.confirmed.connect(_clear)
	add_child(clear_dialog)

	get_viewport().size_changed.connect(_update_columns)
	var decks := PlayerSetupData.decks_for(AppState.profile, hero)
	draft = decks[0] if not decks.is_empty() else UserDeck.create(hero)
	var selected_id := str(AppState.profile.get("selected_deck_id", ""))
	for deck: UserDeck in decks:
		if deck.id == selected_id:
			draft = deck
			break
	_refresh_all()
	_set_tab(Tab.CARDS)
	status_label.text = "Нажмите на карту, чтобы прочитать её полностью"


func _build_no_hero_state() -> void:
	var center := CenterContainer.new()
	center.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(center)
	var panel := UiKit.make_panel(true)
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	panel.add_child(stack)
	var title := _label("СНАЧАЛА ВЫБЕРИТЕ ГЕРОЯ", 40, VisualTokens.COLOR_STEEL_900, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var hint := _label("Колода собирается из карт фракции героя и нейтральных карт.", 28, VisualTokens.COLOR_STEEL_700)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint)
	var choose := UiKit.make_button("ВЫБРАТЬ ГЕРОЯ", UiKit.ButtonRole.PRIMARY)
	choose.name = "ChangeHeroButton"
	choose.pressed.connect(SceneRouter.go_to.bind(Routes.HERO_SELECT))
	stack.add_child(choose)
	show_message("Сначала выберите героя для колоды")


func _build_identity_bar() -> void:
	var bar := UiKit.make_panel(false)
	bar.name = "DeckIdentityBar"
	var bar_box := (bar.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar_box.content_margin_top = 10
	bar_box.content_margin_bottom = 10
	bar_box.content_margin_left = 18
	bar.add_theme_stylebox_override("panel", bar_box)
	content.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	bar.add_child(row)

	var portrait := HeroPortraitPlaceholder.new()
	portrait.name = "DeckHeroPortrait"
	portrait.compact = true
	portrait.custom_minimum_size = Vector2(68, 84)
	portrait.configure(hero)
	row.add_child(portrait)

	var hero_stack := VBoxContainer.new()
	hero_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_stack.custom_minimum_size.x = 250
	row.add_child(hero_stack)
	var hero_label := _label(String(HeroCatalog.HEROES[hero]["name_ru"]).to_upper(), 32, VisualTokens.COLOR_STEEL_900, true)
	hero_label.name = "DeckHero"
	hero_stack.add_child(hero_label)
	var faction_row := HBoxContainer.new()
	faction_row.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	hero_stack.add_child(faction_row)
	var emblem := EmblemView.for_faction(HeroCatalog.faction_of(hero), Color("e6dfd1"))
	emblem.custom_minimum_size = Vector2(30, 30)
	faction_row.add_child(emblem)
	faction_row.add_child(_label(SetupUi.faction_name(HeroCatalog.faction_of(hero)).to_upper(), 22,
		HeroPresentation.faction_accent(hero)))

	var name_stack := VBoxContainer.new()
	name_stack.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_stack)
	name_stack.add_child(_caption("НАЗВАНИЕ КОЛОДЫ"))
	name_edit = LineEdit.new()
	name_edit.name = "DeckName"
	name_edit.placeholder_text = "Название колоды"
	name_edit.max_length = UserDeck.MAX_NAME_LENGTH + 10
	UiKit.prepare_text_field(name_edit)
	name_edit.text_changed.connect(_on_name_changed)
	name_stack.add_child(name_edit)

	var count_stack := VBoxContainer.new()
	count_stack.custom_minimum_size.x = 150
	row.add_child(count_stack)
	count_stack.add_child(_caption("КАРТЫ"))
	count_label = _label("0 / 30", 36, VisualTokens.COLOR_STEEL_900, true)
	count_label.name = "DeckCount"
	count_stack.add_child(count_label)

	var status_stack := VBoxContainer.new()
	status_stack.custom_minimum_size.x = 300
	row.add_child(status_stack)
	var status_caption := HBoxContainer.new()
	status_caption.add_theme_constant_override("separation", VisualTokens.SPACE_2)
	status_stack.add_child(status_caption)
	status_caption.add_child(_caption("СТАТУС"))
	selected_marker = _label("✓ ВЫБРАНА ДЛЯ БОЯ", 18, VisualTokens.COLOR_GOLD_700)
	selected_marker.name = "SelectedForBattle"
	status_caption.add_child(selected_marker)
	ready_marker = PanelContainer.new()
	ready_marker.name = "ReadinessMarker"
	status_stack.add_child(ready_marker)
	ready_label = _label("НЕ ГОТОВА", 26, VisualTokens.COLOR_STEEL_900, true)
	ready_label.name = "DeckStatus"
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_marker.add_child(ready_label)

	var header := find_child("Header", true, false) as HBoxContainer
	var change := UiKit.make_button("СМЕНИТЬ ГЕРОЯ", UiKit.ButtonRole.SUBTLE)
	change.name = "ChangeHeroButton"
	change.add_theme_font_size_override("font_size", 26)
	change.custom_minimum_size = Vector2(240, 72)
	change.pressed.connect(SceneRouter.go_to.bind(Routes.HERO_SELECT))
	header.add_child(change)


func _build_tab_row() -> void:
	var row := HFlowContainer.new()
	row.name = "TabRow"
	row.add_theme_constant_override("h_separation", VisualTokens.SPACE_4)
	row.add_theme_constant_override("v_separation", VisualTokens.SPACE_2)
	content.add_child(row)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", VisualTokens.SPACE_2)
	row.add_child(tabs)
	cards_tab_button = _tab_button("КАРТЫ", "CardsTabButton", Tab.CARDS)
	tabs.add_child(cards_tab_button)
	deck_tab_button = _tab_button("КОЛОДА", "DeckTabButton", Tab.DECK)
	tabs.add_child(deck_tab_button)
	filter_bar = CardFilterBar.new()
	filter_bar.name = "CardFilterBar"
	filter_bar.allowed_factions = [HeroCatalog.faction_of(hero), Faction.Id.NEUTRAL]
	filter_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	filter_bar.filters_changed.connect(_refresh_grid)
	row.add_child(filter_bar)
	deck_hint = _label("Нажмите на название карты, чтобы прочитать её полностью", 22, VisualTokens.COLOR_MUTED)
	deck_hint.name = "DeckHint"
	deck_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	deck_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deck_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deck_hint.custom_minimum_size.y = 68
	row.add_child(deck_hint)


func _tab_button(text_value: String, node_name: String, tab: Tab) -> Button:
	var button := UiKit.make_button(text_value, UiKit.ButtonRole.SEGMENT)
	button.name = node_name
	button.toggle_mode = true
	button.button_group = _tab_group
	button.custom_minimum_size = Vector2(220, 68)
	button.add_theme_font_size_override("font_size", 30)
	button.toggled.connect(func(on: bool) -> void:
		if on:
			_set_tab(tab))
	return button


func _style_tab(button: Button, active: bool) -> void:
	UiKit.style_button(button, UiKit.ButtonRole.PRIMARY if active else UiKit.ButtonRole.SECONDARY)
	button.add_theme_font_size_override("font_size", 30)
	button.custom_minimum_size = Vector2(220, 68)
	button.icon = UiKit.CHECK_ICON if active else null
	button.add_theme_color_override("icon_normal_color", VisualTokens.COLOR_GOLD_300)
	button.add_theme_color_override("icon_pressed_color", VisualTokens.COLOR_GOLD_300)


func _build_cards_page(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "AvailableScroll"
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.prepare_scroll(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	cards_page = scroll
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_top", VisualTokens.SPACE_2)
	wrap.add_theme_constant_override("margin_bottom", VisualTokens.SPACE_3)
	scroll.add_child(wrap)
	grid = GridContainer.new()
	grid.name = "AvailableGrid"
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", VisualTokens.SPACE_3)
	grid.add_theme_constant_override("v_separation", VisualTokens.SPACE_4)
	wrap.add_child(grid)


func _build_deck_page(parent: Control) -> void:
	var page := HBoxContainer.new()
	page.name = "DeckPanel"
	page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	parent.add_child(page)
	deck_page = page

	var list_column := VBoxContainer.new()
	list_column.size_flags_horizontal = SIZE_EXPAND_FILL
	page.add_child(list_column)
	var scroll := ScrollContainer.new()
	scroll.name = "DeckScroll"
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	UiKit.prepare_scroll(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(scroll)
	deck_list = VBoxContainer.new()
	deck_list.name = "DeckList"
	deck_list.size_flags_horizontal = SIZE_EXPAND_FILL
	deck_list.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	scroll.add_child(deck_list)
	empty_deck_hint = _label("Колода пуста. Добавьте карты на вкладке «Карты».", 28, VisualTokens.COLOR_MUTED)
	empty_deck_hint.name = "EmptyDeckHint"
	empty_deck_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_column.add_child(empty_deck_hint)

	var summary_scroll := ScrollContainer.new()
	summary_scroll.name = "DeckSummary"
	summary_scroll.custom_minimum_size.x = 480
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.prepare_scroll(summary_scroll)
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(summary_scroll)
	var summary := UiKit.make_panel(false)
	summary.name = "DeckSummaryPanel"
	summary.size_flags_horizontal = SIZE_EXPAND_FILL
	summary.size_flags_vertical = SIZE_EXPAND_FILL
	summary_scroll.add_child(summary)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	summary.add_child(stack)
	stack.add_child(_caption("КРИВАЯ СТОИМОСТИ"))
	curve_view = DeckCurveView.new()
	curve_view.name = "CostCurve"
	stack.add_child(curve_view)
	stack.add_child(_caption("СОСТАВ"))
	composition_label = _label("", 24, VisualTokens.COLOR_STEEL_900)
	composition_label.name = "DeckComposition"
	composition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(composition_label)
	stack.add_child(_caption("ГОТОВНОСТЬ"))
	guidance_label = _label("", 24, VisualTokens.COLOR_STEEL_700)
	guidance_label.name = "DeckGuidance"
	guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(guidance_label)


func _build_footer() -> void:
	var footer := HBoxContainer.new()
	footer.name = "DeckActions"
	footer.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	content.add_child(footer)
	deck_select = OptionButton.new()
	deck_select.name = "DeckSelector"
	deck_select.custom_minimum_size = Vector2(320, 76)
	deck_select.fit_to_longest_item = false
	deck_select.clip_text = true
	deck_select.tooltip_text = "Сохранённые колоды героя"
	UiKit.prepare_select(deck_select)
	deck_select.add_theme_font_size_override("font_size", 26)
	deck_select.item_selected.connect(_open_selected)
	footer.add_child(deck_select)
	var new_button := UiKit.make_button("НОВАЯ", UiKit.ButtonRole.SECONDARY)
	new_button.name = "NewDeckButton"
	new_button.custom_minimum_size = Vector2(190, 76)
	new_button.pressed.connect(_new_deck)
	footer.add_child(new_button)
	status_label = _label("", 24, VisualTokens.COLOR_STEEL_700)
	status_label.name = "DeckActionStatus"
	status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status_label)
	for action: Array in [
		["ClearDeckButton", "ОЧИСТИТЬ", _ask_clear, UiKit.ButtonRole.SECONDARY],
		["SaveDeckButton", "СОХРАНИТЬ", _save, UiKit.ButtonRole.SECONDARY],
		["SelectDeckButton", "ВЫБРАТЬ", _select_deck, UiKit.ButtonRole.PRIMARY],
	]:
		var button := UiKit.make_button(action[1], action[3])
		button.name = action[0]
		button.custom_minimum_size = Vector2(210, 76)
		button.pressed.connect(action[2])
		footer.add_child(button)


func show_message(text_value: String) -> void:
	super.show_message(text_value)
	if status_label != null:
		status_label.text = text_value


func handle_back_request() -> bool:
	if clear_dialog != null and clear_dialog.visible:
		clear_dialog.cancel()
		return true
	if detail != null and detail.visible:
		detail.close_detail()
		return true
	if name_edit != null and name_edit.has_focus():
		name_edit.release_focus()
		DisplayServer.virtual_keyboard_hide()
		return true
	return super.handle_back_request()


func _set_tab(tab: Tab) -> void:
	active_tab = tab
	cards_page.visible = tab == Tab.CARDS
	deck_page.visible = tab == Tab.DECK
	filter_bar.visible = tab == Tab.CARDS
	deck_hint.visible = tab == Tab.DECK
	var button := cards_tab_button if tab == Tab.CARDS else deck_tab_button
	if not button.button_pressed:
		button.set_pressed_no_signal(true)
	_style_tab(cards_tab_button, tab == Tab.CARDS)
	_style_tab(deck_tab_button, tab == Tab.DECK)


func show_tab(tab: Tab) -> void:
	_set_tab(tab)


func _update_columns() -> void:
	if grid != null:
		grid.columns = ResponsiveLayout.collection_columns_for_size(get_viewport_rect().size)


func _refresh_all() -> void:
	_update_columns()
	name_edit.text = draft.name
	_refresh_selector()
	_refresh_grid()
	_refresh_deck()


func _refresh_selector() -> void:
	deck_select.clear()
	var decks := PlayerSetupData.decks_for(AppState.profile, draft.hero_id)
	deck_select.add_item("НОВАЯ (НЕ СОХРАНЕНА)", 0)
	deck_select.set_item_metadata(0, "")
	deck_select.select(0)
	for i in decks.size():
		deck_select.add_item(decks[i].name, i + 1)
		deck_select.set_item_metadata(i + 1, decks[i].id)
		if decks[i].id == draft.id:
			deck_select.select(i + 1)
	deck_select.disabled = decks.is_empty()


func _open_selected(index: int) -> void:
	var id: String = deck_select.get_item_metadata(index)
	if id.is_empty():
		draft = UserDeck.create(draft.hero_id)
		_refresh_all()
		show_message("Новая колода создана")
		return
	for saved: UserDeck in PlayerSetupData.decks_for(AppState.profile, draft.hero_id):
		if saved.id == id:
			draft = saved
			_refresh_all()
			show_message("Открыта колода «%s»" % saved.name)
			return


func _new_deck() -> void:
	draft = UserDeck.create(draft.hero_id)
	_refresh_all()
	show_message("Новая колода создана")


func _on_name_changed(value: String) -> void:
	draft.name = value
	_refresh_status()


func _refresh_grid() -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_cells.clear()
	for card: CardDefinition in CardDatabase.get_all_cards():
		if not filter_bar.matches(card):
			continue
		var id := String(card.id)
		var cell := VBoxContainer.new()
		cell.name = "Cell_%s" % id
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", VisualTokens.SPACE_1)
		grid.add_child(cell)
		var view := FullCardView.new()
		view.configure(card)
		view.name = "Card_%s" % id
		view.size_flags_horizontal = SIZE_SHRINK_CENTER
		cell.add_child(view)
		view.card_activated.connect(_open_detail)
		var controls := HBoxContainer.new()
		controls.name = "CopyControls"
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		controls.add_theme_constant_override("separation", VisualTokens.SPACE_2)
		cell.add_child(controls)
		var less := _step_button("−", "Less_%s" % id)
		less.pressed.connect(_remove_card.bind(id))
		controls.add_child(less)
		var count := _label("", 28, VisualTokens.COLOR_STEEL_900, true)
		count.name = "Copies_%s" % id
		count.custom_minimum_size.x = 110
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		controls.add_child(count)
		var add := _step_button("+", "Add_%s" % id)
		add.pressed.connect(_add_card.bind(id))
		controls.add_child(add)
		_cells[id] = {"view": view, "less": less, "add": add, "count": count, "limit": card.deck_limit}
	_sync_cells()


func _sync_cells() -> void:
	var full := draft.card_ids.size() >= GameRules.DECK_SIZE
	for id: String in _cells:
		var cell: Dictionary = _cells[id]
		var copies := draft.card_ids.count(id)
		(cell["count"] as Label).text = "%d / %d" % [copies, int(cell["limit"])]
		(cell["add"] as Button).disabled = copies >= int(cell["limit"]) or full
		(cell["less"] as Button).disabled = copies == 0
		(cell["view"] as FullCardView).set_copy_count(copies)


func _add_card(card_id: String) -> void:
	var card := CardDatabase.get_card(StringName(card_id))
	if card == null or (card.faction != HeroCatalog.faction_of(draft.hero_id) and card.faction != Faction.Id.NEUTRAL):
		return
	if draft.card_ids.count(card_id) >= card.deck_limit or draft.card_ids.size() >= GameRules.DECK_SIZE:
		return
	draft.card_ids.append(card_id)
	_after_deck_change()


func _remove_card(card_id: String) -> void:
	var index := draft.card_ids.find(card_id)
	if index < 0:
		return
	draft.card_ids.remove_at(index)
	_after_deck_change()


func _after_deck_change() -> void:
	_sync_cells()
	_refresh_deck()


func _refresh_deck() -> void:
	for child: Node in deck_list.get_children():
		deck_list.remove_child(child)
		child.queue_free()
	var counts: Dictionary = {}
	for id: String in draft.card_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	var ordered: Array = counts.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		var card_a := CardDatabase.get_card(StringName(a))
		var card_b := CardDatabase.get_card(StringName(b))
		var cost_a := card_a.cost if card_a != null else 99
		var cost_b := card_b.cost if card_b != null else 99
		if cost_a != cost_b:
			return cost_a < cost_b
		return (card_a.name_ru if card_a != null else a) < (card_b.name_ru if card_b != null else b))
	for id: String in ordered:
		deck_list.add_child(_deck_row(id, int(counts[id])))
	empty_deck_hint.visible = ordered.is_empty()
	_refresh_summary()
	_refresh_status()


func _deck_row(id: String, copies: int) -> PanelContainer:
	var card := CardDatabase.get_card(StringName(id))
	var row_panel := PanelContainer.new()
	row_panel.name = "Row_%s" % id
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f1ece2")
	box.border_color = VisualTokens.COLOR_STONE_300
	box.set_border_width_all(1)
	box.set_corner_radius_all(VisualTokens.RADIUS_SMALL)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	row_panel.add_child(row)

	var cost := _label(str(card.cost) if card != null else "?", 30, VisualTokens.COLOR_STONE_050, true)
	cost.custom_minimum_size = Vector2(60, 60)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cost_box := StyleBoxFlat.new()
	cost_box.bg_color = VisualTokens.COLOR_STEEL_900
	cost_box.border_color = VisualTokens.COLOR_GOLD_500
	cost_box.set_border_width_all(2)
	cost_box.set_corner_radius_all(VisualTokens.RADIUS_SMALL)
	cost.add_theme_stylebox_override("normal", cost_box)
	row.add_child(cost)
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.color = CardFactionPresentation.accent(card.faction) if card != null else VisualTokens.COLOR_STEEL_500
	row.add_child(stripe)

	var name_button := Button.new()
	name_button.name = "Info_%s" % id
	name_button.flat = true
	name_button.size_flags_horizontal = SIZE_EXPAND_FILL
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.custom_minimum_size.y = 64
	name_button.tooltip_text = "Открыть описание карты"
	name_button.pressed.connect(_open_detail.bind(StringName(id)))
	row.add_child(name_button)
	var name_stack := VBoxContainer.new()
	name_stack.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	name_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	name_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_stack.add_theme_constant_override("separation", 0)
	name_button.add_child(name_stack)
	var title := _label(card.name_ru if card != null else id, 28, VisualTokens.COLOR_STEEL_900, true)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_stack.add_child(title)
	if card != null:
		var sub := _label("%s · %s" % [SetupUi.TYPE_NAMES[card.card_type].to_upper(), SetupUi.RARITY_NAMES[card.rarity].to_upper()],
			17, VisualTokens.COLOR_MUTED)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_stack.add_child(sub)

	var remove := _step_button("−", "Remove_%s" % id)
	remove.pressed.connect(_remove_card.bind(id))
	row.add_child(remove)
	var count := _label("×%d" % copies, 30, VisualTokens.COLOR_STEEL_900, true)
	count.custom_minimum_size.x = 64
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)
	var more := _step_button("+", "More_%s" % id)
	more.disabled = card == null or copies >= card.deck_limit or draft.card_ids.size() >= GameRules.DECK_SIZE
	more.pressed.connect(_add_card.bind(id))
	row.add_child(more)
	return row_panel


func _refresh_summary() -> void:
	var costs: Array[int] = []
	var by_type := {}
	for id: String in draft.card_ids:
		var card := CardDatabase.get_card(StringName(id))
		if card == null:
			continue
		costs.append(card.cost)
		by_type[card.card_type] = int(by_type.get(card.card_type, 0)) + 1
	curve_view.set_costs(costs)
	var parts := PackedStringArray()
	for card_type: CardEnums.Type in [CardEnums.Type.CREATURE, CardEnums.Type.SPELL, CardEnums.Type.ARTIFACT, CardEnums.Type.CURSE]:
		if by_type.has(card_type):
			parts.append("%s: %d" % [CollectionScreen.TYPE_LABELS[card_type], by_type[card_type]])
	composition_label.text = "\n".join(parts) if not parts.is_empty() else "Карт пока нет"


func _refresh_status() -> void:
	var total := draft.card_ids.size()
	count_label.text = "%d / %d" % [total, GameRules.DECK_SIZE]
	var deck_ready := draft.is_ready(CardDatabase)
	ready_label.text = "ГОТОВА" if deck_ready else "НЕ ГОТОВА"
	ready_marker.add_theme_stylebox_override("panel", _marker_box(deck_ready))
	ready_label.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050 if deck_ready else VisualTokens.COLOR_STEEL_900)
	var name_issue := draft.name_problem()
	if not name_issue.is_empty():
		guidance_label.text = name_issue
	elif deck_ready:
		guidance_label.text = "Колода соответствует правилам: %d карт, фракция героя и нейтральные карты, лимиты копий." % GameRules.DECK_SIZE
	elif total < GameRules.DECK_SIZE:
		guidance_label.text = "Нужно ровно %d карт: добавьте ещё %d." % [GameRules.DECK_SIZE, GameRules.DECK_SIZE - total]
	elif total > GameRules.DECK_SIZE:
		guidance_label.text = "Нужно ровно %d карт: уберите %d." % [GameRules.DECK_SIZE, total - GameRules.DECK_SIZE]
	else:
		guidance_label.text = "Проверьте фракцию, карты и лимиты копий."
	var select := find_child("SelectDeckButton", true, false) as Button
	if select != null:
		select.disabled = not deck_ready
	deck_tab_button.text = "КОЛОДА · %d/%d" % [total, GameRules.DECK_SIZE]
	selected_marker.visible = str(AppState.profile.get("selected_deck_id", "")) == draft.id and deck_ready


func _marker_box(deck_ready: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = VisualTokens.COLOR_MAGIC_700 if deck_ready else Color("efe2c4")
	box.border_color = VisualTokens.COLOR_MAGIC_300 if deck_ready else VisualTokens.COLOR_GOLD_700
	box.set_border_width_all(2)
	box.set_corner_radius_all(VisualTokens.RADIUS_SMALL)
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box


func _save() -> void:
	if not draft.name_problem().is_empty():
		show_message(draft.name_problem())
		return
	draft.name = draft.name.strip_edges()
	var next := PlayerSetupData.upsert(AppState.profile, draft, CardDatabase)
	if AppState.persist_profile(next) != OK:
		show_message("Сохранение не удалось. Текущий черновик сохранён на экране.")
		return
	show_message("Колода сохранена" if draft.is_ready(CardDatabase) else "Черновик сохранён; для боя нужна готовая колода")
	_refresh_selector()
	_refresh_status()


func _select_deck() -> void:
	if not draft.is_ready(CardDatabase):
		show_message("Сначала соберите готовую колоду")
		return
	var next := PlayerSetupData.upsert(AppState.profile, draft, CardDatabase)
	next["selected_deck_id"] = draft.id
	if AppState.persist_profile(next) == OK:
		show_message("Колода «%s» выбрана для боя" % draft.name.strip_edges())
		_refresh_selector()
		_refresh_status()
	else:
		show_message("Не удалось сохранить выбор")


func _ask_clear() -> void:
	clear_dialog.popup()


func _clear() -> void:
	draft.card_ids.clear()
	_after_deck_change()
	show_message("Колода очищена")


func _open_detail(card_id: StringName) -> void:
	detail.open_card(card_id)


func _step_button(text_value: String, node_name: String) -> Button:
	var button := UiKit.make_button(text_value, UiKit.ButtonRole.SECONDARY)
	button.name = node_name
	button.custom_minimum_size = Vector2(84, 64)
	button.add_theme_font_size_override("font_size", 38)
	return button


func _caption(text_value: String) -> Label:
	return _label(text_value, 18, VisualTokens.COLOR_MUTED)


func _label(text_value: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		var display_font := load(UiKit.DISPLAY_FONT_PATH) as Font
		if display_font != null:
			label.add_theme_font_override("font", display_font)
	return label
