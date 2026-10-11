class_name StoryCitadelScreen
extends Control
## Story Mode V1 «ИСПЫТАНИЕ ЦИТАДЕЛИ»: three approved intro pages, then the
## preparation view that reads the saved hero and ready deck from AppState.profile.
## It never builds a match or a deck: hero and deck changes reuse Hero Select and
## Deck Builder, and НАЧАТЬ ИСПЫТАНИЕ opens the existing Prebattle in STORY mode.

enum View { INTRO, PREPARATION }

const PAGES: Array[Dictionary] = [
	{
		"title": "ХРАНИТЕЛЬ",
		"body": "Хранитель поднимает жезл, и кольца Цитадели приходят в движение. Он называет предстоящее сражение первым испытанием нынешней Конвергенции.",
		"emphasis": "Для героев оно действительно первое.",
	},
	{
		"title": "ЧЕТЫРЕ СЛЕДА",
		"body": "Книга хранит четыре следа победы. Каждый принадлежит одному из призванных героев, и каждый записан так, будто остальные трое потерпели поражение.",
		"emphasis": "Все четыре записи подлинны.",
	},
	{
		"title": "ПРОТИВОРЕЧИЕ",
		"body": "Ты не знаешь, какая победа произошла первой. Но видишь то, чего не замечают герои: под новой страницей уже проступают стёртые строки прежних циклов.",
		"emphasis": "Войди в испытание и сохрани то, что Книга снова попытается забыть.",
	},
]
const PAGE_NUMERALS := ["I", "II", "III"]

var view: View = View.INTRO
var current_page := 0
var kicker_label: Label
var title_label: Label
var body_label: Label
var emphasis_label: Label
var page_label: Label
var previous_button: Button
var next_button: Button
var story_panel: PanelContainer
var hero_button: Button
var deck_button: Button
var start_button: Button
var status_label: Label

var _display_font: Font


func apply_route_params(params: Dictionary) -> void:
	if str(params.get(StoryFlow.PARAM_VIEW, "")) == StoryFlow.VIEW_PREPARATION:
		view = View.PREPARATION
		return
	var requested: Variant = params.get(StoryFlow.PARAM_PAGE, 0)
	var kind := typeof(requested)
	current_page = clampi(int(requested), 0, PAGES.size() - 1) if kind == TYPE_INT or kind == TYPE_FLOAT else 0


func _ready() -> void:
	UiKit.apply_root_theme(self)
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	if view == View.INTRO:
		add_child(CitadelBackdrop.create(CitadelBackdrop.Mood.CHAMBER, &"convergence"))
		var veil := ColorRect.new()
		veil.name = "StoryVeil"
		veil.color = Color(0.04, 0.055, 0.06, 0.5)
		veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(veil)
	else:
		add_child(CitadelBackdrop.create(CitadelBackdrop.Mood.HALL, &"staging_hall"))
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var layout := VBoxContainer.new()
	layout.name = "StoryLayout"
	layout.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	safe.add_child(layout)
	_build_header(layout)
	if view == View.INTRO:
		_build_intro(layout)
		_render_page()
	else:
		_build_preparation(layout)
		refresh_preparation()


