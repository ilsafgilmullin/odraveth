class_name HeroSelectCard
extends Button
## Interactive Hero Select portrait card. Art and faction emblem are explicit placeholders.

var hero_id: StringName = &""
var portrait: HeroPortraitPlaceholder
var hero_name_label: Label
var faction_label: Label
var selected_marker: Label
var faction_symbol_placeholder: Label
var art_status_label: Label

var _accent := VisualTokens.COLOR_STEEL_500
var _built := false


func configure(id: StringName) -> void:
	hero_id = id
	_accent = HeroPresentation.faction_accent(id)
	_ensure_structure()
	portrait.configure(id)
	var data: Dictionary = HeroCatalog.HEROES[id]
	hero_name_label.text = String(data["name_ru"]).to_upper()
	faction_label.text = SetupUi.faction_name(HeroCatalog.faction_of(id)).to_upper()
	faction_label.add_theme_color_override("font_color", _accent)
	faction_symbol_placeholder.add_theme_color_override("font_color", _accent)
	_apply_styles()


func set_selected_state(selected: bool) -> void:
	button_pressed = selected
	selected_marker.visible = selected
	scale = Vector2(1.008, 1.008) if selected else Vector2.ONE
	z_index = 2 if selected else 0


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
	top.custom_minimum_size.y = 30
	stack.add_child(top)

	faction_symbol_placeholder = Label.new()
	faction_symbol_placeholder.name = "FactionSymbolPlaceholder"
	faction_symbol_placeholder.text = "◇"
	faction_symbol_placeholder.tooltip_text = "Временный слот символа фракции"
	faction_symbol_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faction_symbol_placeholder.add_theme_font_size_override("font_size", 26)
	top.add_child(faction_symbol_placeholder)

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
	portrait.name = "HeroArtPlaceholder"
	portrait.custom_minimum_size = Vector2(0, 160)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(portrait)

	art_status_label = Label.new()
	art_status_label.name = "HeroArtStatus"
	art_status_label.text = "АРТ ГЕРОЯ · ВРЕМЕННО"
	art_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_status_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	art_status_label.add_theme_font_size_override("font_size", 17)
	stack.add_child(art_status_label)

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
