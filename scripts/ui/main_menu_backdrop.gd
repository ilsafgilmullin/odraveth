class_name MainMenuBackdrop
extends Control
## Visual Alpha Guardian Terrace of the Citadel of Nulmeris (temporary procedural
## environment art, D-054): bright high sky, distant cliffs and ring-crowned towers,
## arches with waterfalls, a stone balustrade and the terrace floor. The only
## motion is a slow waterfall shimmer, throttled to keep the menu cheap.

@export var motion_enabled := true
var _elapsed := 0.0
var _redraw_accum := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Production art (ArtAssets slot «guardian_terrace») replaces the procedural terrace.
	set_process(motion_enabled and not ArtAssets.has(&"guardian_terrace"))
	resized.connect(queue_redraw)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 1000.0)
	_redraw_accum += delta
	if _redraw_accum >= 1.0 / 12.0:
		_redraw_accum = 0.0
		queue_redraw()


func _gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))


func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	var art := ArtAssets.texture(&"guardian_terrace")
	if art != null:
		ArtAssets.draw_cover(self, art, Rect2(Vector2.ZERO, s))
		return
	var horizon := s.y * 0.62
	# High bright sky with a warm band near the horizon.
	_gradient(Rect2(0, 0, s.x, horizon * 0.6), Color("cfe1e6"), Color("e3edee"))
	_gradient(Rect2(0, horizon * 0.6, s.x, horizon * 0.4), Color("e3edee"), Color("efeadf"))
	# Light shafts from the upper left.
	for i in 3:
		var x0 := s.x * (0.08 + float(i) * 0.12)
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + s.x * 0.05, 0),
			Vector2(x0 + s.x * 0.28, horizon), Vector2(x0 + s.x * 0.18, horizon)]), Color(1, 1, 1, 0.10))
	# Distant cliffs and Citadel towers.
	draw_colored_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(0, horizon * 0.70), Vector2(s.x * 0.08, horizon * 0.62),
		Vector2(s.x * 0.20, horizon * 0.74), Vector2(s.x * 0.34, horizon * 0.66), Vector2(s.x * 0.50, horizon * 0.78),
		Vector2(s.x * 0.66, horizon * 0.64), Vector2(s.x * 0.82, horizon * 0.72), Vector2(s.x, horizon * 0.60), Vector2(s.x, horizon)]),
		Color("c4c9c5"))
	for tower: Array in [[0.05, 0.42, 0.02], [0.49, 0.44, 0.018]]:
		var tx: float = s.x * float(tower[0])
		var top: float = horizon * float(tower[1])
		var w: float = s.x * float(tower[2])
		draw_rect(Rect2(tx - w * 0.5, top, w, horizon - top), Color("b7b0a3"))
		draw_rect(Rect2(tx - w * 0.5, top, w * 0.35, horizon - top), Color(1, 1, 1, 0.18))
		draw_arc(Vector2(tx, top - w * 0.6), w * 0.85, 0, TAU, 32, Color(VisualTokens.COLOR_STEEL_700, 0.5), 3.0, true)
		draw_arc(Vector2(tx, top - w * 0.6), w * 0.5, 0, TAU, 24, Color(VisualTokens.COLOR_GOLD_500, 0.55), 2.0, true)
	# Arcade of the terrace with waterfalls seen through the arches (right side only,
	# behind the menu panel; the Guardian side stays open sky).
	var arcade_top := horizon * 0.46
	for i in 4:
		var ax := s.x * (0.52 + float(i) * 0.125)
		var aw := s.x * 0.085
		var arch := Rect2(ax, arcade_top, aw, horizon - arcade_top)
		draw_rect(Rect2(arch.position.x - s.x * 0.018, arch.position.y - s.y * 0.03, s.x * 0.018, arch.size.y + s.y * 0.03),
			Color("cfc5b4"))
		var radius := aw * 0.5
		var points := PackedVector2Array([Vector2(arch.position.x, arch.end.y)])
		for k in 17:
			var angle := PI + PI * float(k) / 16.0
			points.append(Vector2(arch.get_center().x + cos(angle) * radius, arch.position.y + radius + sin(angle) * radius))
		points.append(arch.end)
		draw_colored_polygon(points, Color("dbe8ea"))
		var fall := Rect2(arch.get_center().x - aw * 0.09, arch.position.y + radius * 0.8, aw * 0.18, arch.size.y - radius * 0.8)
		draw_rect(fall, Color(0.48, 0.77, 0.80, 0.45))
		for k in 3:
			var y := fall.position.y + fmod(_elapsed * 40.0 + float(k) * fall.size.y / 3.0, fall.size.y)
			draw_line(Vector2(fall.position.x, y), Vector2(fall.end.x, y + 5.0), Color(1, 1, 1, 0.4), 1.5)
	draw_rect(Rect2(s.x * 0.50, arcade_top - s.y * 0.05, s.x * 0.52, s.y * 0.025), Color("cfc5b4"))
	draw_line(Vector2(s.x * 0.50, arcade_top - s.y * 0.025), Vector2(s.x, arcade_top - s.y * 0.025), Color(VisualTokens.COLOR_GOLD_700, 0.45), 2.0)
	# Balustrade along the terrace edge.
	draw_rect(Rect2(0, horizon - s.y * 0.012, s.x, s.y * 0.05), Color("d2c8b7"))
	for i in int(s.x / 34.0) + 1:
		var bx := float(i) * 34.0
		draw_rect(Rect2(bx + 8.0, horizon + s.y * 0.006, 12.0, s.y * 0.03), Color("bfb4a1"))
	draw_line(Vector2(0, horizon - s.y * 0.012), Vector2(s.x, horizon - s.y * 0.012), Color(VisualTokens.COLOR_GOLD_700, 0.55), 2.0)
	# Terrace floor with perspective joints and an engraved ring around the Guardian.
	var floor_top := horizon + s.y * 0.04
	_gradient(Rect2(0, floor_top, s.x, s.y - floor_top), Color("ddd3c2"), Color("c9bea9"))
	var vanish := Vector2(s.x * 0.26, horizon)
	for i in 15:
		var fx := -s.x * 0.4 + float(i) * s.x * 0.13
		draw_line(vanish.lerp(Vector2(fx, s.y), (floor_top - horizon) / (s.y - horizon)), Vector2(fx, s.y),
			Color(0.45, 0.40, 0.33, 0.10), 1.0)
	for i in 4:
		var t := float(i + 1) / 5.0
		var y := floor_top + (s.y - floor_top) * t * t
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.45, 0.40, 0.33, 0.08), 1.0)
	draw_set_transform(Vector2(s.x * 0.235, s.y * 0.86), 0.0, Vector2(1.0, 0.18))
	draw_arc(Vector2.ZERO, s.x * 0.20, 0, TAU, 96, Color(VisualTokens.COLOR_GOLD_700, 0.25), 6.0, true)
	draw_arc(Vector2.ZERO, s.x * 0.15, 0, TAU, 96, Color(VisualTokens.COLOR_MAGIC_500, 0.18), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
