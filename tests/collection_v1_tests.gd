extends RefCounted
## Stage 7E Collection V1 runtime/data checks.

const VIEWPORTS := [
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2400, 1080),
	Vector2i(2800, 1752),
]
const EXPECTED_COLUMNS := [4, 5, 5, 6]
const ROUTE_TIMEOUT_FRAMES := 120

var check: Callable
var tree: SceneTree
var cards: Array[CardDefinition] = []
var saved_profile: Dictionary
var saved_manager: SaveManager


func _init(check_fn: Callable, game_tree: SceneTree) -> void:
	check = check_fn
	tree = game_tree


func _ok(value: bool, description: String) -> void:
	check.call(value, "collection V1: " + description)


func run() -> void:
	saved_profile = AppState.profile
	saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new("user://odraveth_smoke_test/collection_v1.json")
	AppState.profile = PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	_ok(CardDatabase.load_directory() == OK, "authoritative CardDatabase loads")
	cards = CardDatabase.get_all_cards()
	_ok(cards.size() == 40, "authoritative source exposes 40 starter cards")

	_test_filter_state()
	await _test_default_scene()
	await _test_search_and_filters()
	await _test_detail_and_scroll_preservation()
	await _test_responsive_grid()
	await _test_rebuild_stress()
	await _test_route_cycles_and_back_priority()

	AppState.profile = saved_profile
	AppState._save_manager = saved_manager
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)


func _test_filter_state() -> void:
	var state := CollectionFilterState.new()
	var all := state.filter(cards)
	_ok(all.size() == 40, "empty search/filters returns all 40 cards")
	_ok(_ids(all) == CardDatabase.get_card_ids(), "default ordering follows deterministic CardDatabase ordering")
	_ok(_unique_count(_ids(all)) == 40, "default result has no duplicates")

	state.query = "  кров  "
	var ru := state.filter(cards)
	_ok(not ru.is_empty() and ru.all(func(card: CardDefinition) -> bool:
		return card.name_ru.to_lower().contains("кров") or card.name_en.to_lower().contains("кров")),
		"RU partial search is trimmed and case-insensitive")

	state.query = "BLOOD"
	var en := state.filter(cards)
	_ok(not en.is_empty() and en.all(func(card: CardDefinition) -> bool:
		return card.name_en.to_lower().contains("blood") or card.name_ru.to_lower().contains("blood")),
		"EN partial search is case-insensitive")

	state.query = ""
	for faction: Faction.Id in Faction.Id.values():
		state.faction_id = faction
		var result := state.filter(cards)
		_ok(result.size() == 8 and result.all(func(card: CardDefinition) -> bool: return card.faction == faction),
			"%s faction filter uses authoritative faction" % Faction.Id.find_key(faction))
	state.faction_id = CollectionFilterState.ALL

	var type_counts := {
		CardEnums.Type.CREATURE: 27,
		CardEnums.Type.SPELL: 9,
		CardEnums.Type.ARTIFACT: 4,
	}
	for card_type: CardEnums.Type in type_counts:
		state.type_id = card_type
		var result := state.filter(cards)
		_ok(result.size() == type_counts[card_type]
			and result.all(func(card: CardDefinition) -> bool: return card.card_type == card_type),
			"%s type filter matches authoritative type" % CardEnums.Type.find_key(card_type))
	state.type_id = CollectionFilterState.ALL

	var rarity_counts := {
		CardEnums.Rarity.COMMON: 16,
		CardEnums.Rarity.RARE: 13,
		CardEnums.Rarity.EPIC: 7,
		CardEnums.Rarity.LEGENDARY: 4,
	}
	for rarity: CardEnums.Rarity in rarity_counts:
		state.rarity_id = rarity
		var result := state.filter(cards)
		_ok(result.size() == rarity_counts[rarity]
			and result.all(func(card: CardDefinition) -> bool: return card.rarity == rarity),
			"%s rarity filter matches authoritative rarity" % CardEnums.Rarity.find_key(rarity))
	state.rarity_id = CollectionFilterState.ALL

	for bucket: int in [
		CollectionFilterState.COST_0_1, CollectionFilterState.COST_2, CollectionFilterState.COST_3,
		CollectionFilterState.COST_4, CollectionFilterState.COST_5, CollectionFilterState.COST_6,
		CollectionFilterState.COST_7_PLUS,
	]:
		state.cost_bucket = bucket
		var result := state.filter(cards)
		_ok(result.all(func(card: CardDefinition) -> bool: return _cost_bucket_matches(card.cost, bucket)),
			"cost bucket %d matches only intended costs" % bucket)
	state.cost_bucket = CollectionFilterState.COST_ALL

	var target := CardDatabase.get_card(&"ashravael_bloodsworn")
	state.query = "присяж"
	state.faction_id = target.faction
	state.type_id = target.card_type
	state.rarity_id = target.rarity
	state.cost_bucket = _bucket_for_cost(target.cost)
	var combined := state.filter(cards)
	_ok(not combined.is_empty() and combined.all(func(card: CardDefinition) -> bool:
		return state.matches(card)), "search + faction + type + rarity + cost combine with logical AND")
	_ok(state.active_filter_count() == 4, "four non-search filters report active state")
	state.reset_filters()
	_ok(state.active_filter_count() == 0 and state.query == "присяж",
		"filter reset clears filters but preserves search query")


