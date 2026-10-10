class_name FullCardView
extends Button
## Canonical reusable FULL CARD representation for Collection/Deck Builder/Mulligan/detail.
## Gameplay state is supplied by callers; this component never queries deck/match state.
## Content is fitted to the frame: long rules borrow height from the artwork window and
## step down to a readable floor, so text and stats never leave the card silhouette.

signal card_activated(card_id: StringName)

const BASE_SIZE := Vector2(320, 448) # 5:7
const CONTENT_MARGIN := 13.0
const STACK_GAP := 4.0
const NAME_SIZES: Array[int] = [26, 24, 22]
const RULES_MAX := 19
const RULES_MIN := 16
const ART_MIN := 92.0
const ART_MAX_RATIO := 0.50
const META_HEIGHT := 28.0
const STATS_HEIGHT := 40.0

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

var _art_wrap: MarginContainer
var _meta_row: HBoxContainer
var _built := false
var _pointer_down := false
var _focused := false
var _fit_key := ""


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
	_fit_content()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		if _built:
			_fit_content()


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
	_fit_key = ""
	_fit_content()


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


## True when every visible content line and stat plate is inside the card frame.
func content_fits_frame() -> bool:
	var frame := Rect2(Vector2.ZERO, size).grow(1.0)
	for control: Control in [_art_wrap, name_label, rules_label, stats_row]:
		if control == null or not control.visible:
			continue
		var local := Rect2(control.get_global_rect().position - get_global_rect().position, control.size)
		if not frame.encloses(local):
			return false
	return rules_label.get_visible_line_count() == rules_label.get_line_count()


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
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, int(CONTENT_MARGIN))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "CardContent"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", int(STACK_GAP))
	margin.add_child(stack)

	_art_wrap = MarginContainer.new()
	_art_wrap.name = "ArtWrap"
	_art_wrap.custom_minimum_size.y = 200
	_art_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_art_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_art_wrap)
	art_slot = CardArtSlot.new()
	art_slot.name = "ArtSlot"
	art_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_wrap.add_child(art_slot)

	cost_label = Label.new()
	cost_label.name = "Cost"
	cost_label.position = Vector2(7, 7)
	cost_label.size = Vector2(58, 52)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 32)
	cost_label.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	cost_label.add_theme_stylebox_override("normal", _badge_box(VisualTokens.COLOR_STEEL_900, VisualTokens.COLOR_GOLD_500, 2))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_display_font(cost_label)
	add_child(cost_label)

	selected_marker = Label.new()
	selected_marker.name = "SelectedMarker"
	selected_marker.text = "✓ ВЫБРАНО"
	selected_marker.visible = false
	selected_marker.position = Vector2(176, 12)
	selected_marker.size = Vector2(130, 34)
	selected_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_marker.add_theme_font_size_override("font_size", 17)
	selected_marker.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	selected_marker.add_theme_stylebox_override("normal", _badge_box(VisualTokens.COLOR_GOLD_700, VisualTokens.COLOR_GOLD_300, 1))
	selected_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selected_marker)

	copy_count_badge = Label.new()
	copy_count_badge.name = "CopyCountBadge"
	copy_count_badge.visible = false
	copy_count_badge.size = Vector2(60, 40)
	copy_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy_count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	copy_count_badge.add_theme_font_size_override("font_size", 24)
	copy_count_badge.add_theme_stylebox_override("normal", _badge_box(VisualTokens.COLOR_STEEL_700, VisualTokens.COLOR_GOLD_300, 2))
	copy_count_badge.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	copy_count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_display_font(copy_count_badge)
	add_child(copy_count_badge)

	name_label = Label.new()
	name_label.name = "CardName"
	name_label.custom_minimum_size.y = 40
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = false
	name_label.add_theme_font_size_override("font_size", NAME_SIZES[0])
	name_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	name_label.add_theme_constant_override("line_spacing", 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_display_font(name_label)
	stack.add_child(name_label)

	var meta := HBoxContainer.new()
	meta.name = "MetaRow"
	meta.custom_minimum_size.y = META_HEIGHT
	meta.add_theme_constant_override("separation", 6)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(meta)
	_meta_row = meta
	type_label = Label.new()
	type_label.name = "Type"
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 17)
	type_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(type_label)
	rarity_mark = RarityMark.new()
	rarity_mark.name = "RarityMark"
	meta.add_child(rarity_mark)
	rarity_label = Label.new()
	rarity_label.name = "Rarity"
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 16)
	rarity_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(rarity_label)

	rules_label = Label.new()
	rules_label.name = "RulesText"
	rules_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.clip_text = false
	rules_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rules_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	rules_label.add_theme_font_size_override("font_size", RULES_MAX)
	rules_label.add_theme_color_override("font_color", VisualTokens.COLOR_INK)
	rules_label.add_theme_constant_override("line_spacing", 1)
	rules_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(rules_label)

	stats_row = HBoxContainer.new()
	stats_row.name = "StatsRow"
	stats_row.custom_minimum_size.y = STATS_HEIGHT
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 8)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(stats_row)


