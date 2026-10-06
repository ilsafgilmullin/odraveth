class_name DeterministicRng
extends MatchRng
## Seeded RNG for real matches: the same seed gives the same sequence.
## Uses a private RandomNumberGenerator instance, never the global one.

var _generator := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_generator.seed = seed_value


func next_int(exclusive_max: int) -> int:
	return _generator.randi_range(0, exclusive_max - 1) if exclusive_max > 1 else 0


func get_state() -> Variant:
	return _generator.state


func set_state(value: Variant) -> void:
	_generator.state = value
