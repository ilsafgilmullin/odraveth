class_name MainMenuV2
extends Control
## Stage 7B Main Menu. Presentation reads authoritative setup state; gameplay rules stay elsewhere.

@onready var guardian_region: Control = %GuardianRegion
@onready var right_region: VBoxContainer = %RightRegion
@onready var wordmark: Label = %Wordmark
@onready var subtitle: Label = %BrandSubtitle
@onready var hero_status: Label = %HeroStatusLabel
@onready var deck_status: Label = %DeckStatusLabel
@onready var status_panel: PanelContainer = %StatusPanel

@onready var enter_button: Button = %PlayButton
@onready var collection_button: Button = %CollectionButton
@onready var decks_button: Button = %DecksButton
@onready var heroes_button: Button = %HeroesButton
@onready var history_button: Button = %HistoryButton
@onready var progress_button: Button = %ProgressButton
@onready var settings_button: Button = %SettingsButton
var speech: CharacterSpeech
var atmosphere: MenuAtmosphere


func _ready() -> void:
	UiKit.apply_root_theme(self)
	var animations := bool(AppState.profile.get("prebattle", {}).get(PlayerSetupData.ANIMATIONS, true))
	atmosphere = MenuAtmosphere.new()
	atmosphere.name = "MenuAtmosphere"
	atmosphere.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(atmosphere)
	move_child(atmosphere, 1)
	atmosphere.set_enabled(animations)
	speech = CharacterSpeech.new()
	speech.custom_minimum_size.x = 340
	guardian_region.add_child(speech)
	speech.speak("Хранитель Нулмериса", "С возвращением. Врата Нулмериса открыты.", animations)
	guardian_region.resized.connect(_layout_character)
	right_region.resized.connect(_layout_character)
	# Q-15 is still open: do not advertise an undefined progression system.
	progress_button.visible = false
	_style_brand()
	(wordmark as BrandWordmark).stone = VisualTokens.COLOR_STONE_050
	subtitle.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_300)
	_style_navigation()
	_connect_navigation()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_layout_for_size(get_viewport_rect().size)
	refresh_setup_status()


func _style_brand() -> void:
	var display_font := load(UiKit.DISPLAY_FONT_PATH) as Font
	if display_font != null:
		wordmark.add_theme_font_override("font", display_font)
		subtitle.add_theme_font_override("font", display_font)
	subtitle.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_700)
	subtitle.text = "МИР НУЛМЕРИСА"
	var caption := find_child("GuardianCaption", true, false) as Label
	if caption != null:
		caption.text = "ХРАНИТЕЛЬ НУЛМЕРИСА"
		caption.add_theme_font_size_override("font_size", 24)
		caption.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
		caption.add_theme_stylebox_override("normal", WarmMaterials.box(true, Color.WHITE, 24, 12))
		if display_font != null:
			caption.add_theme_font_override("font", display_font)


