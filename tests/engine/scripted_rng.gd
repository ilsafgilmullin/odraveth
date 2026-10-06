extends MatchRng
## Test RNG: returns queued values in order (clamped to the requested range),
## then 0. Lets a test fix the first player, shuffles and random targets.

var values: Array[int] = []
var calls: int = 0


func _init(queued: Array[int] = []) -> void:
	values = queued.duplicate()


func next_int(exclusive_max: int) -> int:
	calls += 1
	if values.is_empty() or exclusive_max <= 1:
		if not values.is_empty() and exclusive_max <= 1:
			values.pop_front()
		return 0
	return clampi(values.pop_front(), 0, exclusive_max - 1)


func get_state() -> Variant:
	return {"values": values.duplicate(), "calls": calls}


func set_state(value: Variant) -> void:
	values.assign(value["values"])
	calls = value["calls"]
