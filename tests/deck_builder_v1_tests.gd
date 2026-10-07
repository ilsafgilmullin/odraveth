extends RefCounted
## Stage 7 Deck Builder V1: tabs, faction-restricted cards, copy controls, detail,
## Back priority, responsive layout and the hero <-> deck invariant.

const PresentationAudit := preload("res://tests/visual_qa/presentation_audit.gd")
const VIEWPORTS := [Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(2800, 1752)]
const K := HeroCatalog.KEZHARYN
const S := HeroCatalog.SYRRAVETH

var check: Callable
var tree: SceneTree
var saved_profile: Dictionary
var saved_manager: SaveManager


func _init(check_fn: Callable, game_tree: SceneTree) -> void:
	check = check_fn
	tree = game_tree


func _ok(value: bool, description: String) -> void:
	check.call(value, "deck builder V1: " + description)


func run() -> void:
	saved_profile = AppState.profile
	saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new("user://odraveth_smoke_test/deck_builder_v1.json")
	CardDatabase.load_directory()
	await _test_tabs_and_card_scope()
	await _test_copy_controls_and_deck_tab()
	await _test_back_priority()
	await _test_hero_deck_invariant()
	await _test_responsive()
	AppState.profile = saved_profile
	AppState._save_manager = saved_manager


func _open(viewport_size: Vector2i = Vector2i(1920, 1080)) -> Array:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var scene := (load(Routes.scene_path(Routes.DECK_BUILDER)) as PackedScene).instantiate() as DeckBuilderScreen
	viewport.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	return [viewport, scene]


func _close(pair: Array) -> void:
	(pair[0] as Node).queue_free()
	await tree.process_frame


func _ready_cards(hero: StringName) -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in BattleLaunchConfig.technical_opponent_deck(hero, CardDatabase):
		ids.append(String(id))
	return ids


func _test_tabs_and_card_scope() -> void:
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), K)
	var pair: Array = await _open()
	var scene: DeckBuilderScreen = pair[1]
	_ok(scene.active_tab == DeckBuilderScreen.Tab.CARDS and scene.cards_page.visible and not scene.deck_page.visible,
		"opens on КАРТЫ with КОЛОДА hidden (no permanent split view)")
	_ok(scene.cards_tab_button.text == "КАРТЫ" and scene.deck_tab_button.text.begins_with("КОЛОДА"),
		"tab labels КАРТЫ | КОЛОДА")
	var allowed := 0
	for card: CardDefinition in CardDatabase.get_all_cards():
		if card.faction == Faction.Id.ASHRAVAEL or card.faction == Faction.Id.NEUTRAL:
			allowed += 1
	_ok(scene.grid.get_child_count() == allowed and allowed == 16, "only hero faction + Нейтральные cards are offered (%d)" % scene.grid.get_child_count())
	var all_full := true
	for cell: Node in scene.grid.get_children():
		if not (cell.get_child(0) is FullCardView):
			all_full = false
	_ok(all_full, "every offered card is the shared FullCardView")
	(scene.filter_bar.faction_buttons[Faction.Id.NEUTRAL] as Button).button_pressed = true
	_ok(scene.grid.get_child_count() == 8, "Нейтральные chip narrows to the 8 neutral cards")
	(scene.filter_bar.faction_buttons[CollectionFilterState.ALL] as Button).button_pressed = true
	scene.filter_bar.search.text = "углекоготь"
	scene.filter_bar.search.text_changed.emit(scene.filter_bar.search.text)
	_ok(scene.grid.get_child_count() == 1, "search reuses Collection filter predicates")
	scene.filter_bar.search.text = ""
	scene.filter_bar.search.text_changed.emit("")
	var header := scene.find_child("DeckIdentityBar", true, false) as Control
	_ok(header != null and (scene.find_child("DeckHero", true, false) as Label).text == "КЕЖАРИН"
		and scene.name_edit != null and scene.count_label.text == "0 / 30" and scene.ready_label.text == "НЕ ГОТОВА",
		"common header shows hero, faction, deck name, N/30 and readiness")
	_ok(not PresentationAudit.has_developer_words(scene), "no developer placeholder words are visible")
	await _close(pair)


