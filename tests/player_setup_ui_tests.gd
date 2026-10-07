extends RefCounted
## Real Stage 5 screen controls and viewport geometry.

var check: Callable
var tree: SceneTree
var saved_profile: Dictionary
var saved_manager: SaveManager


func _init(check_fn: Callable, game_tree: SceneTree) -> void:
	check = check_fn
	tree = game_tree


func _ok(value: bool, description: String) -> void:
	check.call(value, "setup UI: " + description)


func _scene(route: StringName) -> Control:
	var scene := load(Routes.scene_path(route)).instantiate() as Control
	tree.root.add_child(scene)
	return scene


func run() -> void:
	saved_profile = AppState.profile
	saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new("user://odraveth_smoke_test/setup_ui.json")
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	CardDatabase.load_directory()
	_test_hero()
	_test_collection()
	_test_builder()
	_test_prebattle()
	await _test_sizes()
	AppState.profile = saved_profile
	AppState._save_manager = saved_manager


func _test_hero() -> void:
	var scene := _scene(Routes.HERO_SELECT) as HeroSelectScreen
	_ok(scene.hero_buttons.size() == 4 and scene.hero_buttons.has(HeroCatalog.TAZHYRION), "Hero Select displays exactly four heroes")
	var persisted_before: String = AppState.profile["selected_hero_id"]
	(scene.hero_buttons[HeroCatalog.SYRRAVETH] as HeroSelectCard).pressed.emit()
	var selected_card := scene.hero_buttons[HeroCatalog.SYRRAVETH] as HeroSelectCard
	_ok(scene.pending_hero == HeroCatalog.SYRRAVETH and selected_card.selected_marker.visible
		and selected_card.button_pressed, "tap marks selected hero explicitly")
	_ok(AppState.profile["selected_hero_id"] == persisted_before, "hero tap is preview-only before confirmation")
	_ok(scene.power_name_label.text == String(HeroCatalog.HEROES[HeroCatalog.SYRRAVETH]["power_ru"]).to_upper()
		and scene.power_description_label.text == HeroPresentation.power_description(HeroCatalog.SYRRAVETH),
		"selected hero power name and full description come from authoritative presentation path")
	scene.free()


func _select_id(button: OptionButton, id: int) -> void:
	for index in button.item_count:
		if button.get_item_id(index) == id:
			button.select(index)
			button.item_selected.emit(index)
			return


func _select_deck_metadata(scene: DeckBuilderScreen, deck_id: String) -> void:
	for index in scene.deck_select.item_count:
		if String(scene.deck_select.get_item_metadata(index)) == deck_id:
			scene.deck_select.select(index)
			scene.deck_select.item_selected.emit(index)
			return


func _test_collection() -> void:
	var scene := _scene(Routes.COLLECTION) as CollectionScreen
	_ok(scene.card_grid.get_child_count() == 40, "all 40 starter cards visible")
	_select_id(scene.filter_bar.faction, Faction.Id.NEUTRAL)
	_ok(scene.card_grid.get_child_count() == 8
		and scene.filter_bar.faction.get_item_text(scene.filter_bar.faction.selected) == "Нейтральные", "Neutral filter and official label")
	_select_id(scene.filter_bar.faction, CardFilterBar.ALL)
	var card: CardDefinition = CardDatabase.get_all_cards()[0]
	scene.filter_bar.search.text = card.name_ru.to_lower()
	scene.filter_bar.search.text_changed.emit(scene.filter_bar.search.text)
	_ok(scene.card_grid.get_child_count() >= 1 and scene.filter_bar.matches(card), "case-insensitive RU name search")
	scene.filter_bar.search.text = card.name_en.to_upper()
	scene.filter_bar.search.text_changed.emit(scene.filter_bar.search.text)
	_ok(scene.card_grid.get_child_count() >= 1 and scene.filter_bar.matches(card), "case-insensitive EN name search")
	scene.filter_bar.search.text = ""
	scene.filter_bar.search.text_changed.emit("")
	_select_id(scene.filter_bar.card_type, card.card_type)
	_select_id(scene.filter_bar.rarity, card.rarity)
	_select_id(scene.filter_bar.cost, card.cost)
	_select_id(scene.filter_bar.faction, card.faction)
	_ok(scene.filter_bar.matches(card) and scene.card_grid.get_child_count() >= 1, "type, rarity, cost and faction combined")
	_select_id(scene.filter_bar.cost, 10 if card.cost != 10 else 0)
	_ok(not scene.filter_bar.matches(card), "cost filter excludes other costs")
	scene.detail.show_card(card)
	_ok(scene.detail.visible and scene.detail.detail_text.text.contains(card.name_en)
		and scene.detail.detail_text.text.contains(card.rules_text_ru), "read-only detail shows English name and approved rules")
	(scene.detail.find_child("CardDetailCloseButton", true, false) as Button).pressed.emit()
	_ok(not scene.detail.visible, "card detail closes")
	scene.detail.show_card(card)
	_ok(scene.handle_back_request() and not scene.detail.visible,
		"setup Back closes card detail before navigation")
	scene.free()