## Allocates height between artwork and rules from real font metrics.
func _fit_content() -> void:
	if presentation == null or rules_label == null:
		return
	var card_size := Vector2(maxf(size.x, custom_minimum_size.x), maxf(size.y, custom_minimum_size.y))
	var name_font := name_label.get_theme_font("font")
	var rules_font := rules_label.get_theme_font("font")
	var key := "%s|%d|%d|%d|%d" % [card_id, int(card_size.x), int(card_size.y),
		name_font.get_instance_id(), rules_font.get_instance_id()]
	if key == _fit_key:
		return
	_fit_key = key
	var factor := clampf(card_size.x / BASE_SIZE.x, 0.85, 1.4)
	var inner := card_size - Vector2(CONTENT_MARGIN, CONTENT_MARGIN) * 2.0

	var name_size := int(round(NAME_SIZES[-1] * factor))
	var name_lines := 2
	for candidate: int in NAME_SIZES:
		var scaled := int(round(candidate * factor))
		if name_font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled).x <= inner.x - 8.0:
			name_size = scaled
			name_lines = 1
			break
	name_label.add_theme_font_size_override("font_size", name_size)
	var name_height := ceilf(name_font.get_height(name_size) * name_lines) + 2.0
	name_label.custom_minimum_size.y = name_height

	var stats_height := maxf(STATS_HEIGHT, stats_row.get_combined_minimum_size().y) if stats_row.visible else 0.0
	var meta_height := maxf(META_HEIGHT, _meta_row.get_combined_minimum_size().y)
	var gaps := STACK_GAP * (4.0 if stats_row.visible else 3.0)
	var fixed := name_height + meta_height + stats_height + gaps
	var art_max := floorf(inner.y * ART_MAX_RATIO)
	var art_min := floorf(ART_MIN * factor)
	var has_rules := not presentation.rules_text_ru.is_empty()
	var chosen := int(round(RULES_MIN * factor))
	var rules_need := 0.0
	var fitted := false
	for candidate in range(int(round(RULES_MAX * factor)), int(round(RULES_MIN * factor)) - 1, -1):
		rules_need = _rules_height(rules_font, candidate, inner.x) if has_rules else 0.0
		if fixed + art_min + rules_need <= inner.y:
			chosen = candidate
			fitted = true
			break
	if not fitted:
		rules_need = _rules_height(rules_font, chosen, inner.x)
	var art_height := clampf(inner.y - fixed - rules_need, art_min, art_max)
	if not has_rules:
		art_height = clampf(inner.y - fixed - 40.0 * factor, art_min, art_max)
	_art_wrap.custom_minimum_size.y = art_height
	rules_label.add_theme_font_size_override("font_size", chosen)
	var rules_room := inner.y - fixed - art_height
	var line_height := rules_font.get_height(chosen) + 1.0
	rules_label.max_lines_visible = maxi(1, int(floor(rules_room / line_height))) if not fitted else -1
	rules_label.custom_minimum_size.y = 0.0
	copy_count_badge.position = Vector2(card_size.x - copy_count_badge.size.x - 14.0, 58.0)
	selected_marker.position = Vector2(card_size.x - selected_marker.size.x - 14.0, 12.0)


## Height the Label needs to show every line: it fits floor((h + spacing) / (font_h + spacing)) lines.
func _rules_height(font: Font, font_size: int, width: float) -> float:
	var paragraph := TextParagraph.new()
	paragraph.add_string(rules_label.text, font, font_size)
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var spacing := float(rules_label.get_theme_constant("line_spacing"))
	var lines := float(maxi(1, paragraph.get_line_count()))
	return ceilf(lines * (font.get_height(font_size) + spacing)) + 2.0


func _rebuild_stats() -> void:
	for child: Node in stats_row.get_children():
		stats_row.remove_child(child)
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
		attack_badge = _stat_badge("АТК", presentation.attack, Color("8a4a3e"))
		attack_badge.name = "AttackBadge"
		stats_row.add_child(attack_badge)
		if presentation.shows_armor():
			armor_badge = _stat_badge("БРОНЯ", presentation.armor, VisualTokens.COLOR_STEEL_500)
			armor_badge.name = "ArmorBadge"
			stats_row.add_child(armor_badge)
		health_badge = _stat_badge("ЗДР", presentation.health, Color("5f7a4a"))
		health_badge.name = "HealthBadge"
		stats_row.add_child(health_badge)
	elif presentation.shows_charges():
		charges_badge = _stat_badge("ЗАРЯДЫ", presentation.charges, presentation.faction_accent)
		charges_badge.name = "ChargesBadge"
		stats_row.add_child(charges_badge)


func _stat_badge(label_text: String, value: int, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(76, STATS_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := _badge_box(Color("f1ece2"), accent, 2)
	box.content_margin_left = 9
	box.content_margin_right = 9
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var caption := Label.new()
	caption.text = label_text
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", accent.darkened(0.15))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = str(value)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_display_font(value_label)
	row.add_child(value_label)
	return panel


func _badge_box(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(VisualTokens.RADIUS_SMALL)
	return box


func _apply_display_font(label: Label) -> void:
	var display_font := load(UiKit.DISPLAY_FONT_PATH) as Font
	if display_font != null:
		label.add_theme_font_override("font", display_font)


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
