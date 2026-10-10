class_name GuardianPlaceholder
extends Control
## Visual Alpha Guardian of Nulmeris (temporary procedural art, D-054). Canon kept:
## a man of about 70–75, strong and weathered, calm and kind; silver-white hair,
## grey beard, grey-green steel eyes that do not glow; neutral Citadel robes; a
## staff crowned with three nested metallic rings. No wizard hat, no dark sorcery.

const IS_TEMPORARY_ASSET := true

@export var motion_enabled := true
var _elapsed := 0.0
var _redraw_accum := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(motion_enabled)
	resized.connect(queue_redraw)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 1000.0)
	_redraw_accum += delta
	if _redraw_accum >= 1.0 / 15.0:
		_redraw_accum = 0.0
		queue_redraw()


func is_temporary_asset() -> bool:
	return IS_TEMPORARY_ASSET


## Figure box keeps a fixed aspect so the Guardian is never stretched.
func _box() -> Rect2:
	var h := minf(size.y * 0.84, size.x / 0.66)
	var w := h * 0.66
	return Rect2(Vector2((size.x - w) * 0.5, size.y * 0.88 - h), Vector2(w, h))


func _p(box: Rect2, x: float, y: float) -> Vector2:
	return box.position + Vector2(x * box.size.x, y * box.size.y)