func _test_default_scene() -> void:
	var scene := _scene() 
	await tree.process_frame
	await tree.process_frame
	_ok(scene != null, "Collection scene loads")
	if scene == null:
		return
	_ok(scene.theme != null and scene.theme.resource_path == UiKit.THEME_PATH,
		"Stage 7A Visual Alpha theme applied")
	_ok((scene.find_child("ScreenTitle", true, false) as Label).text == "КОЛЛЕКЦИЯ"
		and (scene.find_child("ArchiveLabel", true, false) as Label).text == "АРХИВ НУЛМЕРИСА",
		"Collection identity is intentional Archive of Nulmeris")
	_ok(scene.visible_card_ids.size() == 40 and _unique_count(scene.visible_card_ids) == 40,
		"default grid represents all 40 cards exactly once")
	_ok(scene.visible_card_ids == CardDatabase.get_card_ids(), "grid preserves stable authoritative order")
	_ok(scene.card_grid.get_child_count() == 40, "grid owns exactly 40 card cells")
	for child: Node in scene.card_grid.get_children():
		var view := child.get_child(0) as FullCardView
		_ok(view != null, "%s cell uses Stage 7D FullCardView" % child.name)
		if view != null:
			_ok(view.pressed.get_connections().size() == 1 and view.card_activated.get_connections().size() == 1,
				"%s FullCard has one internal and one Collection activation connection" % view.card_id)
	_ok(scene.find_children("Info_*", "Button", true, false).is_empty(),
		"Collection requires no tiny standalone info buttons")
	_ok(scene.type_filter.item_count == 4 and _option_has_id(scene.type_filter, CardEnums.Type.CURSE) == false,
		"empty CURSE category is not exposed while architecture still supports it")
	_ok(scene.faction_filter.get_item_text(_index_for_id(scene.faction_filter, Faction.Id.NEUTRAL)) == "НЕЙТРАЛЬНЫЕ",
		"official Neutral UI label is НЕЙТРАЛЬНЫЕ")
	scene.free()


