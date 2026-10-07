extends RefCounted
## Stage 7D runtime coverage for the shared card shell and detail modal.

const VIEWPORTS := [
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2400, 1080),
	Vector2i(2800, 1752),
]
const ROUTE_TIMEOUT_FRAMES := 120

var check: Callable
var tree: SceneTree
var saved_profile: Dictionary
var saved_manager: SaveManager
var cards: Array[CardDefinition] = []


func _init(check_fn: Callable, game_tree: SceneTree) -> void:
	check = check_fn
	tree = game_tree


func _ok(value: bool, description: String) -> void:
	check.call(value, "card visual V1: " + description)


func run() -> void:
	saved_profile = AppState.profile
	saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new("user://odraveth_smoke_test/card_visual_v1.json")
	_ok(CardDatabase.load_directory() == OK, "authoritative CardDatabase loads")
	cards = CardDatabase.get_all_cards()
	_ok(cards.size() == 40, "exactly 40 authoritative starter definitions available")

	await _test_all_40_presentations()
	await _test_full_card_scene_and_states()
	await _test_long_content()
	_test_rarity_geometry()
	await _test_curse_future_variant()
	await _test_preview_scene()
	await _test_detail_all_40()
	await _test_detail_responsive()
	await _test_system_back_closes_detail()
	await _test_lifecycle_and_batch_cleanup()

	AppState.profile = saved_profile
	AppState._save_manager = saved_manager
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait_for_route(Routes.MAIN_MENU)


func _test_all_40_presentations() -> void:
	var host := Control.new()
	host.name = "AllCardHost"
	tree.root.add_child(host)
	var seen_factions := {}
	var seen_types := {}
	var seen_rarities := {}
	var placeholder_count := 0

	for card: CardDefinition in cards:
		var presentation := CardPresentation.from_definition(card)
		_ok(presentation != null and presentation.id == card.id, "%s presentation constructs" % card.id)
		_ok(not presentation.name_ru.is_empty() and presentation.name_en == card.name_en,
			"%s names preserved" % card.id)
		_ok(presentation.faction_label == SetupUi.faction_name(card.faction)
			and not presentation.faction_label.is_empty(), "%s faction resolves" % card.id)
		_ok(presentation.type_label == SetupUi.TYPE_NAMES[card.card_type]
			and presentation.rarity_label == SetupUi.RARITY_NAMES[card.rarity],
			"%s type and rarity resolve" % card.id)
		_ok(presentation.current_cost == card.cost, "%s cost resolves" % card.id)

		seen_factions[card.faction] = true
		seen_types[card.card_type] = true
		seen_rarities[card.rarity] = true

		var view := FullCardView.new()
		host.add_child(view)
		view.configure(card)
		await tree.process_frame
		_ok(view.card_id == card.id and view.cost_label.text == str(card.cost)
			and view.name_label.text == card.name_ru, "%s FullCard populates authoritative identity/cost" % card.id)
		_ok(view.rarity_mark.shape_id == _expected_rarity_shape(card.rarity),
			"%s rarity geometry resolves" % card.id)

		var resolved := CardArtResolver.resolve(card.id)
		_ok(view.art_slot.uses_placeholder == (resolved == null),
			"%s artwork resolver/fallback is deterministic" % card.id)
		if view.art_slot.uses_placeholder:
			placeholder_count += 1

		match card.card_type:
			CardEnums.Type.CREATURE:
				_ok(view.attack_badge != null and view.health_badge != null,
					"%s creature shows attack and health" % card.id)
				_ok((view.armor_badge != null) == (card.armor > 0),
					"%s armor badge is conditional" % card.id)
				_ok(view.charges_badge == null and view.stats_row.visible,
					"%s creature does not use artifact charges" % card.id)
			CardEnums.Type.SPELL:
				_ok(view.attack_badge == null and view.health_badge == null and view.armor_badge == null
					and view.charges_badge == null and not view.stats_row.visible,
					"%s spell omits fake combat stats" % card.id)
			CardEnums.Type.ARTIFACT:
				_ok(view.charges_badge != null and view.attack_badge == null and view.health_badge == null
					and view.armor_badge == null and view.stats_row.visible,
					"%s artifact uses charges without creature stats" % card.id)
			_:
				_ok(false, "%s current starter type is supported" % card.id)

		_ok(view.pressed.get_connections().size() == 1,
			"%s FullCard owns one activation connection" % card.id)
		view.queue_free()
		await tree.process_frame

	_ok(seen_factions.size() == 5 and seen_factions.has(Faction.Id.NEUTRAL),
		"all four factions plus official Neutral group render")
	_ok(seen_types.size() == 3 and seen_types.has(CardEnums.Type.CREATURE)
		and seen_types.has(CardEnums.Type.SPELL) and seen_types.has(CardEnums.Type.ARTIFACT),
		"all current starter types render")
	_ok(seen_rarities.size() == 4, "all four rarity families render")
	var missing_art := cards.filter(func(card: CardDefinition) -> bool: return CardArtResolver.resolve(card.id) == null)
	_ok(placeholder_count == missing_art.size(),
		"fallback count exactly matches cards missing individual artwork")
	host.queue_free()
	await tree.process_frame