func _test_builder() -> void:
	var scene := _scene(Routes.DECK_BUILDER) as DeckBuilderScreen
	_ok(scene.draft.card_ids.is_empty() and scene.draft.name == "Новая колода", "new editable draft")
	var allowed := BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase)
	var first: String = String(allowed[0])
	var add := scene.find_child("Add_%s" % first, true, false) as Button
	add.pressed.emit()
	_ok(scene.draft.card_ids.size() == 1, "tap adds one card")
	var remove := scene.find_child("Remove_%s" % first, true, false) as Button
	remove.pressed.emit()
	_ok(scene.draft.card_ids.is_empty(), "remove control removes one copy")
	_ok(scene.filter_bar.allowed_factions == [Faction.Id.ASHRAVAEL, Faction.Id.NEUTRAL], "only hero faction and Neutral offered")
	for id: StringName in allowed:
		(scene.find_child("Add_%s" % id, true, false) as Button).pressed.emit()
	_ok(scene.draft.is_ready(CardDatabase) and scene.ready_label.text == "ГОТОВА", "30 cards gives validator READY")
	_ok(scene.deck_list.get_child_count() > 0 and not (scene.find_child("SelectDeckButton", true, false) as Button).disabled,
		"ready deck exposes selection action")
	var last: String = String(allowed[-1])
	(scene.find_child("Remove_%s" % last, true, false) as Button).pressed.emit()
	_ok(scene.draft.card_ids.size() == 29 and scene.ready_label.text != "ГОТОВА"
		and (scene.find_child("SelectDeckButton", true, false) as Button).disabled, "29-card deck is not selectable")
	(scene.find_child("Add_%s" % last, true, false) as Button).pressed.emit()
	var legendary: CardDefinition
	for card: CardDefinition in CardDatabase.get_all_cards():
		if card.faction == Faction.Id.ASHRAVAEL and card.rarity == CardEnums.Rarity.LEGENDARY:
			legendary = card
			break
	_ok(legendary != null and legendary.deck_limit == 1, "legendary limit comes from CardDefinition")
	if legendary != null:
		scene.draft.card_ids.clear()
		(scene.find_child("Add_%s" % legendary.id, true, false) as Button).pressed.emit()
		_ok((scene.find_child("Add_%s" % legendary.id, true, false) as Button).disabled, "second legendary copy disabled")
	scene.name_edit.text = "Колода A"
	scene.name_edit.text_changed.emit(scene.name_edit.text)
	(scene.find_child("SaveDeckButton", true, false) as Button).pressed.emit()
	var deck_a_id := scene.draft.id
	var deck_a_cards := scene.draft.card_ids.duplicate()
	_ok(AppState.profile["user_decks"].size() == 1 and AppState.profile["user_decks"][0]["name"] == "Колода A",
		"draft save persists deck A")

	(scene.find_child("NewDeckButton", true, false) as Button).pressed.emit()
	_ok(scene.draft.id != deck_a_id, "new deck uses distinct ID")
	_ok(scene.deck_select.get_selected_id() == 0, "unsaved draft is distinct in deck selector")
	scene.name_edit.text = "Колода B"
	scene.name_edit.text_changed.emit(scene.name_edit.text)
	(scene.find_child("SaveDeckButton", true, false) as Button).pressed.emit()
	var deck_b_id := scene.draft.id
	_ok(AppState.profile["user_decks"].size() == 2 and deck_b_id != deck_a_id,
		"deck B save creates a second distinct record")
	_ok(scene.deck_select.item_count == 3, "UI selector offers both saved decks and new draft")

	_select_deck_metadata(scene, deck_a_id)
	_ok(scene.draft.id == deck_a_id and scene.draft.name == "Колода A",
		"DeckSelector switches B -> A")
	_select_deck_metadata(scene, deck_b_id)
	_ok(scene.draft.id == deck_b_id and scene.draft.name == "Колода B",
		"DeckSelector switches A -> B")
	_select_deck_metadata(scene, deck_a_id)
	_ok(scene.draft.id == deck_a_id and scene.draft.name == "Колода A",
		"DeckSelector switches B -> A again")

	_select_deck_metadata(scene, "")
	var new_draft_id := scene.draft.id
	_ok(new_draft_id != deck_a_id and new_draft_id != deck_b_id,
		"DeckSelector draft item creates a new UserDeck ID")
	_ok(scene.draft.card_ids.is_empty(), "DeckSelector draft starts with empty card_ids")
	_ok(scene.draft.name == "Новая колода", "DeckSelector draft uses default name")
	scene.name_edit.text = "Новая третья"
	scene.name_edit.text_changed.emit(scene.name_edit.text)
	scene.draft.card_ids.append("neutral_vantrel_duskling")
	var saved_a_before: UserDeck = PlayerSetupData.decks_for(AppState.profile, HeroCatalog.KEZHARYN).filter(
		func(deck: UserDeck) -> bool: return deck.id == deck_a_id)[0] as UserDeck
	var saved_b_before: UserDeck = PlayerSetupData.decks_for(AppState.profile, HeroCatalog.KEZHARYN).filter(
		func(deck: UserDeck) -> bool: return deck.id == deck_b_id)[0] as UserDeck
	_ok(saved_a_before.name == "Колода A" and saved_a_before.card_ids == deck_a_cards
		and saved_b_before.name == "Колода B" and saved_b_before.card_ids.is_empty(),
		"editing selector-created draft does not mutate saved A/B")
	(scene.find_child("SaveDeckButton", true, false) as Button).pressed.emit()
	_ok(AppState.profile["user_decks"].size() == 3
		and AppState.profile["user_decks"].any(func(record: Dictionary) -> bool: return record["id"] == new_draft_id),
		"saving selector-created draft creates a third record")

	_select_deck_metadata(scene, deck_a_id)
	scene.name_edit.text = "Колода A обновлена"
	scene.name_edit.text_changed.emit(scene.name_edit.text)
	(scene.find_child("SaveDeckButton", true, false) as Button).pressed.emit()
	var a_records: Array = AppState.profile["user_decks"].filter(
		func(record: Dictionary) -> bool: return record["id"] == deck_a_id)
	_ok(AppState.profile["user_decks"].size() == 3 and a_records.size() == 1
		and a_records[0]["name"] == "Колода A обновлена",
		"re-saving A updates its record without creating a duplicate")

	_select_deck_metadata(scene, "")
	(scene.find_child("ClearDeckButton", true, false) as Button).pressed.emit()
	_ok(scene.clear_dialog.visible, "clear requires confirmation")
	_ok(scene.handle_back_request() and not scene.clear_dialog.visible,
		"setup Back dismisses confirmation before navigation")
	(scene.find_child("ClearDeckButton", true, false) as Button).pressed.emit()
	scene.clear_dialog.confirmed.emit()
	_ok(scene.draft.card_ids.is_empty(), "confirmed clear keeps editable draft")
	scene.free()


