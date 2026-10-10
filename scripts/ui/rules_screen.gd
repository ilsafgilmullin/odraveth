class_name RulesScreen
extends Control


func _ready() -> void:
	UiKit.apply_root_theme(self)
	add_child(CitadelBackdrop.create(CitadelBackdrop.Mood.HALL, &"hall"))
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	safe.add_child(layout)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	layout.add_child(header)
	var back := UiKit.make_button("НАЗАД", UiKit.ButtonRole.SECONDARY)
	back.name = "BackButton"
	back.custom_minimum_size.x = 190
	back.pressed.connect(_go_back)
	header.add_child(back)
	var title := UiKit.make_display_label("ПРАВИЛА ИГРЫ")
	title.name = "TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	header.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 190
	header.add_child(spacer)
	var panel := UiKit.make_panel(true)
	panel.name = "RulesPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "RulesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiKit.prepare_scroll(scroll)
	panel.add_child(scroll)
	scroll.add_child(RulesContent.new())


func handle_back_request() -> bool:
	_go_back()
	return true


func _go_back() -> void:
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.MAIN_MENU)
