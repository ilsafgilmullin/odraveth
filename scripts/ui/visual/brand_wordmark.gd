class_name BrandWordmark
extends Label
## ODRAVETH wordmark (Visual Alpha candidate, D-054): the first letter is the
## monumental O-mark — a ring of stone voussoirs with an old-gold keystone — followed
## by the letter-spaced display serif. The Label text stays "ODRAVETH" for layout and
## accessibility; the glyphs are drawn here. No sword, dragon, crown or gothic forms.

@export var stone := VisualTokens.COLOR_STEEL_900
@export var accent := VisualTokens.COLOR_GOLD_500
@export var tracking := 0.06


func _ready() -> void:
	if text.is_empty():
		text = "ODRAVETH"
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	if font == null or font_size <= 0:
		return
	var rest := "DRAVETH"
	var spacing := float(font_size) * tracking
	var o_radius := float(font_size) * 0.40
	var rest_width := 0.0
	for letter: String in rest:
		rest_width += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	var total := o_radius * 2.0 + spacing * 1.5 + rest_width - spacing
	var x := (size.x - total) * 0.5
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			x = 0.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = size.x - total
	var ascent := font.get_ascent(font_size)
	var baseline := (size.y - font.get_height(font_size)) * 0.5 + ascent
	var cap_center := baseline - float(font_size) * 0.36
	NulmerisEmblems.draw_o_mark(self, Vector2(x + o_radius, cap_center), o_radius, stone, accent)
	x += o_radius * 2.0 + spacing * 1.5
	for letter: String in rest:
		draw_string(font, Vector2(x, baseline), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, stone)
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
