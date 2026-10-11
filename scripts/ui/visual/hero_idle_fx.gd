class_name HeroIdleFx
extends RefCounted
## Per-hero idle character drawn as separate layers around the hero art: the art
## itself is never warped. Deterministic functions of time (no RNG), at most
## MAX_PARTICLES primitives per portrait. Anchors are normalised art coordinates
## (0..1 of the texture) and are mapped through the portrait's crop.
##   Кежарин — тепловое напряжение и искры · Вхоразель — медленные потоки душ к жезлу
##   Сирравет — плавные кольца искажения у левой руки · Тажирион — дыхание защитного щита

const MAX_PARTICLES := 14
const EMBERS := 12
const WISPS := 6
const WISP_TAIL := 6
const MOTES := 8
const ANCHORS := {
	HeroCatalog.KEZHARYN: {},
	HeroCatalog.VHORAZEL: {"orb": Vector2(0.215, 0.115), "core": Vector2(0.45, 0.265), "source": Vector2(0.45, 0.62)},
	HeroCatalog.SYRRAVETH: {"hand": Vector2(0.25, 0.165)},
	HeroCatalog.TAZHYRION: {"ward": Vector2(0.5, 0.47), "shield": Vector2(0.8, 0.56)},
}
const FIRE := Color(1.0, 0.62, 0.28)
const EMBER := Color(0.93, 0.33, 0.17)
const SOUL := Color(0.47, 0.83, 0.84)
const DISTORT := Color(0.73, 0.59, 0.9)
const ECHO := Color(0.86, 0.47, 0.78)
const WARD := Color(0.85, 0.76, 0.49)


## Number of animated primitives a hero's idle effect uses (performance contract).
static func particle_count(hero_id: StringName) -> int:
	match hero_id:
		HeroCatalog.KEZHARYN:
			return EMBERS + 1
		HeroCatalog.VHORAZEL:
			return WISPS + 2
		HeroCatalog.SYRRAVETH:
			return 3 + 1 + 6
		HeroCatalog.TAZHYRION:
			return MOTES + 2
	return 0


## [param art_to_canvas] maps a normalised art point to canvas coordinates.
## [param back] = true draws the layer behind the figure, false the sparse front layer.
static func draw(ci: CanvasItem, hero_id: StringName, area: Rect2, art_to_canvas: Callable, time: float,
		strength: float, back: bool) -> void:
	if strength <= 0.01 or area.size.x < 24.0:
		return
	var unit := minf(area.size.x, area.size.y) / 300.0
	match hero_id:
		HeroCatalog.KEZHARYN:
			_kezharyn(ci, area, time, strength, unit, back)
		HeroCatalog.VHORAZEL:
			_vhorazel(ci, area, art_to_canvas, time, strength, unit, back)
		HeroCatalog.SYRRAVETH:
			_syrraveth(ci, art_to_canvas, time, strength, unit, back)
		HeroCatalog.TAZHYRION:
			_tazhyrion(ci, area, art_to_canvas, time, strength, unit, back)


static func _hash(i: int, salt: float) -> float:
	var v := sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453
	return v - floorf(v)


static func _glow(ci: CanvasItem, centre: Vector2, radius: float, color: Color, alpha: float) -> void:
	for k in 4:
		var f := 1.0 - float(k) * 0.22
		ci.draw_circle(centre, radius * f, Color(color, alpha * (0.25 + float(k) * 0.25)))


## Restless heat rising from the ground and embers in front of and behind the figure: tension before the strike.
static func _kezharyn(ci: CanvasItem, area: Rect2, t: float, s: float, unit: float, back: bool) -> void:
	if back:
		var tension := 0.5 + 0.5 * sin(t * 3.1) * sin(t * 1.7 + 0.6)
		var heat := Color(FIRE, (0.22 + 0.18 * tension) * s)
		var clear := Color(FIRE, 0.0)
		var top := area.end.y - area.size.y * 0.42
		ci.draw_polygon(PackedVector2Array([Vector2(area.position.x, top), Vector2(area.end.x, top), area.end,
			Vector2(area.position.x, area.end.y)]), PackedColorArray([clear, clear, heat, heat]))
	for i in EMBERS:
		if (i % 3 == 0) != back:
			continue
		var phase := fposmod(t * (0.16 + 0.1 * _hash(i, 1.0)) + _hash(i, 2.0), 1.0)
		var x := area.position.x + area.size.x * (0.1 + 0.8 * _hash(i, 3.0)) + sin(t * 1.4 + float(i)) * 6.0 * unit
		var y := area.end.y - area.size.y * 0.04 - phase * area.size.y * 0.7
		var fade := pow(1.0 - phase, 0.9) * minf(1.0, phase * 8.0)
		var r := (2.8 + 2.4 * _hash(i, 4.0)) * unit * (1.0 - phase * 0.45)
		var color := FIRE.lerp(EMBER, phase)
		ci.draw_circle(Vector2(x, y), r * 2.4, Color(color, 0.24 * fade * s))
		ci.draw_circle(Vector2(x, y), r, Color(color.lightened(0.3), fade * s))


