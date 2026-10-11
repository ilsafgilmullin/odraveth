class_name HeroSelectCard
extends Button
## Interactive Hero Select portrait card. Portrait is a documented Visual Alpha temporary
## asset; the faction symbol is the Visual Alpha faction mark. The selected card shows
## the hero's idle character (HeroIdleFx) and a soft gold glow that flashes on selection.

const SELECTED_SCALE := 1.015
const GLOW_REST := 0.35

var hero_id: StringName = &""
var portrait: HeroPortraitPlaceholder
var hero_name_label: Label
var faction_label: Label
var selected_marker: Label
var faction_symbol: EmblemView

var _accent := VisualTokens.COLOR_STEEL_500
var _built := false
var _tween: Tween
var _glow_box: StyleBoxFlat
## Selection glow 0..1, drawn as a soft outer light around the card.
var glow := 0.0:
	set(value):
		glow = value
		queue_redraw()


func configure(id: StringName) -> void:
	hero_id = id
	_accent = HeroPresentation.faction_accent(id)
	_ensure_structure()
	portrait.configure(id)
	var data: Dictionary = HeroCatalog.HEROES[id]
	hero_name_label.text = String(data["name_ru"]).to_upper()
	faction_label.text = SetupUi.faction_name(HeroCatalog.faction_of(id)).to_upper()
	faction_label.add_theme_color_override("font_color", _accent)
	faction_symbol.configure_faction(HeroCatalog.faction_of(id), Color("eee9df"))
	_apply_styles()


## [param animations] plays the idle character; [param flash] adds the selection
## glow/ignition transition. With animations off the selected state is a still frame.
func set_selected_state(selected: bool, animations: bool = false, flash: bool = false) -> void:
	button_pressed = selected
	selected_marker.visible = selected
	scale = Vector2.ONE * SELECTED_SCALE if selected else Vector2.ONE
	z_index = 2 if selected else 0
	portrait.set_idle_effects(selected, animations)
	if _tween != null:
		_tween.kill()
		_tween = null
	portrait.effect_strength = 1.0
	glow = GLOW_REST if selected else 0.0
	if selected and animations and flash and is_inside_tree():
		portrait.effect_strength = 0.0
		glow = 1.0
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(portrait, "effect_strength", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(self, "glow", GLOW_REST, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if glow <= 0.01:
		return
	if _glow_box == null:
		_glow_box = StyleBoxFlat.new()
		_glow_box.bg_color = Color(0, 0, 0, 0)
		_glow_box.set_corner_radius_all(VisualTokens.RADIUS_MEDIUM)
		_glow_box.shadow_size = 18
	_glow_box.shadow_color = Color(VisualTokens.COLOR_GOLD_300, 0.75 * glow)
	draw_style_box(_glow_box, Rect2(Vector2.ZERO, size))


func _ensure_structure() -> void:
	if _built:
		return
	_built = true
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	clip_contents = false
	custom_minimum_size = Vector2(280, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(_update_pivot)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size.y = 40
	stack.add_child(top)

	faction_symbol = EmblemView.new()
	faction_symbol.name = "FactionSymbol"
	faction_symbol.custom_minimum_size = Vector2(40, 40)
	top.add_child(faction_symbol)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	selected_marker = Label.new()
	selected_marker.name = "SelectedMarker"
	selected_marker.text = "✓ ВЫБРАН"
	selected_marker.visible = false
	selected_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_marker.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_700)
	selected_marker.add_theme_font_size_override("font_size", 20)
	top.add_child(selected_marker)

	portrait = HeroPortraitPlaceholder.new()
	portrait.name = "HeroPortrait"
	portrait.custom_minimum_size = Vector2(0, 160)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(portrait)

	hero_name_label = Label.new()
	hero_name_label.name = "HeroName"
	hero_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_name_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	hero_name_label.add_theme_font_size_override("font_size", 28)
	stack.add_child(hero_name_label)

	faction_label = Label.new()
	faction_label.name = "FactionName"
	faction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faction_label.add_theme_font_size_override("font_size", 21)
	stack.add_child(faction_label)


func _apply_styles() -> void:
	var normal := _card_box(Color("eee9df"), _accent, 2)
	var hover := _card_box(Color("f5f1e9"), _accent, 3)
	var pressed_box := _card_box(Color("f7f3ea"), VisualTokens.COLOR_GOLD_500, 5)
	var disabled_box := _card_box(Color("dedbd4"), VisualTokens.COLOR_STONE_500, 1)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_box)
	add_theme_stylebox_override("hover_pressed", pressed_box)
	add_theme_stylebox_override("focus", _card_box(Color(0, 0, 0, 0), VisualTokens.COLOR_MAGIC_500, 3))
	add_theme_stylebox_override("disabled", disabled_box)


func _card_box(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(VisualTokens.RADIUS_MEDIUM)
	return box


func _update_pivot() -> void:
	pivot_offset = size * 0.5
