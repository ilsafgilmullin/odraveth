class_name CitadelShellScreen
extends Control
## Stage 7 visual shell for «Настройки» and «Прогресс» in the Citadel hall style.
## Settings exposes only the already persisted battle presentation switches (the
## same profile fields as Prebattle). Progress stays sealed: Q-15 is open, so there
## is no experience, rewards, ranking, achievements or currency.

@export var route_id: StringName = &""

var route_params: Dictionary = {}
var toggles: Dictionary = {}
var status_label: Label

var _display_font: Font


func apply_route_params(params: Dictionary) -> void:
	route_params = params


func _ready() -> void:
	UiKit.apply_root_theme(self)
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	add_child(CitadelBackdrop.create(CitadelBackdrop.Mood.HALL, &"hall"))
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	safe.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	layout.add_child(header)
	var back := UiKit.make_button("НАЗАД", UiKit.ButtonRole.SECONDARY)
	back.name = "BackButton"
	back.pressed.connect(_go_back)
	header.add_child(back)
	var title := UiKit.make_display_label(Routes.title(route_id).to_upper())
	title.name = "TitleLabel"
	title.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	header.add_child(title)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var panel := UiKit.make_panel(true)
	panel.name = "ShellPanel"
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	panel.add_child(stack)
	if route_id == Routes.SETTINGS:
		_build_settings(stack)
	else:
		_build_sealed(stack)


func _heading(parent: Control, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	if _display_font != null:
		label.add_theme_font_override("font", _display_font)
	parent.add_child(label)


func _build_settings(stack: VBoxContainer) -> void:
	_heading(stack, "БОЙ")
	var prefs: Dictionary = PlayerSetupData.normalized(AppState.profile)["prebattle"]
	for key: String in PrebattleScreen.TOGGLE_LABELS:
		var toggle := CheckButton.new()
		toggle.name = "Toggle_%s" % key
		toggle.text = PrebattleScreen.TOGGLE_LABELS[key]
		UiKit.prepare_switch(toggle)
		toggle.set_pressed_no_signal(bool(prefs.get(key, true)))
		toggle.toggled.connect(_set_toggle.bind(key))
		stack.add_child(toggle)
		toggles[key] = toggle
	var note := Label.new()
	note.text = "Эти переключатели совпадают с настройками подготовки к бою и не меняют правила матча."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 24)
	note.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	stack.add_child(note)
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color("9a3b2f"))
	stack.add_child(status_label)


func _set_toggle(enabled: bool, key: String) -> void:
	var next := PlayerSetupData.normalized(AppState.profile)
	next["prebattle"][key] = enabled
	if AppState.persist_profile(next) != OK:
		(toggles[key] as CheckButton).set_pressed_no_signal(not enabled)
		status_label.text = "Не удалось сохранить настройки"


func _build_sealed(stack: VBoxContainer) -> void:
	var seal := EmblemView.seal(Color(0.45, 0.38, 0.28, 0.75))
	seal.custom_minimum_size = Vector2(180, 180)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(seal)
	var label := Label.new()
	label.name = "SealedLabel"
	label.text = "ЛЕТОПИСЬ ПРОГРЕССА ЗАПЕЧАТАНА"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_700)
	if _display_font != null:
		label.add_theme_font_override("font", _display_font)
	stack.add_child(label)
	var note := Label.new()
	note.text = "Страницы этого раздела пока закрыты."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 26)
	note.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	stack.add_child(note)


func handle_back_request() -> bool:
	_go_back()
	return true


func _go_back() -> void:
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.MAIN_MENU)
