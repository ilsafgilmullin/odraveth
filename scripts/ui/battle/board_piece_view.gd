class_name BoardPieceView
extends Button
## Battle board piece for one creature. Shows identity art, attack, health, armor and
## important statuses only (no rules text). All values come from the sanitized
## observation; readiness/targeting flags are supplied by BattleScene from legal
## commands. The `visual` child carries every drawn layer so presentation tweens never
## fight the board container layout.

signal tapped(instance_id: int)
## Hold or right click: read-only Card Detail of the creature's card.
signal detail_requested(instance_id: int)

enum TargetState { NONE, LEGAL, DIMMED, SELECTED }

const BASE_SIZE := Vector2(150, 188)
const HOLD_SECONDS := 0.45
const KEYWORD_TAGS := {"PROVOKE": "ПРОВОКАЦИЯ", "ONSLAUGHT": "НАТИСК", "DEFERRAL": "ОТЛОЖЕНИЕ", "FRENZY": "НЕИСТОВСТВО"}

var instance_id := 0
var card_id: StringName = &""
var data: Dictionary = {}
var can_attack := false
var target_state: TargetState = TargetState.NONE
var visual: Control
var art: CardArtSlot

var _back: Control
var _front: Control
var _faction: Faction.Id = Faction.Id.NEUTRAL
var _display_font: Font
var _hold_time := -1.0
var _hold_fired := false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = BASE_SIZE
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	visual = Control.new()
	visual.name = "Visual"
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	_back = _layer("Back", _draw_back)
	art = CardArtSlot.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(art)
	_front = _layer("Front", _draw_front)
	resized.connect(_layout)
	pressed.connect(func() -> void:
		if _hold_fired:
			_hold_fired = false
		else:
			tapped.emit(instance_id))
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
			detail_requested.emit(instance_id)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_hold_fired = false
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


func _layer(node_name: String, painter: Callable) -> Control:
	var layer := Control.new()
	layer.name = node_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(painter.bind(layer))
	visual.add_child(layer)
	return layer


func configure(creature: Dictionary, ready_to_attack: bool, state: TargetState) -> void:
	var new_card := StringName(str(creature.get("card_id", "")))
	instance_id = int(creature.get("instance_id", 0))
	data = creature
	can_attack = ready_to_attack
	target_state = state
	if new_card != card_id:
		card_id = new_card
		var definition := CardDatabase.get_card(card_id)
		if definition != null:
			_faction = definition.faction
			art.configure(CardPresentation.from_definition(definition))
	name = "Piece_%d" % instance_id
	modulate = Color(1, 1, 1, 0.55) if state == TargetState.DIMMED else Color.WHITE
	_layout()
	_back.queue_redraw()
	_front.queue_redraw()


func is_legal_target() -> bool:
	return target_state == TargetState.LEGAL


func _layout() -> void:
	visual.size = size
	visual.pivot_offset = size * 0.5
	pivot_offset = size * 0.5
	_back.size = size
	_front.size = size
	var inset := size.x * 0.08
	art.position = Vector2(inset, size.y * 0.07)
	art.size = Vector2(size.x - inset * 2.0, size.y * 0.58)
	_back.queue_redraw()
	_front.queue_redraw()


func _shape(rect: Rect2) -> PackedVector2Array:
	var radius := rect.size.x * 0.5
	var spring := rect.position.y + radius * 0.55
	var points := PackedVector2Array()
	points.append(Vector2(rect.position.x, rect.end.y - rect.size.x * 0.06))
	for i in 17:
		var angle := PI + PI * float(i) / 16.0
		points.append(Vector2(rect.get_center().x + cos(angle) * radius, spring + sin(angle) * radius * 0.55))
	points.append(Vector2(rect.end.x, rect.end.y - rect.size.x * 0.06))
	points.append(Vector2(rect.end.x - rect.size.x * 0.06, rect.end.y))
	points.append(Vector2(rect.position.x + rect.size.x * 0.06, rect.end.y))
	return points


func _keywords() -> PackedStringArray:
	var result := PackedStringArray()
	for keyword: Variant in data.get("keywords", []):
		result.append(String(keyword))
	if bool(data.get("deferral_pending", false)) and not result.has("DEFERRAL"):
		result.append("DEFERRAL")
	return result


func _draw_back(layer: Control) -> void:
	var s := layer.size
	if s.x < 10.0:
		return
	var rect := Rect2(Vector2(2, 2), s - Vector2(4, 4))
	var points := _shape(rect)
	var accent := NulmerisEmblems.faction_color(_faction)
	if target_state == TargetState.LEGAL:
		layer.draw_colored_polygon(_shape(rect.grow(6.0)), Color(VisualTokens.COLOR_GOLD_300, 0.55))
	elif can_attack:
		layer.draw_colored_polygon(_shape(rect.grow(5.0)), Color(VisualTokens.COLOR_MAGIC_300, 0.50))
	layer.draw_colored_polygon(points, Color("e7dfd1"))
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	var provoke := _keywords().has("PROVOKE")
	var border_color := VisualTokens.COLOR_GOLD_500 if target_state == TargetState.SELECTED else accent
	layer.draw_polyline(closed, border_color, 6.0 if provoke else 3.0, true)
	if provoke:
		layer.draw_polyline(closed, Color(VisualTokens.COLOR_STEEL_900, 0.55), 2.0, true)


