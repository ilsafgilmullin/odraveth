class_name GuardianPlaceholder
extends Control
## Production composition placeholder only. Final Guardian artwork is not present.
## Preserves the approved left-side crop and the three-ring Guardian Staff concept.

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

	var breath := sin(_elapsed * 0.75) * s.y * 0.004
	var center := Vector2(s.x * 0.45, s.y * 0.46 + breath)
	var stone := Color("8f8a82")
	var deep := Color("46545b")
	var gold := Color("9f8649")
	var steel := Color("343f44")

	# Faceless silhouette: deliberately no final face, hair or costume detailing.
	draw_circle(center + Vector2(0, -s.y * 0.245), s.y * 0.070, stone)
	draw_polygon(PackedVector2Array([
		center + Vector2(-s.x * 0.16, -s.y * 0.15),
		center + Vector2(s.x * 0.13, -s.y * 0.15),
		center + Vector2(s.x * 0.18, s.y * 0.24),
		center + Vector2(s.x * 0.10, s.y * 0.49),
		center + Vector2(-s.x * 0.11, s.y * 0.49),
		center + Vector2(-s.x * 0.20, s.y * 0.23),
	]), PackedColorArray([deep]))
	draw_polygon(PackedVector2Array([
		center + Vector2(-s.x * 0.13, -s.y * 0.12),
		center + Vector2(s.x * 0.08, -s.y * 0.12),
		center + Vector2(s.x * 0.11, s.y * 0.32),
		center + Vector2(-s.x * 0.07, s.y * 0.39),
	]), PackedColorArray([stone]))
	draw_line(center + Vector2(-s.x * 0.10, s.y * 0.05), center + Vector2(s.x * 0.08, s.y * 0.10), gold, 5.0)

	# Guardian Staff placeholder: dark shaft + three nested metallic rings.
	var staff_x := s.x * 0.76
	var staff_top := s.y * 0.19 + sin(_elapsed * 0.55) * 1.5
	draw_line(Vector2(staff_x, staff_top), Vector2(staff_x - s.x * 0.015, s.y * 0.93), steel, 8.0)
	for i in 3:
		var radius := s.y * (0.055 + float(i) * 0.022)
		var ring_color := gold if i == 1 else steel
		draw_arc(Vector2(staff_x, staff_top + s.y * 0.045), radius, 0.0, TAU, 40, ring_color, 4.0)
	draw_circle(Vector2(staff_x, staff_top + s.y * 0.045), s.y * 0.012,
		Color(0.35, 0.72, 0.75, 0.32))