func _build_header(layout: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.name = "StoryHeader"
	header.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	layout.add_child(header)
	var back := UiKit.make_button("НАЗАД", UiKit.ButtonRole.SECONDARY)
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(190, 72)
	back.pressed.connect(_on_back)
	header.add_child(back)
	var heading := UiKit.make_display_label("ИСПЫТАНИЕ ЦИТАДЕЛИ")
	heading.name = "StoryHeading"
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	if view == View.INTRO:
		heading.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	header.add_child(heading)
	var chronicles := UiKit.make_button("ХРОНИКИ", UiKit.ButtonRole.SECONDARY)
	chronicles.name = "ChroniclesButton"
	chronicles.custom_minimum_size = Vector2(220, 72)
	chronicles.pressed.connect(StoryFlow.open_chronicles)
	header.add_child(chronicles)


func _build_intro(layout: VBoxContainer) -> void:
	var center := CenterContainer.new()
	center.name = "StoryCenter"
	center.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(center)
	story_panel = UiKit.make_panel(true)
	story_panel.name = "StoryPanel"
	story_panel.custom_minimum_size = Vector2(1060, 0)
	center.add_child(story_panel)
	var content := VBoxContainer.new()
	content.name = "StoryContent"
	content.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	story_panel.add_child(content)

	var seal := EmblemView.seal(Color(VisualTokens.COLOR_GOLD_700, 0.78))
	seal.name = "StorySeal"
	seal.custom_minimum_size = Vector2(84, 84)
	seal.size_flags_horizontal = SIZE_SHRINK_CENTER
	content.add_child(seal)
	kicker_label = _label("Kicker", 22, VisualTokens.COLOR_GOLD_700)
	kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(kicker_label)
	title_label = _label("PageTitle", 42, VisualTokens.COLOR_STEEL_900, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.name = "PageScroll"
	scroll.custom_minimum_size.y = 280
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = SIZE_EXPAND_FILL
	text_stack.size_flags_vertical = SIZE_EXPAND_FILL
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	scroll.add_child(text_stack)
	body_label = _label("PageBody", 28, VisualTokens.COLOR_INK)
	text_stack.add_child(body_label)
	emphasis_label = _label("PageEmphasis", 29, VisualTokens.COLOR_GOLD_700, true)
	emphasis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_stack.add_child(emphasis_label)

	var navigation := HBoxContainer.new()
	navigation.name = "StoryNavigation"
	navigation.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	content.add_child(navigation)
	previous_button = UiKit.make_button("НАЗАД ПО СТРАНИЦАМ", UiKit.ButtonRole.SECONDARY)
	previous_button.name = "PreviousButton"
	previous_button.custom_minimum_size = Vector2(300, 72)
	previous_button.pressed.connect(_previous_page)
	navigation.add_child(previous_button)
	page_label = _label("PageIndicator", 24, VisualTokens.COLOR_STEEL_700)
	page_label.size_flags_horizontal = SIZE_EXPAND_FILL
	page_label.custom_minimum_size.x = 190
	page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(page_label)
	next_button = UiKit.make_button("ДАЛЕЕ", UiKit.ButtonRole.PRIMARY)
	next_button.name = "NextButton"
	next_button.custom_minimum_size = Vector2(300, 72)
	next_button.pressed.connect(_next_page)
	navigation.add_child(next_button)


func _build_preparation(layout: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.name = "PreparationBody"
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	layout.add_child(body)
	body.add_child(_hero_panel())
	body.add_child(_deck_panel())
	body.add_child(_trial_panel())

	var actions := HBoxContainer.new()
	actions.name = "PreparationActions"
	actions.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	layout.add_child(actions)
	status_label = _label("ReadinessStatus", 26, VisualTokens.COLOR_STEEL_900, true)
	status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var status_panel := UiKit.make_panel(false)
	status_panel.name = "ReadinessPanel"
	status_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	status_panel.add_child(status_label)
	actions.add_child(status_panel)
	start_button = UiKit.make_button("НАЧАТЬ ИСПЫТАНИЕ", UiKit.ButtonRole.PRIMARY)
	start_button.name = "StartTrialButton"
	start_button.custom_minimum_size = Vector2(460, 92)
	start_button.add_theme_font_size_override("font_size", 36)
	start_button.pressed.connect(start_trial)
	actions.add_child(start_button)


func _panel(node_name: String, caption_text: String) -> VBoxContainer:
	var panel := UiKit.make_panel(false)
	panel.name = node_name
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_2)
	panel.add_child(stack)
	stack.add_child(_label("Caption", 20, VisualTokens.COLOR_MUTED))
	(stack.get_child(0) as Label).text = caption_text
	return stack


func _hero_panel() -> PanelContainer:
	var stack := _panel("HeroPanel", "ГЕРОЙ")
	var hero := _selected_hero()
	if HeroCatalog.has_hero(hero):
		var portrait := HeroPortraitPlaceholder.new()
		portrait.name = "HeroPortrait"
		portrait.custom_minimum_size = Vector2(0, 240)
		portrait.size_flags_vertical = SIZE_EXPAND_FILL
		portrait.configure(hero)
		stack.add_child(portrait)
		var name_label := _label("HeroName", 38, VisualTokens.COLOR_STEEL_900, true)
		name_label.text = StoryFlow.hero_name(hero).to_upper()
		stack.add_child(name_label)
		var faction_row := HBoxContainer.new()
		faction_row.add_theme_constant_override("separation", VisualTokens.SPACE_1)
		stack.add_child(faction_row)
		var emblem := EmblemView.for_faction(HeroCatalog.faction_of(hero), Color("e6dfd1"))
		emblem.custom_minimum_size = Vector2(32, 32)
		faction_row.add_child(emblem)
		var faction := _label("HeroFaction", 24, HeroPresentation.faction_accent(hero).darkened(0.25))
		faction.text = SetupUi.faction_name(HeroCatalog.faction_of(hero)).to_upper()
		faction.autowrap_mode = TextServer.AUTOWRAP_OFF
		faction_row.add_child(faction)
	else:
		var missing := _label("HeroName", 34, VisualTokens.COLOR_STEEL_900, true)
		missing.text = "ГЕРОЙ НЕ ВЫБРАН"
		stack.add_child(missing)
		var note := _label("HeroNote", 24, VisualTokens.COLOR_STEEL_700)
		note.text = "Выберите героя, который войдёт в испытание."
		note.size_flags_vertical = SIZE_EXPAND_FILL
		stack.add_child(note)
	hero_button = UiKit.make_button("СМЕНИТЬ ГЕРОЯ" if HeroCatalog.has_hero(hero) else "ВЫБРАТЬ ГЕРОЯ",
		UiKit.ButtonRole.SECONDARY)
	hero_button.name = "HeroButton"
	hero_button.custom_minimum_size.y = 72
	hero_button.add_theme_font_size_override("font_size", 28)
	hero_button.pressed.connect(SceneRouter.go_to.bind(Routes.HERO_SELECT))
	stack.add_child(hero_button)
	return stack.get_parent() as PanelContainer


func _deck_panel() -> PanelContainer:
	var stack := _panel("DeckPanel", "КОЛОДА")
	var deck := PlayerSetupData.selected_deck(AppState.profile, CardDatabase)
	var name_label := _label("DeckName", 34, VisualTokens.COLOR_STEEL_900, true)
	stack.add_child(name_label)
	var detail := _label("DeckDetail", 24, VisualTokens.COLOR_STEEL_700)
	detail.size_flags_vertical = SIZE_EXPAND_FILL
	if deck != null:
		name_label.text = deck.name
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", VisualTokens.SPACE_3)
		stack.add_child(row)
		var count := _label("DeckCount", 30, VisualTokens.COLOR_STEEL_900, true)
		count.text = "%d/%d" % [deck.card_ids.size(), GameRules.DECK_SIZE]
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(count)
		var marker := UiKit.make_status_marker("ГОТОВА")
		marker.name = "DeckReadyMarker"
		row.add_child(marker)
		detail.text = "Бой проходит выбранной колодой без изменений."
	else:
		name_label.text = "НЕТ ГОТОВОЙ КОЛОДЫ"
		detail.text = "Нужна готовая колода из %d карт выбранного героя." % GameRules.DECK_SIZE
	stack.add_child(detail)
	deck_button = UiKit.make_button("СМЕНИТЬ КОЛОДУ" if deck != null else "СОБРАТЬ КОЛОДУ", UiKit.ButtonRole.SECONDARY)
	deck_button.name = "DeckButton"
	deck_button.custom_minimum_size.y = 72
	deck_button.add_theme_font_size_override("font_size", 28)
	deck_button.pressed.connect(SceneRouter.go_to.bind(Routes.DECK_BUILDER))
	stack.add_child(deck_button)
	return stack.get_parent() as PanelContainer


func _trial_panel() -> PanelContainer:
	var stack := _panel("TrialPanel", "ИСПЫТАНИЕ")
	var caption := _label("TrialCaption", 30, VisualTokens.COLOR_GOLD_700, true)
	caption.text = StoryFlow.CHAPTER_CAPTION
	stack.add_child(caption)
	var modifiers := UiKit.make_status_marker(StoryFlow.MODIFIERS_NONE)
	modifiers.name = "ModifiersMarker"
	modifiers.size_flags_horizontal = SIZE_SHRINK_BEGIN
	stack.add_child(modifiers)
	var opponent := _label("TrialOpponent", 24, VisualTokens.COLOR_STEEL_700)
	opponent.text = "Соперника выберут механизмы Цитадели среди трёх других героев."
	stack.add_child(opponent)
	var rules := _label("TrialRules", 24, VisualTokens.COLOR_STEEL_700)
	rules.text = "Бой идёт по обычным правилам. Книга запишет любой исход: победу, поражение или ничью."
	rules.size_flags_vertical = SIZE_EXPAND_FILL
	stack.add_child(rules)
	return stack.get_parent() as PanelContainer


func _label(node_name: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display and _display_font != null:
		label.add_theme_font_override("font", _display_font)
	return label


func _selected_hero() -> StringName:
	return StringName(str(AppState.profile.get("selected_hero_id", "")))


## Ready only with a saved hero and a ready selected deck of that hero (DeckValidator via UserDeck).
func is_ready() -> bool:
	return HeroCatalog.has_hero(_selected_hero()) and PlayerSetupData.selected_deck(AppState.profile, CardDatabase) != null


func refresh_preparation() -> void:
	var setup_ready := is_ready()
	start_button.disabled = not setup_ready
	if not HeroCatalog.has_hero(_selected_hero()):
		status_label.text = "Выберите героя, чтобы начать испытание."
	elif not setup_ready:
		status_label.text = "Выберите готовую колоду из %d карт, чтобы начать испытание." % GameRules.DECK_SIZE
	else:
		status_label.text = "✓ Герой и колода готовы к испытанию."


func _render_page() -> void:
	var page: Dictionary = PAGES[current_page]
	kicker_label.text = "ИСПЫТАНИЕ ЦИТАДЕЛИ · СТРАНИЦА %s" % PAGE_NUMERALS[current_page]
	title_label.text = page["title"]
	body_label.text = page["body"]
	emphasis_label.text = "«%s»" % page["emphasis"]
	page_label.text = "СТРАНИЦА %d ИЗ %d" % [current_page + 1, PAGES.size()]
	previous_button.disabled = current_page == 0
	next_button.text = "К ПОДГОТОВКЕ" if current_page == PAGES.size() - 1 else "ДАЛЕЕ"


func _previous_page() -> void:
	if current_page <= 0:
		return
	current_page -= 1
	_render_page()


func _next_page() -> void:
	if current_page < PAGES.size() - 1:
		current_page += 1
		_render_page()
		return
	# A fresh route entry records the preparation view, so Back from Hero Select,
	# Deck Builder or Story Prebattle returns here and not to the intro.
	SceneRouter.replace_with(Routes.STORY_CITADEL, {StoryFlow.PARAM_VIEW: StoryFlow.VIEW_PREPARATION})


## Opens the existing Prebattle in STORY mode. Returns false while setup is not ready.
func start_trial() -> bool:
	refresh_preparation()
	if not is_ready():
		return false
	return SceneRouter.go_to(Routes.PREBATTLE, StoryFlow.story_params()) == OK


func handle_back_request() -> bool:
	_on_back()
	return true


func _on_back() -> void:
	if view == View.PREPARATION:
		SceneRouter.replace_with(Routes.STORY_CITADEL, {StoryFlow.PARAM_PAGE: PAGES.size() - 1})
	elif current_page > 0:
		_previous_page()
	else:
		SceneRouter.replace_with(Routes.STORY_PROLOGUE, {StoryFlow.PARAM_PAGE: StoryPrologueScreen.PAGES.size() - 1})