func _draw_front(layer: Control) -> void:
	var s := layer.size
	if s.x < 10.0 or _display_font == null:
		return
	var definition: Dictionary = data.get("definition", {})
	var name_y := s.y * 0.66
	var title := ""
	var card := CardDatabase.get_card(card_id)
	if card != null:
		title = card.name_ru
	layer.draw_rect(Rect2(s.x * 0.08, name_y, s.x * 0.84, s.y * 0.11), Color(VisualTokens.COLOR_STEEL_900, 0.78))
	var fitted := fit_text(_display_font, title, s.x * 0.80, int(s.y * 0.072), int(s.y * 0.056))
	layer.draw_string(_display_font, Vector2(s.x * 0.10, name_y + s.y * 0.082), fitted[0], HORIZONTAL_ALIGNMENT_CENTER,
		s.x * 0.80, int(fitted[1]), VisualTokens.COLOR_STONE_050)

	var tags := _keywords()
	var tag_y := s.y * 0.09
	for keyword: String in tags:
		if not KEYWORD_TAGS.has(keyword):
			continue
		var text_value: String = KEYWORD_TAGS[keyword]
		var font_size := int(s.y * 0.058)
		var width := _display_font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0
		var tag := Rect2(s.x * 0.5 - width * 0.5, tag_y, width, s.y * 0.085)
		layer.draw_rect(tag, Color(VisualTokens.COLOR_STEEL_900, 0.82))
		layer.draw_rect(tag, Color(VisualTokens.COLOR_GOLD_300, 0.85), false, 1.0)
		layer.draw_string(_display_font, tag.position + Vector2(6, tag.size.y * 0.78), text_value, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size, VisualTokens.COLOR_STONE_050)
		tag_y += s.y * 0.095

	var attack := int(data.get("attack", 0))
	var health := int(data.get("health", 0))
	var max_health := int(data.get("max_health", health))
	var armor := int(data.get("armor", 0))
	var base_attack := int(definition.get("attack", attack))
	var plate := s.x * 0.30
	var bottom := s.y - plate * 0.5 - 2.0
	# Attack: angular diamond plate.
	var a_center := Vector2(plate * 0.55, bottom)
	layer.draw_colored_polygon(PackedVector2Array([a_center + Vector2(0, -plate * 0.55), a_center + Vector2(plate * 0.55, 0),
		a_center + Vector2(0, plate * 0.55), a_center + Vector2(-plate * 0.55, 0)]), Color("7c3f35"))
	_draw_value(layer, a_center, str(attack), VisualTokens.COLOR_GOLD_300 if attack > base_attack else VisualTokens.COLOR_STONE_050, plate)
	# Health: rounded plate.
	var h_center := Vector2(s.x - plate * 0.55, bottom)
	layer.draw_circle(h_center, plate * 0.50, Color("4f6a3f"))
	layer.draw_arc(h_center, plate * 0.50, 0, TAU, 32, Color(VisualTokens.COLOR_STONE_050, 0.6), 1.5, true)
	var damaged := health < max_health
	_draw_value(layer, h_center, str(health), Color("ffb3a6") if damaged else VisualTokens.COLOR_STONE_050, plate)
	if damaged:
		layer.draw_line(h_center + Vector2(-plate * 0.30, plate * 0.36), h_center + Vector2(plate * 0.30, plate * 0.36),
			Color("ffb3a6"), 2.0)
	# Armor: shield plate (only when present).
	if armor > 0:
		var r_center := Vector2(s.x - plate * 0.45, s.y * 0.13)
		var shield := PackedVector2Array([r_center + Vector2(-plate * 0.40, -plate * 0.36), r_center + Vector2(plate * 0.40, -plate * 0.36),
			r_center + Vector2(plate * 0.36, plate * 0.12), r_center + Vector2(0, plate * 0.46), r_center + Vector2(-plate * 0.36, plate * 0.12)])
		layer.draw_colored_polygon(shield, VisualTokens.COLOR_STEEL_700)
		var closed := PackedVector2Array(shield)
		closed.append(shield[0])
		layer.draw_polyline(closed, VisualTokens.COLOR_STONE_300, 1.5, true)
		_draw_value(layer, r_center + Vector2(0, -plate * 0.02), str(armor), VisualTokens.COLOR_STONE_050, plate * 0.85)
	if target_state == TargetState.LEGAL:
		_draw_target_marker(layer, s)


## Shrinks to min_size, then trims with an ellipsis so a single-line label stays in max_width.
static func fit_text(font: Font, text_value: String, max_width: float, font_size: int, min_size: int) -> Array:
	var current := font_size
	while current > min_size and font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, current).x > max_width:
		current -= 1
	var result := text_value
	while result.length() > 1 and font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, current).x > max_width:
		result = result.substr(0, result.length() - 2) + "…"
	return [result, current]


func _draw_value(layer: Control, center: Vector2, text_value: String, color: Color, plate: float) -> void:
	var font_size := int(plate * 0.62)
	var width := _display_font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := _display_font.get_ascent(font_size)
	layer.draw_string_outline(_display_font, center + Vector2(-width * 0.5, ascent * 0.36), text_value, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, 4, Color(0, 0, 0, 0.55))
	layer.draw_string(_display_font, center + Vector2(-width * 0.5, ascent * 0.36), text_value, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, color)


func _draw_target_marker(layer: Control, s: Vector2) -> void:
	var c := Vector2(s.x * 0.5, s.y * 0.36)
	var r := s.x * 0.20
	var gold := VisualTokens.COLOR_GOLD_300
	for i in 4:
		var angle := PI * 0.25 + PI * 0.5 * float(i)
		var d := Vector2(cos(angle), sin(angle))
		layer.draw_line(c + d * r * 0.65, c + d * r * 1.15, gold, 4.0, true)
	layer.draw_arc(c, r * 0.55, 0, TAU, 32, Color(gold, 0.9), 3.0, true)
