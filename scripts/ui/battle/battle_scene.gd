extends Control
## Battle screen: manages a full match between the player and the AI.
## Uses BattleSession for all engine/AI interaction — never duplicates rules.

const CARD_MIN := Vector2(160, 220)
const CREATURE_MIN := Vector2(180, 140)
const BTN_MIN := Vector2(320, 80)
const EVENT_TIME := 0.55
const AI_DELAY := 0.45

const KEYWORD_RU := {
	"ONSLAUGHT": "Натиск", "PROVOKE": "Провокация",
	"DEFERRAL": "Отложение", "FRENZY": "Неистовство",
}

enum UIState {
	TEST_MODE, MULLIGAN, PLAYER_IDLE, CARD_SELECTED, ATTACKER_SELECTED,
	HERO_POWER_TARGET, SOUL_SHARD_CHOICE, CHOICE_MODAL,
	RESOLVING, AI_TURN, MATCH_ENDED,
}

var route_params: Dictionary = {}

var _session: BattleSession
var _ui_state: UIState = UIState.TEST_MODE
var _selected_card_id: int = 0
var _selected_attacker_id: int = 0
var _shard_card_id: int = 0
var _shard_max: int = 0
var _shard_value: int = 0
var _event_queue: Array[Dictionary] = []
var _event_timer: float = 0.0
var _ai_steps: Array[Dictionary] = []
var _ai_step_index: int = 0
var _ai_step_events: Array[Dictionary] = []
var _presentation_observation: Dictionary = {}
var _presentation_options: Dictionary = {}
var _valid_targets: Array[int] = []
var _mulligan_picks: Array[int] = []

var _opp_name_lbl: Label
var _opp_hp_lbl: Label
var _opp_energy_lbl: Label
var _opp_shards_lbl: Label
var _opp_artifact_lbl: Label
var _opp_board: HBoxContainer
var _opp_hand_lbl: Label
var _opp_deck_lbl: Label
var _opp_hero_btn: Button

var _plr_name_lbl: Label
var _plr_hp_lbl: Label
var _plr_energy_lbl: Label
var _plr_shards_lbl: Label
var _plr_artifact_lbl: Label
var _plr_board: HBoxContainer
var _plr_hero_btn: Button

var _hand_box: HBoxContainer
var _turn_lbl: Label
var _end_turn_btn: Button
var _hero_power_btn: Button
var _impulse_btn: Button
var _event_banner: Label
var _status_lbl: Label
var _log_text: RichTextLabel

var _mulligan_overlay: Control
var _mulligan_box: HBoxContainer
var _mulligan_btn: Button
var _choice_overlay: Control
var _choice_box: HBoxContainer
var _shard_overlay: Control
var _shard_lbl: Label
var _detail_overlay: Control
var _detail_text: RichTextLabel


func apply_route_params(params: Dictionary) -> void:
	route_params = params


func _ready() -> void:
	var cfg: Variant = route_params.get(BattleLaunchConfig.PARAM_KEY)
	if cfg is BattleLaunchConfig:
		_presentation_options = (cfg as BattleLaunchConfig).presentation_options.duplicate(true)
		_build_battle_ui()
		_start_match(cfg as BattleLaunchConfig)
	else:
		_build_test_mode()


func _process(delta: float) -> void:
	if _ui_state == UIState.RESOLVING or _ui_state == UIState.AI_TURN:
		_tick_events(delta)


# ==============================================================================
#  TEST MODE — backward compatibility with smoke_test navigation checks
# ==============================================================================

func _build_test_mode() -> void:
	_ui_state = UIState.TEST_MODE
	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	var title := Label.new()
	title.text = "Бой (тестовый режим)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_v_spacer(col, 48)
	for outcome: MatchOutcome.Result in MatchOutcome.Result.values():
		var key: String = MatchOutcome.Result.find_key(outcome)
		var btn := Button.new()
		btn.name = "Finish%sButton" % key.capitalize()
		btn.text = "Завершить бой: %s" % MatchOutcome.title(outcome)
		btn.custom_minimum_size = BTN_MIN
		btn.pressed.connect(_go_result.bind(outcome))
		col.add_child(btn)
	var menu_btn := Button.new()
	menu_btn.name = "MainMenuButton"
	menu_btn.text = "В главное меню"
	menu_btn.custom_minimum_size = BTN_MIN
	menu_btn.pressed.connect(func() -> void: SceneRouter.reset_to(Routes.MAIN_MENU))
	col.add_child(menu_btn)


func _go_result(outcome: MatchOutcome.Result) -> void:
	SceneRouter.replace_with(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: outcome})


