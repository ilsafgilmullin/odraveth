class_name HistoryShell
extends Control
## Stage 7 «БИБЛИОТЕКА НУЛМЕРИСА»: the central «КНИГА НУЛМЕРИСА» with its eight
## sections. Only approved facts are shown (factions and heroes from
## PRODUCT_BASELINE §3–4); sections without approved text are sealed pages, never
## invented lore. No progression, rewards or unlocks (Q-15 stays open).

const SECTIONS: Array[String] = ["МИР НУЛМЕРИСА", "ЦИТАДЕЛЬ НУЛМЕРИСА", "ФРАКЦИИ", "ГЕРОИ", "ЛИЧНОСТИ", "МЕСТА",
	"ХРОНИКИ", "АВТОРЫ"]
const OPEN_SECTIONS: Array[String] = ["МИР НУЛМЕРИСА", "ФРАКЦИИ", "ГЕРОИ"]
const FACTION_ROWS := [
	[Faction.Id.ASHRAVAEL, "Ashravael", HeroCatalog.KEZHARYN, "красный, огненный"],
	[Faction.Id.NERQATHEN, "Nerqathen", HeroCatalog.VHORAZEL, "холодный бирюзовый"],
	[Faction.Id.DUMORYSS, "Dumoryss", HeroCatalog.SYRRAVETH, "фиолетовый"],
	[Faction.Id.KHEVARUUN, "Khevaruun", HeroCatalog.TAZHYRION, "золотисто-синий"],
]

var section_buttons: Dictionary = {}
var current_section := ""
var page_title: Label
var page_body: VBoxContainer

var _display_font: Font


func _ready() -> void:
	UiKit.apply_root_theme(self)
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	add_child(CitadelBackdrop.create(CitadelBackdrop.Mood.HALL, &"library"))
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	safe.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	layout.add_child(header)
	var back := UiKit.make_button("НАЗАД", UiKit.ButtonRole.SECONDARY)
	back.name = "BackButton"
	back.pressed.connect(_go_back)
	header.add_child(back)
	var title := UiKit.make_display_label("БИБЛИОТЕКА НУЛМЕРИСА")
	title.name = "LibraryTitle"
	title.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	header.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", VisualTokens.SPACE_5)
	layout.add_child(body)
	var shelf := VBoxContainer.new()
	shelf.name = "Sections"
	shelf.custom_minimum_size = Vector2(400, 0)
	shelf.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	body.add_child(shelf)
	for section: String in SECTIONS:
		var button := UiKit.make_button(section, UiKit.ButtonRole.SEGMENT)
		button.name = "Section_%d" % SECTIONS.find(section)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 26)
		button.custom_minimum_size = Vector2(400, 82)
		if section not in OPEN_SECTIONS:
			button.icon = null
			button.tooltip_text = "Страницы запечатаны"
		button.pressed.connect(show_section.bind(section))
		shelf.add_child(button)
		section_buttons[section] = button
	body.add_child(_build_book())
	show_section("ФРАКЦИИ")


func _build_book() -> Control:
	var book := Control.new()
	book.name = "Book"
	book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book.draw.connect(func() -> void: _draw_book(book))
	book.resized.connect(book.queue_redraw)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 72)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	book.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	margin.add_child(stack)
	var book_title := Label.new()
	book_title.name = "HistoryTitle"
	book_title.text = "КНИГА НУЛМЕРИСА"
	book_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	book_title.add_theme_font_size_override("font_size", 26)
	book_title.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_700)
	if _display_font != null:
		book_title.add_theme_font_override("font", _display_font)
	stack.add_child(book_title)
	page_title = Label.new()
	page_title.name = "PageTitle"
	page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_title.add_theme_font_size_override("font_size", 44)
	page_title.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	if _display_font != null:
		page_title.add_theme_font_override("font", _display_font)
	stack.add_child(page_title)
	var scroll := ScrollContainer.new()
	scroll.name = "PageScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.prepare_scroll(scroll)
	stack.add_child(scroll)
	page_body = VBoxContainer.new()
	page_body.name = "PageBody"
	page_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_body.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	scroll.add_child(page_body)
	return book


func _draw_book(book: Control) -> void:
	var s := book.size
	if s.x < 40.0:
		return
	# Production Book of Nulmeris (alpha PNG); the page text stays live Godot UI on top.
	var art := ArtAssets.texture(&"book")
	if art != null:
		ArtAssets.draw_cover(book, art, Rect2(Vector2.ZERO, s))
		return
	var cover := Rect2(Vector2.ZERO, s)
	book.draw_rect(cover, Color("6b5a43"))
	book.draw_rect(cover.grow(-6.0), Color("8a7356"), false, 3.0)
	var pages := cover.grow(-18.0)
	book.draw_rect(pages, Color("f1eadb"))
	# Single folio page with the binding on the left edge.
	book.draw_rect(Rect2(pages.position, Vector2(36.0, pages.size.y)), Color(0.45, 0.38, 0.28, 0.14))
	book.draw_line(Vector2(pages.position.x + 36.0, pages.position.y), Vector2(pages.position.x + 36.0, pages.end.y),
		Color(0.45, 0.38, 0.28, 0.3), 2.0)
	book.draw_rect(pages.grow(-14.0), Color(VisualTokens.COLOR_GOLD_500, 0.45), false, 1.5)
	NulmerisEmblems.draw_seal(book, Vector2(pages.end.x - 80.0, pages.end.y - 80.0), 44.0, Color(0.45, 0.38, 0.28, 0.12),
		Color(VisualTokens.COLOR_MAGIC_500, 0.16))


