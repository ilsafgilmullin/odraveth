class_name HeroSelectScreen
extends Control
## Stage 7C Hero Select V1. Tap previews; only explicit confirmation persists selection.

var pending_hero: StringName = &""
var hero_buttons: Dictionary = {}

@onready var hero_row: HBoxContainer = %HeroCards
@onready var info_panel: PanelContainer = %HeroInfoPanel
@onready var hero_name_label: Label = %SelectedHeroName
@onready var faction_label: Label = %SelectedFaction
@onready var power_name_label: Label = %PowerName
@onready var power_cost_label: Label = %PowerCost
@onready var power_description_label: Label = %PowerDescription
@onready var playstyle_label: Label = %Playstyle
@onready var status_message: Label = %StatusMessage
@onready var confirm_button: Button = %ConfirmHeroButton
@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel

var _button_group := ButtonGroup.new()


func _ready() -> void:
	UiKit.apply_root_theme(self)
	# Production Hero Hall art goes behind everything when present; otherwise the
	# existing Visual Alpha scene background stays as it is.
	if ArtAssets.has(&"hero_hall"):
		var hall := CitadelBackdrop.create(CitadelBackdrop.Mood.HALL, &"hero_hall")
		hall.name = "HeroHallArt"
		add_child(hall)
		move_child(hall, 1 if get_child_count() > 1 and get_child(0) is ColorRect else 0)
	_button_group.allow_unpress = false
	UiKit.style_button(back_button, UiKit.ButtonRole.SECONDARY)
	UiKit.style_button(confirm_button, UiKit.ButtonRole.PRIMARY)
	back_button.pressed.connect(_request_back)
	confirm_button.pressed.connect(_confirm)

	pending_hero = StringName(str(AppState.profile.get("selected_hero_id", "")))
	if not HeroCatalog.has_hero(pending_hero):
		pending_hero = &""

	_build_hero_cards()
	_refresh_selection()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_layout_for_size(get_viewport_rect().size)


func _build_hero_cards() -> void:
	for hero: StringName in PlayerSetupData.HERO_IDS:
		var card := HeroSelectCard.new()
		card.name = "Hero_%s" % hero
		card.button_group = _button_group
		card.configure(hero)
		card.pressed.connect(_choose.bind(hero))
		hero_row.add_child(card)
		hero_buttons[hero] = card


func _choose(hero: StringName) -> void:
	if not HeroCatalog.has_hero(hero):
		return
	pending_hero = hero
	status_message.text = ""
	_refresh_selection()


func _refresh_selection() -> void:
	for hero: StringName in hero_buttons:
		(hero_buttons[hero] as HeroSelectCard).set_selected_state(hero == pending_hero)
	_update_info_panel()
	confirm_button.disabled = not HeroCatalog.has_hero(pending_hero)


func _update_info_panel() -> void:
	if not HeroCatalog.has_hero(pending_hero):
		hero_name_label.text = "ВЫБЕРИТЕ ГЕРОЯ"
		faction_label.text = ""
		power_name_label.text = "СПОСОБНОСТЬ ГЕРОЯ"
		power_cost_label.text = ""
		power_description_label.text = "Коснитесь портрета героя, чтобы открыть полное описание способности."
		playstyle_label.text = ""
		return

	var data: Dictionary = HeroCatalog.HEROES[pending_hero]
	var faction := HeroCatalog.faction_of(pending_hero)
	var accent := HeroPresentation.faction_accent(pending_hero)
	hero_name_label.text = String(data["name_ru"]).to_upper()
	faction_label.text = SetupUi.faction_name(faction).to_upper()
	faction_label.add_theme_color_override("font_color", accent)
	power_name_label.text = String(data["power_ru"]).to_upper()
	power_cost_label.text = "СТОИМОСТЬ: %d ЭНЕРГИИ" % HeroPresentation.power_cost(pending_hero)
	power_description_label.text = HeroPresentation.power_description(pending_hero)
	playstyle_label.text = HeroPresentation.playstyle(pending_hero)


func _confirm() -> void:
	if not HeroCatalog.has_hero(pending_hero):
		status_message.text = "Сначала выберите героя"
		return
	var next := PlayerSetupData.select_hero(AppState.profile, pending_hero)
	if AppState.persist_profile(next) != OK:
		status_message.text = "Не удалось сохранить героя. Выбор остаётся на экране."
		return
	_request_back()


func _request_back() -> void:
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.MAIN_MENU)


func handle_back_request() -> bool:
	# Tap selection is preview-only, so generic SceneRouter Back can safely leave.
	return false


func _on_viewport_size_changed() -> void:
	_apply_layout_for_size(get_viewport_rect().size)


func _apply_layout_for_size(viewport_size: Vector2) -> void:
	var width_class := ResponsiveLayout.width_class(viewport_size.x)
	var cards_height := 318.0
	var info_height := 218.0
	var title_size := 52
	var row_gap := 12

	match width_class:
		ResponsiveLayout.WidthClass.NARROW:
			cards_height = 294.0
			info_height = 210.0
			title_size = 48
			row_gap = 8
		ResponsiveLayout.WidthClass.WIDE:
			cards_height = 338.0
			info_height = 226.0
			title_size = 56
			row_gap = 16

	hero_row.custom_minimum_size.y = cards_height
	hero_row.add_theme_constant_override("separation", row_gap)
	info_panel.custom_minimum_size.y = info_height
	title_label.add_theme_font_size_override("font_size", title_size)
	power_description_label.custom_minimum_size.y = 84.0