# ==============================================================================
#  BATTLE UI LAYOUT
# ==============================================================================

func _build_battle_ui() -> void:
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	safe.add_child(root)

	_build_top_bar(root)
	_build_opp_hero_bar(root)
	_opp_board = _board_row(root, "OpponentBoard")
	_build_center_bar(root)
	_plr_board = _board_row(root, "PlayerBoard")
	_build_plr_hero_bar(root)
	_build_hand(root)
	_build_log_row(root)

	_build_event_banner()
	_build_status_label()
	_build_mulligan_overlay()
	_build_choice_overlay()
	_build_shard_overlay()
	_build_detail_overlay()


func _build_top_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 44
	parent.add_child(bar)
	_turn_lbl = Label.new()
	_turn_lbl.text = "Ход 0"
	_turn_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(_turn_lbl)
	var menu_btn := Button.new()
	menu_btn.name = "MainMenuButton"
	menu_btn.text = "Меню"
	menu_btn.custom_minimum_size.x = 160
	menu_btn.pressed.connect(func() -> void: SceneRouter.reset_to(Routes.MAIN_MENU))
	bar.add_child(menu_btn)


func _build_opp_hero_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 72
	bar.add_theme_constant_override("separation", 16)
	parent.add_child(bar)
	_opp_hero_btn = Button.new()
	_opp_hero_btn.custom_minimum_size.x = 200
	_opp_hero_btn.pressed.connect(_on_hero_tapped.bind(false))
	bar.add_child(_opp_hero_btn)
	_opp_name_lbl = _label(bar, "Противник")
	_opp_hp_lbl = _label(bar, "HP:30")
	_opp_energy_lbl = _label(bar, "E:0/0")
	_opp_shards_lbl = _label(bar, "S:0")
	_opp_artifact_lbl = _label(bar, "")
	_opp_hand_lbl = _label(bar, "Рука:0")
	_opp_deck_lbl = _label(bar, "Колода:0")


func _build_plr_hero_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 72
	bar.add_theme_constant_override("separation", 16)
	parent.add_child(bar)
	_plr_hero_btn = Button.new()
	_plr_hero_btn.custom_minimum_size.x = 200
	_plr_hero_btn.pressed.connect(_on_hero_tapped.bind(true))
	bar.add_child(_plr_hero_btn)
	_plr_name_lbl = _label(bar, "Игрок")
	_plr_hp_lbl = _label(bar, "HP:30")
	_plr_energy_lbl = _label(bar, "E:0/0")
	_plr_shards_lbl = _label(bar, "S:0")
	_plr_artifact_lbl = _label(bar, "")
	_hero_power_btn = Button.new()
	_hero_power_btn.text = "Сила героя"
	_hero_power_btn.custom_minimum_size = Vector2(240, 64)
	_hero_power_btn.pressed.connect(_on_hero_power_pressed)
	bar.add_child(_hero_power_btn)
	_impulse_btn = Button.new()
	_impulse_btn.text = "Импульс"
	_impulse_btn.custom_minimum_size = Vector2(200, 64)
	_impulse_btn.pressed.connect(_on_impulse_pressed)
	bar.add_child(_impulse_btn)


func _build_center_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 56
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	parent.add_child(bar)
	_status_lbl = Label.new()
	_status_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bar.add_child(_status_lbl)
	_end_turn_btn = Button.new()
	_end_turn_btn.text = "Завершить ход"
	_end_turn_btn.custom_minimum_size = Vector2(280, 52)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	bar.add_child(_end_turn_btn)


func _build_hand(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "HandScroll"
	scroll.custom_minimum_size.y = CARD_MIN.y + 16
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	_hand_box = HBoxContainer.new()
	_hand_box.name = "Hand"
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_hand_box)


func _build_log_row(parent: Control) -> void:
	_log_text = RichTextLabel.new()
	_log_text.name = "TurnLog"
	_log_text.custom_minimum_size.y = 44
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.fit_content = true
	_log_text.add_theme_font_size_override("normal_font_size", 24)
	parent.add_child(_log_text)


