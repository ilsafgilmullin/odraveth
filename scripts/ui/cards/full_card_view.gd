class_name FullCardView
extends Button
## Canonical reusable FULL CARD representation for Collection/Deck Builder/Mulligan/detail.
## Gameplay state is supplied by callers; this component never queries deck/match state.

signal card_activated(card_id: StringName)

const BASE_SIZE := Vector2(320, 448) # 5:7

var presentation: CardPresentation
var card_id: StringName = &""
var selected := false
var copy_count := 0

var frame_visual: CardFrameVisual
var cost_label: Label
var art_slot: CardArtSlot
var name_label: Label
var type_label: Label
var rarity_label: Label
var rarity_mark: RarityMark
var rules_label: Label
var stats_row: HBoxContainer
var attack_badge: PanelContainer
var armor_badge: PanelContainer
var health_badge: PanelContainer
var charges_badge: PanelContainer
var selected_marker: Label
var copy_count_badge: Label

var _built := false
var _pointer_down := false
var _focused := false


func _ready() -> void:
	_ensure_structure()
	if not pressed.is_connected(_emit_activation):
		pressed.connect(_emit_activation)
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)
	if not focus_entered.is_connected(_on_focus_entered):
		focus_entered.connect(_on_focus_entered)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)
	_refresh_frame_state()


func configure(card: CardDefinition, current_cost: int = -1) -> void:
	_ensure_structure()
	presentation = CardPresentation.from_definition(card, current_cost)
	if presentation == null:
		return
	card_id = presentation.id
	cost_label.text = str(presentation.current_cost)
	name_label.text = presentation.name_ru
	type_label.text = presentation.type_label.to_upper()
	rarity_label.text = presentation.rarity_label.to_upper()
	rarity_mark.configure(presentation.rarity)
	rules_label.text = presentation.rules_text_ru if not presentation.rules_text_ru.is_empty() else " "
	art_slot.configure(presentation)
	_rebuild_stats()
	frame_visual.configure(presentation.card_type, presentation.faction_accent)
	_refresh_frame_state()


func set_selected_state(value: bool) -> void:
	selected = value
	selected_marker.visible = value
	scale = Vector2(1.012, 1.012) if value else Vector2.ONE
	_refresh_frame_state()


func set_available(value: bool) -> void:
	disabled = not value
	_refresh_frame_state()


func set_copy_count(value: int) -> void:
	copy_count = maxi(0, value)
	copy_count_badge.visible = copy_count > 0
	copy_count_badge.text = "×%d" % copy_count


