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


func _ready() -> void:
	UiKit.apply_root_theme(self)
	_style_brand()
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
	wordmark.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	subtitle.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_700)


func _style_navigation() -> void:
	UiKit.style_button(enter_button, UiKit.ButtonRole.PRIMARY)
	for button: Button in [collection_button, decks_button, heroes_button]:
		UiKit.style_button(button, UiKit.ButtonRole.SECONDARY)
	for button: Button in [history_button, progress_button, settings_button]:
		UiKit.style_button(button, UiKit.ButtonRole.SUBTLE)
	status_panel.modulate.a = 0.88


func _connect_navigation() -> void:
	var routes_by_button := {
		collection_button: Routes.COLLECTION,
		decks_button: Routes.DECK_BUILDER,
		heroes_button: Routes.HERO_SELECT,
		history_button: Routes.HISTORY,
		progress_button: Routes.PROGRESS,
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
	right_region.add_theme_constant_override("separation", ResponsiveLayout.section_gap(viewport_size.x))
	wordmark.add_theme_font_size_override("font_size", wordmark_size)


func _set_horizontal_region(control: Control, left: float, right: float) -> void:
	control.anchor_left = left
	control.anchor_right = right
	control.offset_left = 0.0
	control.offset_right = 0.0
