class_name BootGatesView
extends Control
## Gates of Nulmeris for the boot screen (temporary procedural art, D-054): a stone
## arch with two banded door leaves sealed by the Seal of Nulmeris. The Seal's
## light line traces real loading progress; `opening` parts the doors onto bright
## sky. A failure stops all motion and dims the light line — never a spinner.

var progress := 0.0
var opening := 0.0:
	set(value):
		opening = value
		queue_redraw()
var failed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := size
	if s.x < 50.0 or s.y < 50.0:
		return
	var arch_w := minf(s.x * 0.44, s.y * 0.74)
	var arch_h := s.y * 0.63
	var arch := Rect2(Vector2((s.x - arch_w) * 0.5, s.y * 0.06), Vector2(arch_w, arch_h))
	# Pale wall with coursed stone joints.
	draw_rect(Rect2(Vector2.ZERO, s), Color("e4ddd0"))
	for row in int(s.y / 48.0) + 1:
		var y := float(row) * 48.0
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.45, 0.40, 0.33, 0.07), 1.0)
		var offset := 0.0 if row % 2 == 0 else 60.0
		var x := offset
		while x < s.x:
			draw_line(Vector2(x, y), Vector2(x, y + 48.0), Color(0.45, 0.40, 0.33, 0.06), 1.0)
			x += 120.0
	# Arch frame (voussoirs) around the opening.
	var radius := arch_w * 0.5
	var spring := arch.position.y + radius
	var center := Vector2(arch.get_center().x, spring)
	for i in 13:
		var a0 := PI + PI * float(i) / 13.0 + 0.012
		var a1 := PI + PI * float(i + 1) / 13.0 - 0.012
		draw_colored_polygon(NulmerisEmblems.arc_band(center, radius, radius * 1.13, a0, a1, 6),
			Color("b7ab96") if i != 6 else VisualTokens.COLOR_GOLD_500)
	draw_rect(Rect2(arch.position.x - radius * 0.13, spring, radius * 0.13, arch.end.y - spring), Color("b7ab96"))
	draw_rect(Rect2(arch.end.x, spring, radius * 0.13, arch.end.y - spring), Color("b7ab96"))
	# Opening: bright sky behind the doors.
	var opening_poly := PackedVector2Array([Vector2(arch.position.x, arch.end.y)])
	for i in 33:
		var angle := PI + PI * float(i) / 32.0
		opening_poly.append(center + Vector2(cos(angle), sin(angle)) * radius)
	opening_poly.append(arch.end)
	draw_colored_polygon(opening_poly, Color("f4f1e8").lerp(Color("dcebee"), 0.5))
	# Door leaves slide apart with `opening`.
	var shift := radius * opening
	for side: float in [-1.0, 1.0]:
		var leaf := PackedVector2Array()
		for p: Vector2 in opening_poly:
			var on_side := (p.x - center.x) * side >= -0.5
			var x := p.x if on_side else center.x
			leaf.append(Vector2(x + side * shift, p.y))
		var clipped := Geometry2D.intersect_polygons(leaf, opening_poly)
		for poly: PackedVector2Array in clipped:
			draw_colored_polygon(poly, Color("7f8b8e"))
		var seam := center.x + side * shift
		var edge := center.x + side * radius
		if absf(edge - seam) < 2.0:
			continue
		var lo := minf(seam, edge)
		var hi := maxf(seam, edge)
		# Vertical planks and iron bands, clipped to the visible part of the leaf.
		for k in 4:
			var px := lo + (hi - lo) * float(k + 1) / 5.0
			draw_line(Vector2(px, _arch_top(center, radius, px) + 6.0), Vector2(px, arch.end.y),
				Color(VisualTokens.COLOR_STEEL_900, 0.18), 2.0)
		for band in 3:
			var by := spring + (arch.end.y - spring) * (0.2 + float(band) * 0.3)
			draw_line(Vector2(lo, by), Vector2(hi, by), Color(VisualTokens.COLOR_STEEL_900, 0.55), 7.0)
			for k in 5:
				draw_circle(Vector2(lo + (hi - lo) * (float(k) + 0.5) / 5.0, by), 4.0, VisualTokens.COLOR_GOLD_500)
		if absf(seam - center.x) < radius - 2.0:
			draw_line(Vector2(seam, _arch_top(center, radius, seam)), Vector2(seam, arch.end.y),
				Color(VisualTokens.COLOR_STEEL_900, 0.6), 3.0)
	# The Seal of Nulmeris across the seam; its light line traces progress.
	if opening < 0.3:
		var seal_center := Vector2(center.x, spring + (arch.end.y - spring) * 0.18)
		var seal_r := radius * 0.42
		var fade := 1.0 - opening / 0.3
		NulmerisEmblems.draw_seal(self, seal_center, seal_r, Color(VisualTokens.COLOR_STONE_050, 0.92 * fade),
			Color(VisualTokens.COLOR_MAGIC_300, 0.0))
		var light := Color(VisualTokens.COLOR_STEEL_500, 0.6) if failed else Color(VisualTokens.COLOR_MAGIC_300, 0.95 * fade)
		draw_arc(seal_center, seal_r * 1.12, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 96, light, 5.0, true)
		draw_arc(seal_center, seal_r * 1.12, 0, TAU, 96, Color(VisualTokens.COLOR_STEEL_900, 0.15 * fade), 1.5, true)
	# Threshold step.
	draw_rect(Rect2(arch.position.x - radius * 0.2, arch.end.y, arch_w + radius * 0.4, s.y * 0.025), Color("c9bea9"))


## Y of the arch intrados above [param x] (the doors never draw past it).
func _arch_top(center: Vector2, radius: float, x: float) -> float:
	var dx := clampf(x - center.x, -radius, radius)
	return center.y - sqrt(maxf(0.0, radius * radius - dx * dx))
