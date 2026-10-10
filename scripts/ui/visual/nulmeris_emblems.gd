class_name NulmerisEmblems
extends RefCounted
## Visual Alpha procedural symbol geometry: Seal of Nulmeris, ODRAVETH O-mark and
## faction symbols. Temporary brand/world candidates, not approved final artwork.
## All functions draw into the CanvasItem that is currently executing _draw().

enum Kind { SEAL, O_MARK, FACTION }

const FACTION_COLORS := {
	Faction.Id.ASHRAVAEL: Color("9a4a3c"),
	Faction.Id.NERQATHEN: Color("3f9a9c"),
	Faction.Id.DUMORYSS: Color("6f5a8c"),
	Faction.Id.KHEVARUUN: Color("4f6f8f"),
	Faction.Id.NEUTRAL: Color("7d8487"),
}
const FACTION_SECONDARY := {
	Faction.Id.ASHRAVAEL: Color("c98a4a"),
	Faction.Id.NERQATHEN: Color("9bd6d4"),
	Faction.Id.DUMORYSS: Color("b4a3cf"),
	Faction.Id.KHEVARUUN: Color("c8a95e"),
	Faction.Id.NEUTRAL: Color("c9c3b6"),
}


static func faction_color(faction: Faction.Id) -> Color:
	return FACTION_COLORS.get(faction, VisualTokens.COLOR_STEEL_500)


static func faction_secondary(faction: Faction.Id) -> Color:
	return FACTION_SECONDARY.get(faction, VisualTokens.COLOR_STONE_300)


