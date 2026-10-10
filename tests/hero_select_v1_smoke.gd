extends Node

const HeroSelectV1Tests := preload("res://tests/hero_select_v1_tests.gd")
const WATCHDOG_SECONDS := 30.0

var failures: PackedStringArray = []
var checks := 0
var current_section := "startup"


func _ready() -> void:
	get_tree().current_scene = null
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog_timeout)
	_run.call_deferred()


func _run() -> void:
	await HeroSelectV1Tests.new(_check, get_tree()).run()
	if failures.is_empty():
		print("STAGE 7C TARGETED PASSED: %d checks." % checks)
		get_tree().quit(0)
	else:
		print("STAGE 7C TARGETED FAILED: %d/%d failed." % [failures.size(), checks])
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	current_section = description
	if condition:
		print("ok: %s" % description)
	else:
		failures.append(description)
		print("FAIL: %s" % description)


func _on_watchdog_timeout() -> void:
	print("STAGE 7C TARGETED FAILED: watchdog after %.0f s near '%s'." % [WATCHDOG_SECONDS, current_section])
	get_tree().quit(1)
