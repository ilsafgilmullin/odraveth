class_name DeckBuilderScreen
extends SetupScreen
## Local draft editor. DeckValidator is the only readiness authority.

var draft: UserDeck
var filter_bar: CardFilterBar
var grid: GridContainer
var deck_list: VBoxContainer
var deck_select: OptionButton
var name_edit: LineEdit
var count_label: Label
var ready_label: Label
var detail: CardDetailOverlay
var clear_dialog: ConfirmationDialog


func _route_id() -> StringName:
	return Routes.DECK_BUILDER


func _build_content() -> void:
	var hero := StringName(str(AppState.profile.get("selected_hero_id", "")))
	if not HeroCatalog.has_hero(hero):
		show_message("Сначала выберите героя для колоды")
		var choose := Button.new()
		choose.name = "ChangeHeroButton"
		choose.text = "Выбрать героя"
		choose.custom_minimum_size.y = 88
		choose.pressed.connect(SceneRouter.go_to.bind(Routes.HERO_SELECT))
		content.add_child(choose)
		return
	var title := HBoxContainer.new()
	content.add_child(title)
	var hero_label := Label.new()
	hero_label.name = "DeckHero"
	hero_label.text = "%s · %s" % [HeroCatalog.HEROES[hero]["name_ru"], SetupUi.faction_name(HeroCatalog.faction_of(hero))]
	hero_label.size_flags_horizontal = SIZE_EXPAND_FILL
	title.add_child(hero_label)
	var change := Button.new()
	change.name = "ChangeHeroButton"
	change.text = "Сменить героя"
	change.custom_minimum_size = Vector2(200, 64)
	change.pressed.connect(SceneRouter.go_to.bind(Routes.HERO_SELECT))
	title.add_child(change)
	deck_select = OptionButton.new()
	deck_select.name = "DeckSelector"
	deck_select.custom_minimum_size = Vector2(300, 64)
	title.add_child(deck_select)
	deck_select.item_selected.connect(_open_selected)
	var new_button := Button.new()
	new_button.name = "NewDeckButton"
	new_button.text = "Новая колода"
	new_button.custom_minimum_size = Vector2(190, 64)
	new_button.pressed.connect(_new_deck)
	title.add_child(new_button)
	var body := HBoxContainer.new()
	body.name = "DeckBody"
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(left)
	filter_bar = CardFilterBar.new()
	filter_bar.allowed_factions = [HeroCatalog.faction_of(hero), Faction.Id.NEUTRAL]
	var filter_scroll := ScrollContainer.new()
	filter_scroll.name = "FilterScroll"
	filter_scroll.custom_minimum_size.y = 76
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(filter_scroll)
	filter_scroll.add_child(filter_bar)
	filter_bar.filters_changed.connect(_refresh_grid)
	var scroll := ScrollContainer.new()
	scroll.name = "AvailableScroll"
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	grid = GridContainer.new()
	grid.name = "AvailableGrid"
	grid.columns = 3
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var right := VBoxContainer.new()
	right.name = "DeckPanel"
	right.custom_minimum_size.x = 470
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(right)
	name_edit = LineEdit.new()
	name_edit.name = "DeckName"
	name_edit.placeholder_text = "Название колоды"
	name_edit.custom_minimum_size.y = 64
	name_edit.text_changed.connect(func(value: String) -> void:
		draft.name = value
		_refresh_status())
	right.add_child(name_edit)
	count_label = Label.new()
	count_label.name = "DeckCount"
	right.add_child(count_label)
	ready_label = Label.new()
	ready_label.name = "DeckStatus"
	right.add_child(ready_label)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.name = "DeckScroll"
	deck_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(deck_scroll)
	deck_list = VBoxContainer.new()
	deck_list.name = "DeckList"
	deck_list.size_flags_horizontal = SIZE_EXPAND_FILL
	deck_scroll.add_child(deck_list)
	var actions := HBoxContainer.new()
	right.add_child(actions)
	for action: Array in [["SaveDeckButton", "Сохранить", _save],
			["SelectDeckButton", "Выбрать", _select_deck], ["ClearDeckButton", "Очистить", _ask_clear]]:
		var button := Button.new()
		button.name = action[0]
		button.text = action[1]
		button.custom_minimum_size = Vector2(145, 72)
		button.pressed.connect(action[2])
		actions.add_child(button)
	clear_dialog = ConfirmationDialog.new()
	clear_dialog.name = "ClearConfirmation"
	clear_dialog.dialog_text = "Очистить текущую колоду?"
	clear_dialog.confirmed.connect(_clear)
	add_child(clear_dialog)
	detail = CardDetailOverlay.new()
	add_child(detail)
	get_viewport().size_changed.connect(_update_columns)
	var decks := PlayerSetupData.decks_for(AppState.profile, hero)
	draft = decks[0] if not decks.is_empty() else UserDeck.create(hero)
	var selected_id := str(AppState.profile.get("selected_deck_id", ""))
	for deck: UserDeck in decks:
		if deck.id == selected_id:
			draft = deck
			break
	_refresh_all()


