extends Node

const CAPTURE_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR := "res://preview_output"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not AppState.is_initialized:
		AppState.initialize()
	CardDatabase.load_directory()
	AppState.profile["selected_hero_id"] = String(HeroCatalog.KEZHARYN)
	AppState.profile["selected_deck_id"] = ""

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	await _capture("res://scenes/menu/main_menu.tscn", "stage7d-main-menu.png")
	await _capture("res://scenes/heroes/hero_select.tscn", "stage7d-hero-select.png")
	await _capture("res://scenes/common/card_visual_preview.tscn", "stage7d-card-visual-preview.png")

	print("VISUAL CAPTURE COMPLETE")
	get_tree().quit(0)

func _capture(scene_path: String, file_name: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Cannot load capture scene: %s" % scene_path)
		get_tree().quit(1)
		return

	var viewport := SubViewport.new()
	viewport.name = "CaptureViewport"
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	var scene := packed.instantiate()
	viewport.add_child(scene)

	for i in 8:
		await get_tree().process_frame
	RenderingServer.force_draw(true)
	await get_tree().process_frame

	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Empty capture image for %s" % scene_path)
		get_tree().quit(1)
		return

	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed saving screenshot %s: %s" % [file_name, error_string(result)])
		get_tree().quit(1)
		return

	print("CAPTURED %s" % file_name)
	viewport.queue_free()
	await get_tree().process_frame
