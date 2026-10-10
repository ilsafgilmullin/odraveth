class_name BattlefieldTheme
extends Control
## Battlefield theme contract, separate from the Battle HUD. A theme owns the
## background, peripheral architecture and ambient/music hooks only; it never reads
## or changes match state. Layout hints let the theme keep decor away from the field.

signal ambient_changed(enabled: bool)

var theme_id: StringName = &""
var display_name := ""
var ambient_enabled := true
## Rect (local) where cards, creatures, heroes and targeting live; decor stays outside.
var gameplay_rect := Rect2()
## Vertical position (local) of the dividing line between the two board rows.
var center_line_y := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_layout_hints(field: Rect2, center_y: float) -> void:
	gameplay_rect = field
	center_line_y = center_y
	queue_redraw()


func set_ambient_enabled(enabled: bool) -> void:
	ambient_enabled = enabled
	ambient_changed.emit(enabled)


## Future ambience/music hook: a theme may name an audio cue; Visual Alpha has none.
func ambience_cue() -> StringName:
	return &""
