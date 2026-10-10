class_name CardArtSlot
extends Control
## Artwork slot with exact-card resolver and a deterministic Visual Alpha fallback.
## The fallback is an art-directed TEMPORARY composition (faction palette, type motif,
## faction symbol, per-card variation). It is not final card illustration and never
## shows developer text; `uses_placeholder` keeps the temporary status explicit.

var card_id: StringName = &""
var card_type: CardEnums.Type = CardEnums.Type.CREATURE
var faction: Faction.Id = Faction.Id.NEUTRAL
var rarity: CardEnums.Rarity = CardEnums.Rarity.COMMON
var resolved_path := ""
var uses_placeholder := true

var _texture_rect: TextureRect
var _placeholder_label: Label
var _accent := VisualTokens.COLOR_STEEL_500
var _variant := {}


func _ready() -> void:
	_ensure_children()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func configure(presentation: CardPresentation) -> void:
	if presentation == null:
		return
	_ensure_children()
	card_id = presentation.id
	card_type = presentation.card_type
	faction = presentation.faction
	rarity = presentation.rarity
	_accent = presentation.faction_accent
	resolved_path = CardArtResolver.art_path(card_id)
	var texture := CardArtResolver.resolve(card_id)
	uses_placeholder = texture == null
	_texture_rect.texture = texture
	_texture_rect.visible = texture != null
	_placeholder_label.visible = false
	_placeholder_label.text = ""
	_variant = variant_for(card_id)
	queue_redraw()


## Deterministic composition parameters derived only from the card ID.
static func variant_for(id: StringName) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(id))
	return {
		"light_x": rng.randf_range(0.30, 0.70),
		"light_y": rng.randf_range(0.18, 0.34),
		"horizon": rng.randf_range(0.70, 0.80),
		"rays": rng.randi_range(5, 11),
		"ray_phase": rng.randf_range(0.0, TAU),
		"arch_pointed": rng.randf() < 0.5,
		"rings": rng.randi_range(2, 3),
		"symbol_shift": rng.randf_range(-0.06, 0.06),
		"tilt": rng.randf_range(-0.22, 0.22),
		"steps": rng.randi_range(2, 4),
	}


func _ensure_children() -> void:
	if _texture_rect != null:
		return
	clip_contents = true
	_texture_rect = TextureRect.new()
	_texture_rect.name = "ResolvedArtwork"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_placeholder_label = Label.new()
	_placeholder_label.name = "ArtworkFallbackLabel"
	_placeholder_label.visible = false
	_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placeholder_label)


func _draw() -> void:
	if not uses_placeholder or _variant.is_empty():
		return
	var s := size
	if s.x < 8.0 or s.y < 8.0:
		return
	var tone := NulmerisEmblems.faction_color(faction)
	var glow := NulmerisEmblems.faction_secondary(faction)
	var sky := VisualTokens.COLOR_STONE_050.lerp(glow, 0.22)
	var deep := tone.darkened(0.45).lerp(VisualTokens.COLOR_STEEL_900, 0.35)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([sky, sky, deep, deep]))

	var light := Vector2(s.x * float(_variant["light_x"]), s.y * float(_variant["light_y"]))
	for i in 5:
		draw_circle(light, minf(s.x, s.y) * (0.52 - float(i) * 0.09), Color(1.0, 0.97, 0.88, 0.07))

	match card_type:
		CardEnums.Type.SPELL:
			_draw_spell(s, light, tone, glow)
		CardEnums.Type.ARTIFACT:
			_draw_artifact(s, tone, glow)
		CardEnums.Type.CURSE:
			_draw_curse(s, tone, glow)
		_:
			_draw_creature(s, tone, glow)

	_draw_ground(s, tone)
	if rarity == CardEnums.Rarity.LEGENDARY:
		_draw_legendary_filigree(s)
	_draw_vignette(s)


