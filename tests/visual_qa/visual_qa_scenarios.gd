extends RefCounted
## QA-only screenshot scenarios. Each returns true when its state was prepared.

const GALLERY_IDS: Array[StringName] = [
	&"dumoryss_echo_leech", &"ashravael_warfiend", &"nerqathen_soulmonger", &"neutral_mireglass_wanderer",
	&"khevaruun_wallforged", &"nerqathen_second_burial", &"ashravael_furnace_sigil", &"neutral_vantrel_duskling",
]

var runner: Node
var _overlay: CanvasLayer


func _init(capture_runner: Node) -> void:
	runner = capture_runner


func all() -> Array:
	return [
		["emblems", emblems],
		["main_menu", main_menu],
		["hero_select", hero_select],
		["card_gallery", card_gallery],
		["card_detail", card_detail],
		["collection", collection],
		["collection-bottom", collection_bottom],
		["collection-search", collection_search],
	]


func cleanup() -> void:
	_clear_overlay()


func qa_profile(with_ready_deck: bool = true) -> Dictionary:
	var profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	if with_ready_deck:
		var deck := UserDeck.create(HeroCatalog.KEZHARYN)
		deck.name = "Колода Кежарина"
		deck.card_ids.assign(BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, CardDatabase))
		profile = PlayerSetupData.upsert(profile, deck, CardDatabase)
	return profile


func _use_profile(profile: Dictionary) -> void:
	AppState.persist_profile(profile)


func main_menu() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.MAIN_MENU)


func hero_select() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.HERO_SELECT)


func card_gallery() -> bool:
	_clear_overlay()
	if not await runner.open_route(Routes.MAIN_MENU):
		return false
	var root := _overlay_root()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)
	for card_id: StringName in GALLERY_IDS:
		var view := FullCardView.new()
		grid.add_child(view)
		view.configure(CardDatabase.get_card(card_id))
	return true


func _overlay_root(background_color: Color = Color("e8e2d7")) -> Control:
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	runner.get_tree().root.add_child(_overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_root_theme(root)
	_overlay.add_child(root)
	var background := ColorRect.new()
	background.color = background_color
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	return root


func emblems() -> bool:
	_clear_overlay()
	if not await runner.open_route(Routes.MAIN_MENU):
		return false
	var root := _overlay_root()
	var rows := VBoxContainer.new()
	rows.position = Vector2(60, 60)
	rows.add_theme_constant_override("separation", 28)
	root.add_child(rows)
	for edge: float in [48.0, 96.0, 200.0]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 36)
		rows.add_child(row)
		var views: Array[EmblemView] = [EmblemView.seal(), EmblemView.o_mark()]
		for faction: Faction.Id in [Faction.Id.ASHRAVAEL, Faction.Id.NERQATHEN, Faction.Id.DUMORYSS,
				Faction.Id.KHEVARUUN, Faction.Id.NEUTRAL]:
			views.append(EmblemView.for_faction(faction, Color("e8e2d7")))
		for view: EmblemView in views:
			view.custom_minimum_size = Vector2(edge, edge)
			row.add_child(view)
	var dark := HBoxContainer.new()
	dark.add_theme_constant_override("separation", 36)
	rows.add_child(dark)
	for faction: Faction.Id in [Faction.Id.ASHRAVAEL, Faction.Id.NERQATHEN, Faction.Id.DUMORYSS, Faction.Id.KHEVARUUN]:
		var tile := ColorRect.new()
		tile.color = VisualTokens.COLOR_STEEL_900
		tile.custom_minimum_size = Vector2(150, 150)
		dark.add_child(tile)
		var view := EmblemView.for_faction(faction, VisualTokens.COLOR_STEEL_900)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(view)
	return true


func card_detail() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	if not await runner.open_route(Routes.COLLECTION):
		return false
	var screen := runner.get_tree().current_scene as CollectionScreen
	return screen != null and screen.detail.open_card(&"dumoryss_echo_leech")


func collection() -> bool:
	_clear_overlay()
	_use_profile(qa_profile())
	return await runner.open_route(Routes.COLLECTION)


func collection_bottom() -> bool:
	if not await collection():
		return false
	var screen := runner.get_tree().current_scene as CollectionScreen
	await runner.settle(4)
	screen.card_scroll.scroll_vertical = int(screen.card_scroll.get_v_scroll_bar().max_value)
	return true


func collection_search() -> bool:
	if not await collection():
		return false
	var screen := runner.get_tree().current_scene as CollectionScreen
	screen.search.text = "стран"
	screen.search.text_changed.emit(screen.search.text)
	return true


func _clear_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
