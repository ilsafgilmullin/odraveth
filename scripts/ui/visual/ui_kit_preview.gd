class_name UiKitPreview
extends Control
## Non-product validation scene for the reusable Stage 7A visual foundation.

var component_names: PackedStringArray = []


func _ready() -> void:
	UiKit.apply_root_theme(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var pad := ResponsiveLayout.outer_margin(get_viewport_rect().size.x)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, pad)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", ResponsiveLayout.section_gap(get_viewport_rect().size.x))
	margin.add_child(root)

	_add(root, "DisplayTitle", UiKit.make_display_label("ODRAVETH · НУЛМЕРИС"))
	_add(root, "PrimaryButton", UiKit.make_button("Primary", UiKit.ButtonRole.PRIMARY))
	_add(root, "SecondaryButton", UiKit.make_button("Secondary", UiKit.ButtonRole.SECONDARY))
	_add(root, "SubtleButton", UiKit.make_button("Subtle", UiKit.ButtonRole.SUBTLE))
	_add(root, "CompactBattleButton", UiKit.make_button("Battle", UiKit.ButtonRole.COMPACT_BATTLE))
	_add(root, "IconButton", UiKit.make_button("◆", UiKit.ButtonRole.ICON))
	_add(root, "FilterChip", UiKit.make_filter_chip("Выбрано", true))

	var switch := CheckButton.new()
	switch.text = "Switch"
	_add(root, "Switch", UiKit.prepare_switch(switch))

	var select := OptionButton.new()
	select.add_item("Первый")
	select.add_item("Второй")
	_add(root, "Select", UiKit.prepare_select(select))

	var field := LineEdit.new()
	field.placeholder_text = "Введите текст"
	_add(root, "TextField", UiKit.prepare_text_field(field))
	_add(root, "SegmentedControl", UiKit.make_segmented_control(["A", "B", "C"], 1))
	_add(root, "Panel", UiKit.make_panel(false))
	_add(root, "Modal", UiKit.make_panel(true))
	_add(root, "HeroPortraitFrame", UiKit.make_hero_portrait_frame())
	_add(root, "CardFrameBase", UiKit.make_card_frame_base())
	_add(root, "StatusMarker", UiKit.make_status_marker("Статус"))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 120)
	UiKit.prepare_scroll(scroll)
	var scroll_body := VBoxContainer.new()
	for i in 8:
		var label := Label.new()
		label.text = "Строка %d" % (i + 1)
		scroll_body.add_child(label)
	scroll.add_child(scroll_body)
	_add(root, "ScrollView", scroll)


func _add(parent: Container, component_name: String, control: Control) -> void:
	control.name = component_name
	parent.add_child(control)
	component_names.append(component_name)
