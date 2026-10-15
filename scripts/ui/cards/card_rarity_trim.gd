class_name CardRarityTrim
extends RefCounted
## Shared geometry for all card sizes; separate from ability/target indicators.


static func draw_trim(canvas: CanvasItem, rect: Rect2, rarity: CardEnums.Rarity, board: bool = false) -> void:
	if rarity == CardEnums.Rarity.COMMON or rect.size.x < 30.0:
		return
	var gold := VisualTokens.COLOR_GOLD_500
	var silver := Color("8c9fa7")
	var violet := Color("9d83b7")
	var color := silver if rarity == CardEnums.Rarity.RARE else violet if rarity == CardEnums.Rarity.EPIC else gold
	var line := maxf(1.5, rect.size.x * 0.008)
	var inset := rect.size.x * 0.055
	var span := rect.size.x * (0.18 if rarity == CardEnums.Rarity.LEGENDARY else 0.12)
	var y := rect.position.y + inset if not board else rect.position.y + rect.size.y * 0.58
	for side in [-1, 1]:
		var x := rect.position.x + inset if side < 0 else rect.end.x - inset
		var toward := -float(side)
		canvas.draw_line(Vector2(x, y + span), Vector2(x, y), color, line, true)
		canvas.draw_line(Vector2(x, y), Vector2(x + toward * span, y), color, line, true)
		if rarity >= CardEnums.Rarity.EPIC:
			var c := Vector2(x + toward * span * 0.45, y + span * 0.35)
			var r := span * 0.24
			var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, 0), c + Vector2(0, r), c + Vector2(-r * 0.55, 0), c + Vector2(0, -r)])
			canvas.draw_polyline(diamond, color, line, true)
	if rarity == CardEnums.Rarity.LEGENDARY:
		var center := Vector2(rect.get_center().x, y)
		var crown := PackedVector2Array([center + Vector2(-span, span * 0.20), center + Vector2(-span * 0.85, -span * 0.23),
			center + Vector2(-span * 0.4, span * 0.1), center + Vector2(0, -span * 0.5), center + Vector2(span * 0.4, span * 0.1),
			center + Vector2(span * 0.85, -span * 0.23), center + Vector2(span, span * 0.20)])
		canvas.draw_polyline(crown, color, line * 1.4, true)
		canvas.draw_line(center + Vector2(-span, span * 0.28), center + Vector2(span, span * 0.28), color, line, true)
