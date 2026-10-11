class_name StoryFlow
extends RefCounted
## Story Mode V1 navigation and approved aftermath texts (docs/STORY_MODE_V1.md).
## Presentation only: nothing here reaches MatchEngine, AI, RNG or the save file.

const PARAM_CHAPTER := "story_chapter"
const PARAM_PAGE := "page"
const PARAM_VIEW := "view"
const VIEW_PREPARATION := "preparation"
const CHAPTER_CAPTION := "СЮЖЕТНЫЙ БОЙ · ЦИТАДЕЛЬ"
const MODIFIERS_NONE := "МОДИФИКАТОРЫ: НЕТ"
const CLOSING_LINE := "Хранитель закрывает страницу раньше, чем герои успевают её прочесть."

## Russian agreement for the approved heroes: genitive and grammatical gender.
const _GRAMMAR := {
	HeroCatalog.KEZHARYN: {"genitive": "Кежарина", "feminine": false},
	HeroCatalog.VHORAZEL: {"genitive": "Вхоразеля", "feminine": false},
	HeroCatalog.SYRRAVETH: {"genitive": "Сирравет", "feminine": true},
	HeroCatalog.TAZHYRION: {"genitive": "Тажириона", "feminine": false},
}


## Returns to the Library opened on «ХРОНИКИ» and clears the route history,
## so repeated story loops never grow the stack.
static func open_chronicles() -> Error:
	return SceneRouter.reset_to(Routes.HISTORY, {HistoryShell.PARAM_SECTION: HistoryShell.CHRONICLES})


static func story_params(chapter: StringName = BattleLaunchConfig.STORY_CHAPTER_CITADEL_TRIAL) -> Dictionary:
	return {PARAM_CHAPTER: String(chapter)}


## Known chapter id from route params, or an empty StringName for the ordinary flow.
static func chapter_from_params(params: Dictionary) -> StringName:
	var value: Variant = params.get(PARAM_CHAPTER, "")
	return StringName(value) if BattleLaunchConfig.is_story_chapter(value) else &""


static func hero_name(hero_id: StringName) -> String:
	return String(HeroCatalog.HEROES.get(hero_id, {}).get("name_ru", ""))


static func hero_genitive(hero_id: StringName) -> String:
	return String(_GRAMMAR.get(hero_id, {}).get("genitive", hero_name(hero_id)))


static func is_feminine(hero_id: StringName) -> bool:
	return bool(_GRAMMAR.get(hero_id, {}).get("feminine", false))


static func aftermath_title(outcome: MatchOutcome.Result) -> String:
	match outcome:
		MatchOutcome.Result.VICTORY:
			return "КНИГА ПРИНЯЛА ПОБЕДУ"
		MatchOutcome.Result.DEFEAT:
			return "СТЁРТЫЙ ОТТИСК"
	return "РАЗДЕЛЁННАЯ СТРАНИЦА"


static func aftermath_body(outcome: MatchOutcome.Result, player: StringName, opponent: StringName) -> String:
	match outcome:
		MatchOutcome.Result.VICTORY:
			return ("Книга записывает победу %s. Чернила высыхают — и под ними проступает более старая строка: "
				+ "в этом же испытании %s %s. Обе записи подлинны.") % [hero_genitive(player),
				"победила" if is_feminine(opponent) else "победил", hero_name(opponent)]
		MatchOutcome.Result.DEFEAT:
			var feminine := is_feminine(player)
			return ("Книга записывает победу %s. Но под новой строкой сохраняется стёртый оттиск: "
				+ "%s уже %s из этого испытания %s.") % [hero_genitive(opponent), hero_name(player),
				"выходила" if feminine else "выходил", "победительницей" if feminine else "победителем"]
	return "Книга делит страницу надвое. В одной строке %s %s, в другой — %s. Ни одна запись не исчезает." % [
		"пала" if is_feminine(player) else "пал", hero_name(player), hero_name(opponent)]
