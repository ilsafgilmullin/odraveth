class_name Routes
extends RefCounted
## Navigation targets: route ids, their scene files and Russian screen titles.
##
## The only place that maps a route to a scene path. Screens navigate through
## SceneRouter with these ids and never reference scene files directly.

const BOOT := &"boot"
const MAIN_MENU := &"main_menu"
const HERO_SELECT := &"hero_select"
const COLLECTION := &"collection"
const DECK_BUILDER := &"deck_builder"
const PREBATTLE := &"prebattle"
const BATTLE := &"battle"
const RESULT := &"result"
const PROGRESS := &"progress"
const SETTINGS := &"settings"

## Approved UI flow order, docs/PRODUCT_BASELINE.md section 8.
const APPROVED_FLOW: Array[StringName] = [
	BOOT,
	MAIN_MENU,
	HERO_SELECT,
	COLLECTION,
	DECK_BUILDER,
	PREBATTLE,
	BATTLE,
	RESULT,
]

const _SCENE_PATHS := {
	BOOT: "res://scenes/boot/boot.tscn",
	MAIN_MENU: "res://scenes/menu/main_menu.tscn",
	HERO_SELECT: "res://scenes/heroes/hero_select.tscn",
	COLLECTION: "res://scenes/collection/collection.tscn",
	DECK_BUILDER: "res://scenes/deck_builder/deck_builder.tscn",
	PREBATTLE: "res://scenes/prebattle/prebattle.tscn",
	BATTLE: "res://scenes/battle/battle.tscn",
	RESULT: "res://scenes/result/result.tscn",
	PROGRESS: "res://scenes/progress/progress.tscn",
	SETTINGS: "res://scenes/settings/settings.tscn",
}

const _TITLES := {
	BOOT: "Загрузка",
	MAIN_MENU: "Главное меню",
	HERO_SELECT: "Выбор героя",
	COLLECTION: "Коллекция",
	DECK_BUILDER: "Редактор колоды",
	PREBATTLE: "Подготовка к бою",
	BATTLE: "Боевой экран",
	RESULT: "Результат боя",
	PROGRESS: "Прогресс",
	SETTINGS: "Настройки",
}


static func has_route(route_id: StringName) -> bool:
	return _SCENE_PATHS.has(route_id)


static func scene_path(route_id: StringName) -> String:
	return _SCENE_PATHS.get(route_id, "")


static func title(route_id: StringName) -> String:
	return _TITLES.get(route_id, "")


static func all_routes() -> Array[StringName]:
	var routes: Array[StringName] = []
	routes.assign(_SCENE_PATHS.keys())
	return routes


## Next screen after [param route_id] in [constant APPROVED_FLOW], or an empty
## StringName when the route is the last one or is not part of the flow.
static func next_in_flow(route_id: StringName) -> StringName:
	var index := APPROVED_FLOW.find(route_id)
	if index == -1 or index == APPROVED_FLOW.size() - 1:
		return &""
	return APPROVED_FLOW[index + 1]