func _board_row(parent: Control, row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size.y = CREATURE_MIN.y + 12
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _build_event_banner() -> void:
	_event_banner = Label.new()
	_event_banner.name = "EventBanner"
	_event_banner.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_event_banner.offset_top = 160
	_event_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_banner.add_theme_font_size_override("font_size", 44)
	_event_banner.visible = false
	add_child(_event_banner)


func _build_status_label() -> void:
	pass


func _build_mulligan_overlay() -> void:
	_mulligan_overlay = ColorRect.new()
	_mulligan_overlay.name = "MulliganOverlay"
	_mulligan_overlay.color = Color(0, 0, 0, 0.75)
	_mulligan_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_mulligan_overlay.visible = false
	add_child(_mulligan_overlay)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_mulligan_overlay.add_child(col)
	var title := Label.new()
	title.text = "Замена карт"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	col.add_child(title)
	var hint := Label.new()
	hint.text = "Нажмите на карты, которые хотите заменить"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	_v_spacer(col, 24)
	_mulligan_box = HBoxContainer.new()
	_mulligan_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_mulligan_box.add_theme_constant_override("separation", 16)
	col.add_child(_mulligan_box)
	_v_spacer(col, 24)
	_mulligan_btn = Button.new()
	_mulligan_btn.text = "Подтвердить"
	_mulligan_btn.custom_minimum_size = BTN_MIN
	_mulligan_btn.pressed.connect(_submit_mulligan)
	col.add_child(_mulligan_btn)


func _build_choice_overlay() -> void:
	_choice_overlay = ColorRect.new()
	_choice_overlay.name = "ChoiceOverlay"
	_choice_overlay.color = Color(0, 0, 0, 0.75)
	_choice_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_choice_overlay.visible = false
	add_child(_choice_overlay)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_overlay.add_child(col)
	var title := Label.new()
	title.text = "Выберите карту"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	col.add_child(title)
	_v_spacer(col, 24)
	_choice_box = HBoxContainer.new()
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_theme_constant_override("separation", 16)
	col.add_child(_choice_box)


func _build_shard_overlay() -> void:
	_shard_overlay = ColorRect.new()
	_shard_overlay.name = "ShardOverlay"
	_shard_overlay.color = Color(0, 0, 0, 0.75)
	_shard_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_shard_overlay.visible = false
	add_child(_shard_overlay)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_shard_overlay.add_child(col)
	var title := Label.new()
	title.text = "Осколки души"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	col.add_child(title)
	_shard_lbl = Label.new()
	_shard_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_shard_lbl)
	_v_spacer(col, 16)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(80, 64)
	minus_btn.pressed.connect(func() -> void: _shard_adjust(-1))
	row.add_child(minus_btn)
	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(80, 64)
	plus_btn.pressed.connect(func() -> void: _shard_adjust(1))
	row.add_child(plus_btn)
	_v_spacer(col, 16)
	var ok_btn := Button.new()
	ok_btn.text = "Потратить"
	ok_btn.custom_minimum_size = BTN_MIN
	ok_btn.pressed.connect(_confirm_shard)
	col.add_child(ok_btn)
	var skip_btn := Button.new()
	skip_btn.text = "Пропустить (0)"
	skip_btn.custom_minimum_size = BTN_MIN
	skip_btn.pressed.connect(_skip_shard)
	col.add_child(skip_btn)


func _build_detail_overlay() -> void:
	_detail_overlay = CardDetailOverlay.new()
	add_child(_detail_overlay)
	_detail_text = (_detail_overlay as CardDetailOverlay).detail_text


func _show_card_detail(card_data: Dictionary) -> void:
	var definition := CardDatabase.get_card(StringName(str(card_data.get("card_id", ""))))
	if definition == null:
		return
	(_detail_overlay as CardDetailOverlay).show_card(definition, int(card_data.get("current_cost", definition.cost)))


func _card_with_info(card_data: Dictionary, card_btn: Button) -> HBoxContainer:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	wrap.add_child(card_btn)
	var info := Button.new()
	info.name = "InfoButton"
	info.text = "i"
	info.custom_minimum_size = Vector2(40, 64)
	info.pressed.connect(_show_card_detail.bind(card_data.duplicate(true)))
	wrap.add_child(info)
	return wrap


# ==============================================================================
#  MATCH LIFECYCLE
# ==============================================================================

func _start_match(cfg: BattleLaunchConfig) -> void:
	_session = BattleSession.new(cfg)
	var result := _session.start()
	if not result.ok:
		push_error("BattleScene: setup failed: %s" % result.message)
		return
	_session.run_ai_mulligan()
	_show_mulligan()
	_refresh_ui()


func _show_mulligan() -> void:
	_ui_state = UIState.MULLIGAN
	_mulligan_picks.clear()
	_mulligan_overlay.visible = true
	_rebuild_mulligan_cards()


func _rebuild_mulligan_cards() -> void:
	_clear(_mulligan_box)
	var obs := _session.get_observation()
	var hand: Array = obs.get("own", {}).get("hand", [])
	for card_data: Dictionary in hand:
		var iid: int = int(card_data.get("instance_id", 0))
		var btn := _make_card_btn(card_data)
		btn.custom_minimum_size = CARD_MIN * 1.2
		if iid in _mulligan_picks:
			btn.modulate = Color(1.0, 0.4, 0.4)
		btn.pressed.connect(_toggle_mulligan.bind(iid))
		_mulligan_box.add_child(_card_with_info(card_data, btn))


