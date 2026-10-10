class_name CollectionArchiveBackdrop
extends Control
## Cheap static Archive of Nulmeris environment framing. Cards remain the visual priority.

## ArtAssets slot: «archive» for Collection, «deck_hall» for Deck Builder.
var art_slot: StringName = &"archive"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var s := size
	var art := ArtAssets.texture(art_slot)
	if art != null:
		ArtAssets.draw_cover(self, art, Rect2(Vector2.ZERO, s))
		# Calm veil so the card grid stays the primary content.
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.93, 0.91, 0.87, 0.55))
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color("e8e2d7"))
	# Quiet peripheral archive bands/shelves; central browsing field stays calm.
	var side := minf(150.0, s.x * 0.075)
	draw_rect(Rect2(0, 0, side, s.y), Color("d8d0c1"))
	draw_rect(Rect2(s.x - side, 0, side, s.y), Color("d8d0c1"))
	for i in 7:
		var y := s.y * (0.14 + float(i) * 0.115)
		draw_line(Vector2(0, y), Vector2(side, y), Color(VisualTokens.COLOR_STEEL_500, 0.20), 2.0)
		draw_line(Vector2(s.x - side, y), Vector2(s.x, y), Color(VisualTokens.COLOR_STEEL_500, 0.20), 2.0)
	draw_line(Vector2(side, 0), Vector2(side, s.y), Color(VisualTokens.COLOR_GOLD_500, 0.24), 2.0)
	draw_line(Vector2(s.x - side, 0), Vector2(s.x - side, s.y), Color(VisualTokens.COLOR_GOLD_500, 0.24), 2.0)
	# Restrained blue ambient line near the archive crown.
	draw_line(Vector2(side, 8), Vector2(s.x - side, 8), Color(VisualTokens.COLOR_MAGIC_500, 0.26), 3.0)
