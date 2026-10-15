class_name BattleCardView
extends Button
## Compact battle hand card built from CardPresentation: current cost, art, name and
## relevant stats only (no rules text; full text lives in Card Detail). Playability
## (`disabled`) is supplied by BattleScene from engine legal commands.

## Short tap on a playable card (selection / confirmation is decided by BattleScene).
signal tapped(instance_id: int)
## Hold, right click, or a tap on an unavailable card: open read-only Card Detail.
signal detail_requested(instance_id: int)

const BASE_SIZE := Vector2(190, 266)
const HOLD_SECONDS := 0.45

var instance_id := 0
var card_id: StringName = &""
var presentation: CardPresentation
var current_cost := 0
var selected := false
var is_echo := false
var visual: Control
var art: CardArtSlot

var _frame: CardFrameVisual
var _front: Control
var _name_label: Label
var exposed_width := BASE_SIZE.x
var _display_font: Font
var _hold_time := -1.0
var _hold_fired := false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	visual = Control.new()
	visual.name = "Visual"
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	_frame = CardFrameVisual.new()
	_frame.name = "Frame"
	visual.add_child(_frame)
	art = CardArtSlot.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(art)
	_front = Control.new()
	_front.name = "Front"
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	visual.add_child(_front)
	_name_label = Label.new()
	_name_label.name = "CardName"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_override("font", _display_font)
	_name_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	_name_label.add_theme_constant_override("line_spacing", -2)
	_name_label.minimum_size_changed.connect(func() -> void: _name_label.size.y = 0.0)
	visual.add_child(_name_label)
	resized.connect(_layout)
	pressed.connect(func() -> void:
		if _hold_fired:
			_hold_fired = false
		else:
			tapped.emit(instance_id))
	set_process(false)


func configure(card: Dictionary, playable: bool, is_selected: bool) -> void:
	instance_id = int(card.get("instance_id", 0))
	name = "HandCard_%d" % instance_id
	var new_id := StringName(str(card.get("card_id", "")))
	current_cost = int(card.get("current_cost", card.get("definition", {}).get("cost", 0)))
	is_echo = bool(card.get("is_echo", false))
	if new_id != card_id or presentation == null:
		card_id = new_id
		var definition := CardDatabase.get_card(card_id)
		presentation = CardPresentation.from_definition(definition, current_cost)
		if presentation != null:
			art.configure(presentation)
			_frame.configure(presentation.card_type, presentation.faction_accent, presentation.rarity)
	elif presentation != null:
		presentation.current_cost = current_cost
	if presentation != null:
		_name_label.text = presentation.name_ru
		tooltip_text = "%s · стоимость %d\n%s" % [presentation.name_ru, current_cost, presentation.rules_text_ru]
		if is_echo:
			tooltip_text += "\nЭхо исчезнет в конце хода №%d." % int(card.get("echo_expires_turn", -1))
	disabled = not playable
	selected = is_selected
	_frame.set_visual_state(selected, false, false, disabled)
	_layout()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
			detail_requested.emit(instance_id)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_hold_fired = false
			elif disabled and _hold_time >= 0.0 and not _hold_fired:
				detail_requested.emit(instance_id)
			_hold_time = 0.0 if mouse.pressed else -1.0
			set_process(mouse.pressed)


func _process(delta: float) -> void:
	if _hold_time < 0.0:
		set_process(false)
		return
	_hold_time += delta
	if _hold_time >= HOLD_SECONDS:
		_hold_time = -1.0
		_hold_fired = true
		set_process(false)
		detail_requested.emit(instance_id)


func suppress_release_tap() -> void:
	_hold_fired = true
	_hold_time = -1.0
	set_process(false)


func set_exposed_width(value: float) -> void:
	exposed_width = clampf(value, 64.0, size.x)
	_layout()


func _layout() -> void:
	visual.size = size
	visual.pivot_offset = Vector2(size.x * 0.5, size.y)
	pivot_offset = Vector2(size.x * 0.5, size.y)
	_frame.size = size
	_front.size = size
	var inset := size.x * 0.07
	art.position = Vector2(inset, size.y * 0.06)
	art.size = Vector2(size.x - inset * 2.0, size.y * 0.52)
	# Keep the full name inside the uncovered strip of an overlapping hand.
	# A selected card is on top and receives its entire width from BattleScene.
	var narrow := exposed_width < size.x * 0.8
	if narrow:
		art.size.y = size.y * 0.44
	_name_label.position = Vector2(6.0, size.y * (0.52 if narrow else 0.585))
	_name_label.size = Vector2(minf(exposed_width, size.x) - 12.0, size.y * (0.33 if narrow else 0.29))
	var name_size := int(size.x * 0.105)
	if exposed_width < size.x * 0.8:
		name_size = 16
		for word: String in _name_label.text.split(" "):
			while name_size > 14 and _display_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > _name_label.size.x:
				name_size -= 1
	while name_size > 14 and _display_font.get_multiline_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, _name_label.size.x, name_size).y > _name_label.size.y:
		name_size -= 1
	_name_label.add_theme_font_size_override("font_size", name_size)
	_frame.queue_redraw()
	_front.queue_redraw()


