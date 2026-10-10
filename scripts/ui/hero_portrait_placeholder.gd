class_name HeroPortraitPlaceholder
extends Control
## Visual Alpha TEMPORARY hero portrait: arched Citadel niche, faction backlight, faction
## symbol and a rim-lit silhouette that preserves the approved presentation gender.
## No face, costume, weapon or equipment canon is invented; final character art replaces it.

const IS_TEMPORARY_ASSET := true

var hero_id: StringName = &""
var accent := VisualTokens.COLOR_STEEL_500
var presentation_gender := ""
var faction: Faction.Id = Faction.Id.NEUTRAL
var compact := false


func configure(id: StringName) -> void:
	hero_id = id
	accent = HeroPresentation.faction_accent(id)
	presentation_gender = HeroPresentation.presentation_gender(id)
	faction = HeroCatalog.faction_of(id) if HeroCatalog.has_hero(id) else Faction.Id.NEUTRAL
	queue_redraw()


func is_temporary_asset() -> bool:
	return not ArtAssets.has(ArtAssets.hero_slot(hero_id))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 40.0 or s.y <= 40.0:
		return
	var tone := NulmerisEmblems.faction_color(faction)
	var glow := NulmerisEmblems.faction_secondary(faction)
	var inset := 6.0 if compact else 10.0
	var rect := Rect2(Vector2(inset, inset), s - Vector2(inset, inset) * 2.0)
	var stone := Color("cfc6b6")
	draw_rect(rect, stone)
	# Approved production portrait (crop-safe alpha PNG) replaces the silhouette.
	var art: Texture2D = null
	if hero_id != &"":
		art = ArtAssets.texture(ArtAssets.hero_slot(hero_id))
	if art != null:
		_gradient_niche_backlight(rect)
		ArtAssets.draw_cover(self, art, rect)
		draw_rect(rect, VisualTokens.COLOR_STEEL_700, false, 2.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(4.0, rect.size.y * 0.018))), accent)
		return

	var area := rect.grow(-maxf(4.0, rect.size.x * 0.05))
	if area.size.y < area.size.x * 0.62:
		area = Rect2(Vector2(area.get_center().x - area.size.y * 0.8, area.position.y),
			Vector2(area.size.y * 1.6, area.size.y))
	var niche := _niche_polygon(area)
	var top := VisualTokens.COLOR_STONE_050.lerp(glow, 0.55)
	var bottom := tone.darkened(0.35)
	var colors := PackedColorArray()
	var min_y := rect.position.y
	var max_y := rect.end.y
	for point: Vector2 in niche:
		colors.append(top.lerp(bottom, clampf((point.y - min_y) / maxf(1.0, max_y - min_y), 0.0, 1.0)))
	draw_polygon(niche, colors)

	var emblem_center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.30)
	var emblem_r := minf(rect.size.x, rect.size.y) * 0.30
	for i in 4:
		draw_circle(emblem_center, emblem_r * (1.5 - float(i) * 0.18), Color(1.0, 0.98, 0.9, 0.06))
	NulmerisEmblems.draw_faction(self, faction, emblem_center, emblem_r, Color(tone, 0.55), Color(glow.lightened(0.2), 0.75),
		Color(0, 0, 0, 0))

	_draw_silhouette(Rect2(rect.position, Vector2(rect.size.x, area.end.y - rect.position.y)), tone, glow)

	var closed := PackedVector2Array(niche)
	closed.append(niche[0])
	draw_polyline(closed, VisualTokens.COLOR_GOLD_500.darkened(0.1), maxf(2.0, rect.size.x * 0.012), true)
	draw_rect(rect, VisualTokens.COLOR_STEEL_700, false, 2.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(4.0, rect.size.y * 0.018))), accent)


func _niche_polygon(area: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := area.size.x * 0.5
	var spring := minf(area.position.y + radius * 0.92, area.end.y - 2.0)
	var steps := 24
	points.append(Vector2(area.position.x, area.end.y))
	for i in steps + 1:
		var angle := PI + PI * float(i) / float(steps)
		var point := Vector2(area.get_center().x + cos(angle) * radius, spring + sin(angle) * radius * 0.92)
		point.y -= (1.0 - absf(cos(angle))) * radius * 0.12
		points.append(point)
	points.append(Vector2(area.end.x, area.end.y))
	return points


func _draw_silhouette(rect: Rect2, tone: Color, glow: Color) -> void:
	var female := presentation_gender == "female"
	var cx := rect.get_center().x
	var base := rect.end.y
	var h := rect.size.y
	var w := rect.size.x
	var head_r := h * (0.085 if female else 0.092)
	var head := Vector2(cx, rect.position.y + h * 0.43)
	var shoulder := w * (0.30 if female else 0.37)
	var neck := head_r * (0.42 if female else 0.55)
	var shoulder_y := head.y + head_r * 1.65
	var body := PackedVector2Array([
		Vector2(cx - neck, head.y + head_r * 0.7),
		Vector2(cx + neck, head.y + head_r * 0.7),
		Vector2(cx + neck * 1.2, shoulder_y - head_r * 0.35),
		Vector2(cx + shoulder, shoulder_y + head_r * 0.25),
		Vector2(cx + shoulder * (0.96 if female else 1.08), base),
		Vector2(cx - shoulder * (0.96 if female else 1.08), base),
		Vector2(cx - shoulder, shoulder_y + head_r * 0.25),
		Vector2(cx - neck * 1.2, shoulder_y - head_r * 0.35),
	])
	var figure := VisualTokens.COLOR_STEEL_900.lerp(tone, 0.18)
	var rim := Color(glow.lightened(0.35), 0.9)
	var rim_width := maxf(2.0, w * 0.012)
	var rim_path := PackedVector2Array()
	for index in [4, 3, 2, 1, 0, 7, 6, 5]:
		rim_path.append(body[index])
	draw_polyline(rim_path, rim, rim_width * 2.0, true)
	draw_circle(head, head_r + rim_width, rim)
	draw_colored_polygon(body, figure)
	draw_circle(head, head_r, figure)
	var mantle := PackedVector2Array([
		Vector2(cx - shoulder * 0.86, shoulder_y + head_r * 0.6),
		Vector2(cx, shoulder_y + head_r * (1.4 if female else 1.1)),
		Vector2(cx + shoulder * 0.86, shoulder_y + head_r * 0.6),
	])
	draw_polyline(mantle, Color(glow, 0.45), maxf(1.5, w * 0.008), true)


func _gradient_niche_backlight(rect: Rect2) -> void:
	var glow := NulmerisEmblems.faction_secondary(faction)
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([VisualTokens.COLOR_STONE_050.lerp(glow, 0.5),
		VisualTokens.COLOR_STONE_050.lerp(glow, 0.5), accent.darkened(0.35), accent.darkened(0.35)]))