func _test_copy_controls_and_deck_tab() -> void:
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), K)
	var pair: Array = await _open()
	var scene: DeckBuilderScreen = pair[1]
	var add := scene.find_child("Add_ashravael_cinderclaw", true, false) as Button
	var less := scene.find_child("Less_ashravael_cinderclaw", true, false) as Button
	_ok(add.custom_minimum_size.y >= 64 and add.custom_minimum_size.x >= 64 and less.disabled,
		"large +/- touch controls; − disabled at zero copies")
	add.pressed.emit()
	add.pressed.emit()
	_ok(scene.draft.card_ids.count("ashravael_cinderclaw") == 2 and add.disabled,
		"+ stops at the CardDefinition copy limit")
	_ok((scene.find_child("Copies_ashravael_cinderclaw", true, false) as Label).text == "2 / 2",
		"copy count is shown next to the controls")
	less.pressed.emit()
	_ok(scene.draft.card_ids.count("ashravael_cinderclaw") == 1 and not add.disabled, "− removes one copy")
	scene.show_tab(DeckBuilderScreen.Tab.DECK)
	_ok(scene.deck_page.visible and scene.deck_list.get_child_count() == 1, "КОЛОДА tab lists deck entries")
	var more := scene.find_child("More_ashravael_cinderclaw", true, false) as Button
	more.pressed.emit()
	_ok(scene.draft.card_ids.count("ashravael_cinderclaw") == 2, "deck row + adds a copy")
	(scene.find_child("Info_ashravael_cinderclaw", true, false) as Button).pressed.emit()
	_ok(scene.detail.visible and scene.detail.current_card_id == &"ashravael_cinderclaw", "deck row opens Card Detail")
	scene.detail.close_detail()
	(scene.find_child("Remove_ashravael_cinderclaw", true, false) as Button).pressed.emit()
	_ok(scene.draft.card_ids.count("ashravael_cinderclaw") == 1, "deck row − removes a copy")
	scene.draft.card_ids.assign(_ready_cards(K))
	scene._after_deck_change()
	var first_cost := -1
	var sorted := true
	for row: Node in scene.deck_list.get_children():
		var id := String(row.name).trim_prefix("Row_")
		var cost := CardDatabase.get_card(StringName(id)).cost
		if cost < first_cost:
			sorted = false
		first_cost = cost
	_ok(sorted and scene.ready_label.text == "ГОТОВА" and scene.count_label.text == "30 / 30",
		"30/30 deck is READY and sorted by cost")
	_ok((scene.find_child("Add_neutral_vantrel_duskling", true, false) as Button).disabled,
		"full deck pre-disables further additions")
	_ok(not (scene.find_child("SelectDeckButton", true, false) as Button).disabled, "ready deck can be selected")
	scene.draft.card_ids.remove_at(0)
	scene._after_deck_change()
	_ok(scene.ready_label.text == "НЕ ГОТОВА" and scene.guidance_label.text.contains("добавьте ещё 1")
		and (scene.find_child("SelectDeckButton", true, false) as Button).disabled,
		"29/30 explains the missing card and blocks selection")
	await _close(pair)


func _test_back_priority() -> void:
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), K)
	var pair: Array = await _open()
	var scene: DeckBuilderScreen = pair[1]
	(scene.find_child("Card_ashravael_cinderclaw", true, false) as FullCardView).pressed.emit()
	_ok(scene.detail.visible, "whole-card tap opens Card Detail")
	_ok(scene.handle_back_request() and not scene.detail.visible, "Back closes Card Detail first")
	(scene.find_child("ClearDeckButton", true, false) as Button).pressed.emit()
	_ok(scene.clear_dialog.visible and scene.clear_dialog is ConfirmModal, "clear uses the Visual Alpha confirmation")
	_ok(scene.handle_back_request() and not scene.clear_dialog.visible, "Back cancels the confirmation without clearing")
	_ok(not scene.handle_back_request(), "with nothing transient open, Back is left to route navigation")
	await _close(pair)


