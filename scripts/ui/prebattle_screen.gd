class_name PrebattleScreen
extends SetupScreen
## Stage 7 Prebattle V3. Shows the player's hero and selected deck, difficulty and
## the three presentation toggles. There is no manual opponent choice: НАЙТИ
## СОПЕРНИКА draws a concrete opponent hero with OpponentSelector, builds the
## BattleLaunchConfig and opens the Opponent Search reveal.

const DIFFICULTY_KEYS := ["NOVICE", "TACTICIAN", "STRATEGIST"]
const DIFFICULTY_LABELS := ["НОВИЧОК", "ТАКТИК", "СТРАТЕГ"]
const DIFFICULTY_NOTES := {
	"NOVICE": "Простая оценка текущих ходов без расчёта наперёд. Видит очевидную победу.",
	"TACTICIAN": "Тактическая оценка открытой позиции: размены, угрозы, ресурсы, броня и способности.",
	"STRATEGIST": "Тактика плюс порядок действий, синергия своей руки и бережное расходование ресурсов.",
}
const TOGGLE_LABELS := {
	PlayerSetupData.HINTS: "Подсказки",
	PlayerSetupData.ANIMATIONS: "Анимации",
	PlayerSetupData.FORECAST: "Прогноз урона",
}

var difficulty_buttons: Dictionary = {}
var difficulty_note: Label
var toggles: Dictionary = {}
var find_button: Button
var deck_summary: Label
var deck_name_label: Label
var deck_marker: Label
var curve_view: DeckCurveView
var composition_label: Label
var choose_deck_button: Button
var last_config: BattleLaunchConfig

var _difficulty_group := ButtonGroup.new()


func _route_id() -> StringName:
	return Routes.PREBATTLE


func _build_content() -> void:
	var backdrop := CitadelBackdrop.create(CitadelBackdrop.Mood.HALL)
	add_child(backdrop)
	move_child(backdrop, 0)
	message.visible = false
	var profile := PlayerSetupData.normalized(AppState.profile)

	var body := HBoxContainer.new()
	body.name = "PrebattleBody"
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	content.add_child(body)
	_build_hero_panel(body, StringName(profile["selected_hero_id"]))
	_build_deck_panel(body)
	_build_settings_panel(body, profile["prebattle"])

	var action_row := HBoxContainer.new()
	action_row.name = "PrebattleActions"
	action_row.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	content.add_child(action_row)
	var note := _label("Соперника выберут механизмы Цитадели. Его фракция откроется при поиске, герой — перед боем.",
		24, VisualTokens.COLOR_STEEL_700)
	note.name = "OpponentNote"
	note.size_flags_horizontal = SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_row.add_child(note)
	find_button = UiKit.make_button("НАЙТИ СОПЕРНИКА", UiKit.ButtonRole.PRIMARY)
	find_button.name = "FindOpponentButton"
	find_button.custom_minimum_size = Vector2(460, 92)
	find_button.add_theme_font_size_override("font_size", 38)
	find_button.pressed.connect(find_opponent)
	action_row.add_child(find_button)
	_refresh()


func _panel(parent: Control, node_name: String) -> VBoxContainer:
	var panel := UiKit.make_panel(false)
	panel.name = node_name
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_2)
	panel.add_child(stack)
	return stack


func _build_hero_panel(parent: Control, hero: StringName) -> void:
	var stack := _panel(parent, "HeroPanel")
	stack.add_child(_caption("ВАШ ГЕРОЙ"))
	if not HeroCatalog.has_hero(hero):
		stack.add_child(_label("Герой не выбран", 34, VisualTokens.COLOR_STEEL_900, true))
	else:
		var portrait := HeroPortraitPlaceholder.new()
		portrait.name = "PlayerHeroPortrait"
		portrait.custom_minimum_size = Vector2(0, 280)
		portrait.size_flags_vertical = SIZE_EXPAND_FILL
		portrait.configure(hero)
		stack.add_child(portrait)
		var hero_label := _label(String(HeroCatalog.HEROES[hero]["name_ru"]).to_upper(), 40, VisualTokens.COLOR_STEEL_900, true)
		hero_label.name = "PlayerHero"
		stack.add_child(hero_label)
		var faction_row := HBoxContainer.new()
		faction_row.add_theme_constant_override("separation", VisualTokens.SPACE_1)
		stack.add_child(faction_row)
		var emblem := EmblemView.for_faction(HeroCatalog.faction_of(hero), Color("e6dfd1"))
		emblem.custom_minimum_size = Vector2(32, 32)
		faction_row.add_child(emblem)
		faction_row.add_child(_label(SetupUi.faction_name(HeroCatalog.faction_of(hero)).to_upper(), 24,
			HeroPresentation.faction_accent(hero)))
		var power := _label("%s · %d ЭНЕРГИИ" % [String(HeroCatalog.HEROES[hero]["power_ru"]).to_upper(),
			HeroPresentation.power_cost(hero)], 24, Color("503f20"), true)
		power.name = "PlayerHeroPower"
		stack.add_child(power)
	var change := UiKit.make_button("СМЕНИТЬ ГЕРОЯ", UiKit.ButtonRole.SUBTLE)
	change.name = "ChangeHeroButton"
	change.add_theme_font_size_override("font_size", 26)
	change.pressed.connect(SceneRouter.go_to.bind(Routes.HERO_SELECT))
	stack.add_child(change)


