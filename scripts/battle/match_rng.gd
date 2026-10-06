class_name MatchRng
extends RefCounted
## Source of randomness for one match. Match logic uses only this object and
## never the global randi()/randf(), so a seed (or a scripted sequence in tests)
## fully determines every random decision: first player, shuffles, random targets.


## Returns an integer in [0, exclusive_max). Implemented by subclasses.
func next_int(_exclusive_max: int) -> int:
	push_error("MatchRng.next_int() must be implemented by a subclass.")
	return 0


## Fisher-Yates shuffle in place, driven by next_int().
func shuffle(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other := next_int(index + 1)
		var item: Variant = items[index]
		items[index] = items[other]
		items[other] = item


## Opaque state for rollback and replays.
func get_state() -> Variant:
	return null


func set_state(_value: Variant) -> void:
	pass
