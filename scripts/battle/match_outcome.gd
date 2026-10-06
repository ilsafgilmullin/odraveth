class_name MatchOutcome
extends RefCounted
## Approved match result states, docs/PRODUCT_BASELINE.md section 8.

enum Result { VICTORY, DEFEAT, DRAW }

const _TITLES := {
	Result.VICTORY: "Победа",
	Result.DEFEAT: "Поражение",
	Result.DRAW: "Ничья",
}


static func is_valid(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and _TITLES.has(value)


static func title(result: Result) -> String:
	return _TITLES.get(result, "")
