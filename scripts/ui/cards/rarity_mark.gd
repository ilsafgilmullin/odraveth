class_name RarityMark
extends Control
## Geometry-first rarity mark. Distinguishable without colour.

var rarity: CardEnums.Rarity = CardEnums.Rarity.COMMON
var shape_id := "common_diamond"


func configure(value: CardEnums.Rarity) -> void:
	rarity = value
	match rarity:
		CardEnums.Rarity.COMMON:
			shape_id = "common_diamond"
		CardEnums.Rarity.RARE:
			shape_id = "rare_double_diamond"
		CardEnums.Rarity.EPIC:
			shape_id = "epic_elongated_crystal"
		CardEnums.Rarity.LEGENDARY:
			shape_id = "legendary_multifaceted_seal"
	custom_minimum_size = Vector2(34, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var ink := VisualTokens.COLOR_STEEL_700
	var gold := VisualTokens.COLOR_GOLD_500
	match rarity:
		CardEnums.Rarity.COMMON:
			_diamond(c, 9.0, ink, 2.5)
		CardEnums.Rarity.RARE:
			_diamond(c, 11.0, ink, 2.2)
			_diamond(c, 6.0, ink, 1.8)
		CardEnums.Rarity.EPIC:
			var points := PackedVector2Array([
				c + Vector2(0, -14), c + Vector2(7, -5), c + Vector2(5, 12),
				c + Vector2(0, 16), c + Vector2(-5, 12), c + Vector2(-7, -5),
			])
			_outline(points, ink, 2.2)
		CardEnums.Rarity.LEGENDARY:
			var points := PackedVector2Array()
			for i in 8:
				var angle := -PI / 2.0 + TAU * float(i) / 8.0
				points.append(c + Vector2(cos(angle), sin(angle)) * 14.0)
			draw_colored_polygon(points, Color(gold, 0.23))
			_outline(points, gold, 2.4)
			for i in [0, 2, 4, 6]:
				draw_line(c, points[i], gold, 1.2)


func _diamond(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	])
	_outline(points, color, width)


func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)
