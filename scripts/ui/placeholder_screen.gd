class_name PlaceholderScreen
extends Control
## Stage 0 technical placeholder for an approved screen.
##
## Shows the screen title and navigation along the approved UI flow so routing
## can be checked. Not the final UI: every screen gets its real implementation
## in a separate task.

const ACTION_MIN_SIZE := Vector2(640, 112)

## Route this screen stands for (see Routes).
@export var route_id: StringName
## Caption of the "next screen" button; empty means "Далее: <next screen title>".
@export var next_button_text: String = ""

## Params received from SceneRouter before the screen entered the tree.
var route_params: Dictionary = {}

@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _actions: VBoxContainer = %Actions


func apply_route_params(params: Dictionary) -> void:
	route_params = params


func _ready() -> void:
	_title_label.text = Routes.title(route_id)
	%BackButton.pressed.connect(_on_back_pressed)
	_build_content()


## Adds a button to the action list. [param node_name] makes it findable in tests.
func add_action(text: String, callback: Callable, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = ACTION_MIN_SIZE
	button.pressed.connect(callback)
	_actions.add_child(button)
	return button


## Shows a large message above the actions (hidden while empty).
func set_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = not text.is_empty()


## Screen-specific content. The default offers the next screen of the approved
## flow and the way back to the main menu.
func _build_content() -> void:
	var next_route := Routes.next_in_flow(route_id)
	if next_route != &"":
		var text := next_button_text if not next_button_text.is_empty() else "Далее: %s" % Routes.title(next_route)
		add_action(text, SceneRouter.go_to.bind(next_route), "NextButton")
	add_action("В главное меню", SceneRouter.reset_to.bind(Routes.MAIN_MENU), "MainMenuButton")


func _on_back_pressed() -> void:
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.MAIN_MENU)
