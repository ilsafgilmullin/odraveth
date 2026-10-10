extends Node
## Targeted runner for the Stage 7 Visual Alpha completion modules.
##   godot --headless --path . --scene res://tests/visual_alpha_smoke.tscn [-- --only=deck_builder]

const MODULES := [
	["deck_builder", preload("res://tests/deck_builder_v1_tests.gd")],
	["prebattle", preload("res://tests/prebattle_v3_tests.gd")],
	["battle", preload("res://tests/battle_v2_tests.gd")],
	["result_library", preload("res://tests/result_library_tests.gd")],
]
const WATCHDOG_SECONDS := 180.0

var failures: PackedStringArray = []
var checks := 0
var current_check := "startup"


func _ready() -> void:
	get_tree().current_scene = null
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog_timeout)
	_run.call_deferred()


func _run() -> void:
	var only := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
	for module: Array in MODULES:
		if not only.is_empty() and not only.has(module[0]):
			continue
		print("-- %s" % module[0])
		await module[1].new(_check, get_tree()).run()
	if failures.is_empty():
		print("STAGE 7 VISUAL ALPHA TARGETED PASSED: %d checks." % checks)
		get_tree().quit(0)
	else:
		print("STAGE 7 VISUAL ALPHA TARGETED FAILED: %d/%d failed." % [failures.size(), checks])
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	current_check = description
	if condition:
		print("ok: %s" % description)
	else:
		failures.append(description)
		print("FAIL: %s" % description)


func _on_watchdog_timeout() -> void:
	print("STAGE 7 VISUAL ALPHA TARGETED FAILED: watchdog after %.0f s near '%s'." % [WATCHDOG_SECONDS, current_check])
	get_tree().quit(1)
