class_name StoryPrologueScreen
extends Control
## First narrative slice: «Страница без имени → Цитадель».
## Presentation only. It does not construct a match, alter progression or add
## terrain rules; the final action opens «Испытание Цитадели» (Story Mode V1).

const PAGES: Array[Dictionary] = [
	{
		"kicker": "ПРОЛОГ · СТРАНИЦА I",
		"title": "СТРАНИЦА БЕЗ ИМЕНИ",
		"body": "Книга Нулмериса раскрывается сама. На странице нет имени — только следы прежних побед.\n\nЧетыре исхода противоречат друг другу. Каждый записан так, будто только он когда-либо существовал.",
		"emphasis": "Книга помнит больше, чем её герои.",
	},
	{
		"kicker": "ПРОЛОГ · СТРАНИЦА II",
		"title": "ПАМЯТЬ СТЁРТОГО",
		"body": "Герои не помнят завершённых циклов. Для них предстоящее испытание начинается впервые.\n\nНо ты различаешь следы земель, людей и решений, которых в нынешней реальности никогда не было.",
		"emphasis": "Ты помнишь миры, которых никогда не было.",
	},
	{
		"kicker": "ПРОЛОГ · СТРАНИЦА III",
		"title": "ЦИТАДЕЛЬ НУЛМЕРИСА",
		"body": "Хранитель называет предстоящую Конвергенцию первым испытанием. Книга хранит иное свидетельство: каждый из четырёх героев уже побеждал.\n\nВрата Цитадели открываются. Здесь начинается новый цикл — и впервые память стёртых вариантов входит в него вместе с тобой.",
		"emphasis": "Выбери героя и войди в Конвергенцию.",
	},
]

var current_page := 0
var kicker_label: Label
var title_label: Label
var body_label: Label
var emphasis_label: Label
var page_label: Label
var previous_button: Button
var next_button: Button
var story_panel: PanelContainer

var _requested_page := 0
var _display_font: Font


func apply_route_params(params: Dictionary) -> void:
	var requested: Variant = params.get("page", 0)
	var kind := typeof(requested)
	_requested_page = clampi(int(requested), 0, PAGES.size() - 1) if kind == TYPE_INT or kind == TYPE_FLOAT else 0


func _ready() -> void:
	UiKit.apply_root_theme(self)
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	add_child(CitadelBackdrop.create(CitadelBackdrop.Mood.CHAMBER, &"library"))
	_build_interface()
	current_page = _requested_page
	_render_page()


func _build_interface() -> void:
	var veil := ColorRect.new()
	veil.name = "StoryVeil"
	veil.color = Color(0.04, 0.055, 0.06, 0.52)
	veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)

	var layout := VBoxContainer.new()
	layout.name = "StoryLayout"
	layout.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	safe.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "StoryHeader"
	header.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	layout.add_child(header)
	var back := UiKit.make_button("НАЗАД", UiKit.ButtonRole.SECONDARY)
	back.name = "BackButton"
	back.custom_minimum_size.x = 190
	back.pressed.connect(_on_back)
	header.add_child(back)
	var heading := UiKit.make_display_label("ПАМЯТЬ СТЁРТОГО МИРА")
	heading.name = "StoryHeading"
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	header.add_child(heading)
	var library := UiKit.make_button("БИБЛИОТЕКА", UiKit.ButtonRole.SECONDARY)
	library.name = "LibraryButton"
	library.custom_minimum_size.x = 220
	library.pressed.connect(_open_library)
	header.add_child(library)

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
	seal.custom_minimum_size = Vector2(92, 92)
	seal.size_flags_horizontal = SIZE_SHRINK_CENTER
	content.add_child(seal)

	kicker_label = _label("Kicker", 22, VisualTokens.COLOR_GOLD_700)
	kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(kicker_label)
	title_label = _label("PageTitle", 42, VisualTokens.COLOR_STEEL_900)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _display_font != null:
		title_label.add_theme_font_override("font", _display_font)
	content.add_child(title_label)
	body_label = _label("PageBody", 27, VisualTokens.COLOR_INK)
	body_label.custom_minimum_size.y = 190
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(body_label)
	emphasis_label = _label("PageEmphasis", 28, VisualTokens.COLOR_GOLD_700)
	emphasis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _display_font != null:
		emphasis_label.add_theme_font_override("font", _display_font)
	content.add_child(emphasis_label)

	var navigation := HBoxContainer.new()
	navigation.name = "StoryNavigation"
	navigation.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	content.add_child(navigation)
	previous_button = UiKit.make_button("НАЗАД ПО СТРАНИЦАМ", UiKit.ButtonRole.SECONDARY)
	previous_button.name = "PreviousButton"
	previous_button.custom_minimum_size.x = 300
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
	next_button.custom_minimum_size.x = 300
	next_button.pressed.connect(_next_page)
	navigation.add_child(next_button)


func _label(node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _render_page() -> void:
	var page: Dictionary = PAGES[current_page]
	kicker_label.text = page["kicker"]
	title_label.text = page["title"]
	body_label.text = page["body"]
	emphasis_label.text = "«%s»" % page["emphasis"]
	page_label.text = "СТРАНИЦА %d ИЗ %d" % [current_page + 1, PAGES.size()]
	previous_button.disabled = current_page == 0
	next_button.text = "ВОЙТИ В ЦИТАДЕЛЬ" if current_page == PAGES.size() - 1 else "ДАЛЕЕ"


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
	_enter_citadel()


## Never the ordinary Prebattle: hero and deck readiness are handled by the
## preparation view of «Испытание Цитадели».
func _enter_citadel() -> void:
	SceneRouter.replace_with(Routes.STORY_CITADEL)


func _open_library() -> void:
	StoryFlow.open_chronicles()


func handle_back_request() -> bool:
	_on_back()
	return true


func _on_back() -> void:
	if current_page > 0:
		_previous_page()
	else:
		StoryFlow.open_chronicles()
