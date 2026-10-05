class_name SafeAreaContainer
extends MarginContainer
## Keeps its children inside the display safe area (camera cutouts, rounded
## corners, system bars) on mobile, plus a constant design margin.
##
## Use it as the layout root of every screen so interactive elements never sit
## under a cutout. Insets are applied symmetrically (max of left/right and of
## top/bottom): a "sensor landscape" rotation by 180 degrees moves the cutout to
## the other side without changing the viewport size, so no resize event fires.
## On desktop the safe area is ignored.

## Margin in design pixels (1920x1080 base) added on every side.
@export var base_margin: int = 32


func _ready() -> void:
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var insets := _safe_area_insets()
	var horizontal := base_margin + ceili(maxf(insets.position.x, insets.size.x))
	var vertical := base_margin + ceili(maxf(insets.position.y, insets.size.y))
	add_theme_constant_override(&"margin_left", horizontal)
	add_theme_constant_override(&"margin_right", horizontal)
	add_theme_constant_override(&"margin_top", vertical)
	add_theme_constant_override(&"margin_bottom", vertical)


## Returns the insets in canvas units packed as Rect2:
## position = (left, top), size = (right, bottom).
func _safe_area_insets() -> Rect2:
	if not OS.has_feature("mobile"):
		return Rect2()
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Rect2()
	var safe_area := Rect2(DisplayServer.get_display_safe_area())
	var to_canvas := get_viewport_rect().size / window_size
	var top_left := safe_area.position.max(Vector2.ZERO) * to_canvas
	var bottom_right := (window_size - safe_area.end).max(Vector2.ZERO) * to_canvas
	return Rect2(top_left, bottom_right)
