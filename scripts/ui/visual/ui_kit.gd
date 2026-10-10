class_name UiKit
extends RefCounted
## Reusable Stage 7A component styling. No gameplay state or rules.

enum ButtonRole { PRIMARY, SECONDARY, SUBTLE, COMPACT_BATTLE, ICON, FILTER_CHIP, SEGMENT }

const THEME_PATH := "res://assets/ui/visual_alpha/theme/visual_alpha_theme.tres"
const DISPLAY_FONT_PATH := "res://assets/ui/visual_alpha/fonts/NotoSerif-SemiBold.ttf"
const CHECK_ICON := preload("res://assets/ui/visual_alpha/icons/check.svg")
const CHEVRON_ICON := preload("res://assets/ui/visual_alpha/icons/chevron_down.svg")
const STATUS_ICON := preload("res://assets/ui/visual_alpha/icons/status_diamond.svg")
const SWITCH_ON_PATH := "res://assets/ui/visual_alpha/icons/switch_on.svg"
const SWITCH_OFF_PATH := "res://assets/ui/visual_alpha/icons/switch_off.svg"


static func apply_root_theme(control: Control) -> bool:
	var visual_theme := load(THEME_PATH) as Theme
	if visual_theme == null:
		return false
	control.theme = visual_theme
	return true


static func make_display_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	var display_font := load(DISPLAY_FONT_PATH) as Font
	if display_font != null:
		label.add_theme_font_override("font", display_font)
	label.add_theme_font_size_override("font_size", VisualTokens.FONT_DISPLAY)
	label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	return label


static func _box(background: Color, border: Color, border_width: int, radius: int,
		content_x: float = 22.0, content_y: float = 12.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = content_x
	box.content_margin_right = content_x
	box.content_margin_top = content_y
	box.content_margin_bottom = content_y
	return box


static func _button_palette(role: ButtonRole) -> Dictionary:
	match role:
		ButtonRole.PRIMARY:
			return {"normal": [VisualTokens.COLOR_STEEL_700, VisualTokens.COLOR_GOLD_500],
				"hover": [Color("46575c"), VisualTokens.COLOR_GOLD_300],
				"pressed": [VisualTokens.COLOR_STEEL_900, VisualTokens.COLOR_GOLD_300],
				"font": VisualTokens.COLOR_STONE_050}
		ButtonRole.SECONDARY:
			return {"normal": [VisualTokens.COLOR_STONE_100, VisualTokens.COLOR_STEEL_500],
				"hover": [VisualTokens.COLOR_STONE_050, VisualTokens.COLOR_GOLD_500],
				"pressed": [VisualTokens.COLOR_STONE_300, VisualTokens.COLOR_GOLD_700],
				"font": VisualTokens.COLOR_INK}
		ButtonRole.SUBTLE:
			return {"normal": [Color(0, 0, 0, 0), VisualTokens.COLOR_STONE_500],
				"hover": [Color("eee8dd"), VisualTokens.COLOR_STEEL_500],
				"pressed": [Color("ddd5c7"), VisualTokens.COLOR_GOLD_700],
				"font": VisualTokens.COLOR_STEEL_900}
		ButtonRole.COMPACT_BATTLE:
			return {"normal": [VisualTokens.COLOR_STEEL_900, VisualTokens.COLOR_STEEL_500],
				"hover": [VisualTokens.COLOR_STEEL_700, VisualTokens.COLOR_MAGIC_500],
				"pressed": [Color("172023"), VisualTokens.COLOR_MAGIC_300],
				"font": VisualTokens.COLOR_STONE_050}
		ButtonRole.ICON:
			return {"normal": [Color("ebe5da"), VisualTokens.COLOR_STONE_500],
				"hover": [VisualTokens.COLOR_STONE_050, VisualTokens.COLOR_MAGIC_500],
				"pressed": [VisualTokens.COLOR_STONE_300, VisualTokens.COLOR_MAGIC_700],
				"font": VisualTokens.COLOR_STEEL_900}
		_:
			return {"normal": [Color("eee8dd"), VisualTokens.COLOR_STONE_500],
				"hover": [VisualTokens.COLOR_STONE_050, VisualTokens.COLOR_GOLD_500],
				"pressed": [Color("ded5c4"), VisualTokens.COLOR_GOLD_700],
				"font": VisualTokens.COLOR_INK}


static func style_button(button: Button, role: ButtonRole = ButtonRole.SECONDARY) -> Button:
	var palette := _button_palette(role)
	var compact := role in [ButtonRole.COMPACT_BATTLE, ButtonRole.ICON, ButtonRole.FILTER_CHIP, ButtonRole.SEGMENT]
	var radius := VisualTokens.RADIUS_SMALL if compact else VisualTokens.RADIUS_MEDIUM
	var normal_width := 1 if role in [ButtonRole.SUBTLE, ButtonRole.FILTER_CHIP, ButtonRole.SEGMENT] else 2
	button.add_theme_stylebox_override("normal", _box(palette["normal"][0], palette["normal"][1], normal_width, radius))
	button.add_theme_stylebox_override("hover", _box(palette["hover"][0], palette["hover"][1], maxi(2, normal_width), radius))
	button.add_theme_stylebox_override("pressed", _box(palette["pressed"][0], palette["pressed"][1], 3, radius))
	button.add_theme_stylebox_override("hover_pressed", _box(palette["pressed"][0], VisualTokens.COLOR_GOLD_300, 3, radius))
	button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), VisualTokens.COLOR_MAGIC_500, 3, radius))
	button.add_theme_stylebox_override("disabled", _box(Color("dedbd4"), Color("b9b6ae"), 1, radius))
	button.add_theme_color_override("font_color", palette["font"])
	button.add_theme_color_override("font_hover_color", palette["font"])
	button.add_theme_color_override("font_pressed_color", palette["font"])
	button.add_theme_color_override("font_focus_color", palette["font"])
	button.add_theme_color_override("font_disabled_color", VisualTokens.COLOR_DISABLED)
	button.add_theme_font_size_override("font_size", 30 if compact else VisualTokens.FONT_UI)
	match role:
		ButtonRole.PRIMARY:
			ResponsiveLayout.enforce_touch_target(button, VisualTokens.TOUCH_PRIMARY)
		ButtonRole.COMPACT_BATTLE, ButtonRole.ICON, ButtonRole.FILTER_CHIP, ButtonRole.SEGMENT:
			ResponsiveLayout.enforce_touch_target(button, VisualTokens.TOUCH_COMPACT)
		_:
			ResponsiveLayout.enforce_touch_target(button)
	return button