func _test_full_card_scene_and_states() -> void:
	var packed := load("res://scenes/common/full_card_view.tscn") as PackedScene
	var view := packed.instantiate() as FullCardView if packed != null else null
	_ok(view != null, "reusable FullCard scene loads")
	if view == null:
		return
	tree.root.add_child(view)
	view.configure(cards[0])
	await tree.process_frame
	_ok(view.custom_minimum_size == FullCardView.BASE_SIZE
		and view.size.x >= VisualTokens.TOUCH_MIN.x and view.size.y >= VisualTokens.TOUCH_MIN.y,
		"whole FullCard is an accessible interactive target")

	var activated := PackedStringArray()
	view.card_activated.connect(func(card_id: StringName) -> void: activated.append(String(card_id)))
	view.pressed.emit()
	_ok(activated == PackedStringArray([String(cards[0].id)]),
		"whole-card activation signal exposes card ID without caller coupling")

	view.set_selected_state(true)
	_ok(view.selected_marker.visible and view.scale.x > 1.0 and view.frame_visual.selected,
		"selected state uses explicit marker plus geometry")
	view.set_selected_state(false)
	_ok(not view.selected_marker.visible and is_equal_approx(view.scale.x, 1.0),
		"selected state clears without stale elevation")

	view.set_copy_count(2)
	_ok(view.copy_count_badge.visible and view.copy_count_badge.text == "×2",
		"optional caller-supplied copy-count hook renders without deck query")
	view.set_copy_count(0)
	_ok(not view.copy_count_badge.visible, "copy-count hook can be cleared")

	view.set_available(false)
	_ok(view.disabled and view.frame_visual.unavailable, "disabled/unavailable presentation state is explicit")
	view.set_available(true)
	view.button_down.emit()
	_ok(view.frame_visual.interaction_pressed, "pressed state reaches architectural frame")
	view.button_up.emit()
	_ok(not view.frame_visual.interaction_pressed, "pressed state clears")
	view.grab_focus()
	await tree.process_frame
	_ok(view.frame_visual.interaction_focused, "focus state reaches architectural frame")

	view.queue_free()
	await tree.process_frame