func _build_deck_panel(parent: Control) -> void:
	var stack := _panel(parent, "DeckPanel")
	stack.add_child(_caption("ВАША КОЛОДА"))
	deck_name_label = _label("", 36, VisualTokens.COLOR_STEEL_900, true)
	deck_name_label.name = "SelectedDeckName"
	deck_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(deck_name_label)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	stack.add_child(status_row)
	deck_summary = _label("", 28, VisualTokens.COLOR_STEEL_900, true)
	deck_summary.name = "SelectedDeck"
	status_row.add_child(deck_summary)
	deck_marker = _label("", 22, VisualTokens.COLOR_STONE_050, true)
	deck_marker.name = "DeckReadyMarker"
	status_row.add_child(deck_marker)
	stack.add_child(_caption("КРИВАЯ СТОИМОСТИ"))
	curve_view = DeckCurveView.new()
	curve_view.name = "PrebattleCurve"
	curve_view.custom_minimum_size.y = 240
	stack.add_child(curve_view)
	composition_label = _label("", 24, VisualTokens.COLOR_STEEL_700)
	composition_label.name = "PrebattleComposition"
	composition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	composition_label.size_flags_vertical = SIZE_EXPAND_FILL
	stack.add_child(composition_label)
	choose_deck_button = UiKit.make_button("СМЕНИТЬ КОЛОДУ", UiKit.ButtonRole.SECONDARY)
	choose_deck_button.name = "ChooseDeckButton"
	choose_deck_button.add_theme_font_size_override("font_size", 28)
	choose_deck_button.pressed.connect(SceneRouter.go_to.bind(Routes.DECK_BUILDER))
	stack.add_child(choose_deck_button)


func _build_settings_panel(parent: Control, prefs: Dictionary) -> void:
	var stack := _panel(parent, "SettingsPanel")
	stack.add_child(_caption("СЛОЖНОСТЬ"))
	var row := HBoxContainer.new()
	row.name = "DifficultyRow"
	row.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	stack.add_child(row)
	var current := str(prefs.get("ai_difficulty", "NOVICE"))
	for i in DIFFICULTY_KEYS.size():
		var key: String = DIFFICULTY_KEYS[i]
		var button := UiKit.make_button(DIFFICULTY_LABELS[i], UiKit.ButtonRole.SEGMENT)
		button.name = "Difficulty_%s" % key
		button.toggle_mode = true
		button.button_group = _difficulty_group
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		button.button_pressed = key == current
		button.toggled.connect(_on_difficulty_toggled.bind(key))
		row.add_child(button)
		difficulty_buttons[key] = button
	difficulty_note = _label("", 23, VisualTokens.COLOR_STEEL_700)
	difficulty_note.name = "DifficultyNote"
	difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_note.custom_minimum_size.y = 64
	stack.add_child(difficulty_note)
	_sync_difficulty(current)

	stack.add_child(_caption("ПОДАЧА БОЯ"))
	for key: String in [PlayerSetupData.HINTS, PlayerSetupData.ANIMATIONS, PlayerSetupData.FORECAST]:
		var toggle := CheckButton.new()
		toggle.name = key
		toggle.text = TOGGLE_LABELS[key]
		UiKit.prepare_switch(toggle)
		toggle.add_theme_font_size_override("font_size", 30)
		toggle.button_pressed = bool(prefs[key])
		toggle.toggled.connect(_set_toggle.bind(key))
		stack.add_child(toggle)
		toggles[key] = toggle
	var hint := _label("Меняют только подачу боя: правила, ИИ и исход остаются прежними.", 20, VisualTokens.COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint)