func _test_hero_deck_invariant() -> void:
	var profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), K)
	var kezharyn_deck := UserDeck.create(K)
	kezharyn_deck.name = "Колода Кежарина"
	kezharyn_deck.card_ids.assign(_ready_cards(K))
	profile = PlayerSetupData.upsert(profile, kezharyn_deck, CardDatabase)
	_ok(AppState.persist_profile(profile) == OK and AppState.profile["selected_deck_id"] == kezharyn_deck.id
		and PlayerSetupData.selected_deck(AppState.profile, CardDatabase) != null,
		"invariant: Kezharyn deck exists and is active")
	_ok(AppState.persist_profile(PlayerSetupData.select_hero(AppState.profile, S)) == OK,
		"invariant: switch to Syrraveth through the confirmation path")
	var stored := PlayerSetupData.decks_for(AppState.profile, K)
	_ok(stored.size() == 1 and stored[0].id == kezharyn_deck.id and stored[0].card_ids == kezharyn_deck.card_ids,
		"invariant: Kezharyn deck remains stored unchanged")
	_ok(AppState.profile["selected_deck_id"] == "" and PlayerSetupData.selected_deck(AppState.profile, CardDatabase) == null,
		"invariant: Kezharyn deck is not active and cannot launch for Syrraveth")
	var pair: Array = await _open()
	var scene: DeckBuilderScreen = pair[1]
	var leaks := false
	for index in scene.deck_select.item_count:
		if String(scene.deck_select.get_item_metadata(index)) == kezharyn_deck.id:
			leaks = true
	for cell: Node in scene.grid.get_children():
		var view := cell.get_child(0) as FullCardView
		if view.presentation.faction == Faction.Id.ASHRAVAEL:
			leaks = true
	_ok(not leaks and scene.draft.hero_id == S and scene.draft.card_ids.is_empty(),
		"invariant: Syrraveth builder shows no Kezharyn deck or Ashravael cards")
	await _close(pair)
	_ok(AppState.persist_profile(PlayerSetupData.select_hero(AppState.profile, K)) == OK,
		"invariant: switch back to Kezharyn")
	stored = PlayerSetupData.decks_for(AppState.profile, K)
	_ok(stored.size() == 1 and stored[0].card_ids == kezharyn_deck.card_ids and stored[0].name == "Колода Кежарина",
		"invariant: switching back preserves the stored deck")
	pair = await _open()
	scene = pair[1]
	_ok(scene.draft.id == kezharyn_deck.id and scene.draft.is_ready(CardDatabase),
		"invariant: Kezharyn builder reopens the preserved deck for explicit re-selection")
	await _close(pair)


func _test_responsive() -> void:
	var profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), K)
	var deck := UserDeck.create(K)
	deck.card_ids.assign(_ready_cards(K))
	AppState.profile = PlayerSetupData.upsert(profile, deck, CardDatabase)
	for viewport_size: Vector2i in VIEWPORTS:
		var pair: Array = await _open(viewport_size)
		var scene: DeckBuilderScreen = pair[1]
		var view_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var label := "%dx%d" % [viewport_size.x, viewport_size.y]
		var controls: Array[Control] = [
			scene.find_child("DeckIdentityBar", true, false), scene.cards_tab_button, scene.deck_tab_button,
			scene.find_child("SelectDeckButton", true, false), scene.find_child("NewDeckButton", true, false),
			scene.find_child("BackButton", true, false),
		]
		var inside := controls.all(func(control: Control) -> bool: return view_rect.encloses(control.get_global_rect()))
		_ok(inside, "%s: header, tabs, actions and Back stay inside the viewport" % label)
		var first_cell := scene.grid.get_child(0) as Control
		_ok(first_cell.get_global_rect().end.x <= view_rect.end.x and scene.grid.columns >= 4,
			"%s: card grid uses %d columns without horizontal overflow" % [label, scene.grid.columns])
		if viewport_size.y >= 1080:
			var scroll_rect := (scene.find_child("AvailableScroll", true, false) as Control).get_global_rect()
			var first_add := first_cell.find_child("Add_*", true, false) as Control
			_ok(first_add != null and scroll_rect.encloses(first_add.get_global_rect()),
				"%s: first row card and its + control are fully visible without scrolling" % label)
		scene.show_tab(DeckBuilderScreen.Tab.DECK)
		await tree.process_frame
		var summary := scene.find_child("DeckSummary", true, false) as Control
		_ok(view_rect.encloses(summary.get_global_rect()) and scene.deck_list.get_child_count() > 0,
			"%s: deck list and summary fit" % label)
		await _close(pair)