func _test_search_and_filters() -> void:
	var scene := _scene()
	await tree.process_frame
	var blood := CardDatabase.get_card(&"ashravael_bloodsworn")

	scene.search.text = "  КРОВ  "
	scene.search.text_changed.emit(scene.search.text)
	await tree.process_frame
	_ok(not scene.visible_card_ids.is_empty() and scene.filter_state.normalized_query() == "кров",
		"search field trims and lowercases RU query through filter state")
	_ok(scene.visible_card_ids.has(String(blood.id)), "RU fragment finds matching card")

	scene.search.text = "BLOOD"
	scene.search.text_changed.emit(scene.search.text)
	await tree.process_frame
	_ok(scene.visible_card_ids.has(String(blood.id)), "EN uppercase partial search finds matching card")

	scene.search.text = ""
	scene.search.text_changed.emit("")
	_select_id(scene.faction_filter, Faction.Id.ASHRAVAEL, true)
	_select_id(scene.type_filter, CardEnums.Type.CREATURE, true)
	_select_id(scene.rarity_filter, CardEnums.Rarity.COMMON, true)
	_select_id(scene.cost_filter, CollectionFilterState.COST_0_1, true)
	await tree.process_frame
	_ok(not scene.visible_card_ids.is_empty(), "combined filters produce a non-empty authoritative subset")
	for id: String in scene.visible_card_ids:
		var card := CardDatabase.get_card(StringName(id))
		_ok(card.faction == Faction.Id.ASHRAVAEL and card.card_type == CardEnums.Type.CREATURE
			and card.rarity == CardEnums.Rarity.COMMON and card.cost <= 1,
			"%s satisfies every active filter" % id)
	_ok(scene.active_summary.text == "АКТИВНО: 4"
		and scene.faction_filter.get_item_text(scene.faction_filter.selected) == "АШРАВАЙЛЬ",
		"active filter state is explicit in text/selected control, not colour-only")

	scene.search.text = "zzzz-no-card"
	scene.search.text_changed.emit(scene.search.text)
	await tree.process_frame
	_ok(scene.visible_card_ids.is_empty() and scene.empty_state.visible and not scene.card_scroll.visible,
		"zero-result query shows intentional empty state")
	_ok((scene.empty_state.find_child("EmptyStateTitle", true, false) as Label).text == "КАРТЫ НЕ НАЙДЕНЫ",
		"empty state uses approved product copy")

	scene.search.text = "blood"
	scene.search.text_changed.emit(scene.search.text)
	scene.reset_button.pressed.emit()
	await tree.process_frame
	_ok(scene.search.text == "blood" and scene.filter_state.active_filter_count() == 0,
		"СБРОСИТЬ clears filters without clearing Search")
	_ok(scene.visible_card_ids.has(String(blood.id)), "search remains active after filter reset")
	scene.free()


func _test_detail_and_scroll_preservation() -> void:
	var scene := _scene()
	await tree.process_frame
	await tree.process_frame
	var max_scroll := int(scene.card_scroll.get_v_scroll_bar().max_value)
	_ok(max_scroll > 0, "40-card grid is vertically scrollable")
	scene.card_scroll.scroll_vertical = maxi(1, max_scroll / 2)
	await tree.process_frame
	var before := scene.card_scroll.scroll_vertical

	var target_id := StringName(scene.visible_card_ids[12])
	var view := scene.find_child("Card_%s" % target_id, true, false) as FullCardView
	_ok(view != null, "representative whole FullCard is interactive")
	view.pressed.emit()
	await tree.process_frame
	_ok(scene.detail.visible and scene.detail.current_card_id == target_id,
		"whole-card tap opens Stage 7D CardDetail for correct card")
	var target := CardDatabase.get_card(target_id)
	_ok(scene.detail.ru_name_label.text == target.name_ru and scene.detail.en_name_label.text == target.name_en
		and scene.detail.full_card.card_id == target_id,
		"Collection detail reuses authoritative Stage 7D presentation")

	scene.detail.close_button.pressed.emit()
	await tree.process_frame
	_ok(not scene.detail.visible and scene.card_scroll.scroll_vertical == before,
		"closing Card Detail preserves Collection scroll position")

	view.pressed.emit()
	await tree.process_frame
	_ok(scene.handle_back_request() and not scene.detail.visible
		and scene.card_scroll.scroll_vertical == before,
		"Back closes detail first and preserves underlying Collection state")
	scene.free()


