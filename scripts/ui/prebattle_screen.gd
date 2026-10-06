class_name PrebattleScreen
extends SetupScreen
## Player deck comes only from the selected persisted UserDeck.

const DIFFICULTY_NAMES := ["Новичок", "Тактик", "Стратег"]
const DIFFICULTY_KEYS := ["NOVICE", "TACTICIAN", "STRATEGIST"]

var opponent: StringName = &""
var opponent_buttons: Dictionary = {}
var difficulty: OptionButton
var toggles: Dictionary = {}
var start_button: Button
var deck_summary: Label


func _route_id() -> StringName:
	return Routes.PREBATTLE


func _build_content() -> void:
	var profile := PlayerSetupData.normalized(AppState.profile)
	opponent = StringName(profile["prebattle"]["opponent_hero_id"])
	var body := HBoxContainer.new()
	body.name = "PrebattleBody"
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	content.add_child(body)
	var player_panel := VBoxContainer.new()
	player_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(player_panel)
	var hero := StringName(profile["selected_hero_id"])
	var hero_name := str(HeroCatalog.HEROES[hero]["name_ru"]) if HeroCatalog.has_hero(hero) else "Герой не выбран"
	var player := Label.new()
	player.name = "PlayerHero"
	player.text = "Ваш герой: %s" % hero_name
	player_panel.add_child(player)
	deck_summary = Label.new()
	deck_summary.name = "SelectedDeck"
	deck_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_panel.add_child(deck_summary)
	var builder := Button.new()
	builder.name = "ChooseDeckButton"
	builder.text = "Выбрать/собрать колоду"
	builder.custom_minimum_size.y = 72
	builder.pressed.connect(SceneRouter.go_to.bind(Routes.DECK_BUILDER))
	player_panel.add_child(builder)
	var change_hero := Button.new()
	change_hero.name = "ChangeHeroButton"
	change_hero.text = "Сменить героя"
	change_hero.custom_minimum_size.y = 72
	change_hero.pressed.connect(SceneRouter.go_to.bind(Routes.HERO_SELECT))
	player_panel.add_child(change_hero)
	var opponents := VBoxContainer.new()
	opponents.name = "OpponentChoices"
	opponents.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(opponents)
	var opp_title := Label.new()
	opp_title.text = "Противник"
	opponents.add_child(opp_title)
	for id: StringName in PlayerSetupData.HERO_IDS:
		var button := Button.new()
		button.name = "Opponent_%s" % id
		button.text = HeroCatalog.HEROES[id]["name_ru"]
		button.custom_minimum_size.y = 95
		button.pressed.connect(_choose_opponent.bind(id))
		opponents.add_child(button)
		opponent_buttons[id] = button
	var settings := VBoxContainer.new()
	settings.name = "PrebattleSettings"
	settings.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(settings)
	var label := Label.new()
	label.text = "Сложность ИИ"
	settings.add_child(label)
	difficulty = OptionButton.new()
	difficulty.name = "Difficulty"
	difficulty.custom_minimum_size.y = 72
	for i in DIFFICULTY_KEYS.size():
		difficulty.add_item(DIFFICULTY_NAMES[i], i)
	difficulty.select(maxi(DIFFICULTY_KEYS.find(profile["prebattle"]["ai_difficulty"]), 0))
	difficulty.item_selected.connect(_set_difficulty)
	settings.add_child(difficulty)
	for key: String in [PlayerSetupData.HINTS, PlayerSetupData.ANIMATIONS, PlayerSetupData.FORECAST]:
		var toggle := CheckButton.new()
		toggle.name = key
		toggle.text = {PlayerSetupData.HINTS: "Подсказки", PlayerSetupData.ANIMATIONS: "Анимации",
			PlayerSetupData.FORECAST: "Прогноз урона"}[key]
		toggle.button_pressed = profile["prebattle"][key]
		toggle.custom_minimum_size.y = 72
		toggle.toggled.connect(_set_toggle.bind(key))
		settings.add_child(toggle)
		toggles[key] = toggle
	start_button = Button.new()
	start_button.name = "StartBattleButton"
	start_button.text = "НАЧАТЬ БОЙ"
	start_button.custom_minimum_size.y = 90
	start_button.pressed.connect(_start_battle)
	content.add_child(start_button)
	_refresh()


func _refresh() -> void:
	for id: StringName in opponent_buttons:
		var button: Button = opponent_buttons[id]
		button.text = ("✓ " if id == opponent else "") + HeroCatalog.HEROES[id]["name_ru"]
	var deck := PlayerSetupData.selected_deck(AppState.profile, CardDatabase)
	start_button.disabled = deck == null
	deck_summary.text = "Колода: %s · %d/30 · ГОТОВА" % [deck.name, deck.card_ids.size()] if deck != null else "Нет выбранной готовой колоды"


func _choose_opponent(hero: StringName) -> void:
	var previous := opponent
	opponent = hero
	var next := PlayerSetupData.normalized(AppState.profile)
	next["prebattle"]["opponent_hero_id"] = String(hero)
	if AppState.persist_profile(next) != OK:
		opponent = previous
		show_message("Не удалось сохранить противника")
	_refresh()


func _set_difficulty(index: int) -> void:
	var next := PlayerSetupData.normalized(AppState.profile)
	next["prebattle"]["ai_difficulty"] = DIFFICULTY_KEYS[index]
	if AppState.persist_profile(next) != OK:
		difficulty.select(maxi(DIFFICULTY_KEYS.find(
			PlayerSetupData.normalized(AppState.profile)["prebattle"]["ai_difficulty"]), 0))
		show_message("Не удалось сохранить сложность")


func _set_toggle(enabled: bool, key: String) -> void:
	var next := PlayerSetupData.normalized(AppState.profile)
	next["prebattle"][key] = enabled
	if AppState.persist_profile(next) != OK:
		(toggles[key] as CheckButton).set_pressed_no_signal(
			PlayerSetupData.normalized(AppState.profile)["prebattle"][key])
		show_message("Не удалось сохранить настройки")


func _start_battle() -> void:
	var deck := PlayerSetupData.selected_deck(AppState.profile, CardDatabase)
	if deck == null:
		show_message("Выберите готовую колоду")
		_refresh()
		return
	var prefs: Dictionary = PlayerSetupData.normalized(AppState.profile)["prebattle"]
	var level: AiDifficulty.Level = DIFFICULTY_KEYS.find(prefs["ai_difficulty"]) as AiDifficulty.Level
	var config := BattleLaunchConfig.create(deck.hero_id, deck.card_ids, opponent,
		BattleLaunchConfig.technical_opponent_deck(opponent, CardDatabase), level, 0, prefs)
	SceneRouter.go_to(Routes.BATTLE, {BattleLaunchConfig.PARAM_KEY: config})
