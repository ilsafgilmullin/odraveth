class_name MulliganCardSlot
extends VBoxContainer
## One starting-hand card in the Mulligan V1 overlay. A tap anywhere on the card
## toggles «заменить»; the marked state is shown by a banner, hatching and a
## return arrow (never colour only). «ОПИСАНИЕ» opens the read-only Card Detail.

signal toggled(instance_id: int)
signal detail_requested(instance_id: int)

var instance_id := 0
var marked := false
var card_view: FullCardView
var detail_button: Button
var marker: Control

var _display_font: Font


func _init() -> void:
	add_theme_constant_override("separation", VisualTokens.SPACE_2)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	card_view = FullCardView.new()
	card_view.custom_minimum_size = FullCardView.BASE_SIZE
	card_view.focus_mode = Control.FOCUS_NONE
	add_child(card_view)
	marker = Control.new()
	marker.name = "ReplaceMarker"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.draw.connect(_draw_marker)
	marker.visible = false
	marker.z_index = 5
	card_view.add_child(marker)
	detail_button = UiKit.make_button("ОПИСАНИЕ", UiKit.ButtonRole.SUBTLE)
	detail_button.name = "DetailButton"
	detail_button.focus_mode = Control.FOCUS_NONE
	detail_button.custom_minimum_size = Vector2(FullCardView.BASE_SIZE.x, 64)
	detail_button.add_theme_font_size_override("font_size", 24)
	add_child(detail_button)
	card_view.pressed.connect(func() -> void: toggled.emit(instance_id))
	detail_button.pressed.connect(func() -> void: detail_requested.emit(instance_id))


func configure(card: Dictionary) -> void:
	instance_id = int(card.get("instance_id", 0))
	name = "MulliganCard_%d" % instance_id
	var definition := CardDatabase.get_card(StringName(str(card.get("card_id", ""))))
	if definition != null:
		card_view.configure(definition, int(card.get("current_cost", definition.cost)))
	card_view.name = "Card_%d" % instance_id


func set_marked(value: bool) -> void:
	marked = value
	marker.visible = value
	card_view.modulate = Color(0.86, 0.86, 0.86) if value else Color.WHITE
	marker.queue_redraw()


func _draw_marker() -> void:
	var s := marker.size
	if s.x < 20.0 or _display_font == null:
		return
	# Diagonal hatching over the card: readable without colour.
	var step := 22.0
	var x := -s.y
	while x < s.x:
		marker.draw_line(Vector2(x, s.y), Vector2(x + s.y, 0), Color(VisualTokens.COLOR_STEEL_900, 0.28), 3.0, true)
		x += step
	marker.draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), VisualTokens.COLOR_STEEL_900, false, 4.0)
	# Central banner with a return arrow and the word.
	var band := Rect2(0, s.y * 0.40, s.x, 78)
	marker.draw_rect(band, Color(VisualTokens.COLOR_STEEL_900, 0.92))
	marker.draw_line(band.position, Vector2(band.end.x, band.position.y), VisualTokens.COLOR_GOLD_300, 2.0)
	marker.draw_line(Vector2(band.position.x, band.end.y), band.end, VisualTokens.COLOR_GOLD_300, 2.0)
	var c := Vector2(band.position.x + 46.0, band.get_center().y)
	marker.draw_arc(c, 19.0, -PI * 0.15, PI * 1.45, 28, VisualTokens.COLOR_GOLD_300, 4.0, true)
	var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * 19.0
	marker.draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -9), tip + Vector2(9, -4), tip + Vector2(-2, 10)]),
		VisualTokens.COLOR_GOLD_300)
	marker.draw_string(_display_font, Vector2(band.position.x + 76.0, band.get_center().y + 11.0), "ЗАМЕНИТЬ",
		HORIZONTAL_ALIGNMENT_LEFT, s.x - 84.0, 32, VisualTokens.COLOR_STONE_050)