func _test_long_content() -> void:
	var longest_name := cards[0]
	var longest_rules := cards[0]
	for card: CardDefinition in cards:
		if card.name_ru.length() > longest_name.name_ru.length():
			longest_name = card
		if card.rules_text_ru.length() > longest_rules.rules_text_ru.length():
			longest_rules = card

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)

	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(holder)
	var view := FullCardView.new()
	holder.add_child(view)
	view.configure(longest_name)
	await tree.process_frame
	await tree.process_frame
	_ok(view.name_label.autowrap_mode != TextServer.AUTOWRAP_OFF and not view.name_label.clip_text,
		"longest RU title uses wrapping without destructive clipping")
	_ok(view.name_label.get_line_count() <= 2
		and view.name_label.get_visible_line_count() == view.name_label.get_line_count(),
		"longest RU title fits normal FullCard within two visible lines")
	_ok(view.size.x / view.size.y > 0.63 and view.size.x / view.size.y < 0.78,
		"FullCard remains approximately 5:7 under title stress")

	view.configure(longest_rules)
	await tree.process_frame
	await tree.process_frame
	_ok(view.rules_label.text == longest_rules.rules_text_ru
		and view.rules_label.autowrap_mode != TextServer.AUTOWRAP_OFF and not view.rules_label.clip_text,
		"longest rules text is exact authoritative prose with wrapping")
	_ok(view.rules_label.get_visible_line_count() == view.rules_label.get_line_count(),
		"longest rules text has no hidden/clipped lines in FullCard")
	viewport.queue_free()
	await tree.process_frame


func _test_rarity_geometry() -> void:
	var shapes := {}
	for rarity: CardEnums.Rarity in [
		CardEnums.Rarity.COMMON,
		CardEnums.Rarity.RARE,
		CardEnums.Rarity.EPIC,
		CardEnums.Rarity.LEGENDARY,
	]:
		var mark := RarityMark.new()
		mark.configure(rarity)
		shapes[mark.shape_id] = true
		_ok(mark.shape_id == _expected_rarity_shape(rarity),
			"%s has expected geometry identity" % CardEnums.Rarity.find_key(rarity))
		mark.free()
	_ok(shapes.size() == 4, "rarities remain distinguishable by silhouette in monochrome")


func _test_curse_future_variant() -> void:
	var curse := CardDefinition.new()
	curse.id = &"test_visual_curse"
	curse.name_en = "Test Visual Curse"
	curse.name_ru = "Тестовое проклятие"
	curse.faction = Faction.Id.NEUTRAL
	curse.card_type = CardEnums.Type.CURSE
	curse.rarity = CardEnums.Rarity.RARE
	curse.cost = 1
	curse.rules_text_ru = ""
	var presentation := CardPresentation.from_definition(curse)
	_ok(presentation.is_curse() and presentation.frame_variant == "curse"
		and presentation.type_label == SetupUi.TYPE_NAMES[CardEnums.Type.CURSE],
		"CURSE future presentation variant exists without gameplay invention")
	var view := FullCardView.new()
	tree.root.add_child(view)
	view.configure(curse)
	await tree.process_frame
	_ok(view.frame_visual.card_type == CardEnums.Type.CURSE and not view.stats_row.visible,
		"CURSE uses fractured frame grammar and no fake combat stats")
	view.queue_free()
	await tree.process_frame


func _test_preview_scene() -> void:
	var packed := load("res://scenes/common/card_visual_preview.tscn") as PackedScene
	var preview := packed.instantiate() as CardVisualPreview if packed != null else null
	_ok(preview != null, "development Card Visual preview scene loads")
	if preview == null:
		return
	tree.root.add_child(preview)
	await tree.process_frame
	await tree.process_frame
	_ok(preview.card_views.size() >= 6 and preview.representative_ids.size() == preview.card_views.size(),
		"preview renders a representative stress matrix")
	var preview_types := {}
	var has_legendary := false
	var has_neutral := false
	var has_armored := false
	for card_id: String in preview.representative_ids:
		var card := CardDatabase.get_card(StringName(card_id))
		preview_types[card.card_type] = true
		has_legendary = has_legendary or card.rarity == CardEnums.Rarity.LEGENDARY
		has_neutral = has_neutral or card.faction == Faction.Id.NEUTRAL
		has_armored = has_armored or (card.card_type == CardEnums.Type.CREATURE and card.armor > 0)
	_ok(preview_types.has(CardEnums.Type.CREATURE) and preview_types.has(CardEnums.Type.SPELL)
		and preview_types.has(CardEnums.Type.ARTIFACT), "preview includes creature, spell and artifact")
	_ok(has_legendary and has_neutral and has_armored,
		"preview includes legendary, neutral and armored representatives")
	preview.queue_free()
	await tree.process_frame