## Slow soul currents drift up the figure into the raised staff orb.
static func _vhorazel(ci: CanvasItem, area: Rect2, to_canvas: Callable, t: float, s: float, unit: float,
		back: bool) -> void:
	var anchors: Dictionary = ANCHORS[HeroCatalog.VHORAZEL]
	var orb: Vector2 = to_canvas.call(anchors["orb"])
	if back:
		var breath := 0.5 + 0.5 * sin(t * TAU * 0.22)
		_glow(ci, orb, area.size.x * (0.12 + 0.02 * breath), SOUL, (0.08 + 0.07 * breath) * s)
		_glow(ci, to_canvas.call(anchors["core"]), area.size.x * 0.06, SOUL, (0.05 + 0.05 * breath) * s)
		return
	var source: Vector2 = to_canvas.call(anchors["source"])
	for i in WISPS:
		var tail := PackedVector2Array()
		var colors := PackedColorArray()
		for k in WISP_TAIL:
			var p := fposmod(t * 0.06 + float(i) / float(WISPS) - float(k) * 0.03, 1.0)
			var bend := sin(p * PI * 2.0 + float(i) * 1.3) * area.size.x * 0.12 * (1.0 - p)
			tail.append(source.lerp(orb, p) + Vector2(bend, 0.0))
			var fade := sin(p * PI) * (1.0 - float(k) / float(WISP_TAIL))
			colors.append(Color(SOUL.lightened(0.25), 0.85 * fade * s))
		ci.draw_polyline_colors(tail, colors, maxf(2.0, 3.2 * unit), true)
		ci.draw_circle(tail[0], 3.0 * unit, colors[0])


## Floating rings of distortion around the left hand, with a faint chromatic echo
## and a slow ripple — reality bending, not the image.
static func _syrraveth(ci: CanvasItem, to_canvas: Callable, t: float, s: float, unit: float, back: bool) -> void:
	var hand: Vector2 = to_canvas.call(ANCHORS[HeroCatalog.SYRRAVETH]["hand"])
	if back:
		for ring in 3:
			var radius := (34.0 + float(ring) * 20.0 + 3.0 * sin(t * 0.9 + float(ring))) * unit
			var tilt := t * (0.25 + 0.12 * float(ring)) * (1.0 if ring % 2 == 0 else -1.0)
			_ellipse(ci, hand + Vector2(2.0 * unit, 0.0), radius, radius * 0.55, tilt, Color(ECHO, 0.16 * s), 1.6 * unit)
			_ellipse(ci, hand, radius, radius * 0.55, tilt, Color(DISTORT, (0.45 - float(ring) * 0.1) * s), 2.0 * unit)
		var ripple := fposmod(t / 3.2, 1.0)
		ci.draw_arc(hand, (20.0 + ripple * 90.0) * unit, 0.0, TAU, 48, Color(DISTORT, 0.3 * (1.0 - ripple) * s),
			1.5 * unit, true)
		return
	for i in 6:
		var angle := t * 0.5 + float(i) * TAU / 6.0
		var orbit := (44.0 + 10.0 * sin(t * 0.7 + float(i))) * unit
		var mote := hand + Vector2(cos(angle) * orbit, sin(angle) * orbit * 0.55)
		ci.draw_circle(mote, 2.2 * unit, Color(DISTORT.lightened(0.3), 0.7 * s))


static func _ellipse(ci: CanvasItem, centre: Vector2, rx: float, ry: float, tilt: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		points.append(centre + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	ci.draw_polyline(points, color, maxf(1.0, width), true)


## A measured breathing ward behind the figure and a steady shield glint; slow golden motes.
static func _tazhyrion(ci: CanvasItem, area: Rect2, to_canvas: Callable, t: float, s: float, unit: float,
		back: bool) -> void:
	var anchors: Dictionary = ANCHORS[HeroCatalog.TAZHYRION]
	var breath := 0.5 + 0.5 * sin(t * TAU * 0.2)
	if back:
		var centre: Vector2 = to_canvas.call(anchors["ward"])
		var k := 1.0 + 0.02 * breath
		var half := Vector2(area.size.x * 0.4, area.size.y * 0.42) * k
		var hexagon := PackedVector2Array([
			centre + Vector2(0.0, -half.y), centre + Vector2(half.x, -half.y * 0.55),
			centre + Vector2(half.x, half.y * 0.55), centre + Vector2(0.0, half.y),
			centre + Vector2(-half.x, half.y * 0.55), centre + Vector2(-half.x, -half.y * 0.55),
		])
		ci.draw_colored_polygon(hexagon, Color(WARD, (0.04 + 0.03 * breath) * s))
		var outline := PackedVector2Array(hexagon)
		outline.append(hexagon[0])
		ci.draw_polyline(outline, Color(WARD, (0.22 + 0.16 * breath) * s), maxf(1.5, 3.0 * unit), true)
		for i in MOTES:
			var phase := fposmod(t * 0.05 + _hash(i, 5.0), 1.0)
			var mote := Vector2(area.position.x + area.size.x * (0.08 + 0.84 * _hash(i, 6.0)),
				area.end.y - phase * area.size.y * 0.55)
			ci.draw_circle(mote, 2.0 * unit, Color(WARD, 0.5 * sin(phase * PI) * s))
		return
	_glow(ci, to_canvas.call(anchors["shield"]), area.size.x * 0.07, WARD, (0.05 + 0.06 * breath) * s)
