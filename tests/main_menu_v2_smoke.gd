extends Node

const MainMenuV2Tests := preload("res://tests/main_menu_v2_tests.gd")
var failures: PackedStringArray = []
var checks := 0


func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()


func _run() -> void:
	await MainMenuV2Tests.new(_check, get_tree()).run()
	if failures.is_empty():
		print("STAGE 7B TARGETED PASSED: %d checks." % checks)
		get_tree().quit(0)
	else:
		print("STAGE 7B TARGETED FAILED: %d/%d failed." % [failures.size(), checks])
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("ok: %s" % description)
	else:
		failures.append(description)
		print("FAIL: %s" % description)
