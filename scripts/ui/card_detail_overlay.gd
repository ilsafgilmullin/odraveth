class_name CardDetailOverlay
extends ColorRect
## Reusable Stage 7D card detail modal shared by setup and battle callers.
## Backward-compatible show_card() and detail_text are preserved.

var detail_text: RichTextLabel
var full_card: FullCardView
var close_button: Button
var ru_name_label: Label
var en_name_label: Label
var identity_label: Label
var keywords_row: HFlowContainer
var current_card_id: StringName = &""

var _modal: PanelContainer
var _body: HBoxContainer


func _ready() -> void:
	name = "CardDetailOverlay"
	color = Color(0.02, 0.025, 0.028, 0.76)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)

	_modal = UiKit.make_panel(true)
	_modal.name = "CardDetailPanel"
	_modal.custom_minimum_size = Vector2(1160, 680)
	center.add_child(_modal)

	var root := VBoxContainer.new()
	root.name = "DetailRoot"
	root.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	_modal.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 64
	root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)
	ru_name_label = Label.new()
	ru_name_label.name = "DetailRuName"
	ru_name_label.add_theme_font_size_override("font_size", 36)
	ru_name_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	title_stack.add_child(ru_name_label)
	en_name_label = Label.new()
	en_name_label.name = "DetailEnName"
	en_name_label.add_theme_font_size_override("font_size", 22)
	en_name_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	title_stack.add_child(en_name_label)

	close_button = UiKit.make_button("ЗАКРЫТЬ", UiKit.ButtonRole.SECONDARY)
	close_button.name = "CardDetailCloseButton"
	close_button.custom_minimum_size = Vector2(190, 64)
	close_button.pressed.connect(close_detail)
	header.add_child(close_button)

	_body = HBoxContainer.new()
	_body.name = "DetailBody"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", VisualTokens.SPACE_5)
	root.add_child(_body)

	var card_center := CenterContainer.new()
	card_center.name = "FullCardColumn"
	card_center.custom_minimum_size.x = 390
	card_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(card_center)
	full_card = FullCardView.new()
	full_card.name = "DetailFullCard"
	full_card.custom_minimum_size = Vector2(350, 490)
	card_center.add_child(full_card)

	var info_scroll := ScrollContainer.new()
	info_scroll.name = "DetailInfoScroll"
	info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.prepare_scroll(info_scroll)
	_body.add_child(info_scroll)

	var info := VBoxContainer.new()
	info.name = "DetailInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	info_scroll.add_child(info)

	identity_label = Label.new()
	identity_label.name = "DetailIdentity"
	identity_label.add_theme_font_size_override("font_size", 25)
	identity_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(identity_label)

	detail_text = RichTextLabel.new()
	detail_text.name = "CardDetailText"
	detail_text.fit_content = true
	detail_text.scroll_active = false
	detail_text.custom_minimum_size.y = 230
	detail_text.add_theme_font_size_override("normal_font_size", 28)
	detail_text.add_theme_color_override("default_color", VisualTokens.COLOR_INK)
	info.add_child(detail_text)

	var keyword_title := Label.new()
	keyword_title.text = "КЛЮЧЕВЫЕ СЛОВА"
	keyword_title.add_theme_font_size_override("font_size", 21)
	keyword_title.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_700)
	info.add_child(keyword_title)

	keywords_row = HFlowContainer.new()
	keywords_row.name = "KeywordRow"
	keywords_row.add_theme_constant_override("h_separation", VisualTokens.SPACE_2)
	keywords_row.add_theme_constant_override("v_separation", VisualTokens.SPACE_2)
	info.add_child(keywords_row)


func open_card(source: Variant, current_cost: int = -1) -> bool:
	var card: CardDefinition = null
	if source is CardDefinition:
		card = source as CardDefinition
	elif typeof(source) == TYPE_STRING or typeof(source) == TYPE_STRING_NAME:
		card = CardDatabase.get_card(StringName(str(source)))
	if card == null:
		return false
	_populate(card, current_cost)
	visible = true
	return true


func show_card(card: CardDefinition, current_cost: int = -1) -> void:
	open_card(card, current_cost)


func close_detail() -> void:
	visible = false


func _populate(card: CardDefinition, current_cost: int) -> void:
	var presentation := CardPresentation.from_definition(card, current_cost)
	current_card_id = presentation.id
	full_card.configure(card, current_cost)
	full_card.set_selected_state(false)
	ru_name_label.text = presentation.name_ru
	en_name_label.text = presentation.name_en
	identity_label.text = "%s · %s · %s · СТОИМОСТЬ %d" % [
		presentation.faction_label,
		presentation.type_label,
		presentation.rarity_label,
		presentation.current_cost,
	]

	var lines := PackedStringArray()
	if presentation.is_creature():
		lines.append("Атака: %d    Здоровье: %d" % [presentation.attack, presentation.health])
		if presentation.shows_armor():
			lines.append("Броня: %d" % presentation.armor)
	elif presentation.shows_charges():
		lines.append("Заряды: %d" % presentation.charges)
	if not presentation.rules_text_ru.is_empty():
		lines.append("")
		lines.append(presentation.rules_text_ru)
	detail_text.text = "\n".join(lines)

	for child: Node in keywords_row.get_children():
		keywords_row.remove_child(child)
		child.queue_free()
	if presentation.keywords.is_empty():
		var none := Label.new()
		none.name = "NoKeywords"
		none.text = "Нет отдельных ключевых слов"
		none.add_theme_font_size_override("font_size", 22)
		none.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
		keywords_row.add_child(none)
	else:
		for keyword: String in presentation.keywords:
			var marker := UiKit.make_status_marker(keyword)
			marker.name = "Keyword_%s" % keyword.validate_node_name()
			keywords_row.add_child(marker)


func _apply_responsive_layout() -> void:
	if _modal == null:
		return
	var viewport_size := get_viewport_rect().size
	var width_class := ResponsiveLayout.width_class(viewport_size.x)
	var modal_width := viewport_size.x * 0.74
	var modal_height := viewport_size.y * 0.76
	var card_width := 350.0
	match width_class:
		ResponsiveLayout.WidthClass.NARROW:
			modal_width = viewport_size.x * 0.82
			modal_height = viewport_size.y * 0.80
			card_width = 320.0
		ResponsiveLayout.WidthClass.WIDE:
			modal_width = viewport_size.x * 0.68
			modal_height = viewport_size.y * 0.76
			card_width = 370.0
	_modal.custom_minimum_size = Vector2(modal_width, modal_height)
	if full_card != null:
		full_card.custom_minimum_size = Vector2(card_width, card_width * 1.4)
