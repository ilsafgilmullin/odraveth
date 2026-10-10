class_name CitadelBattlefield
extends BattlefieldTheme
## Visual Alpha battlefield theme «ЦИТАДЕЛЬ НУЛМЕРИСА». Static procedural
## background plus a tiny throttled waterfall shimmer (the only ambient motion).
## Decor stays outside the gameplay rect so cards, creatures, heroes, stats and
## targeting are never obscured. Temporary environment art, not final illustration.

const SHIMMER_FPS := 12.0

var _ambient: Control
var _shimmer_time := 0.0
var _shimmer_accum := 0.0


func _ready() -> void:
	super._ready()
	theme_id = &"citadel_of_nulmeris"
	display_name = "ЦИТАДЕЛЬ НУЛМЕРИСА"
	_ambient = Control.new()
	_ambient.name = "AmbientShimmer"
	_ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ambient.draw.connect(_draw_ambient)
	add_child(_ambient)
	var has_art := ArtAssets.has(&"arena")
	set_process(ambient_enabled and not has_art)
	ambient_changed.connect(func(enabled: bool) -> void: set_process(enabled and not ArtAssets.has(&"arena")))


func _process(delta: float) -> void:
	_shimmer_time += delta
	_shimmer_accum += delta
	if _shimmer_accum >= 1.0 / SHIMMER_FPS:
		_shimmer_accum = 0.0
		_ambient.queue_redraw()


func _field() -> Rect2:
	if gameplay_rect.size.x > 10.0:
		return gameplay_rect
	return Rect2(size.x * 0.12, size.y * 0.10, size.x * 0.76, size.y * 0.64)


func _gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))


func _draw() -> void:
	var s := size
	if s.x < 32.0 or s.y < 32.0:
		return
	var field := _field()
	var art := ArtAssets.texture(&"arena")
	if art != null:
		# Production battlefield: periphery from the painting, a calm readable slab in the centre.
		ArtAssets.draw_cover(self, art, Rect2(Vector2.ZERO, s))
		draw_rect(field.grow(8.0), Color(0.93, 0.90, 0.85, 0.55))
		draw_rect(field, Color(VisualTokens.COLOR_GOLD_700, 0.40), false, 2.0)
		var mid := center_line_y if center_line_y > 0.0 else field.get_center().y
		draw_line(Vector2(field.position.x + 20.0, mid), Vector2(field.end.x - 20.0, mid), Color(VisualTokens.COLOR_GOLD_700, 0.45), 2.0)
		return
	# Sky and distant cliffs behind the Citadel terrace.
	_gradient(Rect2(0, 0, s.x, s.y * 0.55), Color("d7e7ea"), Color("e6ece6"))
	for side: float in [0.0, 1.0]:
		var edge := 0.0 if side == 0.0 else s.x
		var dir := 1.0 if side == 0.0 else -1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(edge, s.y * 0.20), Vector2(edge + dir * s.x * 0.07, s.y * 0.14),
			Vector2(edge + dir * s.x * 0.13, s.y * 0.30), Vector2(edge + dir * s.x * 0.10, s.y),
			Vector2(edge, s.y),
		]), Color("a89c88"))
		# Distant tower with a ring crown.
		var tx := edge + dir * s.x * 0.055
		draw_rect(Rect2(tx - s.x * 0.012, s.y * 0.05, s.x * 0.024, s.y * 0.20), Color("b9ae9c"))
		draw_arc(Vector2(tx, s.y * 0.05), s.x * 0.022, 0, TAU, 32, Color(VisualTokens.COLOR_STEEL_700, 0.55), 3.0, true)
		draw_arc(Vector2(tx, s.y * 0.05), s.x * 0.014, 0, TAU, 24, Color(VisualTokens.COLOR_GOLD_500, 0.6), 2.0, true)
	# Terrace stone surrounding the field.
	_gradient(Rect2(0, s.y * 0.30, s.x, s.y * 0.70), Color("d6cdbd"), Color("c4b9a6"))
	# Peripheral arches (left and right of the field only).
	for side: float in [0.0, 1.0]:
		var x0 := field.position.x - s.x * 0.085 if side == 0.0 else field.end.x + s.x * 0.010
		var arch := Rect2(x0, field.position.y + field.size.y * 0.06, s.x * 0.075, field.size.y * 0.80)
		_draw_arch(arch)
	# Water channels flanking the field.
	for side: float in [0.0, 1.0]:
		var cx := field.position.x - s.x * 0.012 if side == 0.0 else field.end.x + s.x * 0.004
		_gradient(Rect2(cx, field.position.y, s.x * 0.008, field.size.y), Color(0.45, 0.76, 0.80, 0.55),
			Color(0.35, 0.62, 0.68, 0.65))
	# Central field: light aged stone slab with recessed board lanes.
	var slab := field.grow(8.0)
	draw_rect(slab, Color("b3a793"))
	_gradient(field, Color("ede6d8"), Color("e3dacb"))
	var tile := field.size.x / 12.0
	for i in range(1, 12):
		draw_line(Vector2(field.position.x + tile * float(i), field.position.y),
			Vector2(field.position.x + tile * float(i), field.end.y), Color(0.45, 0.40, 0.33, 0.07), 1.0)
	var rows := 6
	for i in range(1, rows):
		var y := field.position.y + field.size.y * float(i) / float(rows)
		draw_line(Vector2(field.position.x, y), Vector2(field.end.x, y), Color(0.45, 0.40, 0.33, 0.06), 1.0)
	# Ancient engraved rings in the field (very faint, behind gameplay).
	var center := Vector2(field.get_center().x, center_line_y if center_line_y > 0.0 else field.get_center().y)
	for i in 3:
		draw_arc(center, field.size.y * (0.20 + float(i) * 0.12), 0, TAU, 96, Color(0.45, 0.40, 0.33, 0.07), 2.0, true)
	NulmerisEmblems.draw_seal(self, center, field.size.y * 0.07, Color(0.45, 0.40, 0.33, 0.14), Color(VisualTokens.COLOR_MAGIC_500, 0.25))
	# Divider between the two board rows.
	draw_line(Vector2(field.position.x + 20.0, center.y), Vector2(center.x - field.size.y * 0.10, center.y),
		Color(VisualTokens.COLOR_GOLD_700, 0.45), 2.0)
	draw_line(Vector2(center.x + field.size.y * 0.10, center.y), Vector2(field.end.x - 20.0, center.y),
		Color(VisualTokens.COLOR_GOLD_700, 0.45), 2.0)
	draw_rect(field, Color(VisualTokens.COLOR_GOLD_700, 0.40), false, 2.0)
	draw_rect(field.grow(-6.0), Color(VisualTokens.COLOR_MAGIC_500, 0.18), false, 1.0)


