class_name ConfirmModal
extends ColorRect
## Visual Alpha confirmation modal. Replaces default-styled Godot dialogs.
## Back/close hides it without confirming.

signal confirmed
signal canceled

var title_label: Label
var message_label: Label
var confirm_button: Button
var cancel_button: Button


static func create(title_text: String, message_text: String, confirm_text: String,
		cancel_text: String = "ОТМЕНА") -> ConfirmModal:
	var modal := ConfirmModal.new()
	modal._build(title_text, message_text, confirm_text, cancel_text)
	return modal


func _build(title_text: String, message_text: String, confirm_text: String, cancel_text: String) -> void:
	color = Color(0.04, 0.05, 0.06, 0.62)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 20

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.make_panel(true)
	panel.name = "ConfirmPanel"
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	panel.add_child(stack)

	title_label = Label.new()
	title_label.name = "ConfirmTitle"
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	var display_font := load(UiKit.DISPLAY_FONT_PATH) as Font
	if display_font != null:
		title_label.add_theme_font_override("font", display_font)
	stack.add_child(title_label)

	message_label = Label.new()
	message_label.name = "ConfirmMessage"
	message_label.text = message_text
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 28)
	message_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_700)
	stack.add_child(message_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	stack.add_child(actions)
	cancel_button = UiKit.make_button(cancel_text, UiKit.ButtonRole.SECONDARY)
	cancel_button.name = "ConfirmCancelButton"
	cancel_button.custom_minimum_size.x = 260
	cancel_button.pressed.connect(cancel)
	actions.add_child(cancel_button)
	confirm_button = UiKit.make_button(confirm_text, UiKit.ButtonRole.PRIMARY)
	confirm_button.name = "ConfirmAcceptButton"
	confirm_button.custom_minimum_size.x = 260
	confirm_button.pressed.connect(_accept)
	actions.add_child(confirm_button)


func popup() -> void:
	visible = true


func cancel() -> void:
	if not visible:
		return
	visible = false
	canceled.emit()


func _accept() -> void:
	visible = false
	confirmed.emit()