func _ensure_structure() -> void:
	if _built:
		return
	_built = true
	name = "FullCardView"
	custom_minimum_size = BASE_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_ALL
	toggle_mode = false
	clip_contents = false
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	resized.connect(_update_pivot)

	frame_visual = CardFrameVisual.new()
	frame_visual.name = "FrameVisual"
	frame_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame_visual)

	var margin := MarginContainer.new()
	margin.name = "CardContentMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 13)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "CardContent"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var art_wrap := MarginContainer.new()
	art_wrap.name = "ArtWrap"
	art_wrap.custom_minimum_size.y = 210
	art_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(art_wrap)
	art_slot = CardArtSlot.new()
	art_slot.name = "ArtSlot"
	art_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_wrap.add_child(art_slot)

	cost_label = Label.new()
	cost_label.name = "Cost"
	cost_label.position = Vector2(7, 7)
	cost_label.size = Vector2(58, 52)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 30)
	cost_label.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	cost_label.add_theme_stylebox_override("normal", _badge_box(VisualTokens.COLOR_STEEL_900, VisualTokens.COLOR_GOLD_500, 2))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cost_label)

	selected_marker = Label.new()
	selected_marker.name = "SelectedMarker"
	selected_marker.text = "✓ ВЫБРАНО"
	selected_marker.visible = false
	selected_marker.position = Vector2(184, 10)
	selected_marker.size = Vector2(120, 34)
	selected_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_marker.add_theme_font_size_override("font_size", 17)
	selected_marker.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_700)
	selected_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selected_marker)

	copy_count_badge = Label.new()
	copy_count_badge.name = "CopyCountBadge"
	copy_count_badge.visible = false
	copy_count_badge.position = Vector2(250, 400)
	copy_count_badge.size = Vector2(56, 34)
	copy_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy_count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	copy_count_badge.add_theme_font_size_override("font_size", 20)
	copy_count_badge.add_theme_stylebox_override("normal", _badge_box(VisualTokens.COLOR_STEEL_700, VisualTokens.COLOR_STONE_300, 1))
	copy_count_badge.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	copy_count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(copy_count_badge)

	name_label = Label.new()
	name_label.name = "CardName"
	name_label.custom_minimum_size.y = 52
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = false
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	var meta := HBoxContainer.new()
	meta.name = "MetaRow"
	meta.custom_minimum_size.y = 32
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(meta)
	type_label = Label.new()
	type_label.name = "Type"
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_label.add_theme_font_size_override("font_size", 18)
	type_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(type_label)
	rarity_mark = RarityMark.new()
	rarity_mark.name = "RarityMark"
	meta.add_child(rarity_mark)
	rarity_label = Label.new()
	rarity_label.name = "Rarity"
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rarity_label.add_theme_font_size_override("font_size", 17)
	rarity_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(rarity_label)

	rules_label = Label.new()
	rules_label.name = "RulesText"
	rules_label.custom_minimum_size.y = 70
	rules_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.clip_text = false
	rules_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rules_label.add_theme_font_size_override("font_size", 19)
	rules_label.add_theme_color_override("font_color", VisualTokens.COLOR_INK)
	rules_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(rules_label)

	stats_row = HBoxContainer.new()
	stats_row.name = "StatsRow"
	stats_row.custom_minimum_size.y = 38
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 8)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(stats_row)


func _rebuild_stats() -> void:
	for child: Node in stats_row.get_children():
		child.queue_free()
	attack_badge = null
	armor_badge = null
	health_badge = null
	charges_badge = null
	if presentation == null:
		stats_row.visible = false
		return
	stats_row.visible = presentation.is_creature() or presentation.shows_charges()
	if presentation.is_creature():
		attack_badge = _stat_badge("АТК", presentation.attack, Color("76453d"))
		stats_row.add_child(attack_badge)
		if presentation.shows_armor():
			armor_badge = _stat_badge("БРОНЯ", presentation.armor, VisualTokens.COLOR_STEEL_500)
			stats_row.add_child(armor_badge)
		health_badge = _stat_badge("ЗДР", presentation.health, Color("65764e"))
		stats_row.add_child(health_badge)
	elif presentation.shows_charges():
		charges_badge = _stat_badge("ЗАРЯДЫ", presentation.charges, presentation.faction_accent)
		charges_badge.custom_minimum_size.x = 152
		stats_row.add_child(charges_badge)


func _stat_badge(label_text: String, value: int, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(82, 38)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _badge_box(Color("e5ded2"), accent, 2))
	var label := Label.new()
	label.text = "%s %d" % [label_text, value]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func _badge_box(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(VisualTokens.RADIUS_SMALL)
	return box


func _emit_activation() -> void:
	if presentation != null:
		card_activated.emit(card_id)


func _on_button_down() -> void:
	_pointer_down = true
	_refresh_frame_state()


func _on_button_up() -> void:
	_pointer_down = false
	_refresh_frame_state()


func _on_focus_entered() -> void:
	_focused = true
	_refresh_frame_state()


func _on_focus_exited() -> void:
	_focused = false
	_refresh_frame_state()


func _refresh_frame_state() -> void:
	if frame_visual != null:
		frame_visual.set_visual_state(selected, _pointer_down, _focused, disabled)


func _update_pivot() -> void:
	pivot_offset = size * 0.5