func _style_navigation() -> void:
	UiKit.style_button(enter_button, UiKit.ButtonRole.PRIMARY)
	for button: Button in [collection_button, decks_button, heroes_button]:
		UiKit.style_button(button, UiKit.ButtonRole.SECONDARY)
	for button: Button in [history_button, settings_button]:
		UiKit.style_button(button, UiKit.ButtonRole.SUBTLE)
	# The navigation sits on a carved stone panel so it never floats over the terrace.
	var menu := enter_button.get_parent() as Control
	var holder := menu.get_parent()
	var index := menu.get_index()
	var panel := UiKit.make_panel(true)
	panel.name = "MenuPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.remove_child(menu)
	panel.add_child(menu)
	holder.add_child(panel)
	holder.move_child(panel, index)
	# Keep scene ownership so owned lookups (tests, tools) still find the buttons.
	panel.owner = self
	menu.owner = self
	for child: Node in menu.get_children():
		child.owner = self
	var box := panel.get_theme_stylebox("panel").duplicate() as StyleBox
	if box != null:
		box.content_margin_left = 22.0
		box.content_margin_right = 22.0
		box.content_margin_top = 16.0
		box.content_margin_bottom = 16.0
		panel.add_theme_stylebox_override("panel", box)
	(menu as VBoxContainer).add_theme_constant_override("separation", VisualTokens.SPACE_1)
	(menu as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER


func _connect_navigation() -> void:
	var routes_by_button := {
		collection_button: Routes.COLLECTION,
		decks_button: Routes.DECK_BUILDER,
		heroes_button: Routes.HERO_SELECT,
		history_button: Routes.HISTORY,
		settings_button: Routes.SETTINGS,
	}
	for button: Button in routes_by_button:
		button.pressed.connect(SceneRouter.go_to.bind(routes_by_button[button]))
	enter_button.pressed.connect(_enter_nulmeris)


func _enter_nulmeris() -> void:
	var route := Routes.PREBATTLE if PlayerSetupData.selected_deck(AppState.profile, CardDatabase) != null 		else Routes.DECK_BUILDER
	SceneRouter.go_to(route)


func refresh_setup_status() -> void:
	var hero_id := StringName(str(AppState.profile.get("selected_hero_id", "")))
	if not HeroCatalog.has_hero(hero_id):
		hero_status.text = "Герой не выбран"
		deck_status.text = "Колода: не выбрана"
		return

	var hero: Dictionary = HeroCatalog.HEROES[hero_id]
	hero_status.text = "%s\n%s" % [
		String(hero["name_ru"]),
		SetupUi.faction_name(HeroCatalog.faction_of(hero_id)),
	]

	var selected_id := str(AppState.profile.get("selected_deck_id", ""))
	var selected_record: UserDeck = null
	for deck: UserDeck in PlayerSetupData.decks_for(AppState.profile, hero_id):
		if deck.id == selected_id:
			selected_record = deck
			break

	if selected_record == null:
		deck_status.text = "Колода: не выбрана"
		return

	var readiness := "ГОТОВА" if selected_record.is_ready(CardDatabase) else "НЕ ГОТОВА"
	deck_status.text = "Колода: %s\n%d/%d · %s" % [
		selected_record.name,
		selected_record.card_ids.size(),
		GameRules.DECK_SIZE,
		readiness,
	]


func _on_viewport_size_changed() -> void:
	_apply_layout_for_size(get_viewport_rect().size)


func _apply_layout_for_size(viewport_size: Vector2) -> void:
	var width_class := ResponsiveLayout.width_class(viewport_size.x)
	var guardian_left := 0.03
	var guardian_right := 0.42
	var menu_left := 0.54
	var menu_right := 0.97
	var wordmark_size := 76

	match width_class:
		ResponsiveLayout.WidthClass.NARROW:
			guardian_left = 0.015
			guardian_right = 0.385
			menu_left = 0.445
			menu_right = 0.985
			wordmark_size = 62
		ResponsiveLayout.WidthClass.WIDE:
			guardian_left = 0.045
			guardian_right = 0.42
			menu_left = 0.59
			menu_right = 0.96
			wordmark_size = 82

	_set_horizontal_region(guardian_region, guardian_left, guardian_right)
	_set_horizontal_region(right_region, menu_left, menu_right)
	_layout_character()
	right_region.add_theme_constant_override("separation", ResponsiveLayout.section_gap(viewport_size.x))
	wordmark.add_theme_font_size_override("font_size", wordmark_size)


func _layout_character() -> void:
	if speech != null:
		speech.position = Vector2(guardian_region.size.x * 0.72, guardian_region.size.y * 0.13)
		var available := right_region.get_global_rect().position.x - guardian_region.get_global_rect().position.x - speech.position.x - 16.0
		speech.custom_minimum_size.x = minf(clampf(get_viewport_rect().size.x * 0.18, 280.0, 380.0), maxf(200.0, available))
		speech.size.x = speech.custom_minimum_size.x
		speech.reset_size()


func _set_horizontal_region(control: Control, left: float, right: float) -> void:
	control.anchor_left = left
	control.anchor_right = right
	control.offset_left = 0.0
	control.offset_right = 0.0
