class_name CharacterSpeech
extends PanelContainer
## A live, noninteractive character bubble; animation changes text visibility only.

var speaker_label: Label
var message_label: Label
var _elapsed := 0.0
var _characters := 0
var _typing := false


func _init() -> void:
	name = "CharacterSpeech"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", WarmMaterials.box(false, Color.WHITE, 22, 16))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	speaker_label = Label.new()
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_label.add_theme_font_size_override("font_size", 20)
	speaker_label.add_theme_color_override("font_color", VisualTokens.COLOR_GOLD_700)
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(speaker_label)
	message_label = Label.new()
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.add_theme_color_override("font_color", VisualTokens.COLOR_INK)
	column.add_child(message_label)
	minimum_size_changed.connect(reset_size)
	set_process(false)


func speak(speaker: String, message: String, animate: bool) -> void:
	speaker_label.text = speaker
	message_label.text = message
	_characters = message.length()
	_elapsed = 0.0
	_typing = animate and _characters > 0
	message_label.visible_characters = 0 if _typing else -1
	set_process(_typing)


func _process(delta: float) -> void:
	_elapsed += delta
	message_label.visible_characters = mini(_characters, int(_elapsed * 34.0))
	if message_label.visible_characters >= _characters:
		finish_typing()


func finish_typing() -> void:
	_typing = false
	message_label.visible_characters = -1
	set_process(false)


func _draw() -> void:
	# Pointer attaches the bubble to the character at its left edge.
	var y := minf(size.y * 0.62, 110.0)
	draw_colored_polygon(PackedVector2Array([Vector2(2, y - 12), Vector2(-20, y + 18), Vector2(2, y + 14)]), Color("edd7ad"))
	draw_polyline(PackedVector2Array([Vector2(2, y - 12), Vector2(-20, y + 18), Vector2(2, y + 14)]), VisualTokens.COLOR_GOLD_700, 2.0, true)