func show_section(section: String) -> void:
	current_section = section
	for key: String in section_buttons:
		var button := section_buttons[key] as Button
		UiKit.style_button(button, UiKit.ButtonRole.PRIMARY if key == section else UiKit.ButtonRole.SEGMENT)
		button.add_theme_font_size_override("font_size", 26)
		button.text = key if key in OPEN_SECTIONS else "%s\nзапечатано" % key
		button.add_theme_font_size_override("font_size", 26 if key in OPEN_SECTIONS else 22)
	page_title.text = section
	for child: Node in page_body.get_children():
		page_body.remove_child(child)
		child.queue_free()
	match section:
		"МИР НУЛМЕРИСА":
			_paragraph("Нулмерис (NULMERYS) — мир игры ODRAVETH.")
			_paragraph("В мире известны четыре фракции и их герои — их страницы уже открыты в этой книге.")
			_sealed_note("Остальные записи о мире пока запечатаны.")
		"ФРАКЦИИ":
			for row: Array in FACTION_ROWS:
				_faction_entry(row[0], row[1], row[2], row[3])
			_faction_entry(Faction.Id.NEUTRAL, "Neutral", &"", "серебряно-каменный")
		"ГЕРОИ":
			for hero_id: StringName in [HeroCatalog.KEZHARYN, HeroCatalog.VHORAZEL, HeroCatalog.SYRRAVETH, HeroCatalog.TAZHYRION]:
				_hero_entry(hero_id)
		_:
			_sealed_page()


func _paragraph(text_value: String, font_size: int = 28, color: Color = VisualTokens.COLOR_INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	page_body.add_child(label)
	return label


func _sealed_note(text_value: String) -> void:
	_paragraph(text_value, 24, VisualTokens.COLOR_MUTED)


func _sealed_page() -> void:
	var seal := EmblemView.seal(Color(0.45, 0.38, 0.28, 0.7))
	seal.name = "SealedSeal"
	seal.custom_minimum_size = Vector2(180, 180)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page_body.add_child(seal)
	var label := _paragraph("СТРАНИЦЫ ЗАПЕЧАТАНЫ", 34, VisualTokens.COLOR_STEEL_700)
	label.name = "SealedLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := _paragraph("Записи этого раздела ещё не открыты.", 24, VisualTokens.COLOR_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _entry_row(faction: Faction.Id) -> VBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	page_body.add_child(row)
	var emblem := EmblemView.for_faction(faction, Color("f1eadb"))
	emblem.custom_minimum_size = Vector2(84, 84)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(emblem)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 2)
	row.add_child(text_stack)
	return text_stack


func _line(parent: Control, text_value: String, font_size: int, color: Color, display: bool = false) -> void:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display and _display_font != null:
		label.add_theme_font_override("font", _display_font)
	parent.add_child(label)


func _faction_entry(faction: Faction.Id, name_en: String, hero_id: StringName, accent: String) -> void:
	var stack := _entry_row(faction)
	var title := SetupUi.faction_name(faction) if faction != Faction.Id.NEUTRAL else "Нейтральные карты"
	_line(stack, "%s · %s" % [title.to_upper(), name_en], 32, NulmerisEmblems.faction_color(faction).darkened(0.3), true)
	if hero_id != &"":
		_line(stack, "Герой: %s" % HeroCatalog.HEROES[hero_id]["name_ru"], 24, VisualTokens.COLOR_STEEL_700)
	else:
		_line(stack, "Не фракция героя: карты, доступные любой колоде.", 24, VisualTokens.COLOR_STEEL_700)
	_line(stack, "Цвет: %s" % accent, 22, VisualTokens.COLOR_MUTED)


func _hero_entry(hero_id: StringName) -> void:
	var data: Dictionary = HeroCatalog.HEROES[hero_id]
	var stack := _entry_row(HeroCatalog.faction_of(hero_id))
	_line(stack, "%s · %s" % [String(data["name_ru"]).to_upper(), data["name_en"]], 32, VisualTokens.COLOR_STEEL_900, true)
	_line(stack, "Фракция: %s" % SetupUi.faction_name(HeroCatalog.faction_of(hero_id)), 24,
		HeroPresentation.faction_accent(hero_id).darkened(0.3))
	_line(stack, "Способность «%s» · %d энергии" % [data["power_ru"], HeroPresentation.power_cost(hero_id)], 24,
		VisualTokens.COLOR_STEEL_700)
	_line(stack, HeroPresentation.power_description(hero_id), 22, VisualTokens.COLOR_INK)
	var style := HeroPresentation.playstyle(hero_id)
	if not style.is_empty():
		_line(stack, "Стиль: %s" % style, 22, VisualTokens.COLOR_MUTED)


func handle_back_request() -> bool:
	_go_back()
	return true


func _go_back() -> void:
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.MAIN_MENU)