func _toggle_mulligan(iid: int) -> void:
	if iid in _mulligan_picks:
		_mulligan_picks.erase(iid)
	else:
		_mulligan_picks.append(iid)
	_rebuild_mulligan_cards()


func _submit_mulligan() -> void:
	var ids: Array[int] = []
	ids.assign(_mulligan_picks)
	var result := _session.submit_mulligan(ids)
	if not result.ok:
		_log("Ошибка маллигана: %s" % result.message)
		return
	_mulligan_overlay.visible = false
	_mulligan_picks.clear()
	_refresh_ui()
	_after_command(result)


func _after_command(result: ActionResult) -> void:
	if not result.events.is_empty():
		_event_queue.append_array(result.events)
		_event_timer = 0.0
		_ui_state = UIState.RESOLVING
		return
	_check_turn()


func _check_turn() -> void:
	if _session.is_over():
		_end_match()
	elif _session.is_choice_pending():
		_show_choice()
	elif _session.is_player_turn():
		_set_state(UIState.PLAYER_IDLE)
		_refresh_ui()
	else:
		_start_ai_turn()


# ==============================================================================
#  UI REFRESH
# ==============================================================================

func _refresh_ui() -> void:
	if _session == null:
		return
	var obs := _presentation_observation if _ui_state == UIState.AI_TURN and not _presentation_observation.is_empty() else _session.get_observation()
	if obs.is_empty():
		return
	var own: Dictionary = obs.get("own", {})
	var opp: Dictionary = obs.get("opponent", {})
	_refresh_hero_bar(opp, false)
	_refresh_hero_bar(own, true)
	_refresh_board(_opp_board, opp.get("board", []), false)
	_refresh_board(_plr_board, own.get("board", []), true)
	_refresh_hand_cards(own.get("hand", []))
	_refresh_controls(obs)
	var tn: int = int(obs.get("turn_number", 0))
	_turn_lbl.text = "Ход %d" % tn


func _refresh_hero_bar(data: Dictionary, is_player: bool) -> void:
	var hero: Dictionary = data.get("hero", {})
	var hero_id := StringName(hero.get("id", ""))
	var hero_data: Dictionary = HeroCatalog.HEROES.get(hero_id, {})
	var name_ru: String = hero_data.get("name_ru", String(hero_id))
	var hp: int = int(hero.get("health", 0))
	var e_cur: int = int(data.get("energy_current", 0))
	var e_max: int = int(data.get("energy_max", 0))
	var shards: int = int(data.get("soul_shards", 0))
	var artifact: Dictionary = data.get("artifact", {})
	var art_text := ""
	if not artifact.is_empty():
		var art_id := StringName(artifact.get("card_id", ""))
		var art_def := CardDatabase.get_card(art_id)
		art_text = "%s [%d]" % [art_def.name_ru if art_def != null else String(art_id), int(artifact.get("charges", 0))]
	if is_player:
		_plr_hero_btn.text = name_ru
		_plr_name_lbl.text = name_ru
		_plr_hp_lbl.text = "HP:%d" % hp
		_plr_energy_lbl.text = "E:%d/%d" % [e_cur, e_max]
		_plr_shards_lbl.text = "S:%d" % shards
		_plr_artifact_lbl.text = art_text
	else:
		_opp_hero_btn.text = name_ru
		_opp_name_lbl.text = name_ru
		_opp_hp_lbl.text = "HP:%d" % hp
		_opp_energy_lbl.text = "E:%d/%d" % [e_cur, e_max]
		_opp_shards_lbl.text = "S:%d" % shards
		_opp_artifact_lbl.text = art_text
		_opp_hand_lbl.text = "Рука:%d" % int(data.get("hand_count", 0))
		_opp_deck_lbl.text = "Колода:%d" % int(data.get("deck_count", 0))


func _refresh_board(container: HBoxContainer, board: Array, is_player: bool) -> void:
	_clear(container)
	for creature: Dictionary in board:
		var btn := _make_creature_btn(creature)
		var iid: int = int(creature.get("instance_id", 0))
		if is_player:
			btn.pressed.connect(_on_own_creature_tapped.bind(iid))
		else:
			btn.pressed.connect(_on_enemy_creature_tapped.bind(iid))
		if iid == _selected_attacker_id:
			btn.modulate = Color(0.5, 0.85, 1.0)
		elif iid in _valid_targets:
			btn.modulate = Color(1.0, 0.9, 0.3)
		container.add_child(btn)


