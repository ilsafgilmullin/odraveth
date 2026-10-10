extends Node

const CardVisualSystemTests := preload("res://tests/card_visual_system_tests.gd")
const WATCHDOG_SECONDS := 45.0

var failures: PackedStringArray = []
var checks := 0
var current_check := "startup"


func _ready() -> void:
	get_tree().current_scene = null
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog_timeout)
	_run.call_deferred()


func _run() -> void:
	await CardVisualSystemTests.new(_check, get_tree()).run()
	if failures.is_empty():
		print("STAGE 7D TARGETED PASSED: %d checks." % checks)
		get_tree().quit(0)
	else:
		print("STAGE 7D TARGETED FAILED: %d/%d failed." % [failures.size(), checks])
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
	print("STAGE 7D TARGETED FAILED: watchdog after %.0f s near '%s'." % [WATCHDOG_SECONDS, current_check])
	get_tree().quit(1)
