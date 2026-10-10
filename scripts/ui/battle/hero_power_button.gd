class_name HeroPowerButton
extends Button
## Round hero power medallion with cost gem and caption. Availability (`disabled`)
## is supplied by BattleScene from engine legal targets; `used` mirrors the public
## observation flag so a spent power reads «ИСПОЛЬЗОВАНА», not only a dim colour.

var hero_id: StringName = &""
var power_name := ""
var cost := GameRules.HERO_ABILITY_COST
var used := false
var active := false

var _display_font: Font


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(150, 168)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	resized.connect(queue_redraw)


func configure(id: StringName, is_used: bool, is_active: bool) -> void:
	hero_id = id
	power_name = String(HeroCatalog.HEROES.get(id, {}).get("power_ru", ""))
	tooltip_text = power_name
	used = is_used
	active = is_active
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	if _display_font == null or size.x < 20.0:
		return
	var faction := HeroCatalog.faction_of(hero_id) if HeroCatalog.has_hero(hero_id) else Faction.Id.NEUTRAL
	var accent := NulmerisEmblems.faction_color(faction)
	var radius := minf(size.x * 0.40, (size.y - 44.0) * 0.5)
	var center := Vector2(size.x * 0.5, radius + 4.0)
	var available := not disabled
	if active:
		draw_circle(center, radius + 9.0, Color(VisualTokens.COLOR_GOLD_300, 0.55))
	elif available:
		draw_circle(center, radius + 6.0, Color(VisualTokens.COLOR_MAGIC_300, 0.45))
	draw_circle(center, radius, VisualTokens.COLOR_STEEL_700 if available else Color("6f7477"))
	draw_arc(center, radius, 0, TAU, 48, VisualTokens.COLOR_GOLD_500 if available else VisualTokens.COLOR_STONE_500, 4.0, true)
	draw_arc(center, radius * 0.80, 0, TAU, 48, Color(VisualTokens.COLOR_STONE_050, 0.25), 1.5, true)
	var symbol := accent if available else VisualTokens.COLOR_STONE_300
	NulmerisEmblems.draw_faction(self, faction, center, radius * 0.56, symbol.lightened(0.25), Color(VisualTokens.COLOR_STONE_050, 0.8),
		VisualTokens.COLOR_STEEL_700)
	# Cost gem (energy colour) on the upper-left rim.
	var gem := center + Vector2(-radius * 0.74, -radius * 0.74)
	var g := radius * 0.30
	draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -g), gem + Vector2(g * 0.8, 0), gem + Vector2(0, g), gem + Vector2(-g * 0.8, 0)]),
		VisualTokens.COLOR_MAGIC_700 if available else Color("5d6366"))
	var cost_size := int(g * 1.25)
	var cost_text := str(cost)
	var cw := _display_font.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cost_size).x
	draw_string(_display_font, gem + Vector2(-cw * 0.5, cost_size * 0.36), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cost_size,
		VisualTokens.COLOR_STONE_050)
	# Caption: power name, and the spent state in words.
	var caption := power_name.to_upper()
	var caption_size := 21
	var fitted := BoardPieceView.fit_text(_display_font, caption, size.x, caption_size, 16)
	draw_string(_display_font, Vector2(0, center.y + radius + 28.0), fitted[0], HORIZONTAL_ALIGNMENT_CENTER, size.x, int(fitted[1]),
		VisualTokens.COLOR_STEEL_900)
	if used:
		var band := Rect2(center.x - radius, center.y - 14.0, radius * 2.0, 28.0)
		draw_rect(band, Color(VisualTokens.COLOR_STEEL_900, 0.85))
		draw_string(_display_font, Vector2(band.position.x, band.position.y + 21.0), "ИСПОЛЬЗОВАНА", HORIZONTAL_ALIGNMENT_CENTER,
			band.size.x, 17, VisualTokens.COLOR_STONE_050)