func _refresh_hand_cards(hand: Array) -> void:
	_clear(_hand_box)
	var legal_cards: Array[int] = []
	if _ui_state == UIState.PLAYER_IDLE or _ui_state == UIState.CARD_SELECTED \
			or _ui_state == UIState.ATTACKER_SELECTED or _ui_state == UIState.HERO_POWER_TARGET:
		for command: MatchCommand in _session.get_legal_commands():
			if command.kind == MatchCommand.Kind.PLAY_CARD and command.source_id not in legal_cards:
				legal_cards.append(command.source_id)
	for card_data: Dictionary in hand:
		var iid: int = int(card_data.get("instance_id", 0))
		var btn := _make_card_btn(card_data)
		btn.disabled = iid not in legal_cards
		btn.pressed.connect(_on_hand_card_tapped.bind(iid))
		if iid == _selected_card_id:
			btn.modulate = Color(0.5, 0.85, 1.0)
		_hand_box.add_child(_card_with_info(card_data, btn))


func _refresh_controls(obs: Dictionary) -> void:
	var can_act: bool = _ui_state == UIState.PLAYER_IDLE or _ui_state == UIState.CARD_SELECTED \
		or _ui_state == UIState.ATTACKER_SELECTED or _ui_state == UIState.HERO_POWER_TARGET
	var own: Dictionary = obs.get("own", {})
	_end_turn_btn.disabled = not can_act or not _session.is_player_turn()
	var hp_cost: int = GameRules.HERO_ABILITY_COST
	var hp_can: bool = can_act and _session.is_player_turn() and not _session.get_valid_hero_power_targets().is_empty()
	_hero_power_btn.disabled = not hp_can
	_hero_power_btn.text = "%s (%d)" % [_session.hero_power_name(), hp_cost] if _session != null else "Сила героя"
	var imp_avail: bool = own.get("impulse_shard_available", false)
	_impulse_btn.disabled = not (can_act and _session.is_player_turn() and imp_avail)
	_impulse_btn.visible = imp_avail or int(obs.get("turn_number", 0)) <= 2
	match _ui_state:
		UIState.AI_TURN:
			_status_lbl.text = "Ход противника..."
		UIState.RESOLVING:
			_status_lbl.text = ""
		UIState.CARD_SELECTED:
			_status_lbl.text = "Выберите цель или нажмите ещё раз для отмены"
		UIState.ATTACKER_SELECTED:
			_status_lbl.text = "Выберите цель атаки"
		UIState.HERO_POWER_TARGET:
			_status_lbl.text = "Выберите цель способности"
		_:
			_status_lbl.text = ""


# ==============================================================================
#  STATE MACHINE — INPUT HANDLING
# ==============================================================================

func _set_state(new_state: UIState) -> void:
	_ui_state = new_state
	if new_state != UIState.CARD_SELECTED and new_state != UIState.ATTACKER_SELECTED \
			and new_state != UIState.HERO_POWER_TARGET:
		_selected_card_id = 0
		_selected_attacker_id = 0
		_valid_targets.clear()


func _on_hand_card_tapped(iid: int) -> void:
	if _ui_state != UIState.PLAYER_IDLE and _ui_state != UIState.CARD_SELECTED \
			and _ui_state != UIState.ATTACKER_SELECTED and _ui_state != UIState.HERO_POWER_TARGET:
		return
	if _selected_card_id == iid:
		_set_state(UIState.PLAYER_IDLE)
		_refresh_ui()
		return
	_selected_card_id = iid
	_selected_attacker_id = 0
	var targets := _session.get_valid_play_targets(iid)
	if targets.is_empty():
		_set_state(UIState.PLAYER_IDLE)
		_refresh_ui()
		return
	if targets.size() == 1 and targets[0] == 0:
		_try_play_card(iid, 0)
		return
	if 0 in targets:
		targets.erase(0)
	_valid_targets.assign(targets)
	_set_state(UIState.CARD_SELECTED)
	_refresh_ui()


