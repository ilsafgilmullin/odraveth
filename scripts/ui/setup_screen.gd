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
	var header := HBoxContainer.new()
	content.add_child(header)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Назад"
	back.custom_minimum_size = Vector2(180, 72)
	back.pressed.connect(func() -> void:
		if SceneRouter.can_go_back():
			SceneRouter.go_back()
		else:
			SceneRouter.reset_to(Routes.MAIN_MENU))
	header.add_child(back)
	var title := Label.new()
	title.name = "ScreenTitle"
	title.text = Routes.title(StringName(route_params.get("route", _route_id())))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
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
