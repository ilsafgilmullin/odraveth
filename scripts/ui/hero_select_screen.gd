class_name HeroSelectScreen
extends SetupScreen

const POWER_TEXT := {
	HeroCatalog.KEZHARYN: "Герой получает 1 урон. Союзное существо получает +2 к атаке до конца хода.",
	HeroCatalog.VHORAZEL: "Получить 1 Осколок души; 2, если союзное существо погибло в этом ходу.",
	HeroCatalog.SYRRAVETH: "Следующая подходящая карта противника стоимостью до 3 получает +1 к стоимости.",
	HeroCatalog.TAZHYRION: "Выбранное союзное существо получает +1 к максимальной и текущей броне.",
}
const STYLES := {
	HeroCatalog.KEZHARYN: "Агрессия · самоповреждение · усиление существ",
	HeroCatalog.SYRRAVETH: "Контроль · задержка · искажение действий",
}

var pending_hero: StringName = &""
var hero_buttons: Dictionary = {}
var hero_captions: Dictionary = {}


func _route_id() -> StringName:
	return Routes.HERO_SELECT


func _build_content() -> void:
	pending_hero = StringName(str(AppState.profile.get("selected_hero_id", "")))
	var row := HBoxContainer.new()
	row.name = "HeroCards"
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	for hero: StringName in PlayerSetupData.HERO_IDS:
		var data: Dictionary = HeroCatalog.HEROES[hero]
		var faction := HeroCatalog.faction_of(hero)
		var button := Button.new()
		button.name = "Hero_%s" % hero
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.size_flags_vertical = SIZE_EXPAND_FILL
		button.clip_text = true
		button.add_theme_color_override("font_color", SetupUi.ACCENTS[faction])
		button.text = "%s\n%s\n\n%s (2 энергии)\n%s\n\n%s" % [
			data["name_ru"], SetupUi.faction_name(faction), data["power_ru"],
			POWER_TEXT[hero], STYLES.get(hero, "")]
		button.pressed.connect(_choose.bind(hero))
		row.add_child(button)
		hero_buttons[hero] = button
		hero_captions[hero] = button.text
	_refresh_selection()
	var confirm := Button.new()
	confirm.name = "ConfirmHeroButton"
	confirm.text = "ПОДТВЕРДИТЬ"
	confirm.custom_minimum_size.y = 88
	confirm.pressed.connect(_confirm)
	content.add_child(confirm)


func _choose(hero: StringName) -> void:
	pending_hero = hero
	_refresh_selection()


func _refresh_selection() -> void:
	for hero: StringName in hero_buttons:
		var button: Button = hero_buttons[hero]
		button.text = ("✓ ВЫБРАН\n" if hero == pending_hero else "Выбрать\n") + String(hero_captions[hero])


func _confirm() -> void:
	if not HeroCatalog.has_hero(pending_hero):
		show_message("Сначала выберите героя")
		return
	var next := PlayerSetupData.select_hero(AppState.profile, pending_hero)
	if AppState.persist_profile(next) != OK:
		show_message("Не удалось сохранить героя. Выбор остаётся на экране.")
		return
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.MAIN_MENU)