func _on_own_creature_tapped(iid: int) -> void:
	match _ui_state:
		UIState.PLAYER_IDLE:
			var atk_targets := _session.get_valid_attack_targets(iid)
			if atk_targets.is_empty():
				return
			_selected_attacker_id = iid
			_selected_card_id = 0
			_valid_targets.assign(atk_targets)
			_set_state(UIState.ATTACKER_SELECTED)
			_refresh_ui()
		UIState.ATTACKER_SELECTED:
			if iid == _selected_attacker_id:
				_set_state(UIState.PLAYER_IDLE)
				_refresh_ui()
			else:
				var atk_targets := _session.get_valid_attack_targets(iid)
				if not atk_targets.is_empty():
					_selected_attacker_id = iid
					_valid_targets.assign(atk_targets)
					_refresh_ui()
		UIState.CARD_SELECTED:
			if iid in _valid_targets:
				_try_play_card(_selected_card_id, iid)
		UIState.HERO_POWER_TARGET:
			_use_hero_power_on(iid)
		_:
			pass


func _on_enemy_creature_tapped(iid: int) -> void:
	match _ui_state:
		UIState.ATTACKER_SELECTED:
			if iid in _valid_targets:
				_try_attack(_selected_attacker_id, iid)
		UIState.CARD_SELECTED:
			if iid in _valid_targets:
				_try_play_card(_selected_card_id, iid)
		_:
			pass


func _on_hero_tapped(is_own: bool) -> void:
	if _session == null:
		return
	var obs := _session.get_observation()
	var hero_iid: int
	if is_own:
		hero_iid = int(obs.get("own", {}).get("hero", {}).get("instance_id", 0))
	else:
		hero_iid = int(obs.get("opponent", {}).get("hero", {}).get("instance_id", 0))
	match _ui_state:
		UIState.ATTACKER_SELECTED:
			if hero_iid in _valid_targets:
				_try_attack(_selected_attacker_id, hero_iid)
		UIState.CARD_SELECTED:
			if hero_iid in _valid_targets:
				_try_play_card(_selected_card_id, hero_iid)
		_:
			pass


# ==============================================================================
#  CARD PLAY
# ==============================================================================

func _try_play_card(card_id: int, target_id: int) -> void:
	var shard_options := _get_shard_options(card_id)
	if shard_options.size() > 1:
		_shard_card_id = card_id
		_shard_max = shard_options.max()
		_shard_value = 0
		_show_shard_choice(target_id)
		return
	var choices: Dictionary = {}
	if not shard_options.is_empty() and shard_options[0] > 0:
		choices[MatchCommand.CHOICE_SOUL_SHARDS] = shard_options[0]
	var result := _session.play_card(card_id, target_id, choices)
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_log("Карта сыграна")
		_after_command(result)
	else:
		_log("Нельзя: %s" % result.message)
	_refresh_ui()


func _get_shard_options(card_id: int) -> Array[int]:
	var amounts: Array[int] = []
	for cmd: MatchCommand in _session.get_legal_commands():
		if cmd.kind == MatchCommand.Kind.PLAY_CARD and cmd.source_id == card_id:
			var spend: Variant = cmd.choices.get(MatchCommand.CHOICE_SOUL_SHARDS)
			if spend != null:
				var val: int = int(spend)
				if val not in amounts:
					amounts.append(val)
	amounts.sort()
	return amounts


func _show_shard_choice(target_id: int) -> void:
	_shard_value = 0
	_shard_overlay.visible = true
	_shard_lbl.text = "Потратить: %d / %d" % [_shard_value, _shard_max]
	_shard_overlay.set_meta("target_id", target_id)
	_set_state(UIState.SOUL_SHARD_CHOICE)


func _shard_adjust(delta: int) -> void:
	_shard_value = clampi(_shard_value + delta, 0, _shard_max)
	_shard_lbl.text = "Потратить: %d / %d" % [_shard_value, _shard_max]


func _confirm_shard() -> void:
	var target_id: int = int(_shard_overlay.get_meta("target_id", 0))
	_shard_overlay.visible = false
	var choices := {MatchCommand.CHOICE_SOUL_SHARDS: _shard_value}
	var result := _session.play_card(_shard_card_id, target_id, choices)
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_log("Карта сыграна (осколки: %d)" % _shard_value)
		_after_command(result)
	else:
		_log("Нельзя: %s" % result.message)
	_refresh_ui()


func _skip_shard() -> void:
	var target_id: int = int(_shard_overlay.get_meta("target_id", 0))
	_shard_overlay.visible = false
	var result := _session.play_card(_shard_card_id, target_id, {MatchCommand.CHOICE_SOUL_SHARDS: 0})
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_log("Карта сыграна (без осколков)")
		_after_command(result)
	else:
		_log("Нельзя: %s" % result.message)
	_refresh_ui()


# ==============================================================================
#  ATTACK
# ==============================================================================

func _try_attack(attacker_id: int, target_id: int) -> void:
	var result := _session.attack(attacker_id, target_id)
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_log("Атака!")
		_after_command(result)
	else:
		_log("Нельзя атаковать: %s" % result.message)
	_refresh_ui()


