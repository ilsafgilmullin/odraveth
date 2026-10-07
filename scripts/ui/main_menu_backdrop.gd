class_name MainMenuBackdrop
extends Control
## Stage 7B procedural composition placeholder for the Guardian Terrace.
## This is not final environment art. It establishes depth, crop and motion budget.

@export var motion_enabled := true
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(motion_enabled)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 1000.0)
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return

	# Bright high-altitude sky and restrained atmospheric bands.
	draw_rect(Rect2(Vector2.ZERO, s), Color("dfecef"))
	draw_rect(Rect2(0, s.y * 0.30, s.x, s.y * 0.40), Color("d4e3e6"))
	draw_rect(Rect2(0, s.y * 0.57, s.x, s.y * 0.43), Color("c8bdab"))

	_draw_clouds(s)
	_draw_distant_citadel(s)
	_draw_cliffs_and_water(s)
	_draw_terrace(s)
	_draw_arch_arc(s)


func _draw_clouds(s: Vector2) -> void:
	var cloud := Color(1.0, 1.0, 1.0, 0.48)
	for i in 5:
		var speed := 4.0 + float(i) * 0.7
		var x := fmod(float(i) * s.x * 0.23 + _elapsed * speed, s.x + 360.0) - 180.0
		var y := s.y * (0.11 + float(i % 3) * 0.075)
		var r := 42.0 + float(i % 2) * 18.0
		draw_circle(Vector2(x, y), r, cloud)
		draw_circle(Vector2(x + r * 0.85, y + 8.0), r * 0.72, cloud)
		draw_circle(Vector2(x - r * 0.82, y + 12.0), r * 0.62, cloud)


func _draw_distant_citadel(s: Vector2) -> void:
	var stone := Color("b5aa99")
	var steel := Color("59656a")
	var bases := [0.48, 0.58, 0.69, 0.80]
	for i in bases.size():
		var x: float = s.x * float(bases[i])
		var h := s.y * (0.23 + float(i % 2) * 0.08)
		var w := s.x * 0.035
		draw_rect(Rect2(x, s.y * 0.58 - h, w, h), stone)
		draw_polygon(PackedVector2Array([
			Vector2(x - w * 0.18, s.y * 0.58 - h),
			Vector2(x + w * 0.50, s.y * 0.58 - h - h * 0.19),
			Vector2(x + w * 1.18, s.y * 0.58 - h),
		]), PackedColorArray([steel]))


func _draw_cliffs_and_water(s: Vector2) -> void:
	var cliff := Color("978a78")
	draw_polygon(PackedVector2Array([
		Vector2(0, s.y * 0.62), Vector2(s.x * 0.22, s.y * 0.54),
		Vector2(s.x * 0.33, s.y), Vector2(0, s.y),
	]), PackedColorArray([cliff]))
	draw_polygon(PackedVector2Array([
		Vector2(s.x, s.y * 0.55), Vector2(s.x * 0.86, s.y * 0.62),
		Vector2(s.x * 0.78, s.y), Vector2(s.x, s.y),
	]), PackedColorArray([cliff]))

	var water := Color(0.30, 0.70, 0.75, 0.42)
	var shimmer := 0.5 + sin(_elapsed * 1.4) * 0.12
	draw_rect(Rect2(s.x * 0.735, s.y * 0.48, s.x * 0.009, s.y * 0.38), Color(water, shimmer))
	draw_rect(Rect2(s.x * 0.775, s.y * 0.44, s.x * 0.006, s.y * 0.31), Color(water, shimmer * 0.8))


func _draw_terrace(s: Vector2) -> void:
	draw_rect(Rect2(0, s.y * 0.78, s.x, s.y * 0.22), Color("d5ccbd"))
	draw_line(Vector2(0, s.y * 0.785), Vector2(s.x, s.y * 0.785), Color("806a38"), 3.0)
	for i in 9:
		var x := float(i) * s.x / 8.0
		draw_line(Vector2(x, s.y * 0.785), Vector2(x + s.x * 0.04, s.y), Color(0.45, 0.42, 0.37, 0.18), 1.0)


func _draw_arch_arc(s: Vector2) -> void:
	var center := Vector2(s.x * 0.25, s.y * 0.51)
	draw_arc(center, s.y * 0.38, PI * 1.05, PI * 1.95, 48, Color(0.22, 0.27, 0.29, 0.30), 9.0)
	draw_arc(center, s.y * 0.34, PI * 1.05, PI * 1.95, 48, Color(0.72, 0.61, 0.33, 0.28), 3.0)
