class_name HeroClusterView
extends Control
## Compact hero HUD cluster: portrait (also the attack/spell target button), HP,
## energy, deck count, hidden hand count (opponent), Soul Shards when relevant and the
## active artifact. Values come only from the sanitized public observation.

signal artifact_detail_requested(card_id: StringName)

enum TargetState { NONE, LEGAL, DIMMED }

var is_player := true
var hero_id: StringName = &""
var portrait_button: Button
var portrait: HeroPortraitPlaceholder
var artifact_button: Button
var target_state: TargetState = TargetState.NONE
var view: Dictionary = {}

var _overlay: Control
var _info: Control
var _display_font: Font
var _body_font: Font
var _artifact_id: StringName = &""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	_body_font = load("res://assets/ui/visual_alpha/fonts/NotoSerif-Regular.ttf") as Font
	portrait_button = Button.new()
	portrait_button.name = "HeroPortraitButton"
	portrait_button.flat = true
	portrait_button.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		portrait_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(portrait_button)
	portrait = HeroPortraitPlaceholder.new()
	portrait.name = "Portrait"
	portrait.compact = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_button.add_child(portrait)
	_overlay = Control.new()
	_overlay.name = "PortraitOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	portrait_button.add_child(_overlay)
	_info = Control.new()
	_info.name = "Info"
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.draw.connect(_draw_info)
	add_child(_info)
	artifact_button = Button.new()
	artifact_button.name = "ArtifactChip"
	artifact_button.flat = true
	artifact_button.focus_mode = Control.FOCUS_NONE
	artifact_button.visible = false
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		artifact_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	artifact_button.draw.connect(_draw_artifact)
	artifact_button.pressed.connect(func() -> void:
		if _artifact_id != &"":
			artifact_detail_requested.emit(_artifact_id))
	add_child(artifact_button)
	resized.connect(_layout)


func update_view(data: Dictionary, player_side: bool, state: TargetState) -> void:
	view = data
	is_player = player_side
	target_state = state
	var id := StringName(str(data.get("hero", {}).get("id", "")))
	if id != hero_id:
		hero_id = id
		portrait.configure(hero_id)
	var artifact: Dictionary = data.get("artifact", {})
	_artifact_id = StringName(str(artifact.get("card_id", ""))) if not artifact.is_empty() else &""
	artifact_button.visible = _artifact_id != &""
	portrait_button.modulate = Color(1, 1, 1, 0.6) if state == TargetState.DIMMED else Color.WHITE
	_layout()


func hero_instance_id() -> int:
	return int(view.get("hero", {}).get("instance_id", 0))


func portrait_center() -> Vector2:
	return portrait_button.get_global_rect().get_center()


func _layout() -> void:
	var h := size.y
	var pw := h * 0.86
	portrait_button.position = Vector2(0, (h - h) * 0.5)
	portrait_button.size = Vector2(pw, h)
	portrait.position = Vector2.ZERO
	portrait.size = Vector2(pw, h * 0.88)
	_overlay.position = Vector2.ZERO
	_overlay.size = portrait_button.size
	_info.position = Vector2(pw + 14.0, 0)
	_info.size = Vector2(maxf(10.0, size.x - pw - 14.0), h)
	artifact_button.size = Vector2(minf(300.0, _info.size.x), h * 0.26)
	artifact_button.position = Vector2(_info.position.x, h - artifact_button.size.y)
	_overlay.queue_redraw()
	_info.queue_redraw()
	artifact_button.queue_redraw()


func _draw_overlay() -> void:
	var s := _overlay.size
	if s.x < 10.0 or _display_font == null:
		return
	var hp := int(view.get("hero", {}).get("health", 0))
	var r := s.x * 0.24
	var c := Vector2(s.x * 0.5, s.y - r * 0.95)
	_overlay.draw_circle(c, r, Color("7c3f35") if hp > 10 else Color("a3372b"))
	_overlay.draw_arc(c, r, 0, TAU, 40, VisualTokens.COLOR_GOLD_300, 2.5, true)
	var font_size := int(r * 1.05)
	var text_value := str(hp)
	var w := _display_font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_overlay.draw_string(_display_font, c + Vector2(-w * 0.5, font_size * 0.36), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, VisualTokens.COLOR_STONE_050)
	if target_state == TargetState.LEGAL:
		var tc := Vector2(s.x * 0.5, s.y * 0.40)
		var ring_r := s.x * 0.30
		_overlay.draw_arc(tc, ring_r, 0, TAU, 48, VisualTokens.COLOR_GOLD_300, 4.0, true)
		for i in 4:
			var angle := PI * 0.25 + PI * 0.5 * float(i)
			var d := Vector2(cos(angle), sin(angle))
			_overlay.draw_line(tc + d * ring_r * 0.8, tc + d * ring_r * 1.25, VisualTokens.COLOR_GOLD_300, 4.0, true)


