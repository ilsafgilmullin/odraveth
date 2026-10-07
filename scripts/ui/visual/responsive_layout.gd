class_name ResponsiveLayout
extends RefCounted
## Shared landscape layout metrics. Keeps screen code free from duplicated breakpoints.

enum WidthClass { NARROW, STANDARD, WIDE }

const NARROW_MAX := 1679.0
const WIDE_MIN := 2200.0


static func width_class(viewport_width: float) -> WidthClass:
	if viewport_width <= NARROW_MAX:
		return WidthClass.NARROW
	if viewport_width >= WIDE_MIN:
		return WidthClass.WIDE
	return WidthClass.STANDARD


static func outer_margin(viewport_width: float) -> int:
	match width_class(viewport_width):
		WidthClass.NARROW:
			return 24
		WidthClass.WIDE:
			return 48
		_:
			return 36


static func section_gap(viewport_width: float) -> int:
	match width_class(viewport_width):
		WidthClass.NARROW:
			return VisualTokens.SPACE_3
		WidthClass.WIDE:
			return VisualTokens.SPACE_5
		_:
			return VisualTokens.SPACE_4


static func collection_columns(viewport_width: float) -> int:
	match width_class(viewport_width):
		WidthClass.NARROW:
			return 4
		WidthClass.WIDE:
			return 6
		_:
			return 5


static func enforce_touch_target(control: Control, preferred: Vector2 = VisualTokens.TOUCH_MIN) -> void:
	control.custom_minimum_size = Vector2(
		maxf(control.custom_minimum_size.x, preferred.x),
		maxf(control.custom_minimum_size.y, preferred.y)
	)