func _test_detail_all_40() -> void:
	var overlay := CardDetailOverlay.new()
	tree.root.add_child(overlay)
	await tree.process_frame
	var base_child_count := _node_count(overlay)

	for card: CardDefinition in cards:
		_ok(overlay.open_card(card.id), "%s Card Detail opens by card ID" % card.id)
		await tree.process_frame
		_ok(overlay.current_card_id == card.id
			and overlay.ru_name_label.text == card.name_ru and overlay.en_name_label.text == card.name_en,
			"%s Card Detail has RU primary and EN reference name" % card.id)
		_ok(overlay.full_card.card_id == card.id and overlay.full_card.presentation.rules_text_ru == card.rules_text_ru,
			"%s Card Detail reuses canonical FullCard/presentation" % card.id)
		match card.card_type:
			CardEnums.Type.CREATURE:
				_ok(overlay.body_text.text.contains("Атака:") and overlay.body_text.text.contains("Здоровье:"),
					"%s detail shows creature stats" % card.id)
				_ok(overlay.body_text.text.contains("Броня:") == (card.armor > 0),
					"%s detail armor omission is meaningful" % card.id)
			CardEnums.Type.SPELL:
				_ok(not overlay.body_text.text.contains("Атака:")
					and not overlay.body_text.text.contains("Здоровье:")
					and not overlay.body_text.text.contains("Броня:")
					and not overlay.body_text.text.contains("Заряды:"),
					"%s spell detail omits irrelevant stats" % card.id)
			CardEnums.Type.ARTIFACT:
				_ok(overlay.body_text.text.contains("Заряды: %d" % card.charges)
					and not overlay.body_text.text.contains("Атака:")
					and not overlay.body_text.text.contains("Здоровье:"),
					"%s artifact detail shows dedicated charges only" % card.id)

	var keyword_card := CardDatabase.get_card(&"khevaruun_ironwarden")
	overlay.open_card(keyword_card)
	await tree.process_frame
	_ok(overlay.keywords_row.get_child_count() >= 1
		and overlay.keywords_row.get_child(0).name != "NoKeywords",
		"Card Detail surfaces structured keyword markers")

	overlay.open_card(cards[0])
	await tree.process_frame
	var stable_count := _node_count(overlay)
	_ok(stable_count >= base_child_count, "detail node graph is bounded after population")
	overlay.close_detail()
	_ok(not overlay.visible, "detail close API hides modal")
	overlay.queue_free()
	await tree.process_frame


func _test_detail_responsive() -> void:
	var stress_card := cards[0]
	for card: CardDefinition in cards:
		if card.rules_text_ru.length() > stress_card.rules_text_ru.length():
			stress_card = card

	for viewport_size: Vector2i in VIEWPORTS:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		tree.root.add_child(viewport)
		var overlay := CardDetailOverlay.new()
		viewport.add_child(overlay)
		await tree.process_frame
		overlay.open_card(stress_card)
		await tree.process_frame
		await tree.process_frame

		var modal := overlay.find_child("CardDetailPanel", true, false) as Control
		var info_scroll := overlay.find_child("DetailInfoScroll", true, false) as ScrollContainer
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_ok(modal != null and viewport_rect.encloses(modal.get_global_rect()),
			"%dx%d detail modal remains within viewport" % [viewport_size.x, viewport_size.y])
		_ok(overlay.full_card.size.x >= 300.0 and overlay.full_card.size.y >= 420.0,
			"%dx%d enlarged FullCard remains usable" % [viewport_size.x, viewport_size.y])
		_ok(info_scroll != null and info_scroll.size.x >= 360.0
			and info_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
			"%dx%d right information column remains readable/scrollable" % [viewport_size.x, viewport_size.y])
		_ok(overlay.close_button.size.y >= 64.0,
			"%dx%d close action keeps Android touch target" % [viewport_size.x, viewport_size.y])
		_ok(overlay.body_text.fit_content and overlay.body_text.text.contains(stress_card.rules_text_ru),
			"%dx%d full authoritative rules remain accessible" % [viewport_size.x, viewport_size.y])

		viewport.queue_free()
		await tree.process_frame


