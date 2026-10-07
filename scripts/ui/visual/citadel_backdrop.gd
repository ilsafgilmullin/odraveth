class_name CitadelBackdrop
extends Control
## Visual Alpha procedural Citadel of Nulmeris environment. Static drawing only
## (no per-frame work). Temporary environment art, not final illustration.

enum Mood { HALL, CHAMBER }

var mood: Mood = Mood.HALL
var accent := VisualTokens.COLOR_MAGIC_500
## 0..1 darkening overlay for modal moments (Result, Mulligan).
var dim := 0.0


static func create(value: Mood) -> CitadelBackdrop:
	var view := CitadelBackdrop.new()
	view.name = "CitadelBackdrop"
	view.mood = value
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return view


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x < 16.0 or s.y < 16.0:
		return
	if mood == Mood.CHAMBER:
		_draw_chamber(s)
	else:
		_draw_hall(s)
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.07, 0.08, dim))


func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))


func _draw_hall(s: Vector2) -> void:
	var wall := Color("d9d1c2")
	var wall_dark := Color("c9bfad")
	_gradient_rect(Rect2(Vector2.ZERO, s), Color("e3dccf"), wall)
	var floor_y := s.y * 0.70
	var windows := 3 if s.x / s.y < 2.0 else 4
	var span := s.x / float(windows)
	var window_w := minf(span * 0.46, s.y * 0.30)
	for i in windows:
		var cx := span * (float(i) + 0.5)
		_draw_window(Rect2(cx - window_w * 0.5, s.y * 0.11, window_w, floor_y - s.y * 0.19), i)
	for i in windows + 1:
		var x := span * float(i)
		var pilaster := Rect2(x - s.x * 0.016, 0, s.x * 0.032, floor_y)
		_gradient_rect(pilaster, wall_dark, wall_dark.darkened(0.06))
		draw_rect(Rect2(pilaster.position.x - s.x * 0.006, s.y * 0.08, pilaster.size.x + s.x * 0.012, s.y * 0.018), wall_dark.darkened(0.1))
	draw_rect(Rect2(0, s.y * 0.06, s.x, s.y * 0.012), Color(VisualTokens.COLOR_GOLD_700, 0.35))
	_gradient_rect(Rect2(0, floor_y, s.x, s.y - floor_y), Color("e7dfd1"), Color("d3c9b8"))
	draw_line(Vector2(0, floor_y), Vector2(s.x, floor_y), Color(VisualTokens.COLOR_GOLD_700, 0.55), 3.0)
	draw_line(Vector2(0, floor_y + 7), Vector2(s.x, floor_y + 7), Color(accent, 0.22), 2.0)
	var vanish := Vector2(s.x * 0.5, floor_y - s.y * 0.35)
	for i in 13:
		var x := s.x * (float(i) / 12.0)
		var from := vanish.lerp(Vector2(x, s.y), (floor_y - vanish.y) / (s.y - vanish.y))
		draw_line(from, Vector2(x + (x - s.x * 0.5) * 0.4, s.y), Color(0.42, 0.38, 0.33, 0.12), 1.5)
	for i in 4:
		var y := floor_y + (s.y - floor_y) * pow(float(i + 1) / 5.0, 1.6)
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.42, 0.38, 0.33, 0.10), 1.0)
	_gradient_rect(Rect2(0, 0, s.x * 0.06, s.y), Color(0.25, 0.27, 0.27, 0.10), Color(0.25, 0.27, 0.27, 0.14))
	_gradient_rect(Rect2(s.x * 0.94, 0, s.x * 0.06, s.y), Color(0.25, 0.27, 0.27, 0.10), Color(0.25, 0.27, 0.27, 0.14))


