extends Node
## QA-only runtime screenshot runner. Lives under tests/ so it is never exported.
##
## Renders real Godot 4.7.2 frames of product screens at the window size given by
## --resolution and writes PNG files. Product state comes from a temporary QA save;
## match states are prepared through the same white-box fixture as tests.
##
##   xvfb-run -a -s "-screen 0 3000x2000x24" godot --path . --resolution 1920x1080 \
##       --rendering-method gl_compatibility res://tests/visual_qa/visual_capture.tscn \
##       -- --out=/abs/output/dir [--only=main_menu,collection]

const QaScenarios := preload("res://tests/visual_qa/visual_qa_scenarios.gd")
const QA_SAVE_PATH := "user://odraveth_visual_qa/profile.json"
const SETTLE_FRAMES := 14
const WATCHDOG_SECONDS := 240.0

var out_dir := ""
var only := PackedStringArray()
var captured := PackedStringArray()
var failures := PackedStringArray()


func _ready() -> void:
	get_tree().current_scene = null
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	_parse_args()
	_run.call_deferred()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)


func _run() -> void:
	if out_dir.is_empty():
		push_error("VisualCapture: --out=<absolute dir> is required")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_prepare_isolated_save()
	var scenarios := QaScenarios.new(self)
	for entry: Array in scenarios.all():
		var scenario_name: String = entry[0]
		if not only.is_empty() and not only.has(scenario_name) and not only.has(scenario_name.get_slice("-", 0)):
			continue
		var ok: bool = await entry[1].call()
		if not ok:
			failures.append(scenario_name)
			print("VISUAL QA SKIPPED %s (setup failed)" % scenario_name)
			continue
		await shot(scenario_name)
	scenarios.cleanup()
	print("VISUAL CAPTURE SIZE %dx%d" % [get_window().size.x, get_window().size.y])
	print("VISUAL CAPTURE COUNT %d" % captured.size())
	if failures.is_empty():
		print("VISUAL CAPTURE COMPLETE")
		get_tree().quit(0)
	else:
		print("VISUAL CAPTURE FAILED: %s" % ", ".join(failures))
		get_tree().quit(1)


func _prepare_isolated_save() -> void:
	var dir := QA_SAVE_PATH.get_base_dir()
	if FileAccess.file_exists(QA_SAVE_PATH):
		DirAccess.remove_absolute(QA_SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	AppState._save_manager = SaveManager.new(QA_SAVE_PATH)
	AppState.is_initialized = false
	AppState.initialize()
	CardDatabase.load_directory()


func settle(frames: int = SETTLE_FRAMES) -> void:
	for _i in frames:
		await get_tree().process_frame


func shot(file_stem: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		failures.append(file_stem)
		push_error("VisualCapture: empty image for %s" % file_stem)
		return
	# The window framebuffer alpha is not shown on device; blended overlays leave alpha < 1.
	image.convert(Image.FORMAT_RGB8)
	var path := out_dir.path_join("%s.png" % file_stem)
	var error := image.save_png(path)
	if error != OK:
		failures.append(file_stem)
		push_error("VisualCapture: cannot save %s: %s" % [path, error_string(error)])
		return
	captured.append(file_stem)
	print("CAPTURED %s %dx%d" % [file_stem, image.get_width(), image.get_height()])


func open_route(route: StringName, params: Dictionary = {}) -> bool:
	for _i in 30:
		if not SceneRouter.is_changing():
			break
		await get_tree().process_frame
	if SceneRouter.reset_to(route, params) != OK:
		return false
	for _i in 120:
		await get_tree().process_frame
		if SceneRouter.current_route == route and not SceneRouter.is_changing() \
				and get_tree().current_scene != null:
			return true
	return false


func _on_watchdog() -> void:
	print("VISUAL CAPTURE FAILED: watchdog after %d s" % WATCHDOG_SECONDS)
	get_tree().quit(1)
