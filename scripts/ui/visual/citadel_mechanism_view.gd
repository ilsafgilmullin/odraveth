class_name CitadelMechanismView
extends Control
## Visual Alpha ring mechanism of the Citadel used by Opponent Search. Pure
## presentation: the screen drives angles/glow/faction; this view only draws.

const SEAL_ORDER: Array[Faction.Id] = [Faction.Id.ASHRAVAEL, Faction.Id.NERQATHEN, Faction.Id.DUMORYSS,
	Faction.Id.KHEVARUUN]

var outer_angle := 0.0
var inner_angle := 0.0
var glow := 0.0
var lock_glow := 0.0
var shown_faction := -1
var highlight_faction := -1


static func seal_angle(faction: Faction.Id) -> float:
	var index := SEAL_ORDER.find(faction)
	return -PI * 0.5 + PI * 0.5 * float(maxi(index, 0))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.47
	if r < 20.0:
		return
	var c := size * 0.5
	var light := VisualTokens.COLOR_MAGIC_300

	for i in 6:
		draw_circle(c, r * (1.18 - float(i) * 0.03), Color(light, 0.018 * glow))

	# Production ring layers (alpha PNG) replace the procedural rings when present.
	var outer_art := ArtAssets.texture(&"convergence_ring_outer")
	var inner_art := ArtAssets.texture(&"convergence_ring_inner")
	if outer_art != null:
		draw_set_transform(c, outer_angle, Vector2.ONE)
		draw_texture_rect(outer_art, Rect2(-Vector2(r, r), Vector2(r, r) * 2.0), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if inner_art != null:
		draw_set_transform(c, inner_angle, Vector2.ONE)
		draw_texture_rect(inner_art, Rect2(-Vector2(r, r) * 0.74, Vector2(r, r) * 1.48), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if outer_art == null:
		_draw_outer_ring(c, r)

	# Faction seal sockets.
	for faction: Faction.Id in SEAL_ORDER:
		var a := seal_angle(faction)
		var p := c + Vector2(cos(a), sin(a)) * r * 0.90
		var active := faction == highlight_faction
		var socket := r * 0.125
		draw_circle(p, socket * 1.12, Color("4b443b"))
		draw_circle(p, socket, Color("d8cfbf") if not active else Color("efe8da"))
		if active:
			draw_arc(p, socket * 1.20, 0.0, TAU, 40, Color(light, 0.35 + 0.65 * lock_glow), maxf(2.0, r * 0.012), true)
		var tone := NulmerisEmblems.faction_color(faction) if active else Color("7d7468")
		var second := NulmerisEmblems.faction_secondary(faction) if active else Color("a69c8c")
		NulmerisEmblems.draw_faction(self, faction, p, socket * 0.78, tone, second, Color("d8cfbf") if not active else Color("efe8da"))

	if inner_art != null:
		_draw_window(c, r, light)
		return
	# Steel ring with notches (rotates).
	draw_arc(c, r * 0.70, 0.0, TAU, 96, VisualTokens.COLOR_STEEL_700, r * 0.07, true)
	for i in 36:
		var a := outer_angle + TAU * float(i) / 36.0
		var d := Vector2(cos(a), sin(a))
		var long := i % 3 == 0
		draw_line(c + d * r * (0.665 if long else 0.68), c + d * r * 0.735, Color("c9bfae", 0.85 if long else 0.45),
			maxf(1.0, r * (0.010 if long else 0.006)))
	var marker := outer_angle
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(cos(marker), sin(marker)) * r * 0.775,
		c + Vector2(cos(marker + 0.05), sin(marker + 0.05)) * r * 0.735,
		c + Vector2(cos(marker - 0.05), sin(marker - 0.05)) * r * 0.735,
	]), VisualTokens.COLOR_GOLD_300)

	# Gold inner ring with rune ticks (counter-rotates).
	draw_arc(c, r * 0.60, 0.0, TAU, 96, VisualTokens.COLOR_GOLD_500.darkened(0.15), r * 0.018, true)
	for i in 12:
		var a := inner_angle + TAU * float(i) / 12.0
		var d := Vector2(cos(a), sin(a))
		var t := Vector2(-d.y, d.x)
		draw_line(c + d * r * 0.56 + t * r * 0.02, c + d * r * 0.56 - t * r * 0.02, VisualTokens.COLOR_GOLD_300, maxf(1.5, r * 0.008))

	_draw_window(c, r, light)


func _draw_outer_ring(c: Vector2, r: float) -> void:
	draw_arc(c, r * 0.90, 0.0, TAU, 96, Color("8e8475"), r * 0.20, true)
	draw_arc(c, r * 0.995, 0.0, TAU, 96, Color("b9ae9b"), r * 0.025, true)
	draw_arc(c, r * 0.805, 0.0, TAU, 96, Color("5f574c"), r * 0.02, true)
	for i in 24:
		var a := TAU * float(i) / 24.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.81, c + d * r * 0.99, Color(0.32, 0.29, 0.25, 0.35), maxf(1.0, r * 0.006))


## Luminous central window: the live faction reveal stays procedural on top of any art.
func _draw_window(c: Vector2, r: float, light: Color) -> void:
	var window_r := r * 0.50
	draw_circle(c, window_r, Color("1c2427"))
	for i in 8:
		var k := 1.0 - float(i) / 8.0
		draw_circle(c, window_r * k, Color(light.lerp(Color.WHITE, 1.0 - k), 0.05 + 0.10 * glow))
	draw_arc(c, window_r, 0.0, TAU, 96, Color(light, 0.25 + 0.55 * glow), maxf(2.0, r * 0.012), true)
	if shown_faction >= 0:
		var faction := shown_faction as Faction.Id
		var emblem_r := window_r * 0.62
		draw_circle(c, emblem_r * 1.15, Color(NulmerisEmblems.faction_secondary(faction), 0.10 + 0.20 * lock_glow))
		NulmerisEmblems.draw_faction(self, faction, c, emblem_r, NulmerisEmblems.faction_color(faction).lightened(0.15),
			NulmerisEmblems.faction_secondary(faction).lightened(0.25), Color("1c2427"))
	else:
		NulmerisEmblems.draw_seal(self, c, window_r * 0.55, Color(light, 0.35 + 0.4 * glow), Color(1, 1, 1, 0.5 * glow))
	if lock_glow > 0.0:
		for i in 16:
			var a := TAU * float(i) / 16.0
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * window_r * 1.02, c + d * window_r * (1.02 + 0.12 * lock_glow), Color(light, 0.35 * lock_glow),
				maxf(1.0, r * 0.006))