func _test_prebattle() -> void:
	var scene := _scene(Routes.PREBATTLE) as PrebattleScreen
	_ok(scene.start_button.disabled and scene.opponent_buttons.size() == 4, "invalid selection blocks Start; four opponent choices")
	_ok(scene.difficulty.item_count == 3 and scene.toggles.values().all(func(toggle: CheckButton) -> bool: return toggle.button_pressed),
		"three difficulties and three default ON toggles")
	scene.toggles[PlayerSetupData.ANIMATIONS].button_pressed = false
	scene.toggles[PlayerSetupData.ANIMATIONS].toggled.emit(false)
	_ok(AppState.profile["prebattle"][PlayerSetupData.ANIMATIONS] == false,
		"animation preference persisted by UI")
	scene.opponent_buttons[HeroCatalog.KEZHARYN].pressed.emit()
	_ok(AppState.profile["prebattle"]["opponent_hero_id"] == String(HeroCatalog.KEZHARYN), "mirror opponent allowed and saved")
	scene.difficulty.select(1)
	scene.difficulty.item_selected.emit(1)
	_ok(AppState.profile["prebattle"]["ai_difficulty"] == "TACTICIAN", "difficulty saved")
	scene.free()


func _test_sizes() -> void:
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(2400, 1080)]:
		tree.root.size = dimensions
		for route: StringName in [Routes.HERO_SELECT, Routes.COLLECTION, Routes.DECK_BUILDER, Routes.PREBATTLE]:
			var scene := _scene(route)
			await tree.process_frame
			await tree.process_frame
			var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
			var back := scene.find_child("BackButton", true, false) as Control
			_ok(viewport.encloses(back.get_global_rect()) and back.is_visible_in_tree(),
				"%s %s: navigation in viewport" % [route, dimensions])
			if route == Routes.HERO_SELECT:
				var confirm := scene.find_child("ConfirmHeroButton", true, false) as Control
				_ok(viewport.encloses(confirm.get_global_rect()) and confirm.is_visible_in_tree(),
					"%s: four heroes and confirm accessible" % dimensions)
			if route == Routes.COLLECTION:
				var collection := scene as CollectionScreen
				_ok(collection.card_scroll.size.y > 0 and collection.card_grid.columns >= 4
					and viewport.encloses(collection.card_scroll.get_global_rect()),
					"%s: adaptive vertically scrollable Collection grid" % dimensions)
			if route == Routes.DECK_BUILDER:
				var editor := scene as DeckBuilderScreen
				var panel := scene.find_child("DeckPanel", true, false) as Control
				var grid_scroll := scene.find_child("AvailableScroll", true, false) as Control
				var deck_scroll := scene.find_child("DeckScroll", true, false) as ScrollContainer
				_ok(grid_scroll.get_global_rect().end.x <= panel.get_global_rect().position.x + 2
					and viewport.encloses(panel.get_global_rect()) and deck_scroll.size.y > 0,
					"%s: editor grid and scrollable deck panel do not overlap (%s, %s)" % [dimensions,
						grid_scroll.get_global_rect(), panel.get_global_rect()])
				_ok(editor.grid.columns >= 2 and viewport.encloses((scene.find_child("SaveDeckButton", true, false) as Control).get_global_rect()),
					"%s: deck actions visible" % dimensions)
				editor.draft.card_ids.assign(BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase))
				editor._refresh_deck()
				await tree.process_frame
				if editor.deck_list.get_child_count() > 1:
					deck_scroll.scroll_vertical = int(deck_scroll.get_v_scroll_bar().max_value)
					await tree.process_frame
					_ok(editor.deck_list.get_child_count() > 1 and deck_scroll.get_global_rect().end.y >=
						(editor.deck_list.get_child(editor.deck_list.get_child_count() - 1) as Control).get_global_rect().end.y - 2,
						"%s: last entry in 30-card deck accessible by scroll (%s, %s, scroll %d/%f)" % [dimensions,
							deck_scroll.get_global_rect(),
							(editor.deck_list.get_child(editor.deck_list.get_child_count() - 1) as Control).get_global_rect(),
							deck_scroll.scroll_vertical, deck_scroll.get_v_scroll_bar().max_value])
			if route == Routes.PREBATTLE:
				var start := scene.find_child("StartBattleButton", true, false) as Control
				_ok(viewport.encloses(start.get_global_rect()) and start.is_visible_in_tree(),
					"%s: Start Battle in viewport" % dimensions)
			scene.free()
	tree.root.size = Vector2i(1920, 1080)