func _draw_arch(rect: Rect2) -> void:
	var stone := Color("c2b6a2")
	draw_rect(rect, stone)
	var inner := rect.grow(-rect.size.x * 0.18)
	var points := PackedVector2Array()
	var radius := inner.size.x * 0.5
	var spring := inner.position.y + radius
	points.append(Vector2(inner.position.x, inner.end.y))
	for i in 17:
		var angle := PI + PI * float(i) / 16.0
		points.append(Vector2(inner.get_center().x + cos(angle) * radius, spring + sin(angle) * radius))
	points.append(inner.end)
	var colors := PackedColorArray()
	for p: Vector2 in points:
		colors.append(Color("dfeaec").lerp(Color("c9d6d6"), clampf((p.y - inner.position.y) / inner.size.y, 0.0, 1.0)))
	draw_polygon(points, colors)
	draw_rect(Rect2(inner.position.x + inner.size.x * 0.42, inner.position.y + inner.size.y * 0.30, inner.size.x * 0.16,
		inner.size.y * 0.70), Color(0.45, 0.76, 0.80, 0.55))
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, Color(VisualTokens.COLOR_GOLD_700, 0.55), 2.0, true)


func _draw_ambient() -> void:
	if not ambient_enabled or size.x < 32.0 or size.y < 32.0 or ArtAssets.has(&"arena"):
		return
	var field := _field()
	for side: float in [0.0, 1.0]:
		var x0 := field.position.x - size.x * 0.085 if side == 0.0 else field.end.x + size.x * 0.010
		var arch := Rect2(x0, field.position.y + field.size.y * 0.06, size.x * 0.075, field.size.y * 0.80)
		var inner := arch.grow(-arch.size.x * 0.18)
		var fall := Rect2(inner.position.x + inner.size.x * 0.42, inner.position.y + inner.size.y * 0.30, inner.size.x * 0.16,
			inner.size.y * 0.70)
		for i in 4:
			var y := fall.position.y + fmod(_shimmer_time * 60.0 + float(i) * fall.size.y * 0.25, fall.size.y)
			_ambient.draw_line(Vector2(fall.position.x, y), Vector2(fall.end.x, y + 6.0), Color(1, 1, 1, 0.35), 1.5)