func _draw_creature(s: Vector2, tone: Color, glow: Color) -> void:
	var horizon := s.y * float(_variant["horizon"])
	var cx := s.x * (0.5 + float(_variant["symbol_shift"]))
	var top := s.y * (0.16 if bool(_variant["arch_pointed"]) else 0.08)
	var stone := VisualTokens.COLOR_STONE_300.lerp(tone, 0.12)
	var rad := minf(s.x * 0.23, (horizon - top) * 0.46)
	var arch_w := rad * 2.0
	var spring_y := top + rad
	var opening := PackedVector2Array()
	var steps := 18
	for i in steps + 1:
		var angle := PI + PI * float(i) / float(steps)
		var point := Vector2(cx + cos(angle) * rad, spring_y + sin(angle) * rad)
		if bool(_variant["arch_pointed"]):
			point.y -= (1.0 - absf(cos(angle))) * rad * 0.35
		opening.append(point)
	opening.append(Vector2(cx + rad, horizon))
	opening.append(Vector2(cx - rad, horizon))
	var pillar := s.x * 0.07
	draw_rect(Rect2(cx - rad - pillar, spring_y, pillar, horizon - spring_y), stone)
	draw_rect(Rect2(cx + rad, spring_y, pillar, horizon - spring_y), stone)
	draw_colored_polygon(opening, Color(glow, 0.38).lerp(VisualTokens.COLOR_STONE_050, 0.35))
	var closed := PackedVector2Array(opening)
	closed.append(opening[0])
	draw_polyline(closed, stone.darkened(0.25), maxf(2.0, s.x * 0.012), true)
	var radius := minf(arch_w * 0.38, (horizon - top) * 0.30)
	var center := Vector2(cx, top + (horizon - top) * 0.56)
	draw_circle(center, radius * 1.25, Color(glow, 0.22))
	NulmerisEmblems.draw_faction(self, faction, center, radius, tone.darkened(0.25), glow.lightened(0.1),
		Color(VisualTokens.COLOR_STONE_050, 0.55))


func _draw_spell(s: Vector2, light: Vector2, tone: Color, glow: Color) -> void:
	var center := Vector2(s.x * 0.5, s.y * 0.48)
	var base_r := minf(s.x, s.y) * 0.36
	var rays := int(_variant["rays"])
	var phase := float(_variant["ray_phase"])
	for i in rays:
		var angle := phase + TAU * float(i) / float(rays)
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * base_r * 0.35, center + dir * base_r * 1.55, Color(glow, 0.30), maxf(1.5, s.x * 0.008), true)
	for ring in int(_variant["rings"]):
		var r := base_r * (1.0 - float(ring) * 0.24)
		draw_arc(center, r, 0.0, TAU, 64, Color(tone.lightened(0.15), 0.85 - float(ring) * 0.18), maxf(1.5, s.x * 0.010), true)
		for tick in 16:
			var a := TAU * float(tick) / 16.0 + float(ring) * 0.2
			var d := Vector2(cos(a), sin(a))
			draw_line(center + d * r * 0.93, center + d * r * 1.04, Color(tone, 0.7), maxf(1.0, s.x * 0.006))
	draw_line(light, center, Color(1, 1, 1, 0.18), maxf(2.0, s.x * 0.016), true)
	draw_circle(center, base_r * 0.42, Color(glow, 0.45))
	NulmerisEmblems.draw_faction(self, faction, center, base_r * 0.36, tone.darkened(0.2), VisualTokens.COLOR_STONE_050,
		Color(0, 0, 0, 0))