func _draw_info() -> void:
	var s := _info.size
	if s.x < 40.0 or _display_font == null:
		return
	var hero: Dictionary = HeroCatalog.HEROES.get(hero_id, {})
	var name_size := int(s.y * 0.17)
	_info.draw_string(_display_font, Vector2(0, name_size), String(hero.get("name_ru", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
		s.x, name_size, VisualTokens.COLOR_STEEL_900)
	var faction := HeroCatalog.faction_of(hero_id) if HeroCatalog.has_hero(hero_id) else Faction.Id.NEUTRAL
	var small := int(s.y * 0.105)
	_info.draw_string(_body_font, Vector2(0, name_size + small * 1.25), SetupUi.faction_name(faction).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, s.x, small, HeroPresentation.faction_accent(hero_id))
	# Energy pips.
	var energy := int(view.get("energy_current", 0))
	var energy_max := int(view.get("energy_max", 0))
	var pip_y := name_size + small * 2.6
	var pip := s.y * 0.06
	var x := pip
	var shown := maxi(energy_max, energy)
	for i in shown:
		var c := Vector2(x, pip_y)
		var poly := PackedVector2Array([c + Vector2(0, -pip), c + Vector2(pip * 0.75, 0), c + Vector2(0, pip), c + Vector2(-pip * 0.75, 0)])
		if i < energy:
			_info.draw_colored_polygon(poly, VisualTokens.COLOR_MAGIC_500 if i < energy_max else VisualTokens.COLOR_GOLD_500)
		var closed := PackedVector2Array(poly)
		closed.append(poly[0])
		_info.draw_polyline(closed, VisualTokens.COLOR_STEEL_700, 1.5, true)
		x += pip * 1.75
	_info.draw_string(_display_font, Vector2(x + 4.0, pip_y + small * 0.38), "%d/%d" % [energy, energy_max], HORIZONTAL_ALIGNMENT_LEFT,
		-1, int(small * 1.15), VisualTokens.COLOR_STEEL_900)
	# Resource chips: deck, hidden hand (opponent), Soul Shards when relevant.
	var chip_y := pip_y + small * 1.9
	var chips := PackedStringArray(["КОЛОДА %d" % int(view.get("deck_count", 0))])
	if not is_player:
		chips.append("РУКА %d" % int(view.get("hand_count", 0)))
	var shards := int(view.get("soul_shards", 0))
	if shards > 0 or hero_id == HeroCatalog.VHORAZEL:
		chips.append("ОСКОЛКИ ДУШИ %d" % shards)
	var cx := 0.0
	for chip: String in chips:
		var w := _body_font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 16.0
		var rect := Rect2(cx, chip_y - small * 0.95, w, small * 1.45)
		_info.draw_rect(rect, Color(VisualTokens.COLOR_STONE_050, 0.85))
		_info.draw_rect(rect, Color(VisualTokens.COLOR_STEEL_500, 0.8), false, 1.0)
		_info.draw_string(_body_font, Vector2(cx + 8.0, chip_y + small * 0.18), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, small,
			VisualTokens.COLOR_STEEL_900)
		cx += w + 8.0
	if not is_player:
		_draw_hand_backs(Vector2(cx + 10.0, chip_y - small * 1.05), int(view.get("hand_count", 0)), small * 1.6)


func _draw_hand_backs(origin: Vector2, count: int, card_h: float) -> void:
	var card_w := card_h * 0.70
	for i in mini(count, 10):
		var rect := Rect2(origin + Vector2(float(i) * card_w * 0.38, 0), Vector2(card_w, card_h))
		_info.draw_rect(rect, VisualTokens.COLOR_STEEL_700)
		_info.draw_rect(rect, VisualTokens.COLOR_GOLD_500, false, 1.0)
		NulmerisEmblems.draw_o_mark(_info, rect.get_center(), card_w * 0.28, Color(VisualTokens.COLOR_STONE_300, 0.6),
			Color(VisualTokens.COLOR_GOLD_300, 0.7))


func _draw_artifact() -> void:
	if _artifact_id == &"" or _display_font == null:
		return
	var s := artifact_button.size
	var card := CardDatabase.get_card(_artifact_id)
	var charges := int(view.get("artifact", {}).get("charges", 0))
	var accent := NulmerisEmblems.faction_color(card.faction) if card != null else VisualTokens.COLOR_STEEL_500
	artifact_button.draw_rect(Rect2(Vector2.ZERO, s), Color("efe7d8"))
	artifact_button.draw_rect(Rect2(Vector2.ZERO, s), accent, false, 2.0)
	artifact_button.draw_arc(Vector2(s.y * 0.5, s.y * 0.5), s.y * 0.32, 0, TAU, 24, VisualTokens.COLOR_STEEL_700, 3.0, true)
	artifact_button.draw_arc(Vector2(s.y * 0.5, s.y * 0.5), s.y * 0.18, 0, TAU, 24, VisualTokens.COLOR_GOLD_500, 2.0, true)
	var title: String = card.name_ru if card != null else ""
	var font_size := int(s.y * 0.40)
	var fitted := BoardPieceView.fit_text(_display_font, title, s.x - s.y * 2.1, font_size, int(s.y * 0.30))
	artifact_button.draw_string(_display_font, Vector2(s.y * 1.0, s.y * 0.66), fitted[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(fitted[1]), VisualTokens.COLOR_STEEL_900)
	var charge_text := "×%d" % charges
	artifact_button.draw_string(_display_font, Vector2(s.x - s.y * 1.0, s.y * 0.68), charge_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, accent.darkened(0.2))
