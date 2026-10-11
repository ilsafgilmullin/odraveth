class_name StoryAftermathScreen
extends Control
## Story Mode V1 aftermath: the Book's record of the authoritative MatchEngine
## outcome with the real player and opponent heroes. No rewards, unlocks,
## experience or completion flags; the chapter stays repeatable.

var route_params: Dictionary = {}
var config: BattleLaunchConfig
var outcome: MatchOutcome.Result = MatchOutcome.Result.DRAW
var valid := false
var kicker_label: Label
var title_label: Label
var body_label: Label
var closing_label: Label
var story_panel: PanelContainer
var rematch_button: Button
var chronicles_button: Button
var menu_button: Button
## The configuration handed to the next route (tests read it).
var last_config: BattleLaunchConfig

var _display_font: Font


func apply_route_params(params: Dictionary) -> void:
	route_params = params


func _ready() -> void:
	UiKit.apply_root_theme(self)
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	var cfg: Variant = route_params.get(BattleLaunchConfig.PARAM_KEY)
	config = cfg as BattleLaunchConfig if cfg is BattleLaunchConfig else null
	var raw_outcome: Variant = route_params.get(ResultScreen.PARAM_OUTCOME)
	valid = config != null and config.is_story() and MatchOutcome.is_valid(raw_outcome) \
		and HeroCatalog.has_hero(config.player_hero) and HeroCatalog.has_hero(config.opponent_hero)
	if valid:
		outcome = int(raw_outcome) as MatchOutcome.Result
	add_child(CitadelBackdrop.create(CitadelBackdrop.Mood.CHAMBER, &"library"))
	var veil := ColorRect.new()
	veil.name = "StoryVeil"
	veil.color = Color(0.04, 0.055, 0.06, 0.5)
	veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_build()


func _build() -> void:
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var layout := VBoxContainer.new()
	layout.name = "StoryLayout"
	layout.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	safe.add_child(layout)
	var heading := UiKit.make_display_label("ИСПЫТАНИЕ ЦИТАДЕЛИ")
	heading.name = "StoryHeading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	heading.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	layout.add_child(heading)

	var center := CenterContainer.new()
	center.name = "StoryCenter"
	center.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(center)
	story_panel = UiKit.make_panel(true)
	story_panel.name = "StoryPanel"
	story_panel.custom_minimum_size = Vector2(1240, 0)
	center.add_child(story_panel)
	var content := VBoxContainer.new()
	content.name = "StoryContent"
	content.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	story_panel.add_child(content)

	kicker_label = _label("Kicker", 22, VisualTokens.COLOR_GOLD_700)
	kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(kicker_label)
	title_label = _label("AftermathTitle", 44, VisualTokens.COLOR_STEEL_900, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var record := HBoxContainer.new()
	record.name = "Record"
	record.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	content.add_child(record)
	if valid:
		record.add_child(_hero_column("PlayerRecord", "ВЫ", config.player_hero))
	var scroll := ScrollContainer.new()
	scroll.name = "RecordScroll"
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 250
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	record.add_child(scroll)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = SIZE_EXPAND_FILL
	text_stack.size_flags_vertical = SIZE_EXPAND_FILL
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(text_stack)
	body_label = _label("AftermathBody", 28, VisualTokens.COLOR_INK)
	text_stack.add_child(body_label)
	if valid:
		record.add_child(_hero_column("OpponentRecord", "СОПЕРНИК", config.opponent_hero))

	closing_label = _label("ClosingLine", 28, VisualTokens.COLOR_GOLD_700, true)
	closing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(closing_label)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	content.add_child(actions)
	if valid:
		rematch_button = _action(actions, "ПОВТОРИТЬ ИСПЫТАНИЕ", "RematchButton", UiKit.ButtonRole.PRIMARY, rematch)
	chronicles_button = _action(actions, "В ХРОНИКИ", "ChroniclesButton",
		UiKit.ButtonRole.SECONDARY if valid else UiKit.ButtonRole.PRIMARY, StoryFlow.return_from.bind(config))
	menu_button = _action(actions, "ГЛАВНОЕ МЕНЮ", "MainMenuButton", UiKit.ButtonRole.SECONDARY,
		SceneRouter.reset_to.bind(Routes.MAIN_MENU))
	_render()


func _render() -> void:
	if not valid:
		kicker_label.text = "КНИГА НУЛМЕРИСА"
		title_label.text = "ЗАПИСЬ НЕДОСТУПНА"
		body_label.text = "Страница испытания не сохранилась. Вернитесь в Хроники и начните испытание снова."
		body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		closing_label.text = ""
		closing_label.visible = false
		return
	kicker_label.text = "ЗАПИСЬ КНИГИ · ИСХОД: %s" % MatchOutcome.title(outcome).to_upper()
	title_label.text = StoryFlow.aftermath_title(outcome)
	body_label.text = StoryFlow.aftermath_body(outcome, config.player_hero, config.opponent_hero)
	closing_label.text = "«%s»" % StoryFlow.CLOSING_LINE


func _hero_column(node_name: String, caption_text: String, hero_id: StringName) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.custom_minimum_size.x = 200
	column.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	var caption := _label("Caption", 20, VisualTokens.COLOR_MUTED)
	caption.text = caption_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var portrait := HeroPortraitPlaceholder.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(170, 200)
	portrait.size_flags_horizontal = SIZE_SHRINK_CENTER
	portrait.configure(hero_id)
	column.add_child(portrait)
	var hero_label := _label("HeroName", 28, VisualTokens.COLOR_STEEL_900, true)
	hero_label.text = StoryFlow.hero_name(hero_id).to_upper()
	hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(hero_label)
	return column


func _label(node_name: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display and _display_font != null:
		label.add_theme_font_override("font", _display_font)
	return label


func _action(parent: Control, text_value: String, node_name: String, role: UiKit.ButtonRole, callback: Callable) -> Button:
	var button := UiKit.make_button(text_value, role)
	button.name = node_name
	button.custom_minimum_size = Vector2(320, 84)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


## Same hero, exact deck snapshot, opponent, difficulty and STORY context; fresh seed.
func rematch() -> void:
	if not valid:
		return
	last_config = config.rematch()
	SceneRouter.replace_with(Routes.BATTLE, {BattleLaunchConfig.PARAM_KEY: last_config})


func handle_back_request() -> bool:
	StoryFlow.return_from(config)
	return true