func _poly(box: Rect2, points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for point: Vector2 in points:
		packed.append(_p(box, point.x, point.y))
	draw_colored_polygon(packed, color)


func _draw() -> void:
	if size.x < 40.0 or size.y < 60.0:
		return
	var box := _box()
	var breath := sin(_elapsed * 0.8) * 0.003
	var robe := Color("566369")
	var robe_shadow := Color("3f4b50")
	var inner := Color("c9bfae")
	var inner_shadow := Color("a99f8e")
	var gold := Color("a88d4f")
	var skin := Color("c8a68a")
	var skin_shadow := Color("a8866b")
	var hair := Color("e7e4dd")
	var beard := Color("c9c6bf")
	var steel := Color("39464b")

	# Ancient ring behind the Guardian (very soft, part of the terrace light).
	var halo := _p(box, 0.48, 0.22)
	draw_arc(halo, box.size.x * 0.46, PI * 1.02, PI * 1.98, 64, Color(VisualTokens.COLOR_STEEL_500, 0.22), 6.0, true)
	draw_arc(halo, box.size.x * 0.40, PI * 1.05, PI * 1.95, 64, Color(VisualTokens.COLOR_GOLD_500, 0.22), 2.0, true)

	# Ground shadow.
	draw_set_transform(_p(box, 0.48, 0.985), 0.0, Vector2(1.0, 0.16))
	draw_circle(Vector2.ZERO, box.size.x * 0.40, Color(0.2, 0.18, 0.15, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Staff (behind the right hand): dark steel-bound shaft.
	var staff_x := 0.80
	draw_line(_p(box, staff_x, 0.13), _p(box, staff_x - 0.015, 0.985), Color("4a3f33"), box.size.x * 0.022, true)
	draw_line(_p(box, staff_x - 0.004, 0.13), _p(box, staff_x - 0.019, 0.985), Color(1, 1, 1, 0.12), box.size.x * 0.005, true)

	# Outer mantle: broad, strong shoulders, falling to the hem.
	var y0 := 0.30 + breath
	_poly(box, [Vector2(0.27, y0 + 0.01), Vector2(0.48, y0 - 0.025), Vector2(0.69, y0 + 0.01), Vector2(0.76, y0 + 0.08),
		Vector2(0.74, 0.62), Vector2(0.79, 0.985), Vector2(0.17, 0.985), Vector2(0.22, 0.62), Vector2(0.20, y0 + 0.08)], robe)
	# Mantle fold shadows.
	_poly(box, [Vector2(0.20, y0 + 0.08), Vector2(0.27, y0 + 0.10), Vector2(0.27, 0.985), Vector2(0.17, 0.985), Vector2(0.22, 0.62)],
		robe_shadow)
	_poly(box, [Vector2(0.66, 0.55), Vector2(0.74, 0.62), Vector2(0.79, 0.985), Vector2(0.70, 0.985)], robe_shadow)
	# Inner robe (neutral Citadel stone colour) visible down the front.
	_poly(box, [Vector2(0.41, y0 + 0.07), Vector2(0.55, y0 + 0.07), Vector2(0.60, 0.985), Vector2(0.36, 0.985)], inner)
	_poly(box, [Vector2(0.41, y0 + 0.07), Vector2(0.46, y0 + 0.07), Vector2(0.43, 0.985), Vector2(0.36, 0.985)], inner_shadow)
	for i in 3:
		var fx := 0.45 + float(i) * 0.04
		draw_line(_p(box, fx, 0.66), _p(box, fx + 0.01 * float(i - 1), 0.975), Color(0.45, 0.40, 0.33, 0.35), 2.0, true)
	# Gold trim along the mantle edges and a plain sash.
	draw_line(_p(box, 0.41, y0 + 0.07), _p(box, 0.36, 0.985), gold, box.size.x * 0.008, true)
	draw_line(_p(box, 0.55, y0 + 0.07), _p(box, 0.60, 0.985), gold, box.size.x * 0.008, true)
	_poly(box, [Vector2(0.38, 0.555), Vector2(0.58, 0.545), Vector2(0.585, 0.575), Vector2(0.375, 0.585)], Color("6d5d45"))
	draw_line(_p(box, 0.38, 0.556), _p(box, 0.58, 0.546), gold, 2.0, true)

	# Left arm resting along the body; right arm raised to the staff.
	_poly(box, [Vector2(0.22, y0 + 0.07), Vector2(0.30, y0 + 0.09), Vector2(0.31, 0.53), Vector2(0.26, 0.57), Vector2(0.20, 0.52)],
		robe_shadow)
	_poly(box, [Vector2(0.24, 0.525), Vector2(0.30, 0.525), Vector2(0.30, 0.575), Vector2(0.25, 0.58)], skin_shadow)
	_poly(box, [Vector2(0.64, y0 + 0.03), Vector2(0.75, y0 + 0.07), Vector2(0.80, 0.41), Vector2(0.75, 0.45), Vector2(0.64, y0 + 0.13)],
		robe)
	_poly(box, [Vector2(0.69, 0.40), Vector2(0.80, 0.375), Vector2(0.82, 0.43), Vector2(0.73, 0.46)], robe_shadow)
	# Right hand gripping the staff.
	_poly(box, [Vector2(0.765, 0.385), Vector2(0.83, 0.38), Vector2(0.835, 0.445), Vector2(0.77, 0.45)], skin)
	draw_line(_p(box, 0.775, 0.405), _p(box, 0.83, 0.402), skin_shadow, 2.0, true)
	draw_line(_p(box, 0.775, 0.425), _p(box, 0.832, 0.423), skin_shadow, 2.0, true)

	# Head: weathered face in three-quarter light.
	var head := _p(box, 0.485, 0.205 + breath)
	var hr := box.size.x * 0.085
	# Silver-white hair falling to the shoulders, behind the head.
	_poly(box, [Vector2(0.395, 0.17), Vector2(0.485, 0.108), Vector2(0.578, 0.17), Vector2(0.588, 0.255), Vector2(0.57, 0.335),
		Vector2(0.545, 0.30), Vector2(0.43, 0.30), Vector2(0.405, 0.335), Vector2(0.385, 0.255)], hair)
	draw_set_transform(head, 0.0, Vector2(0.86, 1.08))
	draw_circle(Vector2.ZERO, hr, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(head + Vector2(hr * 0.42, 0), 0.0, Vector2(0.42, 1.0))
	draw_circle(Vector2.ZERO, hr * 0.95, Color(skin_shadow, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Hair line and crown, swept back.
	_poly(box, [Vector2(0.40, 0.175), Vector2(0.43, 0.13), Vector2(0.485, 0.112), Vector2(0.545, 0.125), Vector2(0.575, 0.165),
		Vector2(0.55, 0.15), Vector2(0.485, 0.14), Vector2(0.43, 0.16)], hair)
	# Brows, calm eyes (grey-green steel, not glowing), nose.
	var eye_y := 0.195 + breath
	draw_line(_p(box, 0.432, eye_y - 0.014), _p(box, 0.468, eye_y - 0.017), Color("d9d6cf"), box.size.x * 0.009, true)
	draw_line(_p(box, 0.502, eye_y - 0.017), _p(box, 0.538, eye_y - 0.014), Color("d9d6cf"), box.size.x * 0.009, true)
	draw_circle(_p(box, 0.452, eye_y), box.size.x * 0.0065, Color("5e6f69"))
	draw_circle(_p(box, 0.518, eye_y), box.size.x * 0.0065, Color("5e6f69"))
	draw_line(_p(box, 0.486, eye_y + 0.002), _p(box, 0.48, eye_y + 0.035), skin_shadow, 2.0, true)
	# Long grey beard, layered, down to the chest.
	_poly(box, [Vector2(0.415, 0.225), Vector2(0.445, 0.245), Vector2(0.485, 0.25), Vector2(0.525, 0.245), Vector2(0.555, 0.225),
		Vector2(0.56, 0.30), Vector2(0.53, 0.38), Vector2(0.485, 0.43), Vector2(0.44, 0.38), Vector2(0.41, 0.30)], beard)
	_poly(box, [Vector2(0.445, 0.245), Vector2(0.485, 0.25), Vector2(0.525, 0.245), Vector2(0.505, 0.265), Vector2(0.465, 0.265)],
		Color("b3afa7"))
	for i in 5:
		var bx := 0.44 + float(i) * 0.024
		draw_line(_p(box, bx, 0.28), _p(box, 0.485 + (bx - 0.485) * 0.5, 0.40), Color(0.55, 0.53, 0.50, 0.5), 1.5, true)
	draw_line(_p(box, 0.468, 0.252), _p(box, 0.503, 0.252), Color("8f7c6a"), 2.0, true)

	# Rim light from the open sky on the left edge of the figure.
	draw_line(_p(box, 0.27, y0 + 0.012), _p(box, 0.20, y0 + 0.08), Color(1, 1, 1, 0.35), 3.0, true)
	draw_line(_p(box, 0.20, y0 + 0.08), _p(box, 0.22, 0.62), Color(1, 1, 1, 0.22), 3.0, true)
	draw_arc(head, hr * 1.02, PI * 0.75, PI * 1.35, 16, Color(1, 1, 1, 0.35), 2.5, true)

	# Staff crown: three nested metallic rings (steel, old gold, steel) around a
	# still, non-glowing core.
	var crown := _p(box, staff_x, 0.105)
	var ring := box.size.x * 0.105
	var turn := _elapsed * 0.25
	draw_arc(crown, ring, turn, turn + TAU * 0.92, 48, steel, box.size.x * 0.016, true)
	draw_arc(crown, ring * 0.72, -turn * 1.3, -turn * 1.3 + TAU * 0.88, 40, gold, box.size.x * 0.014, true)
	draw_arc(crown, ring * 0.46, turn * 0.8, turn * 0.8 + TAU * 0.9, 32, steel, box.size.x * 0.012, true)
	draw_circle(crown, ring * 0.16, Color("8fb9b6"))
	draw_line(crown + Vector2(0, ring * 1.0), _p(box, staff_x, 0.13), Color("4a3f33"), box.size.x * 0.02, true)
