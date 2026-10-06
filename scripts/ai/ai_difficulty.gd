class_name AiDifficulty
extends RefCounted
## Approved deterministic offline AI difficulty levels.

enum Level { NOVICE, TACTICIAN, STRATEGIST }

const _CODES := {
	Level.NOVICE: "NOVICE",
	Level.TACTICIAN: "TACTICIAN",
	Level.STRATEGIST: "STRATEGIST",
}
const _NAMES_RU := {
	Level.NOVICE: "Новичок",
	Level.TACTICIAN: "Тактик",
	Level.STRATEGIST: "Стратег",
}


static func is_valid(value: int) -> bool:
	return value in Level.values()


static func code(value: Level) -> String:
	return _CODES[value]


static func name_ru(value: Level) -> String:
	return _NAMES_RU[value]