func _draw_window(rect: Rect2, index: int) -> void:
	var points := _arch(rect)
	var sky_top := Color("dbeaee")
	var sky_low := Color("eef3ef")
	var colors := PackedColorArray()
	for p: Vector2 in points:
		colors.append(sky_top.lerp(sky_low, clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)))
	draw_polygon(points, colors)
	var horizon := rect.position.y + rect.size.y * 0.72
	var cliff := Color("a99d8b")
	var left_peak := rect.position.x + rect.size.x * (0.25 + 0.15 * float(index % 2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(rect.position.x, horizon - rect.size.y * 0.05),
		Vector2(left_peak, horizon - rect.size.y * 0.22),
		Vector2(rect.position.x + rect.size.x * 0.62, horizon - rect.size.y * 0.08),
		Vector2(rect.end.x, horizon - rect.size.y * 0.16),
		Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y),
	]), cliff)
	var tower_x := rect.position.x + rect.size.x * (0.68 if index % 2 == 0 else 0.30)
	draw_rect(Rect2(tower_x, horizon - rect.size.y * 0.42, rect.size.x * 0.08, rect.size.y * 0.30), Color("b8ad9c"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(tower_x - rect.size.x * 0.015, horizon - rect.size.y * 0.42),
		Vector2(tower_x + rect.size.x * 0.04, horizon - rect.size.y * 0.50),
		Vector2(tower_x + rect.size.x * 0.095, horizon - rect.size.y * 0.42),
	]), Color("6f7b7f"))
	var fall_x := rect.position.x + rect.size.x * (0.44 if index % 2 == 0 else 0.58)
	draw_rect(Rect2(fall_x, horizon - rect.size.y * 0.10, rect.size.x * 0.035, rect.size.y * 0.30), Color(0.45, 0.76, 0.80, 0.55))
	draw_rect(Rect2(rect.position.x, rect.end.y - rect.size.y * 0.10, rect.size.x, rect.size.y * 0.10), Color("cfc5b4"))
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, Color("b6aa96"), maxf(4.0, rect.size.x * 0.05), true)
	draw_polyline(closed, Color(VisualTokens.COLOR_GOLD_500, 0.55), 2.0, true)


func _arch(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := rect.size.x * 0.5
	var spring := rect.position.y + radius
	points.append(Vector2(rect.position.x, rect.end.y))
	for i in 21:
		var angle := PI + PI * float(i) / 20.0
		points.append(Vector2(rect.get_center().x + cos(angle) * radius, spring + sin(angle) * radius))
	points.append(rect.end)
	return points


func _draw_chamber(s: Vector2) -> void:
	_gradient_rect(Rect2(Vector2.ZERO, s), Color("33403f"), Color("161d20"))
	var floor_y := s.y * 0.78
	for side: float in [0.0, 1.0]:
		for i in 3:
			var x := s.x * (0.04 + float(i) * 0.075) if side == 0.0 else s.x * (0.96 - float(i) * 0.075)
			var w := s.x * (0.040 - float(i) * 0.006)
			_gradient_rect(Rect2(x - w * 0.5, 0, w, floor_y), Color(0.44, 0.47, 0.46, 0.55 - float(i) * 0.12),
				Color(0.22, 0.26, 0.27, 0.6 - float(i) * 0.12))
	var shaft := PackedVector2Array([
		Vector2(s.x * 0.40, 0), Vector2(s.x * 0.60, 0), Vector2(s.x * 0.74, floor_y), Vector2(s.x * 0.26, floor_y)])
	draw_polygon(shaft, PackedColorArray([Color(0.85, 0.95, 0.95, 0.10), Color(0.85, 0.95, 0.95, 0.10),
		Color(0.85, 0.95, 0.95, 0.0), Color(0.85, 0.95, 0.95, 0.0)]))
	_gradient_rect(Rect2(0, floor_y, s.x, s.y - floor_y), Color("2c3638"), Color("12181a"))
	draw_line(Vector2(0, floor_y), Vector2(s.x, floor_y), Color(VisualTokens.COLOR_GOLD_500, 0.35), 2.0)
	var center := Vector2(s.x * 0.5, floor_y + (s.y - floor_y) * 0.35)
	for i in 4:
		draw_arc(center, s.y * (0.10 + float(i) * 0.05), PI * 0.05, PI * 0.95, 48, Color(accent, 0.10 - float(i) * 0.02), 2.0, true)