func _test_responsive_grid() -> void:
	var longest_name := cards[0]
	for card: CardDefinition in cards:
		if card.name_ru.length() > longest_name.name_ru.length():
			longest_name = card

	for index in VIEWPORTS.size():
		var dimensions: Vector2i = VIEWPORTS[index]
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		tree.root.add_child(viewport)
		var packed := load(Routes.scene_path(Routes.COLLECTION)) as PackedScene
		var scene := packed.instantiate() as CollectionScreen if packed != null else null
		_ok(scene != null, "%dx%d Collection instantiates" % [dimensions.x, dimensions.y])
		if scene == null:
			viewport.queue_free()
			continue
		viewport.add_child(scene)
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame

		_ok(scene.card_grid.columns == EXPECTED_COLUMNS[index],
			"%dx%d uses %d columns" % [dimensions.x, dimensions.y, EXPECTED_COLUMNS[index]])
		_ok(ResponsiveLayout.collection_columns_for_size(Vector2(dimensions)) == EXPECTED_COLUMNS[index],
			"%dx%d size-aware responsive classification matches grid" % [dimensions.x, dimensions.y])
		_ok(scene.search.size.y >= VisualTokens.TOUCH_MIN.y
			and scene.filter_toggle.size.y >= VisualTokens.TOUCH_MIN.y
			and scene.reset_button.size.y >= VisualTokens.TOUCH_MIN.y,
			"%dx%d search/filter controls keep Android touch height" % [dimensions.x, dimensions.y])

		var cards_rect := scene.card_scroll.get_global_rect()
		_ok(cards_rect.size.y > 300.0 and cards_rect.end.y <= float(dimensions.y) + 1.0,
			"%dx%d card browser keeps useful vertical area" % [dimensions.x, dimensions.y])
		var previous_by_row := {}
		for child: Node in scene.card_grid.get_children():
			var view := child.get_child(0) as FullCardView
			_ok(view.size.x >= 320.0 and view.size.y >= 448.0,
				"%dx%d %s retains Stage 7D readable FullCard minimum" % [dimensions.x, dimensions.y, view.card_id])
			var row := child.get_index() / scene.card_grid.columns
			if previous_by_row.has(row):
				var previous := previous_by_row[row] as Control
				_ok(previous.get_global_rect().end.x <= child.get_global_rect().position.x + 1.0,
					"%dx%d row %d cards do not overlap" % [dimensions.x, dimensions.y, row])
			previous_by_row[row] = child

		var longest := scene.find_child("Card_%s" % longest_name.id, true, false) as FullCardView
		_ok(longest != null and longest.name_label.autowrap_mode != TextServer.AUTOWRAP_OFF
			and not longest.name_label.clip_text and longest.name_label.get_line_count() <= 2
			and longest.name_label.get_visible_line_count() == longest.name_label.get_line_count(),
			"%dx%d longest RU card title remains fully visible in grid" % [dimensions.x, dimensions.y])

		var scrollbar := scene.card_scroll.get_v_scroll_bar()
		scene.card_scroll.scroll_vertical = int(scrollbar.max_value)
		await tree.process_frame
		await tree.process_frame
		var last_cell := scene.card_grid.get_child(scene.card_grid.get_child_count() - 1) as Control
		_ok(scene.card_scroll.get_global_rect().end.y >= last_cell.get_global_rect().end.y - 2.0,
			"%dx%d last Collection row is reachable by vertical scroll" % [dimensions.x, dimensions.y])

		scene.detail.open_card(longest_name)
		await tree.process_frame
		var modal := scene.detail.find_child("CardDetailPanel", true, false) as Control
		_ok(modal != null and Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(modal.get_global_rect()),
			"%dx%d Stage 7D Card Detail fits over Collection" % [dimensions.x, dimensions.y])

		viewport.queue_free()
		await tree.process_frame


func _test_rebuild_stress() -> void:
	var scene := _scene()
	await tree.process_frame
	var queries := ["blood", "", "кров", "null", "", "меридиан", "", "shield", "", "zzzz", ""]
	for cycle in 3:
		for query: String in queries:
			scene.search.text = query
			scene.search.text_changed.emit(query)
			await tree.process_frame
			_ok(scene.card_grid.get_child_count() == scene.visible_card_ids.size(),
				"stress cycle %d query '%s' has no stale grid nodes" % [cycle + 1, query])
			_ok(_unique_count(scene.visible_card_ids) == scene.visible_card_ids.size(),
				"stress cycle %d query '%s' has no duplicate IDs" % [cycle + 1, query])
		_select_id(scene.faction_filter, Faction.Id.NEUTRAL, true)
		await tree.process_frame
		var neutral_only := true
		for id: String in scene.visible_card_ids:
			if CardDatabase.get_card(StringName(id)).faction != Faction.Id.NEUTRAL:
				neutral_only = false
				break
		_ok(neutral_only, "stress cycle %d faction result has no stale cards" % (cycle + 1))
		scene.reset_button.pressed.emit()
		await tree.process_frame
		_ok(scene.filter_state.active_filter_count() == 0, "stress cycle %d reset clears active filters" % (cycle + 1))
	_ok(scene.card_grid.get_child_count() == 40, "stress returns to bounded 40-card node population")
	for child: Node in scene.card_grid.get_children():
		var view := child.get_child(0) as FullCardView
		_ok(view.card_activated.get_connections().size() == 1,
			"%s retains one Collection activation signal after rebuild stress" % view.card_id)
	scene.free()