func _test_system_back_closes_detail() -> void:
	SceneRouter.reset_to(Routes.COLLECTION)
	_ok(await _wait_for_route(Routes.COLLECTION), "Collection host route opens for detail Back integration")
	var collection := tree.current_scene as CollectionScreen
	_ok(collection != null and collection.detail != null, "existing Collection uses shared CardDetailOverlay")
	var card := cards[0]
	collection.detail.open_card(card)
	await tree.process_frame
	_ok(collection.detail.visible, "detail visible before system Back")
	tree.root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await tree.process_frame
	await tree.process_frame
	_ok(SceneRouter.current_route == Routes.COLLECTION and not collection.detail.visible,
		"System Back closes Card Detail before navigating away")


func _test_lifecycle_and_batch_cleanup() -> void:
	var overlay := CardDetailOverlay.new()
	tree.root.add_child(overlay)
	await tree.process_frame
	var first := cards[0]
	var second := cards[1]
	overlay.open_card(first)
	await tree.process_frame
	var first_count := _node_count(overlay)
	for i in 12:
		var card := second if i % 2 == 0 else first
		overlay.open_card(card)
		await tree.process_frame
		_ok(overlay.current_card_id == card.id
			and overlay.ru_name_label.text == card.name_ru
			and overlay.en_name_label.text == card.name_en,
			"detail switch %d has no stale previous-card identity" % (i + 1))
		overlay.close_detail()
	overlay.open_card(first)
	await tree.process_frame
	_ok(_node_count(overlay) == first_count,
		"repeated open/switch/close returns to stable detail node count")
	_ok(overlay.close_button.pressed.get_connections().size() == 1,
		"detail close keeps one signal connection")
	overlay.queue_free()
	await tree.process_frame

	var batch := Control.new()
	tree.root.add_child(batch)
	for i in 30:
		var view := FullCardView.new()
		batch.add_child(view)
		view.configure(cards[i % cards.size()])
	await tree.process_frame
	_ok(batch.get_child_count() == 30, "batch creates 30 reusable FullCards")
	for child: Node in batch.get_children():
		child.queue_free()
	await tree.process_frame
	await tree.process_frame
	_ok(batch.get_child_count() == 0, "destroyed FullCard batch leaves no retained card nodes")
	batch.queue_free()
	await tree.process_frame


func _expected_rarity_shape(rarity: CardEnums.Rarity) -> String:
	match rarity:
		CardEnums.Rarity.COMMON:
			return "common_diamond"
		CardEnums.Rarity.RARE:
			return "rare_double_diamond"
		CardEnums.Rarity.EPIC:
			return "epic_elongated_crystal"
		CardEnums.Rarity.LEGENDARY:
			return "legendary_multifaceted_seal"
	return ""


func _node_count(root: Node) -> int:
	var total := 1
	for child: Node in root.get_children():
		total += _node_count(child)
	return total


func _wait_for_route(route_id: StringName) -> bool:
	for _frame in ROUTE_TIMEOUT_FRAMES:
		await tree.process_frame
		if SceneRouter.current_route == route_id and not SceneRouter.is_changing():
			return tree.current_scene != null and tree.current_scene.scene_file_path == Routes.scene_path(route_id)
	return false
