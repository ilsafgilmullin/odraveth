class_name CardDetailOverlay
extends ColorRect
## Read-only card description shared by Collection, Deck Builder and Battle.

const KEYWORD_RU := {
	"ONSLAUGHT": "Натиск", "PROVOKE": "Провокация",
	"DEFERRAL": "Отложение", "FRENZY": "Неистовство",
}

var detail_text: RichTextLabel


func _ready() -> void:
	name = "CardDetailOverlay"
	color = Color(0, 0, 0, 0.88)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	visible = false
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel.offset_left = 96
	panel.offset_top = 72
	panel.offset_right = -96
	panel.offset_bottom = -72
	add_child(panel)
	detail_text = RichTextLabel.new()
	detail_text.name = "CardDetailText"
	detail_text.size_flags_vertical = SIZE_EXPAND_FILL
	detail_text.add_theme_font_size_override("normal_font_size", 34)
	panel.add_child(detail_text)
	var close := Button.new()
	close.name = "CardDetailCloseButton"
	close.text = "Закрыть"
	close.custom_minimum_size.y = 72
	close.pressed.connect(func() -> void: visible = false)
	panel.add_child(close)


func show_card(card: CardDefinition, current_cost: int = -1) -> void:
	if card == null:
		return
	var lines := PackedStringArray([
		card.name_ru, card.name_en,
		"Стоимость: %d" % (current_cost if current_cost >= 0 else card.cost),
		"Фракция: %s" % SetupUi.faction_name(card.faction),
		"Редкость: %s" % SetupUi.RARITY_NAMES[card.rarity],
		"Тип: %s" % SetupUi.TYPE_NAMES[card.card_type],
	])
	if card.card_type == CardEnums.Type.CREATURE:
		lines.append("Атака: %d  Здоровье: %d  Броня: %d" % [card.attack, card.health, card.armor])
	elif card.card_type == CardEnums.Type.ARTIFACT:
		lines.append("Заряды: %d" % card.charges)
	lines.append(card.rules_text_ru)
	var keywords := PackedStringArray()
	for effect: CardEffectSpec in card.effects:
		var keyword := String(effect.keyword)
		if not keyword.is_empty() and keyword not in keywords:
			keywords.append(KEYWORD_RU.get(keyword, keyword))
	lines.append("Ключевые слова: %s" % ", ".join(keywords))
	detail_text.text = "\n".join(lines)
	visible = true
