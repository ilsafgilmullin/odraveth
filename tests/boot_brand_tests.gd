extends RefCounted
## Stage 7 Boot (Gates of Nulmeris), brand wordmark and app icon.

const PresentationAudit := preload("res://tests/visual_qa/presentation_audit.gd")
const BootScene := preload("res://scenes/boot/boot.tscn")

var _check: Callable
var _tree: SceneTree
var _expect_errors := Callable()


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


## Smoke test hook: the negative boot check logs an expected engine error.
func set_expect_errors(callback: Callable) -> void:
	_expect_errors = callback


func _expecting(value: bool) -> void:
	if _expect_errors.is_valid():
		_expect_errors.call(value)


func run() -> void:
	await _test_boot_failure_and_retry()
	await _test_boot_success()
	_test_brand_and_icon()


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "boot/brand: " + label)


func _wait(route: StringName) -> bool:
	for _i in 180:
		await _tree.process_frame
		if SceneRouter.current_route == route and not SceneRouter.is_changing() and _tree.current_scene != null:
			return true
	return false


func _test_boot_failure_and_retry() -> void:
	SceneRouter.reset_to(Routes.SETTINGS)
	await _wait(Routes.SETTINGS)
	var boot := BootScene.instantiate() as BootScreen
	boot.cards_dir = "res://data/missing_cards_for_boot_test"
	_expecting(true)
	_tree.root.add_child(boot)
	for _i in 30:
		await _tree.process_frame
		if boot.state == BootScreen.State.FAILED:
			break
	_expecting(false)
	_ok(boot.state == BootScreen.State.FAILED and boot.retry_button.visible and boot.note_label.visible
		and boot.status_label.text == "Не удалось открыть врата Нулмериса" and boot.gates.failed,
		"a failed card load stops on a safe error with ПОВТОРИТЬ (no spinner)")
	_ok(SceneRouter.current_route == Routes.SETTINGS and boot.progress < 1.0,
		"an uninitialised Main Menu is never entered")
	boot.cards_dir = CardDatabase.DEFAULT_CARDS_DIR
	boot.retry_button.pressed.emit()
	_ok(await _wait(Routes.MAIN_MENU) and CardDatabase.get_all_cards().size() == 40,
		"ПОВТОРИТЬ reruns the real steps and reaches Main Menu")
	if is_instance_valid(boot):
		boot.queue_free()
	await _tree.process_frame


func _test_boot_success() -> void:
	var boot := BootScene.instantiate() as BootScreen
	var seen: Array[String] = []
	_tree.root.add_child(boot)
	var last := -1.0
	var monotonic := true
	for _i in 60:
		await _tree.process_frame
		if not boot.status_label.text.is_empty() and boot.status_label.text not in seen:
			seen.append(boot.status_label.text)
		monotonic = monotonic and boot.progress >= last
		last = boot.progress
		if boot.state == BootScreen.State.DONE:
			break
	_ok(boot.state == BootScreen.State.DONE and is_equal_approx(boot.progress, 1.0) and monotonic,
		"weighted progress only grows and completes")
	_ok(seen.has("Пробуждение Цитадели…") and seen.has("Загрузка карт Нулмериса…") and seen.has("Открываем врата Нулмериса…"),
		"status lines name the real steps (%s)" % ", ".join(seen))
	_ok(not PresentationAudit.has_developer_words(boot) and boot.find_child("Gates", true, false) is BootGatesView,
		"Gates of Nulmeris without engine or developer branding")
	_ok(await _wait(Routes.MAIN_MENU), "boot opens the Main Menu")
	if is_instance_valid(boot):
		boot.queue_free()
	await _tree.process_frame


func _test_brand_and_icon() -> void:
	_ok(ProjectSettings.get_setting("application/config/icon") == "res://assets/ui/brand/app_icon.svg"
		and FileAccess.file_exists("res://assets/ui/brand/app_icon.svg"), "app icon is the ODRAVETH O-mark")
	_ok(ProjectSettings.get_setting("application/boot_splash/show_image") == false,
		"native splash shows no engine image")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_ok(presets.contains("res://assets/ui/brand/app_icon.svg") and not presets.contains("qa_icon"),
		"Android launcher icons use the O-mark")
	var wordmark := BrandWordmark.new()
	_ok(wordmark.text.is_empty() or wordmark.text == "ODRAVETH", "wordmark keeps the readable text")
	wordmark.free()