# ==============================================================================
#  HERO POWER
# ==============================================================================

func _on_hero_power_pressed() -> void:
	if _ui_state != UIState.PLAYER_IDLE and _ui_state != UIState.CARD_SELECTED \
			and _ui_state != UIState.ATTACKER_SELECTED:
		return
	var targets := _session.get_valid_hero_power_targets()
	if targets.is_empty():
		return
	if 0 not in targets:
		_set_state(UIState.HERO_POWER_TARGET)
		_selected_card_id = 0
		_selected_attacker_id = 0
		_valid_targets.assign(targets)
		_refresh_ui()
	else:
		_use_hero_power_on(0)


func _use_hero_power_on(target_id: int) -> void:
	if _ui_state != UIState.HERO_POWER_TARGET and _ui_state != UIState.PLAYER_IDLE \
			and _ui_state != UIState.CARD_SELECTED and _ui_state != UIState.ATTACKER_SELECTED:
		return
	if target_id not in _session.get_valid_hero_power_targets():
		return
	var result := _session.use_hero_power(target_id)
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_log("Сила героя использована")
		_after_command(result)
	else:
		_log("Нельзя: %s" % result.message)
	_refresh_ui()


# ==============================================================================
#  IMPULSE SHARD / END TURN
# ==============================================================================

func _on_impulse_pressed() -> void:
	if _ui_state != UIState.PLAYER_IDLE and _ui_state != UIState.CARD_SELECTED:
		return
	var result := _session.use_impulse_shard()
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_log("Осколок импульса использован")
		_after_command(result)
	else:
		_log("Нельзя: %s" % result.message)
	_refresh_ui()


func _on_end_turn_pressed() -> void:
	if _ui_state != UIState.PLAYER_IDLE and _ui_state != UIState.CARD_SELECTED \
			and _ui_state != UIState.ATTACKER_SELECTED and _ui_state != UIState.HERO_POWER_TARGET:
		return
	if not _session.is_player_turn():
		return
	_set_state(UIState.RESOLVING)
	var result := _session.end_turn()
	if result.ok:
		_log("Ход завершён")
		_after_command(result)
	else:
		_log("Ошибка: %s" % result.message)


# ==============================================================================
#  CHOICE MODAL (Cartographer CHOOSE)
# ==============================================================================

func _show_choice() -> void:
	_set_state(UIState.CHOICE_MODAL)
	_choice_overlay.visible = true
	_clear(_choice_box)
	var obs := _session.get_observation()
	var pending: Dictionary = obs.get("pending_choice", {})
	var options: Array = pending.get("options", [])
	for opt: Dictionary in options:
		var iid: int = int(opt.get("instance_id", 0))
		var btn := _make_card_btn(opt)
		btn.custom_minimum_size = CARD_MIN * 1.2
		btn.pressed.connect(_choose_option.bind(iid))
		_choice_box.add_child(btn)


func _choose_option(option_id: int) -> void:
	_choice_overlay.visible = false
	var result := _session.choose(option_id)
	if result.ok:
		_log("Выбор сделан")
		_after_command(result)
	else:
		_log("Ошибка выбора: %s" % result.message)
	_refresh_ui()


# ==============================================================================
#  AI TURN
# ==============================================================================

func _start_ai_turn() -> void:
	_set_state(UIState.AI_TURN)
	_presentation_observation = _session.get_observation()
	_refresh_ui()
	_ai_steps = _session.run_ai_turn_steps()
	_ai_step_index = 0
	_ai_step_events.clear()
	_event_timer = 0.0


func _tick_events(delta: float) -> void:
	_event_timer += delta
	var delay: float = (AI_DELAY if _ui_state == UIState.AI_TURN else EVENT_TIME) \
		if _presentation_options.get(PlayerSetupData.ANIMATIONS, true) else 0.001
	if _event_timer < delay:
		return
	_event_timer = 0.0
	if _ui_state == UIState.AI_TURN:
		_tick_ai_presentation()
		return
	while not _event_queue.is_empty():
		var evt: Dictionary = _event_queue.pop_front()
		var txt := _event_text(evt)
		if not txt.is_empty():
			_show_banner(txt)
			_refresh_ui()
			return
		_refresh_ui()
	_event_banner.visible = false
	_check_turn()