static func make_button(text_value: String, role: ButtonRole = ButtonRole.SECONDARY) -> Button:
	var button := Button.new()
	button.text = text_value
	return style_button(button, role)


static func prepare_switch(control: CheckButton) -> CheckButton:
	ResponsiveLayout.enforce_touch_target(control)
	control.add_theme_font_size_override("font_size", VisualTokens.FONT_UI)
	control.add_theme_color_override("font_color", VisualTokens.COLOR_INK)
	control.add_theme_color_override("font_pressed_color", VisualTokens.COLOR_STEEL_900)
	control.add_theme_color_override("font_hover_color", VisualTokens.COLOR_INK)
	control.add_theme_color_override("font_hover_pressed_color", VisualTokens.COLOR_STEEL_900)
	control.add_theme_color_override("font_focus_color", VisualTokens.COLOR_INK)
	var on_icon := load(SWITCH_ON_PATH) as Texture2D
	var off_icon := load(SWITCH_OFF_PATH) as Texture2D
	if on_icon != null and off_icon != null:
		for icon_name: String in ["checked", "checked_disabled", "checked_mirrored", "checked_disabled_mirrored"]:
			control.add_theme_icon_override(icon_name, on_icon)
		for icon_name: String in ["unchecked", "unchecked_disabled", "unchecked_mirrored", "unchecked_disabled_mirrored"]:
			control.add_theme_icon_override(icon_name, off_icon)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		control.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return control


static func prepare_select(control: OptionButton) -> OptionButton:
	ResponsiveLayout.enforce_touch_target(control)
	control.add_theme_icon_override("arrow", CHEVRON_ICON)
	control.add_theme_font_size_override("font_size", VisualTokens.FONT_UI)
	return control


static func prepare_text_field(control: LineEdit) -> LineEdit:
	ResponsiveLayout.enforce_touch_target(control)
	control.add_theme_font_size_override("font_size", VisualTokens.FONT_UI)
	control.add_theme_color_override("font_color", VisualTokens.COLOR_INK)
	control.add_theme_color_override("font_placeholder_color", VisualTokens.COLOR_MUTED)
	return control


static func make_filter_chip(text_value: String, selected: bool = false) -> Button:
	var button := make_button(text_value, ButtonRole.FILTER_CHIP)
	button.toggle_mode = true
	button.button_pressed = selected
	_connect_toggle_icon(button)
	_sync_toggle_icon(button)
	return button


static func _connect_toggle_icon(button: Button) -> void:
	button.toggled.connect(func(_pressed: bool) -> void: _sync_toggle_icon(button))


static func _sync_toggle_icon(button: Button) -> void:
	button.icon = CHECK_ICON if button.button_pressed else null
	button.expand_icon = false


static func make_segmented_control(labels: PackedStringArray, selected_index: int = 0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	var group := ButtonGroup.new()
	for i in labels.size():
		var button := make_button(labels[i], ButtonRole.SEGMENT)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == selected_index
		_connect_toggle_icon(button)
		_sync_toggle_icon(button)
		row.add_child(button)
	return row


static func make_panel(modal: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	var background := Color("f0ebe2") if modal else Color("e6dfd1")
	var border := VisualTokens.COLOR_GOLD_500 if modal else VisualTokens.COLOR_STONE_500
	panel.add_theme_stylebox_override("panel", _box(background, border, 2 if modal else 1,
		VisualTokens.RADIUS_LARGE, VisualTokens.SPACE_5, VisualTokens.SPACE_4))
	return panel


static func make_hero_portrait_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(220, 280)
	frame.add_theme_stylebox_override("panel", _box(Color("d8d0c1"), VisualTokens.COLOR_GOLD_500, 3,
		VisualTokens.RADIUS_LARGE, VisualTokens.SPACE_2, VisualTokens.SPACE_2))
	return frame


static func make_card_frame_base() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(220, 320)
	frame.add_theme_stylebox_override("panel", _box(Color("eee8dd"), VisualTokens.COLOR_STEEL_500, 2,
		VisualTokens.RADIUS_MEDIUM, VisualTokens.SPACE_2, VisualTokens.SPACE_2))
	return frame


static func make_status_marker(text_value: String) -> PanelContainer:
	var marker := PanelContainer.new()
	marker.add_theme_stylebox_override("panel", _box(Color("e4f1ef"), VisualTokens.COLOR_MAGIC_500, 1,
		VisualTokens.RADIUS_SMALL, VisualTokens.SPACE_2, VisualTokens.SPACE_1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	marker.add_child(row)
	var icon := TextureRect.new()
	icon.texture = STATUS_ICON
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", VisualTokens.COLOR_MAGIC_700)
	label.add_theme_font_size_override("font_size", 26)
	row.add_child(label)
	return marker


static func prepare_scroll(control: ScrollContainer) -> ScrollContainer:
	control.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	control.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return control
