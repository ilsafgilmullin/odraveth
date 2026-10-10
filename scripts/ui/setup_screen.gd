class_name SetupScreen
extends Control
## Safe-area root and large touch controls for the Stage 5 setup screens.

var route_params: Dictionary = {}
var content: VBoxContainer
var message: Label


func apply_route_params(params: Dictionary) -> void:
	route_params = params


func _ready() -> void:
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	content = VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 12)
	safe.add_child(content)
	UiKit.apply_root_theme(self)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	content.add_child(header)
	var back := UiKit.make_button("НАЗАД", UiKit.ButtonRole.SECONDARY)
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(180, 72)
	back.pressed.connect(_request_back)
	header.add_child(back)
	var title := Label.new()
	title.name = "ScreenTitle"
	title.text = Routes.title(StringName(route_params.get("route", _route_id()))).to_upper()
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	title.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	var display_font := load(UiKit.DISPLAY_FONT_PATH) as Font
	if display_font != null:
		title.add_theme_font_override("font", display_font)
	header.add_child(title)
	message = Label.new()
	message.name = "StatusMessage"
	message.custom_minimum_size.y = 40
	content.add_child(message)
	_build_content()


func _route_id() -> StringName:
	return &""


func _build_content() -> void:
	pass


func show_message(text_value: String) -> void:
	message.text = text_value


## Gives transient UI first refusal of Android/UI Back. SceneRouter calls this
## before changing screens, so a detail or confirmation is dismissed safely.
func handle_back_request() -> bool:
	var detail_overlay := find_child("CardDetailOverlay", true, false) as CanvasItem
	if detail_overlay != null and detail_overlay.visible:
		detail_overlay.visible = false
		return true
	for child: Node in get_children():
		if child is ConfirmModal and (child as ConfirmModal).visible:
			(child as ConfirmModal).cancel()
			return true
		if child is ConfirmationDialog and child.visible:
			(child as ConfirmationDialog).hide()
			return true
	return false


func _request_back() -> void:
	if handle_back_request():
		return
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.MAIN_MENU)
