class_name ResultScreen
extends Control
## Stage 7 Result V1 over a dimmed Citadel battlefield: ПОБЕДА / ПОРАЖЕНИЕ / НИЧЬЯ,
## the player's hero, faction and deck on the left, the opponent's hero, faction and
## AI difficulty on the right, authoritative turn/card counts only, and four actions.
## ПОВТОРИТЬ БОЙ keeps the exact deck snapshot, opponent and settings with a fresh
## seed; НОВЫЙ СОПЕРНИК draws again through OpponentSelector and the search scene.

const PARAM_OUTCOME := "outcome"
const DIM_SHADER := preload("res://assets/ui/visual_alpha/shaders/battlefield_dim.gdshader")

var route_params: Dictionary = {}
var config: BattleLaunchConfig
var outcome_valid := false
var message_label: Label
var stats_label: Label
var rematch_button: Button
var opponent_button: Button
var deck_button: Button
var menu_button: Button
## The configuration handed to the next route (tests and QA read it).
var last_config: BattleLaunchConfig

var _display_font: Font


func apply_route_params(params: Dictionary) -> void:
	route_params = params


func _ready() -> void:
	UiKit.apply_root_theme(self)
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	var cfg: Variant = route_params.get(BattleLaunchConfig.PARAM_KEY)
	if cfg is BattleLaunchConfig:
		config = cfg as BattleLaunchConfig
	var battlefield := CitadelBattlefield.new()
	battlefield.name = "Battlefield"
	battlefield.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(battlefield)
	battlefield.set_ambient_enabled(false)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim_material := ShaderMaterial.new()
	dim_material.shader = DIM_SHADER
	dim_material.set_shader_parameter("tint", Color(0.13, 0.15, 0.16, 0.5))
	dim.material = dim_material
	add_child(dim)
	_build()


func _build() -> void:
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var col := VBoxContainer.new()
	col.name = "Layout"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	safe.add_child(col)

	var seal := EmblemView.seal(Color(VisualTokens.COLOR_STONE_050, 0.85))
	seal.name = "ResultSeal"
	seal.custom_minimum_size = Vector2(120, 120)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(seal)
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.uppercase = true
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 104)
	message_label.add_theme_color_override("font_outline_color", Color(VisualTokens.COLOR_STEEL_900, 0.55))
	message_label.add_theme_constant_override("outline_size", 8)
	if _display_font != null:
		message_label.add_theme_font_override("font", _display_font)
	col.add_child(message_label)
	var outcome: Variant = route_params.get(PARAM_OUTCOME)
	outcome_valid = MatchOutcome.is_valid(outcome)
	if outcome_valid:
		message_label.text = MatchOutcome.title(outcome)
		message_label.add_theme_color_override("font_color", _outcome_color(outcome))
	else:
		push_warning("ResultScreen: missing or invalid '%s' param: %s." % [PARAM_OUTCOME, outcome])
		message_label.text = "Результат неизвестен"
		message_label.uppercase = false
		message_label.add_theme_font_size_override("font_size", 64)
		message_label.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)

	var row := HBoxContainer.new()
	row.name = "Sides"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", VisualTokens.SPACE_6)
	col.add_child(row)
	if config != null:
		var deck_name := config.player_deck_name if not config.player_deck_name.is_empty() else "Колода игрока"
		row.add_child(_side_panel("PlayerSide", "ВЫ", config.player_hero, deck_name))
	stats_label = Label.new()
	stats_label.name = "ResultStats"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 30)
	stats_label.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	stats_label.add_theme_constant_override("line_spacing", 10)
	stats_label.custom_minimum_size = Vector2(360, 0)
	stats_label.text = "Ходов: %d\nСыграно карт:\n%d (вы) / %d (ИИ)" % [int(route_params.get("turns", 0)),
		int(route_params.get("cards_player", 0)), int(route_params.get("cards_ai", 0))]
	stats_label.visible = config != null
	row.add_child(stats_label)
	if config != null:
		row.add_child(_side_panel("OpponentSide", "СОПЕРНИК", config.opponent_hero,
			"Сложность: %s" % AiDifficulty.name_ru(config.ai_difficulty)))

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	col.add_child(actions)
	if config != null:
		rematch_button = _action(actions, "ПОВТОРИТЬ БОЙ", "RematchButton", UiKit.ButtonRole.PRIMARY, _rematch)
	opponent_button = _action(actions, "НОВЫЙ СОПЕРНИК", "OpponentButton", UiKit.ButtonRole.SECONDARY, _new_opponent)
	deck_button = _action(actions, "СМЕНИТЬ КОЛОДУ", "DeckButton", UiKit.ButtonRole.SECONDARY,
		SceneRouter.replace_with.bind(Routes.DECK_BUILDER))
	menu_button = _action(actions, "ГЛАВНОЕ МЕНЮ", "MainMenuButton", UiKit.ButtonRole.SUBTLE,
		SceneRouter.reset_to.bind(Routes.MAIN_MENU))
	menu_button.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	menu_button.add_theme_color_override("font_hover_color", VisualTokens.COLOR_STEEL_900)