func _draw_artifact(s: Vector2, tone: Color, glow: Color) -> void:
	var center := Vector2(s.x * 0.5, s.y * 0.47)
	var r := minf(s.x, s.y) * 0.36
	var tilt := float(_variant["tilt"])
	var steel := VisualTokens.COLOR_STEEL_700.lerp(tone, 0.25)
	draw_line(Vector2(center.x, s.y * 0.04), Vector2(center.x, s.y * 0.90), Color(steel, 0.85), maxf(3.0, s.x * 0.02))
	draw_arc(center, r, tilt, tilt + TAU, 72, steel, maxf(4.0, s.x * 0.03), true)
	for tick in 24:
		var a := tilt + TAU * float(tick) / 24.0
		var d := Vector2(cos(a), sin(a))
		draw_line(center + d * r, center + d * r * 1.10, steel, maxf(2.0, s.x * 0.012))
	var inner_r := r * 0.66
	draw_arc(center + Vector2(r * 0.06, 0), inner_r, -tilt, -tilt + TAU, 64, VisualTokens.COLOR_GOLD_500.darkened(0.1),
		maxf(2.0, s.x * 0.014), true)
	draw_circle(center, inner_r * 0.62, Color(glow, 0.5))
	NulmerisEmblems.draw_faction(self, faction, center, inner_r * 0.55, tone.darkened(0.25), VisualTokens.COLOR_STONE_050,
		Color(0, 0, 0, 0))


func _draw_curse(s: Vector2, tone: Color, glow: Color) -> void:
	var center := Vector2(s.x * 0.5, s.y * 0.48)
	var r := minf(s.x, s.y) * 0.34
	draw_arc(center, r, 0.3, PI - 0.2, 40, tone.darkened(0.3), maxf(4.0, s.x * 0.03), true)
	draw_arc(center + Vector2(r * 0.12, r * 0.08), r, PI + 0.1, TAU - 0.2, 40, tone.darkened(0.3), maxf(4.0, s.x * 0.03), true)
	draw_polyline(PackedVector2Array([center + Vector2(0, -r * 1.2), center + Vector2(-r * 0.15, -r * 0.3),
		center + Vector2(r * 0.12, r * 0.2), center + Vector2(-r * 0.05, r * 1.2)]), glow, maxf(2.0, s.x * 0.012), true)


func _draw_ground(s: Vector2, tone: Color) -> void:
	var horizon := s.y * float(_variant["horizon"])
	var ground := VisualTokens.COLOR_STONE_500.lerp(tone, 0.18).darkened(0.12)
	draw_rect(Rect2(0, horizon, s.x, s.y - horizon), Color(ground, 0.92))
	var count := int(_variant["steps"])
	for i in count:
		var y := horizon + (s.y - horizon) * float(i + 1) / float(count + 1)
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(VisualTokens.COLOR_STONE_050, 0.16), 1.0)
	draw_line(Vector2(0, horizon), Vector2(s.x, horizon), Color(VisualTokens.COLOR_GOLD_300, 0.55), maxf(1.5, s.x * 0.006))


func _draw_legendary_filigree(s: Vector2) -> void:
	var gold := Color(VisualTokens.COLOR_GOLD_300, 0.85)
	var inset := maxf(5.0, s.x * 0.025)
	draw_rect(Rect2(Vector2(inset, inset), s - Vector2(inset, inset) * 2.0), gold, false, maxf(1.5, s.x * 0.005))
	var corner := minf(s.x, s.y) * 0.10
	for p: Vector2 in [Vector2(inset, inset), Vector2(s.x - inset, inset), Vector2(inset, s.y - inset), Vector2(s.x - inset, s.y - inset)]:
		var sx := 1.0 if p.x < s.x * 0.5 else -1.0
		var sy := 1.0 if p.y < s.y * 0.5 else -1.0
		draw_line(p, p + Vector2(corner * sx, 0), gold, maxf(2.0, s.x * 0.009))
		draw_line(p, p + Vector2(0, corner * sy), gold, maxf(2.0, s.x * 0.009))


func _draw_vignette(s: Vector2) -> void:
	var edge := Color(VisualTokens.COLOR_STEEL_900, 0.0)
	var dark := Color(VisualTokens.COLOR_STEEL_900, 0.32)
	var band := s.y * 0.16
	draw_polygon(PackedVector2Array([Vector2(0, s.y - band), Vector2(s.x, s.y - band), s, Vector2(0, s.y)]),
		PackedColorArray([edge, edge, dark, dark]))
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, band * 0.6), Vector2(0, band * 0.6)]),
		PackedColorArray([Color(dark, 0.18), Color(dark, 0.18), edge, edge]))