func _tick_ai_presentation() -> void:
	if _ai_step_events.is_empty():
		if _ai_step_index >= _ai_steps.size():
			_presentation_observation.clear()
			_event_banner.visible = false
			_check_turn()
			return
		var step: Dictionary = _ai_steps[_ai_step_index]
		_ai_step_index += 1
		_presentation_observation = step["observation_after_command"]
		_ai_step_events.assign(step["events"])
		_refresh_ui()
	while not _ai_step_events.is_empty():
		var text_line := _event_text(_ai_step_events.pop_front())
		if not text_line.is_empty():
			_show_banner(text_line)
			return


func _show_banner(txt: String) -> void:
	_event_banner.text = txt
	_event_banner.visible = true


func _event_text(evt: Dictionary) -> String:
	var etype: Variant = evt.get("type")
	if etype == MatchEvent.CARD_PLAYED:
		var cid := StringName(str(evt.get("card_id", "")))
		var d := CardDatabase.get_card(cid)
		return "Сыграна: %s" % (d.name_ru if d != null else String(cid))
	if etype == MatchEvent.ATTACK_DECLARED:
		return "Атака!"
	if etype == MatchEvent.DAMAGE_DEALT:
		return "Урон: %d" % int(evt.get("amount", 0))
	if etype == MatchEvent.CREATURE_DIED:
		return "Существо уничтожено"
	if etype == MatchEvent.HERO_POWER_USED:
		return "Сила героя"
	if etype == MatchEvent.TURN_STARTED:
		return "Ход %d" % int(evt.get("turn_number", 0))
	if etype == MatchEvent.IMPULSE_SHARD_USED:
		return "Осколок импульса!"
	if etype == MatchEvent.MATCH_ENDED:
		return "Бой завершён!"
	return ""


# ==============================================================================
#  MATCH END
# ==============================================================================

func _end_match() -> void:
	_set_state(UIState.MATCH_ENDED)
	_event_banner.visible = false
	_refresh_ui()
	var outcome := _session.get_outcome()
	var params: Dictionary = {
		ResultScreen.PARAM_OUTCOME: outcome,
		"turns": _session.turn_count,
		"cards_player": _session.cards_played_player,
		"cards_ai": _session.cards_played_ai,
		BattleLaunchConfig.PARAM_KEY: _session.config,
		"player_hero": _session.config.player_hero,
		"opponent_hero": _session.config.opponent_hero,
		"ai_difficulty": _session.config.ai_difficulty,
	}
	SceneRouter.replace_with(Routes.RESULT, params)


# ==============================================================================
#  HELPERS — node creation
# ==============================================================================

func _make_card_btn(card_data: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_MIN
	btn.clip_text = true
	var card_id := StringName(str(card_data.get("card_id", "")))
	var definition := CardDatabase.get_card(card_id)
	var name_ru: String = definition.name_ru if definition != null else String(card_id)
	var cost: int = int(card_data.get("current_cost", card_data.get("definition", {}).get("cost", 0)))
	var def_data: Dictionary = card_data.get("definition", {})
	var type_str: String = String(def_data.get("type", ""))
	var stats := ""
	match type_str:
		"CREATURE":
			stats = "%d/%d" % [int(def_data.get("attack", 0)), int(def_data.get("health", 0))]
		"ARTIFACT":
			stats = "Зар.%d" % int(def_data.get("charges", 0))
		"SPELL":
			stats = "Закл."
	var lines: PackedStringArray = [
		"[%d]" % cost,
		name_ru,
		stats,
	]
	btn.text = "\n".join(lines)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return btn


func _make_creature_btn(creature: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CREATURE_MIN
	btn.clip_text = true
	var card_id := StringName(str(creature.get("card_id", "")))
	var definition := CardDatabase.get_card(card_id)
	var name_ru: String = definition.name_ru if definition != null else String(card_id)
	var atk: int = int(creature.get("attack", 0))
	var hp: int = int(creature.get("health", 0))
	var armor: int = int(creature.get("armor", 0))
	var kws: Array = creature.get("keywords", [])
	var kw_parts: PackedStringArray = []
	for kw: Variant in kws:
		kw_parts.append(KEYWORD_RU.get(String(kw), String(kw)))
	var lines: PackedStringArray = [name_ru]
	if not kw_parts.is_empty():
		lines.append(" ".join(kw_parts))
	var stat_line := "%d/%d" % [atk, hp]
	if armor > 0:
		stat_line += " Б:%d" % armor
	lines.append(stat_line)
	btn.text = "\n".join(lines)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return btn


func _label(parent: Control, txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	parent.add_child(lbl)
	return lbl


func _v_spacer(parent: Control, height: float) -> void:
	var sp := Control.new()
	sp.custom_minimum_size.y = height
	parent.add_child(sp)


func _clear(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _log(msg: String) -> void:
	if _log_text != null:
		_log_text.append_text(msg + "\n")
