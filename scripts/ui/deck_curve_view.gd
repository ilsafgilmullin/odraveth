class_name DeckCurveView
extends Control
## Mana-curve style cost histogram for the current deck draft. Presentation only.

const BUCKETS := ["0–1", "2", "3", "4", "5", "6", "7+"]

var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]


static func bucket_for(cost: int) -> int:
	return clampi(cost - 1, 0, 6)


func set_costs(costs: Array[int]) -> void:
	counts = [0, 0, 0, 0, 0, 0, 0]
	for value: int in costs:
		counts[bucket_for(value)] += 1
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(360, 190)
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := get_theme_default_font()
	var label_h := 30.0
	var top_pad := 30.0
	var area := Rect2(Vector2(0, top_pad), Vector2(size.x, size.y - top_pad - label_h))
	var slot := area.size.x / float(BUCKETS.size())
	var peak := maxi(4, int(counts.max()))
	draw_line(Vector2(0, area.end.y), Vector2(size.x, area.end.y), Color(VisualTokens.COLOR_STEEL_500, 0.6), 2.0)
	for i in BUCKETS.size():
		var bar_w := slot * 0.56
		var x := slot * float(i) + (slot - bar_w) * 0.5
		var h := area.size.y * float(counts[i]) / float(peak)
		var bar := Rect2(x, area.end.y - h, bar_w, h)
		if counts[i] > 0:
			draw_rect(bar, VisualTokens.COLOR_STEEL_700)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x, 3.0)), VisualTokens.COLOR_GOLD_500)
		var value_text := str(counts[i])
		draw_string(font, Vector2(x, area.end.y - h - 6.0), value_text, HORIZONTAL_ALIGNMENT_CENTER, bar_w, 22,
			VisualTokens.COLOR_STEEL_900 if counts[i] > 0 else VisualTokens.COLOR_MUTED)
		draw_string(font, Vector2(slot * float(i), size.y - 6.0), BUCKETS[i], HORIZONTAL_ALIGNMENT_CENTER, slot, 20,
			VisualTokens.COLOR_MUTED)