func _update_columns() -> void:
	if grid != null:
		grid.columns = clampi(int((get_viewport_rect().size.x - 500.0) / 340.0), 2, 5)


func _refresh_all() -> void:
	_update_columns()
	name_edit.text = draft.name
	_refresh_selector()
	_refresh_grid()
	_refresh_deck()


func _refresh_selector() -> void:
	deck_select.clear()
	var decks := PlayerSetupData.decks_for(AppState.profile, draft.hero_id)
	deck_select.add_item("Новая колода (черновик)", 0)
	deck_select.set_item_metadata(0, "")
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
		return
	for saved: UserDeck in PlayerSetupData.decks_for(AppState.profile, draft.hero_id):
		if saved.id == id:
			draft = saved
			_refresh_all()
			return


func _new_deck() -> void:
	draft = UserDeck.create(draft.hero_id)
	_refresh_all()


func _refresh_grid() -> void:
	for child: Node in grid.get_children():
		child.queue_free()
		grid.remove_child(child)
	for card: CardDefinition in CardDatabase.get_all_cards():
		if not filter_bar.matches(card):
			continue
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 250
		grid.add_child(cell)
		var add := SetupUi.card_tile(card)
		add.name = "Add_%s" % card.id
		add.text += "\nВ колоде: %d/%d · +" % [draft.card_ids.count(String(card.id)), card.deck_limit]
		add.disabled = draft.card_ids.count(String(card.id)) >= card.deck_limit or draft.card_ids.size() >= GameRules.DECK_SIZE
		add.pressed.connect(_add_card.bind(card))
		cell.add_child(add)
		var info := Button.new()
		info.name = "Info_%s" % card.id
		info.text = "Описание"
		info.custom_minimum_size.y = 52
		info.pressed.connect(detail.show_card.bind(card))
		cell.add_child(info)


func _add_card(card: CardDefinition) -> void:
	if card.faction != HeroCatalog.faction_of(draft.hero_id) and card.faction != Faction.Id.NEUTRAL:
		return
	if draft.card_ids.count(String(card.id)) >= card.deck_limit or draft.card_ids.size() >= GameRules.DECK_SIZE:
		return
	draft.card_ids.append(String(card.id))
	_refresh_grid()
	_refresh_deck()


func _remove_card(card_id: String) -> void:
	var index := draft.card_ids.find(card_id)
	if index >= 0:
		draft.card_ids.remove_at(index)
	_refresh_grid()
	_refresh_deck()


func _refresh_deck() -> void:
	for child: Node in deck_list.get_children():
		child.queue_free()
		deck_list.remove_child(child)
	var counts: Dictionary = {}
	for id: String in draft.card_ids:
		counts[id] = counts.get(id, 0) + 1
	for id: String in counts:
		var card: CardDefinition = CardDatabase.get_card(StringName(id))
		var remove := Button.new()
		remove.name = "Remove_%s" % id
		remove.text = "%s ×%d  −" % [card.name_ru if card != null else id, counts[id]]
		remove.custom_minimum_size.y = 54
		remove.pressed.connect(_remove_card.bind(id))
		deck_list.add_child(remove)
	_refresh_status()


func _refresh_status() -> void:
	count_label.text = "%d/%d карт" % [draft.card_ids.size(), GameRules.DECK_SIZE]
	var issues := draft.problems(CardDatabase)
	if not draft.name_problem().is_empty():
		ready_label.text = draft.name_problem()
	elif issues.is_empty():
		ready_label.text = "ГОТОВА"
	elif draft.card_ids.size() != GameRules.DECK_SIZE:
		ready_label.text = "Нужно ровно %d карт" % GameRules.DECK_SIZE
	else:
		ready_label.text = "Проверьте фракцию, карты и лимиты копий"
	var select := find_child("SelectDeckButton", true, false) as Button
	select.disabled = not draft.is_ready(CardDatabase)


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
		show_message("Колода выбрана для боя")
		_refresh_selector()
	else:
		show_message("Не удалось сохранить выбор")


func _ask_clear() -> void:
	clear_dialog.popup_centered()


func _clear() -> void:
	draft.card_ids.clear()
	_refresh_grid()
	_refresh_deck()
