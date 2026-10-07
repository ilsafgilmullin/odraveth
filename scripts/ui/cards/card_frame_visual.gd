class_name CardFrameVisual
extends Control
## Architectural card silhouette with clipped corners; avoids tavern/gem card grammar.

var accent := VisualTokens.COLOR_STEEL_500
var card_type: CardEnums.Type = CardEnums.Type.CREATURE
var selected := false
var interaction_pressed := false
var interaction_focused := false
var unavailable := false


func configure(type_value: CardEnums.Type, accent_value: Color) -> void:
	card_type = type_value
	accent = accent_value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_visual_state(is_selected: bool, is_pressed: bool, is_focused: bool, is_unavailable: bool) -> void:
	selected = is_selected
	interaction_pressed = is_pressed
	interaction_focused = is_focused
	unavailable = is_unavailable
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x < 8 or s.y < 8:
		return
	var cut := minf(s.x, s.y) * 0.045
	var asym := cut * 1.65 if card_type == CardEnums.Type.CURSE else cut
	var points := PackedVector2Array([
		Vector2(cut, 0),
		Vector2(s.x - cut, 0),
		Vector2(s.x, cut),
		Vector2(s.x, s.y - asym),
		Vector2(s.x - asym, s.y),
		Vector2(cut, s.y),
		Vector2(0, s.y - cut),
		Vector2(0, cut),
	])
	var base := Color("e8e1d5")
	if card_type == CardEnums.Type.ARTIFACT:
		base = Color("dcded9")
	elif card_type == CardEnums.Type.SPELL:
		base = Color("eee9df")
	elif card_type == CardEnums.Type.CURSE:
		base = Color("ddd7d5")
	if interaction_pressed:
		base = base.darkened(0.08)
	if unavailable:
		base = base.darkened(0.18)

	draw_colored_polygon(points, base)
	var border := VisualTokens.COLOR_GOLD_500 if selected else accent
	if interaction_focused:
		border = VisualTokens.COLOR_MAGIC_500
	var width := 5.0 if selected else 2.5
	if interaction_pressed:
		width += 1.0
	_outline(points, border, width)

	# Secondary steel line keeps faction colour subordinate.
	var inner := Rect2(Vector2(8, 8), s - Vector2(16, 16))
	draw_line(inner.position + Vector2(cut, 0), Vector2(inner.end.x - cut, inner.position.y),
		Color(VisualTokens.COLOR_STEEL_700, 0.35), 1.0)
	if card_type == CardEnums.Type.CURSE:
		draw_line(Vector2(s.x * 0.72, s.y * 0.12), Vector2(s.x * 0.61, s.y * 0.28),
			Color(VisualTokens.COLOR_STEEL_700, 0.45), 2.0)
		draw_line(Vector2(s.x * 0.61, s.y * 0.28), Vector2(s.x * 0.69, s.y * 0.37),
			Color(VisualTokens.COLOR_STEEL_700, 0.45), 2.0)


func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)
