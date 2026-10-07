class_name HeroPortraitPlaceholder
extends Control
## HERO ART = PLACEHOLDER. Neutral production slot; final character art is separate.

var hero_id: StringName = &""
var accent := VisualTokens.COLOR_STEEL_500
var presentation_gender := ""


func configure(id: StringName) -> void:
	hero_id = id
	accent = HeroPresentation.faction_accent(id)
	presentation_gender = HeroPresentation.presentation_gender(id)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	var inset := 8.0
	var rect := Rect2(Vector2(inset, inset), s - Vector2(inset * 2.0, inset * 2.0))
	draw_rect(rect, Color("d9d2c5"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7.0)), accent)
	draw_line(rect.position, rect.end, Color(0.25, 0.28, 0.29, 0.10), 1.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y),
		Color(0.25, 0.28, 0.29, 0.10), 1.0)

	# Deliberately generic bust silhouette: no final face/costume/body canon is invented.
	var center := Vector2(s.x * 0.50, s.y * 0.47)
	var silhouette := Color("6f7473")
	draw_circle(center + Vector2(0.0, -s.y * 0.15), s.y * 0.105, silhouette)
	draw_polygon(PackedVector2Array([
		center + Vector2(-s.x * 0.18, -s.y * 0.02),
		center + Vector2(s.x * 0.18, -s.y * 0.02),
		center + Vector2(s.x * 0.26, s.y * 0.28),
		center + Vector2(-s.x * 0.26, s.y * 0.28),
	]), PackedColorArray([silhouette]))