func _test_route_cycles_and_back_priority() -> void:
	SceneRouter.reset_to(Routes.MAIN_MENU)
	_ok(await _wait_for_route(Routes.MAIN_MENU), "Main Menu route available before Collection cycles")
	for cycle in 3:
		SceneRouter.go_to(Routes.COLLECTION)
		_ok(await _wait_for_route(Routes.COLLECTION), "route cycle %d opens Collection" % (cycle + 1))
		var scene := tree.current_scene as CollectionScreen
		_ok(scene != null and scene.card_grid.get_child_count() == 40,
			"route cycle %d starts with one bounded 40-card grid" % (cycle + 1))
		for i in 10:
			var id := StringName(scene.visible_card_ids[i])
			var view := scene.find_child("Card_%s" % id, true, false) as FullCardView
			view.pressed.emit()
			await tree.process_frame
			_ok(scene.detail.current_card_id == id, "route cycle %d detail %d opens correct card" % [cycle + 1, i + 1])
			scene.detail.close_detail()
		scene.search.grab_focus()
		await tree.process_frame
		_ok(scene.search.has_focus() and scene.handle_back_request() and not scene.search.has_focus(),
			"route cycle %d Back dismisses Search focus before navigation" % (cycle + 1))
		SceneRouter.go_back()
		_ok(await _wait_for_route(Routes.MAIN_MENU), "route cycle %d leaves Collection cleanly" % (cycle + 1))
		var collection_roots := 0
		for child: Node in tree.root.get_children():
			if child.name == "Collection":
				collection_roots += 1
		_ok(collection_roots == 0, "route cycle %d leaves no stale Collection root" % (cycle + 1))


func _scene() -> CollectionScreen:
	var packed := load(Routes.scene_path(Routes.COLLECTION)) as PackedScene
	var scene := packed.instantiate() as CollectionScreen if packed != null else null
	if scene != null:
		tree.root.add_child(scene)
	return scene


func _select_id(control: OptionButton, id: int, emit_selected: bool) -> void:
	var index := _index_for_id(control, id)
	if index < 0:
		return
	control.select(index)
	if emit_selected:
		control.item_selected.emit(index)


func _index_for_id(control: OptionButton, id: int) -> int:
	for index in control.item_count:
		if control.get_item_id(index) == id:
			return index
	return -1


func _option_has_id(control: OptionButton, id: int) -> bool:
	return _index_for_id(control, id) >= 0


func _bucket_for_cost(cost: int) -> int:
	if cost <= 1:
		return CollectionFilterState.COST_0_1
	if cost >= 7:
		return CollectionFilterState.COST_7_PLUS
	return cost


func _cost_bucket_matches(cost: int, bucket: int) -> bool:
	if bucket == CollectionFilterState.COST_0_1:
		return cost <= 1
	if bucket == CollectionFilterState.COST_7_PLUS:
		return cost >= 7
	return cost == bucket


func _ids(values: Array[CardDefinition]) -> PackedStringArray:
	return PackedStringArray(values.map(func(card: CardDefinition) -> String: return String(card.id)))


func _unique_count(values: PackedStringArray) -> int:
	var unique := {}
	for value: String in values:
		unique[value] = true
	return unique.size()


func _wait_for_route(route_id: StringName) -> bool:
	for _frame in ROUTE_TIMEOUT_FRAMES:
		await tree.process_frame
		if SceneRouter.current_route == route_id and not SceneRouter.is_changing():
			return tree.current_scene != null and tree.current_scene.scene_file_path == Routes.scene_path(route_id)
	return false
