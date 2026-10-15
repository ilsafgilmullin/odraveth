class_name MenuAtmosphere
extends Control
## Cheap deterministic light and drifting motes over the recovered terrace.
## Stops redraws with animations off, invisibility or focus loss.

const REDRAW_INTERVAL := 1.0 / 24.0
const PARTICLES := 12
var enabled := true
var elapsed := 0.0
var _wait := 0.0
var _focused := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_sync_processing)
	resized.connect(queue_redraw)
	_sync_processing()


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		elapsed = 0.0
	_sync_processing()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
		_sync_processing()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true
		_sync_processing()


func _sync_processing() -> void:
	set_process(enabled and _focused and is_visible_in_tree())


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 900.0)
	_wait += delta
	if _wait >= REDRAW_INTERVAL:
		_wait = 0.0
		queue_redraw()


func _draw() -> void:
	if size.x < 10.0:
		return
	var light := 0.04 + sin(elapsed * 0.35) * 0.018
	var shaft := PackedVector2Array([Vector2(size.x * 0.17, 0), Vector2(size.x * 0.24, 0), Vector2(size.x * 0.46, size.y), Vector2(size.x * 0.10, size.y)])
	draw_colored_polygon(shaft, Color(1.0, 0.84, 0.55, light))
	if enabled:
		for i in PARTICLES:
			var x := size.x * (0.12 + float(i % 5) * 0.07) + sin(elapsed * 0.2 + i) * 14.0
			var y := fmod(float(i) * 91.0 - elapsed * (4.0 + i % 3) + size.y * 20.0, size.y)
			draw_circle(Vector2(x, y), 1.4 + float(i % 2), Color(1.0, 0.90, 0.65, 0.22))