static func arc_band(center: Vector2, r_in: float, r_out: float, a0: float, a1: float,
		steps: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := lerpf(a0, a1, float(i) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * r_out)
	for i in range(steps, -1, -1):
		var angle := lerpf(a0, a1, float(i) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * r_in)
	return points


static func _scaled(points: Array, center: Vector2, radius: float, offset: Vector2 = Vector2.ZERO,
		factor: float = 1.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Vector2 in points:
		result.append(center + (p * factor + offset) * radius)
	return result


static func _outline(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	ci.draw_polyline(closed, color, width, true)


## Open/broken double ring, vertical Citadel axis, foundation and a restrained light line.
static func draw_seal(ci: CanvasItem, center: Vector2, radius: float, color: Color,
		light: Color = VisualTokens.COLOR_MAGIC_300, cut: Color = Color(0, 0, 0, 0)) -> void:
	var top := -PI * 0.5
	ci.draw_colored_polygon(arc_band(center, radius * 0.86, radius, top + 0.24, top + TAU * 0.5, 30), color)
	ci.draw_colored_polygon(arc_band(center, radius * 0.86, radius, top + TAU * 0.5, top + TAU - 0.24, 30), color)
	var inner := color.lightened(0.18)
	ci.draw_colored_polygon(arc_band(center, radius * 0.60, radius * 0.70, top + 0.42, top + PI - 0.30, 24), inner)
	ci.draw_colored_polygon(arc_band(center, radius * 0.60, radius * 0.70, top + PI + 0.30, top + TAU - 0.42, 24), inner)
	if cut.a > 0.0:
		ci.draw_line(center + Vector2(-radius * 0.12, -radius * 1.05), center + Vector2(-radius * 0.12, radius * 0.80),
			cut, radius * 0.05)
		ci.draw_line(center + Vector2(radius * 0.12, -radius * 1.05), center + Vector2(radius * 0.12, radius * 0.80),
			cut, radius * 0.05)
	ci.draw_colored_polygon(_scaled([
		Vector2(-0.075, 0.80), Vector2(0.075, 0.80), Vector2(0.050, -0.92),
		Vector2(0.0, -1.12), Vector2(-0.050, -0.92),
	], center, radius), color)
	ci.draw_colored_polygon(_scaled([
		Vector2(-0.40, 0.74), Vector2(0.40, 0.74), Vector2(0.40, 0.84), Vector2(-0.40, 0.84),
	], center, radius), color)
	ci.draw_colored_polygon(_scaled([
		Vector2(-0.56, 0.86), Vector2(0.56, 0.86), Vector2(0.56, 0.97), Vector2(-0.56, 0.97),
	], center, radius), color)
	ci.draw_line(center + Vector2(0, -radius * 0.86), center + Vector2(0, radius * 0.66), light, maxf(1.5, radius * 0.022), true)
	ci.draw_colored_polygon(_scaled([
		Vector2(0, -1.01), Vector2(0.035, -0.95), Vector2(0, -0.89), Vector2(-0.035, -0.95),
	], center, radius), light)


## ODRAVETH monumental O: a voussoir ring with a raised keystone. Not the Seal.
static func draw_o_mark(ci: CanvasItem, center: Vector2, radius: float, stone: Color,
		accent: Color = VisualTokens.COLOR_GOLD_500, joint: Color = Color(0, 0, 0, 0)) -> void:
	var segments := 10
	var top := -PI * 0.5
	var gap := 0.028
	var span := TAU / float(segments)
	for i in segments:
		var a0 := top + span * (float(i) - 0.5) + gap
		var a1 := top + span * (float(i) + 0.5) - gap
		if i == 0:
			ci.draw_colored_polygon(arc_band(center, radius * 0.60, radius * 1.07, a0, a1, 8), accent)
		else:
			ci.draw_colored_polygon(arc_band(center, radius * 0.62, radius, a0, a1, 8), stone)
	if joint.a > 0.0:
		ci.draw_arc(center, radius * 0.81, 0, TAU, 72, joint, maxf(1.0, radius * 0.012), true)
	ci.draw_arc(center, radius * 0.52, 0, TAU, 72, Color(accent, 0.85), maxf(1.5, radius * 0.03), true)


static func draw_faction(ci: CanvasItem, faction: Faction.Id, center: Vector2, radius: float,
		primary: Color, secondary: Color, cut: Color) -> void:
	match faction:
		Faction.Id.ASHRAVAEL:
			_draw_ashravael(ci, center, radius, primary, secondary, cut)
		Faction.Id.NERQATHEN:
			_draw_nerqathen(ci, center, radius, primary, secondary)
		Faction.Id.DUMORYSS:
			_draw_dumoryss(ci, center, radius, primary, secondary, cut)
		Faction.Id.KHEVARUUN:
			_draw_khevaruun(ci, center, radius, primary, secondary, cut)
		_:
			_draw_neutral(ci, center, radius, primary, secondary)


## Broken blade/spear framed by an angular flame crown.
static func _draw_ashravael(ci: CanvasItem, c: Vector2, r: float, primary: Color, secondary: Color, cut: Color) -> void:
	var crown := _scaled([
		Vector2(-0.66, 0.16), Vector2(-0.86, -0.30), Vector2(-0.56, -0.10), Vector2(-0.50, -0.64),
		Vector2(-0.28, -0.22), Vector2(-0.18, -0.50), Vector2(0.0, -0.24), Vector2(0.18, -0.50),
		Vector2(0.28, -0.22), Vector2(0.50, -0.64), Vector2(0.56, -0.10), Vector2(0.86, -0.30),
		Vector2(0.66, 0.16), Vector2(0.40, 0.30), Vector2(0.0, 0.20), Vector2(-0.40, 0.30),
	], c, r)
	ci.draw_colored_polygon(crown, secondary)
	var upper := _scaled([
		Vector2(0, -1.0), Vector2(0.12, -0.74), Vector2(0.10, -0.14), Vector2(-0.10, -0.03), Vector2(-0.12, -0.74),
	], c, r)
	var lower := _scaled([
		Vector2(0.10, 0.07), Vector2(-0.10, 0.18), Vector2(-0.09, 0.60), Vector2(0.09, 0.60),
	], c, r, Vector2(0.045, 0.03))
	if cut.a > 0.0:
		_outline(ci, upper, cut, maxf(2.0, r * 0.07))
		_outline(ci, lower, cut, maxf(2.0, r * 0.07))
	ci.draw_colored_polygon(upper, primary)
	ci.draw_colored_polygon(lower, primary)
	ci.draw_colored_polygon(_scaled([
		Vector2(-0.34, 0.60), Vector2(0.34, 0.60), Vector2(0.30, 0.69), Vector2(-0.30, 0.69),
	], c, r, Vector2(0.045, 0.03)), primary)
	ci.draw_colored_polygon(_scaled([
		Vector2(-0.05, 0.69), Vector2(0.05, 0.69), Vector2(0.05, 0.90), Vector2(-0.05, 0.90),
	], c, r, Vector2(0.045, 0.03)), primary)
	ci.draw_colored_polygon(_scaled([
		Vector2(0, 0.88), Vector2(0.08, 0.96), Vector2(0, 1.04), Vector2(-0.08, 0.96),
	], c, r, Vector2(0.045, 0.03)), secondary)


## Segmented circle with an empty core and inward-pointing elements.
static func _draw_nerqathen(ci: CanvasItem, c: Vector2, r: float, primary: Color, secondary: Color) -> void:
	var segments := 6
	var span := TAU / float(segments)
	var top := -PI * 0.5
	for i in segments:
		var mid := top + span * (float(i) + 0.5)
		ci.draw_colored_polygon(arc_band(c, r * 0.72, r, mid - span * 0.5 + 0.10, mid + span * 0.5 - 0.10, 10), primary)
		var dir := Vector2(cos(mid), sin(mid))
		var side := Vector2(-dir.y, dir.x)
		ci.draw_colored_polygon(PackedVector2Array([
			c + dir * r * 0.66 + side * r * 0.13,
			c + dir * r * 0.36,
			c + dir * r * 0.66 - side * r * 0.13,
		]), secondary)
	ci.draw_arc(c, r * 0.24, 0, TAU, 40, Color(secondary, 0.55), maxf(1.0, r * 0.025), true)


## Broken, displaced ring split by a central fracture.
static func _draw_dumoryss(ci: CanvasItem, c: Vector2, r: float, primary: Color, secondary: Color, cut: Color) -> void:
	var shift := Vector2(r * 0.10, -r * 0.10)
	ci.draw_colored_polygon(arc_band(c, r * 0.66, r * 0.94, PI * 0.5 + 0.16, PI * 1.5 - 0.16, 26), primary)
	ci.draw_colored_polygon(arc_band(c + shift, r * 0.66, r * 0.94, -PI * 0.5 + 0.16, PI * 0.5 - 0.16, 26), primary)
	var fracture := _scaled([
		Vector2(0.06, -0.86), Vector2(-0.09, -0.44), Vector2(0.08, -0.12), Vector2(-0.07, 0.20),
		Vector2(0.09, 0.50), Vector2(-0.03, 0.88),
	], c, r)
	if cut.a > 0.0:
		ci.draw_polyline(fracture, cut, maxf(3.0, r * 0.16), true)
	ci.draw_polyline(fracture, secondary, maxf(2.0, r * 0.08), true)


## Interlocking shield plates.
static func _draw_khevaruun(ci: CanvasItem, c: Vector2, r: float, primary: Color, secondary: Color, cut: Color) -> void:
	var plate := [
		Vector2(0, -0.86), Vector2(0.42, -0.64), Vector2(0.42, 0.14), Vector2(0, 0.86),
		Vector2(-0.42, 0.14), Vector2(-0.42, -0.64),
	]
	var left := _scaled(plate, c, r, Vector2(-0.46, 0.10), 0.78)
	var right := _scaled(plate, c, r, Vector2(0.46, 0.10), 0.78)
	ci.draw_colored_polygon(left, secondary)
	ci.draw_colored_polygon(right, secondary)
	var front := _scaled(plate, c, r)
	if cut.a > 0.0:
		_outline(ci, front, cut, maxf(3.0, r * 0.09))
	ci.draw_colored_polygon(front, primary)
	# Chevron plate seams (interlocking plates), deliberately not a cross.
	ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.34, -r * 0.30), c + Vector2(0, -r * 0.04), c + Vector2(r * 0.34, -r * 0.30)]),
		Color(secondary, 0.9), maxf(1.5, r * 0.05), true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.34, r * 0.02), c + Vector2(0, r * 0.28), c + Vector2(r * 0.34, r * 0.02)]),
		Color(secondary, 0.55), maxf(1.0, r * 0.03), true)


static func _draw_neutral(ci: CanvasItem, c: Vector2, r: float, primary: Color, secondary: Color) -> void:
	var outer := _scaled([Vector2(0, -0.92), Vector2(0.70, 0), Vector2(0, 0.92), Vector2(-0.70, 0)], c, r)
	ci.draw_colored_polygon(outer, primary)
	_outline(ci, _scaled([Vector2(0, -0.52), Vector2(0.38, 0), Vector2(0, 0.52), Vector2(-0.38, 0)], c, r),
		secondary, maxf(1.5, r * 0.06))