func _outcome_color(outcome: Variant) -> Color:
	match outcome:
		MatchOutcome.Result.VICTORY:
			return VisualTokens.COLOR_GOLD_300
		MatchOutcome.Result.DEFEAT:
			return Color("d9cfc2")
	return VisualTokens.COLOR_STONE_050


func _side_panel(node_name: String, caption_text: String, hero_id: StringName, detail_text: String) -> PanelContainer:
	var panel := UiKit.make_panel(true)
	panel.name = node_name
	panel.custom_minimum_size = Vector2(440, 0)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_2)
	panel.add_child(stack)
	var caption := Label.new()
	caption.text = caption_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	stack.add_child(caption)
	var portrait := HeroPortraitPlaceholder.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(220, 250)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.configure(hero_id)
	stack.add_child(portrait)
	var hero_name := Label.new()
	hero_name.name = "HeroName"
	hero_name.text = String(HeroCatalog.HEROES.get(hero_id, {}).get("name_ru", "")).to_upper()
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_name.add_theme_font_size_override("font_size", 38)
	hero_name.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	if _display_font != null:
		hero_name.add_theme_font_override("font", _display_font)
	stack.add_child(hero_name)
	var faction_row := HBoxContainer.new()
	faction_row.alignment = BoxContainer.ALIGNMENT_CENTER
	faction_row.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	stack.add_child(faction_row)
	if HeroCatalog.has_hero(hero_id):
		var faction := HeroCatalog.faction_of(hero_id)
		var emblem := EmblemView.for_faction(faction)
		emblem.custom_minimum_size = Vector2(36, 36)
		faction_row.add_child(emblem)
		var faction_label := Label.new()
		faction_label.name = "FactionName"
		faction_label.text = SetupUi.faction_name(faction).to_upper()
		faction_label.add_theme_font_size_override("font_size", 24)
		faction_label.add_theme_color_override("font_color", HeroPresentation.faction_accent(hero_id).darkened(0.25))
		faction_row.add_child(faction_label)
	var detail := Label.new()
	detail.name = "SideDetail"
	detail.text = detail_text
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 26)
	detail.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_700)
	stack.add_child(detail)
	return panel


func _action(parent: Control, text_value: String, node_name: String, role: UiKit.ButtonRole, callback: Callable) -> Button:
	var button := UiKit.make_button(text_value, role)
	button.name = node_name
	button.custom_minimum_size = Vector2(320, 88)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


## Same hero, exact deck snapshot, same opponent, difficulty and settings; fresh seed.
func _rematch() -> void:
	if config == null:
		return
	last_config = config.rematch()
	SceneRouter.replace_with(Routes.BATTLE, {BattleLaunchConfig.PARAM_KEY: last_config})


## Draws a new opponent through the same selector and reveal scene as Prebattle.
func _new_opponent() -> void:
	if config == null:
		SceneRouter.replace_with(Routes.PREBATTLE)
		return
	var opponent := OpponentSelector.pick_with_seed(config.player_hero, BattleLaunchConfig.generate_seed())
	last_config = config.with_opponent(opponent, CardDatabase)
	SceneRouter.replace_with(Routes.OPPONENT_SEARCH, {BattleLaunchConfig.PARAM_KEY: last_config})


func handle_back_request() -> bool:
	SceneRouter.reset_to(Routes.MAIN_MENU)
	return true