func _refresh() -> void:
	var deck := PlayerSetupData.selected_deck(AppState.profile, CardDatabase)
	find_button.disabled = deck == null
	if deck == null:
		deck_name_label.text = "НЕТ ГОТОВОЙ КОЛОДЫ"
		deck_summary.text = "Выберите готовую колоду из 30 карт"
		deck_marker.text = ""
		deck_marker.visible = false
		choose_deck_button.text = "СОБРАТЬ КОЛОДУ"
		var no_costs: Array[int] = []
		curve_view.set_costs(no_costs)
		composition_label.text = ""
		return
	deck_name_label.text = deck.name
	deck_summary.text = "%d/%d" % [deck.card_ids.size(), GameRules.DECK_SIZE]
	deck_marker.visible = true
	deck_marker.text = "  ✓ ГОТОВА  "
	var box := StyleBoxFlat.new()
	box.bg_color = VisualTokens.COLOR_MAGIC_700
	box.set_corner_radius_all(VisualTokens.RADIUS_SMALL)
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	deck_marker.add_theme_stylebox_override("normal", box)
	choose_deck_button.text = "СМЕНИТЬ КОЛОДУ"
	var costs: Array[int] = []
	var by_type := {}
	for id: String in deck.card_ids:
		var card := CardDatabase.get_card(StringName(id))
		if card != null:
			costs.append(card.cost)
			by_type[card.card_type] = int(by_type.get(card.card_type, 0)) + 1
	curve_view.set_costs(costs)
	var parts := PackedStringArray()
	for card_type: CardEnums.Type in [CardEnums.Type.CREATURE, CardEnums.Type.SPELL, CardEnums.Type.ARTIFACT]:
		if by_type.has(card_type):
			parts.append("%s %d" % [CollectionScreen.TYPE_LABELS[card_type], by_type[card_type]])
	composition_label.text = " · ".join(parts)


func _on_difficulty_toggled(on: bool, key: String) -> void:
	if not on:
		return
	var next := PlayerSetupData.normalized(AppState.profile)
	var previous: String = next["prebattle"]["ai_difficulty"]
	next["prebattle"]["ai_difficulty"] = key
	if AppState.persist_profile(next) != OK:
		(difficulty_buttons[previous] as Button).set_pressed_no_signal(true)
		_sync_difficulty(previous)
		show_message("Не удалось сохранить сложность")
		return
	_sync_difficulty(key)


func _sync_difficulty(key: String) -> void:
	for value: String in difficulty_buttons:
		var button := difficulty_buttons[value] as Button
		var active := value == key
		UiKit.style_button(button, UiKit.ButtonRole.PRIMARY if active else UiKit.ButtonRole.SEGMENT)
		button.custom_minimum_size = Vector2(0, 72)
		button.add_theme_font_size_override("font_size", 26)
		button.icon = UiKit.CHECK_ICON if active else null
		if active and not button.button_pressed:
			button.set_pressed_no_signal(true)
	difficulty_note.text = DIFFICULTY_NOTES.get(key, "")


func selected_difficulty() -> String:
	return str(PlayerSetupData.normalized(AppState.profile)["prebattle"]["ai_difficulty"])


func _set_toggle(enabled: bool, key: String) -> void:
	var next := PlayerSetupData.normalized(AppState.profile)
	next["prebattle"][key] = enabled
	if AppState.persist_profile(next) != OK:
		(toggles[key] as CheckButton).set_pressed_no_signal(
			PlayerSetupData.normalized(AppState.profile)["prebattle"][key])
		show_message("Не удалось сохранить настройки")


## Draws the opponent (setup RNG, not the match RNG), snapshots the deck and
## opens the Opponent Search reveal. Returns the launched config for tests.
func find_opponent() -> BattleLaunchConfig:
	var deck := PlayerSetupData.selected_deck(AppState.profile, CardDatabase)
	if deck == null:
		show_message("Выберите готовую колоду")
		_refresh()
		return null
	var prefs: Dictionary = PlayerSetupData.normalized(AppState.profile)["prebattle"]
	var level := DIFFICULTY_KEYS.find(prefs["ai_difficulty"]) as AiDifficulty.Level
	var opponent := OpponentSelector.pick_with_seed(deck.hero_id, BattleLaunchConfig.generate_seed())
	var config := BattleLaunchConfig.create(deck.hero_id, deck.card_ids, opponent,
		BattleLaunchConfig.technical_opponent_deck(opponent, CardDatabase), level, 0, prefs)
	config.player_deck_name = deck.name
	config.player_deck_id = deck.id
	last_config = config
	SceneRouter.go_to(Routes.OPPONENT_SEARCH, {BattleLaunchConfig.PARAM_KEY: config})
	return config


func _caption(text_value: String) -> Label:
	return _label(text_value, 19, VisualTokens.COLOR_MUTED)


func _label(text_value: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		var display_font := load(UiKit.DISPLAY_FONT_PATH) as Font
		if display_font != null:
			label.add_theme_font_override("font", display_font)
	return label