func _draw_front() -> void:
	if presentation == null or _display_font == null:
		return
	var s := size
	var glow_color := Color(VisualTokens.COLOR_MAGIC_300, 0.9)
	if not disabled and not selected:
		var outline := PackedVector2Array([Vector2(3, 3), Vector2(s.x - 3, 3), Vector2(s.x - 3, s.y - 3), Vector2(3, s.y - 3), Vector2(3, 3)])
		_front.draw_polyline(outline, glow_color, 3.0, true)
	# Cost plate.
	var plate := Rect2(Vector2(4, 4), Vector2(s.x * 0.27, s.x * 0.27))
	_front.draw_rect(plate, VisualTokens.COLOR_STEEL_900)
	var increased := current_cost > presentation.cost
	var reduced := current_cost < presentation.cost
	_front.draw_rect(plate, VisualTokens.COLOR_GOLD_500 if not increased else Color("d07a55"), false, 2.0)
	var cost_text := str(current_cost)
	var cost_size := int(s.x * 0.20)
	var cost_w := _display_font.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cost_size).x
	var cost_color := VisualTokens.COLOR_STONE_050
	if increased:
		cost_color = Color("ffb08f")
	elif reduced:
		cost_color = VisualTokens.COLOR_MAGIC_300
	_front.draw_string(_display_font, plate.get_center() + Vector2(-cost_w * 0.5, cost_size * 0.36), cost_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, cost_size, cost_color)
	if increased:
		_front.draw_string(_display_font, plate.end + Vector2(2, -4), "▲", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.x * 0.08), Color("d07a55"))
	# Stats line.
	var stats_y := s.y - s.y * 0.075
	var small := int(s.x * 0.085)
	if is_echo:
		var echo_rect := Rect2(s.x * 0.25, s.y * 0.79, s.x * 0.5, s.y * 0.08)
		_front.draw_rect(echo_rect, VisualTokens.COLOR_STEEL_900)
		_front.draw_string(_display_font, echo_rect.position + Vector2(0, echo_rect.size.y * 0.80), "ЭХО",
			HORIZONTAL_ALIGNMENT_CENTER, echo_rect.size.x, small, VisualTokens.COLOR_MAGIC_300)
	if presentation.is_creature():
		_stat(Vector2(s.x * 0.22, stats_y), str(presentation.attack), Color("7c3f35"), true)
		_stat(Vector2(s.x * 0.78, stats_y), str(presentation.health), Color("4f6a3f"), false)
		if presentation.shows_armor():
			_stat(Vector2(s.x * 0.50, stats_y), str(presentation.armor), VisualTokens.COLOR_STEEL_700, false, true)
	elif presentation.shows_charges():
		_front.draw_string(_display_font, Vector2(0, stats_y + small * 0.4), "ЗАРЯДЫ %d" % presentation.charges,
			HORIZONTAL_ALIGNMENT_CENTER, s.x, small, presentation.faction_accent.darkened(0.2))
	else:
		_front.draw_string(_display_font, Vector2(0, stats_y + small * 0.4), presentation.type_label.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, s.x, small, VisualTokens.COLOR_MUTED)


func _stat(center: Vector2, value: String, color: Color, angular: bool, shield: bool = false) -> void:
	var r := size.x * 0.115
	if angular:
		_front.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r),
			center + Vector2(-r, 0)]), color)
	elif shield:
		_front.draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.8, -r * 0.8), center + Vector2(r * 0.8, -r * 0.8),
			center + Vector2(r * 0.75, r * 0.2), center + Vector2(0, r), center + Vector2(-r * 0.75, r * 0.2)]), color)
	else:
		_front.draw_circle(center, r * 0.95, color)
	var font_size := int(r * 1.15)
	var w := _display_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_front.draw_string(_display_font, center + Vector2(-w * 0.5, font_size * 0.36), value, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, VisualTokens.COLOR_STONE_050)
