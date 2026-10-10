extends Control
## Battle V2 + Mulligan V1 (Stage 7 Visual Alpha). The field dominates: opponent on
## top, player at the bottom, a clean centre and the HUD on the edges. Every action
## goes through BattleSession → MatchEngine; playability and targets come from the
## engine's legal commands, the UI never duplicates rules. Presentation (animations,
## history, previews) reads only sanitized observations and MatchEvents, so turning
## animations off keeps exactly the same state and event order.

const EVENT_TIME := 0.55
const AI_DELAY := 0.45
const BTN_MIN := Vector2(320, 80)
const HAND_GAP := 12.0
const PIECE_GAP := 14.0
const DIM_SHADER := preload("res://assets/ui/visual_alpha/shaders/battlefield_dim.gdshader")
## Events that get their own presentation beat; the rest resolve in between.
const KEY_EVENTS: Array[StringName] = [MatchEvent.CARD_PLAYED, MatchEvent.ATTACK_DECLARED, MatchEvent.CREATURE_DIED,
	MatchEvent.HERO_POWER_USED, MatchEvent.TURN_STARTED, MatchEvent.IMPULSE_SHARD_USED, MatchEvent.MATCH_ENDED]

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
var _history: BattleHistory
var _animations := true
var _hints := true

var _battlefield: CitadelBattlefield
var _hud: Control
var _effects: Control
var _field_rect := Rect2()
var _center_y := 0.0
var _piece_scale := 1.0
var _opp_hero: HeroClusterView
var _plr_hero: HeroClusterView
var _opp_hero_btn: Button
var _plr_hero_btn: Button
var _opp_board: HBoxContainer
var _plr_board: HBoxContainer
var _hand_box: Control
var _card_actions: VBoxContainer
var _play_btn: Button
var _card_detail_btn: Button
var _cancel_btn: Button
var _turn_lbl: Label
var _turn_owner_lbl: Label
var _end_turn_btn: Button
var _end_turn_ready_box: StyleBoxFlat
var _end_turn_normal_box: StyleBox
var _hero_power_btn: HeroPowerButton
var _impulse_btn: Button
var _history_btn: Button
var _menu_btn: Button
var _pill: PanelContainer
var _status_lbl: Label
var _hint_lbl: Label
var _event_banner: Label
var _play_preview: FullCardView
var _history_panel: PanelContainer
var _log_text: RichTextLabel

var _mulligan_overlay: Control
var _mulligan_box: HBoxContainer
var _mulligan_btn: Button
var _mulligan_info: Label
var _mulligan_count: Label
var _mulligan_impulse: PanelContainer
var _opponent_portrait: HeroPortraitPlaceholder
var _opponent_name: Label
var _opponent_faction: Label
var _opponent_emblem: EmblemView
var _choice_overlay: Control
var _choice_box: HBoxContainer
var _shard_overlay: Control
var _shard_lbl: Label
var _detail_overlay: Control
var _detail_text: RichTextLabel
var _exit_dialog: ConfirmModal

var _pointer := Vector2(-1, -1)
var _last_rects: Dictionary = {}
var _hand_seen := false
var _display_font: Font


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


func _input(event: InputEvent) -> void:
	if _effects != null and event is InputEventMouseMotion and _is_targeting():
		_pointer = _effects.get_local_mouse_position()
		_effects.queue_redraw()


# ==============================================================================
#  TEST MODE — explicit legacy route without a launch config (smoke navigation)
# ==============================================================================

func _build_test_mode() -> void:
	_ui_state = UIState.TEST_MODE
	UiKit.apply_root_theme(self)
	var backdrop := CitadelBackdrop.create(CitadelBackdrop.Mood.HALL)
	add_child(backdrop)
	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	safe.add_child(col)
	var title := UiKit.make_display_label("БОЙ · ТЕХНИЧЕСКИЙ РЕЖИМ")
	title.add_theme_font_size_override("font_size", VisualTokens.FONT_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	for outcome: MatchOutcome.Result in MatchOutcome.Result.values():
		var key: String = MatchOutcome.Result.find_key(outcome)
		var btn := UiKit.make_button("Завершить бой: %s" % MatchOutcome.title(outcome))
		btn.name = "Finish%sButton" % key.capitalize()
		btn.custom_minimum_size = BTN_MIN
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_go_result.bind(outcome))
		col.add_child(btn)
	var menu_btn := UiKit.make_button("В главное меню")
	menu_btn.name = "MainMenuButton"
	menu_btn.custom_minimum_size = BTN_MIN
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.pressed.connect(func() -> void: SceneRouter.reset_to(Routes.MAIN_MENU))
	col.add_child(menu_btn)


func _go_result(outcome: MatchOutcome.Result) -> void:
	SceneRouter.replace_with(Routes.RESULT, {ResultScreen.PARAM_OUTCOME: outcome})


# ==============================================================================
#  BATTLE UI — field, HUD on the edges, hand fan
# ==============================================================================

func _build_battle_ui() -> void:
	UiKit.apply_root_theme(self)
	_display_font = load(UiKit.DISPLAY_FONT_PATH) as Font
	_animations = bool(_presentation_options.get(PlayerSetupData.ANIMATIONS, true))
	_hints = bool(_presentation_options.get(PlayerSetupData.HINTS, true))
	_battlefield = CitadelBattlefield.new()
	_battlefield.name = "Battlefield"
	_battlefield.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_battlefield)
	_battlefield.set_ambient_enabled(_animations)

	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.base_margin = 16
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	_hud = Control.new()
	_hud.name = "Hud"
	_hud.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud.resized.connect(_layout_hud)
	_hud.gui_input.connect(_on_field_input)
	safe.add_child(_hud)

	_opp_hero = _hero_cluster("OpponentHero", false)
	_plr_hero = _hero_cluster("PlayerHero", true)
	_opp_hero_btn = _opp_hero.portrait_button
	_plr_hero_btn = _plr_hero.portrait_button
	_opp_board = _board_row("OpponentBoard")
	_plr_board = _board_row("PlayerBoard")
	_build_side_controls()
	_build_center_feedback()
	_hand_box = Control.new()
	_hand_box.name = "Hand"
	_hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hand_box)

	_effects = Control.new()
	_effects.name = "Effects"
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_effects.draw.connect(_draw_effects)
	_effects.z_index = 9
	add_child(_effects)

	_build_history_drawer()
	_build_mulligan_overlay()
	_build_choice_overlay()
	_build_shard_overlay()
	_build_detail_overlay()
	_build_exit_dialog()
	_layout_hud.call_deferred()


func _hero_cluster(node_name: String, is_player: bool) -> HeroClusterView:
	var cluster := HeroClusterView.new()
	cluster.name = node_name
	cluster.is_player = is_player
	cluster.portrait_button.pressed.connect(_on_hero_tapped.bind(is_player))
	cluster.artifact_detail_requested.connect(_show_definition_detail)
	_hud.add_child(cluster)
	return cluster


func _board_row(row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(PIECE_GAP))
	_hud.add_child(row)
	return row


func _build_side_controls() -> void:
	_hero_power_btn = HeroPowerButton.new()
	_hero_power_btn.name = "HeroPowerButton"
	_hero_power_btn.pressed.connect(_on_hero_power_pressed)
	_hud.add_child(_hero_power_btn)
	_impulse_btn = UiKit.make_button("ОСКОЛОК ИМПУЛЬСА", UiKit.ButtonRole.COMPACT_BATTLE)
	_impulse_btn.name = "ImpulseButton"
	_impulse_btn.focus_mode = Control.FOCUS_NONE
	_impulse_btn.add_theme_font_size_override("font_size", 20)
	_impulse_btn.tooltip_text = "+1 энергия до конца хода, один раз за матч"
	_impulse_btn.visible = false
	_impulse_btn.pressed.connect(_on_impulse_pressed)
	_hud.add_child(_impulse_btn)

	_play_preview = FullCardView.new()
	_play_preview.name = "PlayedCardPreview"
	_play_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_preview.focus_mode = Control.FOCUS_NONE
	_play_preview.visible = false
	_hud.add_child(_play_preview)

	_turn_lbl = _hud_label("TurnLabel", 24, VisualTokens.COLOR_MUTED)
	_turn_owner_lbl = _hud_label("TurnOwnerLabel", 30, VisualTokens.COLOR_STEEL_900)
	_end_turn_btn = UiKit.make_button("ЗАВЕРШИТЬ ХОД", UiKit.ButtonRole.PRIMARY)
	_end_turn_btn.name = "EndTurnButton"
	_end_turn_btn.focus_mode = Control.FOCUS_NONE
	_end_turn_btn.add_theme_font_size_override("font_size", 26)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_hud.add_child(_end_turn_btn)
	_end_turn_normal_box = _end_turn_btn.get_theme_stylebox("normal")
	_end_turn_ready_box = UiKit._box(VisualTokens.COLOR_STEEL_700, VisualTokens.COLOR_MAGIC_300, 4, VisualTokens.RADIUS_MEDIUM)
	_end_turn_ready_box.shadow_color = Color(VisualTokens.COLOR_MAGIC_300, 0.45)
	_end_turn_ready_box.shadow_size = 10

	_card_actions = VBoxContainer.new()
	_card_actions.name = "CardActions"
	_card_actions.add_theme_constant_override("separation", VisualTokens.SPACE_2)
	_card_actions.visible = false
	_hud.add_child(_card_actions)
	_play_btn = UiKit.make_button("РАЗЫГРАТЬ", UiKit.ButtonRole.PRIMARY)
	_play_btn.name = "PlayCardButton"
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.add_theme_font_size_override("font_size", 26)
	_play_btn.pressed.connect(func() -> void:
		if _selected_card_id != 0:
			_on_hand_card_tapped(_selected_card_id))
	_card_actions.add_child(_play_btn)
	_card_detail_btn = UiKit.make_button("ОПИСАНИЕ", UiKit.ButtonRole.SECONDARY)
	_card_detail_btn.name = "SelectedCardDetailButton"
	_card_detail_btn.focus_mode = Control.FOCUS_NONE
	_card_detail_btn.add_theme_font_size_override("font_size", 24)
	_card_detail_btn.pressed.connect(func() -> void: _show_hand_detail(_selected_card_id))
	_card_actions.add_child(_card_detail_btn)
	_cancel_btn = UiKit.make_button("ОТМЕНА", UiKit.ButtonRole.SUBTLE)
	_cancel_btn.name = "CancelSelectionButton"
	_cancel_btn.focus_mode = Control.FOCUS_NONE
	_cancel_btn.add_theme_font_size_override("font_size", 24)
	_cancel_btn.pressed.connect(_cancel_selection)
	_card_actions.add_child(_cancel_btn)

	_hint_lbl = _hud_label("HintLabel", 22, VisualTokens.COLOR_STEEL_700)
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_history_btn = UiKit.make_button("ИСТОРИЯ", UiKit.ButtonRole.COMPACT_BATTLE)
	_history_btn.name = "HistoryButton"
	_history_btn.focus_mode = Control.FOCUS_NONE
	_history_btn.add_theme_font_size_override("font_size", 24)
	_history_btn.pressed.connect(_toggle_history)
	_hud.add_child(_history_btn)
	_menu_btn = UiKit.make_button("МЕНЮ", UiKit.ButtonRole.COMPACT_BATTLE)
	_menu_btn.name = "MainMenuButton"
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.add_theme_font_size_override("font_size", 24)
	_menu_btn.pressed.connect(_request_exit_battle)
	_hud.add_child(_menu_btn)


func _hud_label(node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if _display_font != null and font_size >= 24:
		label.add_theme_font_override("font", _display_font)
	_hud.add_child(label)
	return label


func _build_center_feedback() -> void:
	_pill = PanelContainer.new()
	_pill.name = "InstructionPill"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_box := UiKit._box(Color(VisualTokens.COLOR_STEEL_900, 0.88), VisualTokens.COLOR_GOLD_500, 2, 26, 28.0, 10.0)
	_pill.add_theme_stylebox_override("panel", pill_box)
	_pill.visible = false
	_hud.add_child(_pill)
	_status_lbl = Label.new()
	_status_lbl.name = "InstructionLabel"
	_status_lbl.add_theme_font_size_override("font_size", 28)
	_status_lbl.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	if _display_font != null:
		_status_lbl.add_theme_font_override("font", _display_font)
	_pill.add_child(_status_lbl)

	_event_banner = Label.new()
	_event_banner.name = "EventBanner"
	_event_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_banner.add_theme_font_size_override("font_size", 54)
	_event_banner.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	_event_banner.add_theme_color_override("font_outline_color", Color(VisualTokens.COLOR_STEEL_900, 0.8))
	_event_banner.add_theme_constant_override("outline_size", 6)
	if _display_font != null:
		_event_banner.add_theme_font_override("font", _display_font)
	var band := StyleBoxFlat.new()
	band.bg_color = Color(VisualTokens.COLOR_STEEL_900, 0.72)
	band.border_color = VisualTokens.COLOR_GOLD_500
	band.border_width_top = 2
	band.border_width_bottom = 2
	_event_banner.add_theme_stylebox_override("normal", band)
	_event_banner.visible = false
	_event_banner.z_index = 8
	_hud.add_child(_event_banner)


func _layout_hud() -> void:
	if _hand_box == null or _battlefield == null:
		return
	var s := _hud.size
	if s.x < 200.0 or s.y < 200.0:
		return
	var left_w := clampf(s.x * 0.18, 330.0, 440.0)
	var right_w := clampf(s.x * 0.14, 260.0, 340.0)
	_field_rect = Rect2(left_w, s.y * 0.15, s.x - left_w - right_w, s.y * 0.56)
	_center_y = _field_rect.get_center().y
	var width_fit := (_field_rect.size.x - 32.0 - PIECE_GAP * 6.0) / (BoardPieceView.BASE_SIZE.x * 7.0)
	var height_fit := _field_rect.size.y * 0.42 / BoardPieceView.BASE_SIZE.y
	_piece_scale = clampf(minf(width_fit, height_fit), 0.7, 1.12)
	var piece := BoardPieceView.BASE_SIZE * _piece_scale
	for row: HBoxContainer in [_opp_board, _plr_board]:
		var row_center := _field_rect.position.y + _field_rect.size.y * (0.25 if row == _opp_board else 0.75)
		row.position = Vector2(_field_rect.position.x + 16.0, row_center - piece.y * 0.5)
		row.size = Vector2(_field_rect.size.x - 32.0, piece.y)
		for child: Node in row.get_children():
			(child as Control).custom_minimum_size = piece

	var cluster_h := clampf(s.y * 0.19, 180.0, 250.0)
	_opp_hero.position = Vector2.ZERO
	_opp_hero.size = Vector2(left_w - 16.0, cluster_h)
	_plr_hero.position = Vector2(0, s.y - cluster_h)
	_plr_hero.size = Vector2(left_w - 16.0, cluster_h)
	_hero_power_btn.size = Vector2(150, 168)
	_hero_power_btn.position = Vector2(6, s.y - cluster_h - 184.0)
	_hero_power_btn.pivot_offset = _hero_power_btn.size * 0.5
	_impulse_btn.size = Vector2(left_w - 190.0, 64)
	_impulse_btn.position = Vector2(170, s.y - cluster_h - 120.0)
	var preview_top := cluster_h + 18.0
	var preview_room := maxf(120.0, _hero_power_btn.position.y - 18.0 - preview_top)
	var preview_scale := clampf(minf(preview_room / FullCardView.BASE_SIZE.y, (left_w - 32.0) / FullCardView.BASE_SIZE.x), 0.4, 0.9)
	_play_preview.size = FullCardView.BASE_SIZE
	_play_preview.scale = Vector2.ONE * preview_scale
	_play_preview.position = Vector2((left_w - 16.0 - FullCardView.BASE_SIZE.x * preview_scale) * 0.5, preview_top)

	var rx := s.x - right_w + 16.0
	var rw := right_w - 16.0
	_end_turn_btn.size = Vector2(rw, 92)
	_end_turn_btn.position = Vector2(rx, _center_y - 46.0)
	_turn_owner_lbl.position = Vector2(rx, _center_y - 104.0)
	_turn_owner_lbl.size = Vector2(rw, 46)
	_turn_lbl.position = Vector2(rx, _center_y - 142.0)
	_turn_lbl.size = Vector2(rw, 36)
	_card_actions.position = Vector2(rx, _center_y + 70.0)
	_card_actions.size = Vector2(rw, 0)
	_hint_lbl.position = Vector2(rx, s.y - 150.0)
	_hint_lbl.size = Vector2(rw, 150)
	_menu_btn.size = Vector2(150, 64)
	_menu_btn.position = Vector2(s.x - 150.0, 0)
	_history_btn.size = Vector2(190, 64)
	_history_btn.position = Vector2(s.x - 352.0, 0)
	_event_banner.position = Vector2(_field_rect.position.x, _center_y - 52.0)
	_event_banner.size = Vector2(_field_rect.size.x, 104)
	_hand_box.position = Vector2.ZERO
	_hand_box.size = s
	var offset := _hud.get_global_rect().position - _battlefield.get_global_rect().position
	_battlefield.set_layout_hints(Rect2(_field_rect.position + offset, _field_rect.size), _center_y + offset.y)
	_place_pill()
	_layout_hand()


func _place_pill() -> void:
	if _pill == null:
		return
	_pill.size = _pill.get_combined_minimum_size()
	_pill.position = Vector2(_field_rect.get_center().x - _pill.size.x * 0.5, _center_y - _pill.size.y * 0.5)


## Fan layout: 3–5 cards are larger; up to 10 overlap in a controlled arc so cost
## and identity stay readable. The selected card lifts and straightens.
func _layout_hand(fresh: Array[int] = []) -> void:
	if _field_rect.size.x < 10.0:
		return
	var cards: Array[BattleCardView] = []
	for child: Node in _hand_box.get_children():
		if child is BattleCardView and not child.is_queued_for_deletion():
			cards.append(child as BattleCardView)
	var n := cards.size()
	if n == 0:
		return
	var hand_scale := 1.08 if n <= 5 else 1.0
	var card := BattleCardView.BASE_SIZE * hand_scale
	var avail := _field_rect.size.x - 24.0
	var step := card.x + HAND_GAP
	if n > 1:
		step = minf(card.x + HAND_GAP, (avail - card.x) / float(n - 1))
	var total := card.x + step * float(n - 1)
	var x0 := _field_rect.get_center().x - total * 0.5
	var mid := float(n - 1) * 0.5
	var curve := 1.6
	var base_y := _hud.size.y - card.y - 4.0 - mid * mid * curve
	var angle_step := minf(3.0, 20.0 / float(n))
	var board_bottom := _plr_board.position.y + _plr_board.size.y
	for i in n:
		var view := cards[i]
		var offset := float(i) - mid
		var target := Vector2(x0 + step * float(i), base_y + offset * offset * curve)
		var target_rotation := deg_to_rad(offset * angle_step)
		var target_scale := Vector2.ONE
		view.z_index = mini(i, 8)
		if view.selected:
			target.y -= clampf(target.y - board_bottom - 8.0, 0.0, 40.0)
			target_rotation = 0.0
			target_scale = Vector2(1.06, 1.06)
			view.z_index = 9
		view.custom_minimum_size = card
		view.size = card
		var running: Variant = view.get_meta("tween", null)
		if running is Tween and (running as Tween).is_valid():
			(running as Tween).kill()
		if _animations and view.instance_id in fresh:
			view.position = _plr_hero.position + Vector2(_plr_hero.size.x * 0.5, 0)
			view.scale = Vector2(0.55, 0.55)
			view.rotation = 0.0
			var tween := view.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(view, "position", target, 0.32)
			tween.tween_property(view, "scale", target_scale, 0.32)
			tween.tween_property(view, "rotation", target_rotation, 0.32)
			view.set_meta("tween", tween)
		else:
			view.position = target
			view.rotation = target_rotation
			view.scale = target_scale


func _build_history_drawer() -> void:
	_history_panel = UiKit.make_panel(true)
	_history_panel.name = "HistoryDrawer"
	_history_panel.anchor_left = 1.0
	_history_panel.anchor_right = 1.0
	_history_panel.anchor_bottom = 1.0
	_history_panel.offset_left = -620
	_history_panel.offset_right = -24
	_history_panel.offset_top = 104
	_history_panel.offset_bottom = -24
	_history_panel.z_index = 15
	_history_panel.visible = false
	add_child(_history_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	_history_panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := Label.new()
	title.text = "ИСТОРИЯ БОЯ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	if _display_font != null:
		title.add_theme_font_override("font", _display_font)
	header.add_child(title)
	var close := UiKit.make_button("ЗАКРЫТЬ", UiKit.ButtonRole.SECONDARY)
	close.name = "HistoryCloseButton"
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(_toggle_history)
	header.add_child(close)
	_log_text = RichTextLabel.new()
	_log_text.name = "BattleHistory"
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.scroll_following = true
	_log_text.selection_enabled = false
	_log_text.add_theme_font_size_override("normal_font_size", 24)
	_log_text.add_theme_color_override("default_color", VisualTokens.COLOR_INK)
	stack.add_child(_log_text)


func _toggle_history() -> void:
	_history_panel.visible = not _history_panel.visible
	if _history_panel.visible:
		_sync_history_text()


func _sync_history_text() -> void:
	if _log_text == null or _history == null:
		return
	_log_text.text = _history.text() if not _history.lines.is_empty() else "Бой только начинается."


func _dim_layer() -> ColorRect:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.11, 0.13, 0.14, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var material_dim := ShaderMaterial.new()
	material_dim.shader = DIM_SHADER
	dim.material = material_dim
	return dim


func _overlay_title(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", VisualTokens.COLOR_STONE_050)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("outline_size", 4)
	if _display_font != null:
		label.add_theme_font_override("font", _display_font)
	return label


func _overlay_text(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _overlay_root(node_name: String) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 10
	overlay.visible = false
	add_child(overlay)
	overlay.add_child(_dim_layer())
	return overlay


func _build_mulligan_overlay() -> void:
	_mulligan_overlay = _overlay_root("MulliganOverlay")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	_mulligan_overlay.add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	margin.add_child(col)
	col.add_child(_overlay_title("СТАРТОВАЯ РУКА", 60))
	_mulligan_info = _overlay_text(30, VisualTokens.COLOR_STONE_100)
	_mulligan_info.name = "MulliganInfo"
	col.add_child(_mulligan_info)
	var rules := _overlay_text(24, VisualTokens.COLOR_STONE_300)
	rules.name = "MulliganRules"
	rules.text = "Нажмите на карту, чтобы отметить её для замены. Можно заменить любые карты, все или ни одной. Заменённые карты не вернутся в эту же руку."
	col.add_child(rules)
	var row := HBoxContainer.new()
	row.name = "MulliganRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", VisualTokens.SPACE_6)
	col.add_child(row)
	row.add_child(_build_opponent_reveal())
	_mulligan_box = HBoxContainer.new()
	_mulligan_box.name = "MulliganCards"
	_mulligan_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_mulligan_box.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	row.add_child(_mulligan_box)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", VisualTokens.SPACE_5)
	col.add_child(footer)
	_mulligan_impulse = UiKit.make_panel(false)
	_mulligan_impulse.name = "ImpulseNote"
	var impulse_label := Label.new()
	impulse_label.text = "«ОСКОЛОК ИМПУЛЬСА» · +1 энергия до конца хода, один раз за матч · в замене не участвует"
	impulse_label.add_theme_font_size_override("font_size", 22)
	impulse_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	_mulligan_impulse.add_child(impulse_label)
	footer.add_child(_mulligan_impulse)
	_mulligan_count = _overlay_text(28, VisualTokens.COLOR_STONE_050)
	_mulligan_count.name = "MulliganCount"
	_mulligan_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.add_child(_mulligan_count)
	_mulligan_btn = UiKit.make_button("ПОДТВЕРДИТЬ РУКУ", UiKit.ButtonRole.PRIMARY)
	_mulligan_btn.name = "ConfirmHandButton"
	_mulligan_btn.custom_minimum_size = Vector2(420, 88)
	_mulligan_btn.pressed.connect(_submit_mulligan)
	footer.add_child(_mulligan_btn)


func _build_opponent_reveal() -> Control:
	var panel := UiKit.make_panel(false)
	panel.name = "OpponentReveal"
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", VisualTokens.SPACE_2)
	panel.add_child(stack)
	var caption := Label.new()
	caption.text = "ВАШ СОПЕРНИК"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	stack.add_child(caption)
	_opponent_portrait = HeroPortraitPlaceholder.new()
	_opponent_portrait.name = "OpponentPortrait"
	_opponent_portrait.custom_minimum_size = Vector2(250, 300)
	stack.add_child(_opponent_portrait)
	_opponent_name = Label.new()
	_opponent_name.name = "OpponentName"
	_opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opponent_name.add_theme_font_size_override("font_size", 36)
	_opponent_name.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	if _display_font != null:
		_opponent_name.add_theme_font_override("font", _display_font)
	stack.add_child(_opponent_name)
	var faction_row := HBoxContainer.new()
	faction_row.alignment = BoxContainer.ALIGNMENT_CENTER
	faction_row.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	stack.add_child(faction_row)
	_opponent_emblem = EmblemView.for_faction(Faction.Id.NEUTRAL)
	_opponent_emblem.custom_minimum_size = Vector2(40, 40)
	faction_row.add_child(_opponent_emblem)
	_opponent_faction = Label.new()
	_opponent_faction.name = "OpponentFaction"
	_opponent_faction.add_theme_font_size_override("font_size", 24)
	faction_row.add_child(_opponent_faction)
	return panel


func _build_choice_overlay() -> void:
	_choice_overlay = _overlay_root("ChoiceOverlay")
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	_choice_overlay.add_child(col)
	col.add_child(_overlay_title("ВЫБЕРИТЕ КАРТУ", 56))
	var hint := _overlay_text(26, VisualTokens.COLOR_STONE_100)
	hint.text = "Нажмите на карту, чтобы выбрать её."
	col.add_child(hint)
	_choice_box = HBoxContainer.new()
	_choice_box.name = "ChoiceCards"
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_theme_constant_override("separation", VisualTokens.SPACE_5)
	col.add_child(_choice_box)


func _build_shard_overlay() -> void:
	_shard_overlay = _overlay_root("ShardOverlay")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_shard_overlay.add_child(center)
	var panel := UiKit.make_panel(true)
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", VisualTokens.SPACE_4)
	panel.add_child(col)
	var title := UiKit.make_display_label("ОСКОЛКИ ДУШИ")
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_shard_lbl = Label.new()
	_shard_lbl.name = "ShardAmount"
	_shard_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shard_lbl.add_theme_font_size_override("font_size", 34)
	_shard_lbl.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	col.add_child(_shard_lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	col.add_child(row)
	var minus_btn := UiKit.make_button("−", UiKit.ButtonRole.ICON)
	minus_btn.name = "ShardMinus"
	minus_btn.custom_minimum_size = Vector2(96, 72)
	minus_btn.pressed.connect(func() -> void: _shard_adjust(-1))
	row.add_child(minus_btn)
	var plus_btn := UiKit.make_button("+", UiKit.ButtonRole.ICON)
	plus_btn.name = "ShardPlus"
	plus_btn.custom_minimum_size = Vector2(96, 72)
	plus_btn.pressed.connect(func() -> void: _shard_adjust(1))
	row.add_child(plus_btn)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	col.add_child(actions)
	var skip_btn := UiKit.make_button("БЕЗ ОСКОЛКОВ", UiKit.ButtonRole.SECONDARY)
	skip_btn.name = "ShardSkip"
	skip_btn.custom_minimum_size = Vector2(280, 80)
	skip_btn.pressed.connect(_skip_shard)
	actions.add_child(skip_btn)
	var ok_btn := UiKit.make_button("ПОТРАТИТЬ", UiKit.ButtonRole.PRIMARY)
	ok_btn.name = "ShardConfirm"
	ok_btn.custom_minimum_size = Vector2(280, 80)
	ok_btn.pressed.connect(_confirm_shard)
	actions.add_child(ok_btn)


func _build_detail_overlay() -> void:
	_detail_overlay = CardDetailOverlay.new()
	_detail_overlay.z_index = 25
	add_child(_detail_overlay)
	_detail_text = (_detail_overlay as CardDetailOverlay).detail_text


func _build_exit_dialog() -> void:
	_exit_dialog = ConfirmModal.create("ВЫЙТИ ИЗ БОЯ?",
		"Текущий бой будет завершён без результата. Вернуться в главное меню?", "ВЫЙТИ", "ОСТАТЬСЯ")
	_exit_dialog.name = "ExitBattleConfirmation"
	_exit_dialog.z_index = 30
	_exit_dialog.confirmed.connect(SceneRouter.reset_to.bind(Routes.MAIN_MENU))
	add_child(_exit_dialog)


## Consumed by SceneRouter before history navigation. Back closes the topmost
## read-only layer first, then a pending selection, and only then asks for an
## explicit confirmation before abandoning the match.
func handle_back_request() -> bool:
	if _ui_state == UIState.TEST_MODE:
		return false
	if _detail_overlay != null and _detail_overlay.visible:
		_detail_overlay.visible = false
		return true
	if _exit_dialog != null and _exit_dialog.visible:
		_exit_dialog.cancel()
		return true
	if _history_panel != null and _history_panel.visible:
		_history_panel.visible = false
		return true
	if _ui_state == UIState.SOUL_SHARD_CHOICE:
		_shard_overlay.visible = false
		_set_state(UIState.PLAYER_IDLE)
		_refresh_ui()
		return true
	if _is_selecting():
		_cancel_selection()
		return true
	_request_exit_battle()
	return true


func _request_exit_battle() -> void:
	if _exit_dialog != null and not _exit_dialog.visible:
		_exit_dialog.popup()


func _show_card_detail(card_data: Dictionary) -> void:
	var definition := CardDatabase.get_card(StringName(str(card_data.get("card_id", ""))))
	if definition == null:
		return
	(_detail_overlay as CardDetailOverlay).show_card(definition, int(card_data.get("current_cost", definition.cost)))


func _show_definition_detail(card_id: StringName) -> void:
	_show_card_detail({"card_id": String(card_id)})


func _show_hand_detail(instance_id: int) -> void:
	for card: Dictionary in _current_observation().get("own", {}).get("hand", []):
		if int(card.get("instance_id", 0)) == instance_id:
			_show_card_detail(card)
			return


func _show_creature_detail(instance_id: int) -> void:
	var piece := _find_piece(instance_id)
	if piece != null:
		_show_definition_detail(piece.card_id)


# ==============================================================================
#  MATCH LIFECYCLE
# ==============================================================================

func _start_match(cfg: BattleLaunchConfig) -> void:
	_session = BattleSession.new(cfg)
	_history = BattleHistory.new(_session.player_index)
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
	_hand_box.visible = false
	_rebuild_mulligan_cards()
	var obs := _session.get_observation()
	var first := int(obs.get("first_player", 0)) == _session.player_index
	var hand_size: int = obs.get("own", {}).get("hand", []).size()
	if first:
		_mulligan_info.text = "Вы ходите первым · %d %s" % [hand_size, _cards_word(hand_size)]
	else:
		_mulligan_info.text = "Вы ходите вторым · %d %s и «Осколок импульса»" % [hand_size, _cards_word(hand_size)]
	_mulligan_impulse.visible = not first
	var opponent_id := StringName(str(obs.get("opponent", {}).get("hero", {}).get("id", "")))
	if HeroCatalog.has_hero(opponent_id):
		_opponent_portrait.configure(opponent_id)
		_opponent_name.text = String(HeroCatalog.HEROES[opponent_id]["name_ru"]).to_upper()
		var faction := HeroCatalog.faction_of(opponent_id)
		_opponent_faction.text = SetupUi.faction_name(faction).to_upper()
		_opponent_faction.add_theme_color_override("font_color", HeroPresentation.faction_accent(opponent_id).darkened(0.25))
		_opponent_emblem.configure_faction(faction)
	_update_mulligan_count()


func _cards_word(count: int) -> String:
	if count % 10 == 1 and count % 100 != 11:
		return "карта"
	if count % 10 in [2, 3, 4] and not (count % 100 in [12, 13, 14]):
		return "карты"
	return "карт"


func _rebuild_mulligan_cards() -> void:
	_clear(_mulligan_box)
	for card_data: Dictionary in _session.get_observation().get("own", {}).get("hand", []):
		var slot := MulliganCardSlot.new()
		slot.configure(card_data)
		slot.set_marked(slot.instance_id in _mulligan_picks)
		slot.toggled.connect(_toggle_mulligan)
		slot.detail_requested.connect(_show_hand_detail)
		_mulligan_box.add_child(slot)


func _toggle_mulligan(iid: int) -> void:
	if _ui_state != UIState.MULLIGAN:
		return
	if iid in _mulligan_picks:
		_mulligan_picks.erase(iid)
	else:
		_mulligan_picks.append(iid)
	for child: Node in _mulligan_box.get_children():
		var slot := child as MulliganCardSlot
		slot.set_marked(slot.instance_id in _mulligan_picks)
	_update_mulligan_count()


func _update_mulligan_count() -> void:
	var total := _mulligan_box.get_child_count()
	_mulligan_count.text = "Отмечено для замены: %d из %d" % [_mulligan_picks.size(), total]


func _submit_mulligan() -> void:
	if _ui_state != UIState.MULLIGAN:
		return
	var ids: Array[int] = []
	ids.assign(_mulligan_picks)
	var result := _session.submit_mulligan(ids)
	if not result.ok:
		_flash_status("Не удалось подтвердить руку")
		return
	_mulligan_overlay.visible = false
	_hand_box.visible = true
	_mulligan_picks.clear()
	_refresh_ui()
	_after_command(result)


func _after_command(result: ActionResult) -> void:
	if not result.events.is_empty():
		_event_queue.append_array(result.events)
		_event_timer = 0.0
		_ui_state = UIState.RESOLVING
		_refresh_ui()
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

func _current_observation() -> Dictionary:
	if _session == null:
		return {}
	if _ui_state == UIState.AI_TURN and not _presentation_observation.is_empty():
		return _presentation_observation
	return _session.get_observation()


func _refresh_ui() -> void:
	if _session == null:
		return
	var obs := _current_observation()
	if obs.is_empty():
		return
	_history.remember(obs)
	var own: Dictionary = obs.get("own", {})
	var opp: Dictionary = obs.get("opponent", {})
	var legal := _legal_snapshot()
	_plr_hero.update_view(own, true, _hero_state(own))
	_opp_hero.update_view(opp, false, _hero_state(opp))
	_sync_board(_opp_board, opp.get("board", []), false, legal)
	_sync_board(_plr_board, own.get("board", []), true, legal)
	_sync_hand(own.get("hand", []), legal)
	_refresh_controls(obs, legal)
	_effects.queue_redraw()


func _can_act() -> bool:
	return _ui_state in [UIState.PLAYER_IDLE, UIState.CARD_SELECTED, UIState.ATTACKER_SELECTED, UIState.HERO_POWER_TARGET]


func _is_selecting() -> bool:
	return _ui_state in [UIState.CARD_SELECTED, UIState.ATTACKER_SELECTED, UIState.HERO_POWER_TARGET]


func _is_targeting() -> bool:
	return _is_selecting() and not _valid_targets.is_empty()


func _legal_snapshot() -> Dictionary:
	var playable: Array[int] = []
	var attackers: Array[int] = []
	var other := false
	if _session != null and _can_act() and _session.is_player_turn():
		for command: MatchCommand in _session.get_legal_commands():
			match command.kind:
				MatchCommand.Kind.PLAY_CARD:
					if command.source_id not in playable:
						playable.append(command.source_id)
				MatchCommand.Kind.ATTACK:
					if command.source_id not in attackers:
						attackers.append(command.source_id)
				MatchCommand.Kind.USE_HERO_POWER, MatchCommand.Kind.USE_IMPULSE_SHARD:
					other = true
	return {"playable": playable, "attackers": attackers, "other": other}


func _hero_state(data: Dictionary) -> HeroClusterView.TargetState:
	if not _is_targeting():
		return HeroClusterView.TargetState.NONE
	var iid := int(data.get("hero", {}).get("instance_id", 0))
	return HeroClusterView.TargetState.LEGAL if iid in _valid_targets else HeroClusterView.TargetState.DIMMED


func _piece_state(iid: int) -> BoardPieceView.TargetState:
	if iid == _selected_attacker_id and _ui_state == UIState.ATTACKER_SELECTED:
		return BoardPieceView.TargetState.SELECTED
	if not _is_targeting():
		return BoardPieceView.TargetState.NONE
	return BoardPieceView.TargetState.LEGAL if iid in _valid_targets else BoardPieceView.TargetState.DIMMED


func _sync_board(row: HBoxContainer, board: Array, is_player: bool, legal: Dictionary) -> void:
	var wanted: Array[int] = []
	for creature: Dictionary in board:
		wanted.append(int(creature.get("instance_id", 0)))
	for child: Node in row.get_children():
		var old := child as BoardPieceView
		if old != null and old.instance_id not in wanted:
			_last_rects[old.instance_id] = old.get_global_rect()
			if _animations and _ui_state != UIState.MULLIGAN:
				_spawn_ghost(old.get_global_rect(), old.card_id)
			row.remove_child(old)
			old.queue_free()
	var attackers: Array = legal.get("attackers", [])
	var piece_size := BoardPieceView.BASE_SIZE * _piece_scale
	for i in board.size():
		var creature: Dictionary = board[i]
		var iid := int(creature.get("instance_id", 0))
		var piece := row.get_node_or_null("Piece_%d" % iid) as BoardPieceView
		var fresh := piece == null
		if fresh:
			piece = BoardPieceView.new()
			piece.tapped.connect(_on_own_creature_tapped if is_player else _on_enemy_creature_tapped)
			piece.detail_requested.connect(_show_creature_detail)
			row.add_child(piece)
		row.move_child(piece, i)
		piece.custom_minimum_size = piece_size
		piece.configure(creature, is_player and iid in attackers, _piece_state(iid))
		if fresh and _animations and _ui_state != UIState.MULLIGAN:
			piece.visual.scale = Vector2(0.8, 0.8)
			piece.visual.modulate = Color(1, 1, 1, 0)
			var tween := piece.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(piece.visual, "scale", Vector2.ONE, 0.3)
			tween.tween_property(piece.visual, "modulate", Color.WHITE, 0.22)


func _find_piece(iid: int) -> BoardPieceView:
	for row: HBoxContainer in [_plr_board, _opp_board]:
		var piece := row.get_node_or_null("Piece_%d" % iid) as BoardPieceView
		if piece != null:
			return piece
	return null


func _sync_hand(hand: Array, legal: Dictionary) -> void:
	var wanted: Array[int] = []
	for card: Dictionary in hand:
		wanted.append(int(card.get("instance_id", 0)))
	for child: Node in _hand_box.get_children():
		var old := child as BattleCardView
		if old != null and old.instance_id not in wanted:
			_hand_box.remove_child(old)
			old.queue_free()
	var playable: Array = legal.get("playable", [])
	var fresh: Array[int] = []
	for i in hand.size():
		var card: Dictionary = hand[i]
		var iid := int(card.get("instance_id", 0))
		var view := _hand_box.get_node_or_null("HandCard_%d" % iid) as BattleCardView
		if view == null:
			view = BattleCardView.new()
			view.tapped.connect(_on_hand_card_tapped)
			view.detail_requested.connect(_show_hand_detail)
			_hand_box.add_child(view)
			if _hand_seen:
				fresh.append(iid)
		_hand_box.move_child(view, i)
		view.configure(card, iid in playable, iid == _selected_card_id)
	if _ui_state != UIState.MULLIGAN:
		_hand_seen = true
	_layout_hand(fresh)


func _refresh_controls(obs: Dictionary, legal: Dictionary) -> void:
	var own: Dictionary = obs.get("own", {})
	var own_turn: bool = obs.get("phase") == "TURN" and int(obs.get("active_player", -1)) == _session.player_index
	var can_act := _can_act() and _session.is_player_turn()
	_end_turn_btn.disabled = not can_act
	_end_turn_btn.text = "ЗАВЕРШИТЬ ХОД" if own_turn or _ui_state == UIState.MULLIGAN else "ХОД СОПЕРНИКА"
	var nothing_else: bool = can_act and (legal["playable"] as Array).is_empty() and (legal["attackers"] as Array).is_empty() \
		and not bool(legal["other"])
	_end_turn_btn.add_theme_stylebox_override("normal", _end_turn_ready_box if nothing_else else _end_turn_normal_box)
	var power_targets: Array[int] = []
	if can_act:
		power_targets = _session.get_valid_hero_power_targets()
	_hero_power_btn.disabled = power_targets.is_empty()
	_hero_power_btn.configure(_session.config.player_hero, bool(own.get("hero_power_used_this_turn", false)),
		_ui_state == UIState.HERO_POWER_TARGET)
	var impulse := bool(own.get("impulse_shard_available", false))
	_impulse_btn.visible = impulse
	_impulse_btn.disabled = not (can_act and impulse)
	_turn_lbl.text = "ХОД %d" % int(obs.get("turn_number", 0))
	_turn_owner_lbl.text = "ВАШ ХОД" if own_turn else "ХОД СОПЕРНИКА"
	_card_actions.visible = _ui_state == UIState.CARD_SELECTED and _selected_card_id != 0
	_play_btn.visible = _card_actions.visible and _valid_targets.is_empty()
	_status_lbl.text = _instruction_text()
	_pill.visible = not _status_lbl.text.is_empty()
	_place_pill()
	_hint_lbl.text = _hint_text(legal) if _hints else ""


## Mandatory target instructions are always shown, independent of «Подсказки».
func _instruction_text() -> String:
	match _ui_state:
		UIState.CARD_SELECTED:
			if _valid_targets.is_empty():
				return ""
			return "Выберите цель"
		UIState.ATTACKER_SELECTED:
			return "Выберите цель атаки"
		UIState.HERO_POWER_TARGET:
			return "Выберите цель: «%s»" % _session.hero_power_name()
	return ""


## Optional explanatory hints («Подсказки» toggle).
func _hint_text(legal: Dictionary) -> String:
	match _ui_state:
		UIState.CARD_SELECTED:
			if _valid_targets.is_empty():
				return "Нажмите карту ещё раз или «Разыграть»."
			return "Подсвеченные цели допустимы. Нажмите карту ещё раз для отмены."
		UIState.ATTACKER_SELECTED:
			return "Нажмите существо ещё раз для отмены."
		UIState.PLAYER_IDLE:
			if not (legal["attackers"] as Array).is_empty():
				return "Существа с бирюзовой каймой могут атаковать: нажмите на них."
			return "Удерживайте карту, чтобы прочитать описание."
		UIState.AI_TURN:
			return "Соперник делает ход."
	return ""


func _flash_status(text_value: String) -> void:
	_status_lbl.text = text_value
	_pill.visible = true
	_place_pill()


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
		_pointer = Vector2(-1, -1)


func _cancel_selection() -> void:
	if not _is_selecting():
		return
	_set_state(UIState.PLAYER_IDLE)
	_refresh_ui()


func _on_field_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_cancel_selection()


## First tap selects (lifts) a card; a targetless card plays on the second tap or
## «РАЗЫГРАТЬ»; a targeted card highlights the engine-legal targets.
func _on_hand_card_tapped(iid: int) -> void:
	if not _can_act():
		return
	var targets := _session.get_valid_play_targets(iid)
	if _selected_card_id == iid and _ui_state == UIState.CARD_SELECTED:
		if targets.size() == 1 and targets[0] == 0:
			_try_play_card(iid, 0)
		else:
			_cancel_selection()
		return
	if targets.is_empty():
		_show_hand_detail(iid)
		return
	_set_state(UIState.PLAYER_IDLE)
	_selected_card_id = iid
	if not (targets.size() == 1 and targets[0] == 0):
		targets.erase(0)
		_valid_targets.assign(targets)
	_set_state(UIState.CARD_SELECTED)
	_refresh_ui()


func _on_own_creature_tapped(iid: int) -> void:
	match _ui_state:
		UIState.PLAYER_IDLE:
			_select_attacker(iid)
		UIState.ATTACKER_SELECTED:
			if iid == _selected_attacker_id:
				_cancel_selection()
			else:
				_select_attacker(iid)
		UIState.CARD_SELECTED:
			if iid in _valid_targets:
				_try_play_card(_selected_card_id, iid)
			else:
				_set_state(UIState.PLAYER_IDLE)
				_select_attacker(iid)
				_refresh_ui()
		UIState.HERO_POWER_TARGET:
			_use_hero_power_on(iid)
		_:
			pass


func _select_attacker(iid: int) -> void:
	var atk_targets := _session.get_valid_attack_targets(iid)
	if atk_targets.is_empty():
		return
	_set_state(UIState.PLAYER_IDLE)
	_selected_attacker_id = iid
	_valid_targets.assign(atk_targets)
	_set_state(UIState.ATTACKER_SELECTED)
	_refresh_ui()


func _on_enemy_creature_tapped(iid: int) -> void:
	match _ui_state:
		UIState.ATTACKER_SELECTED:
			if iid in _valid_targets:
				_try_attack(_selected_attacker_id, iid)
		UIState.CARD_SELECTED:
			if iid in _valid_targets:
				_try_play_card(_selected_card_id, iid)
		UIState.HERO_POWER_TARGET:
			if iid in _valid_targets:
				_use_hero_power_on(iid)
		_:
			pass


func _on_hero_tapped(is_own: bool) -> void:
	if _session == null:
		return
	var obs := _session.get_observation()
	var hero_iid := int(obs.get("own" if is_own else "opponent", {}).get("hero", {}).get("instance_id", 0))
	match _ui_state:
		UIState.ATTACKER_SELECTED:
			if hero_iid in _valid_targets:
				_try_attack(_selected_attacker_id, hero_iid)
		UIState.CARD_SELECTED:
			if hero_iid in _valid_targets:
				_try_play_card(_selected_card_id, hero_iid)
		UIState.HERO_POWER_TARGET:
			if hero_iid in _valid_targets:
				_use_hero_power_on(hero_iid)
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
		_after_command(result)
	else:
		_flash_status("Это действие сейчас недоступно")
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
	_shard_lbl.text = "Потратить: %d из %d" % [_shard_value, _shard_max]
	_shard_overlay.set_meta("target_id", target_id)
	_set_state(UIState.SOUL_SHARD_CHOICE)


func _shard_adjust(delta: int) -> void:
	_shard_value = clampi(_shard_value + delta, 0, _shard_max)
	_shard_lbl.text = "Потратить: %d из %d" % [_shard_value, _shard_max]


func _confirm_shard() -> void:
	_play_with_shards(_shard_value)


func _skip_shard() -> void:
	_play_with_shards(0)


func _play_with_shards(amount: int) -> void:
	if _ui_state != UIState.SOUL_SHARD_CHOICE:
		return
	var target_id: int = int(_shard_overlay.get_meta("target_id", 0))
	_shard_overlay.visible = false
	var result := _session.play_card(_shard_card_id, target_id, {MatchCommand.CHOICE_SOUL_SHARDS: amount})
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_after_command(result)
	else:
		_flash_status("Это действие сейчас недоступно")
	_refresh_ui()


# ==============================================================================
#  ATTACK / HERO POWER / IMPULSE / END TURN
# ==============================================================================

func _try_attack(attacker_id: int, target_id: int) -> void:
	var result := _session.attack(attacker_id, target_id)
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_after_command(result)
	else:
		_flash_status("Атака сейчас недоступна")
	_refresh_ui()


func _on_hero_power_pressed() -> void:
	if not _can_act():
		return
	if _ui_state == UIState.HERO_POWER_TARGET:
		_cancel_selection()
		return
	var targets := _session.get_valid_hero_power_targets()
	if targets.is_empty():
		return
	if 0 not in targets:
		_set_state(UIState.PLAYER_IDLE)
		_valid_targets.assign(targets)
		_set_state(UIState.HERO_POWER_TARGET)
		_refresh_ui()
	else:
		_use_hero_power_on(0)


func _use_hero_power_on(target_id: int) -> void:
	if not _can_act():
		return
	if target_id not in _session.get_valid_hero_power_targets():
		return
	var result := _session.use_hero_power(target_id)
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_after_command(result)
	else:
		_flash_status("Способность сейчас недоступна")
	_refresh_ui()


func _on_impulse_pressed() -> void:
	if not _can_act():
		return
	var result := _session.use_impulse_shard()
	_set_state(UIState.PLAYER_IDLE)
	if result.ok:
		_after_command(result)
	_refresh_ui()


func _on_end_turn_pressed() -> void:
	if not _can_act() or not _session.is_player_turn():
		return
	_set_state(UIState.RESOLVING)
	var result := _session.end_turn()
	if result.ok:
		_after_command(result)
	else:
		_set_state(UIState.PLAYER_IDLE)
		_refresh_ui()


# ==============================================================================
#  CHOICE MODAL (Cartographer CHOOSE)
# ==============================================================================

func _show_choice() -> void:
	_set_state(UIState.CHOICE_MODAL)
	_choice_overlay.visible = true
	_clear(_choice_box)
	var pending: Dictionary = _session.get_observation().get("pending_choice", {})
	for option: Dictionary in pending.get("options", []):
		var definition := CardDatabase.get_card(StringName(str(option.get("card_id", ""))))
		if definition == null:
			continue
		var view := FullCardView.new()
		view.custom_minimum_size = FullCardView.BASE_SIZE
		view.configure(definition)
		view.name = "Choice_%d" % int(option.get("instance_id", 0))
		view.pressed.connect(_choose_option.bind(int(option.get("instance_id", 0))))
		_choice_box.add_child(view)
	_refresh_ui()


func _choose_option(option_id: int) -> void:
	if _ui_state != UIState.CHOICE_MODAL:
		return
	_choice_overlay.visible = false
	var result := _session.choose(option_id)
	if result.ok:
		_after_command(result)
	else:
		_choice_overlay.visible = true
	_refresh_ui()


# ==============================================================================
#  EVENT PRESENTATION / AI TURN
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
	var delay: float = (AI_DELAY if _ui_state == UIState.AI_TURN else EVENT_TIME) if _animations else 0.001
	if _event_timer < delay:
		return
	_event_timer = 0.0
	if _ui_state == UIState.AI_TURN:
		_tick_ai_presentation()
		return
	while not _event_queue.is_empty():
		if _present_event(_event_queue.pop_front()):
			_refresh_ui()
			return
	_refresh_ui()
	_check_turn()


func _tick_ai_presentation() -> void:
	if _ai_step_events.is_empty():
		if _ai_step_index >= _ai_steps.size():
			_presentation_observation.clear()
			_play_preview.visible = false
			_check_turn()
			return
		var step: Dictionary = _ai_steps[_ai_step_index]
		_ai_step_index += 1
		_presentation_observation = step["observation_after_command"]
		_ai_step_events.assign(step["events"])
		_refresh_ui()
	while not _ai_step_events.is_empty():
		if _present_event(_ai_step_events.pop_front()):
			return


## Records the event in the history and plays its (optional) presentation. Returns
## true for events that deserve their own beat. Never changes match state.
func _present_event(evt: Dictionary) -> bool:
	_history.add_events([evt])
	if _history_panel.visible:
		_sync_history_text()
	var kind: StringName = StringName(str(evt.get("type", "")))
	var own := int(evt.get("player", -1)) == _session.player_index
	match kind:
		MatchEvent.TURN_STARTED:
			_play_preview.visible = false
			_show_banner("ВАШ ХОД" if own else "ХОД СОПЕРНИКА")
		MatchEvent.CARD_PLAYED:
			if not own:
				_show_play_preview(StringName(str(evt.get("card_id", ""))))
		MatchEvent.ATTACK_DECLARED:
			_animate_attack(int(evt.get("attacker_id", 0)), int(evt.get("target_id", 0)))
		MatchEvent.DAMAGE_DEALT:
			_float_damage(int(evt.get("target_id", 0)), int(evt.get("to_health", 0)), int(evt.get("to_armor", 0)))
		MatchEvent.HERO_POWER_USED:
			_pulse(_hero_power_btn if own else _opp_hero.portrait_button)
		MatchEvent.ARTIFACT_PLAYED:
			_pulse(_plr_hero.artifact_button if own else _opp_hero.artifact_button)
		MatchEvent.MATCH_ENDED:
			var outcome := _session.get_outcome()
			_show_banner(MatchOutcome.title(outcome).to_upper())
	return kind in KEY_EVENTS


func _show_banner(text_value: String) -> void:
	if not _animations:
		return
	_event_banner.text = text_value
	_event_banner.visible = true
	_event_banner.modulate = Color(1, 1, 1, 0)
	var tween := _event_banner.create_tween()
	tween.tween_property(_event_banner, "modulate", Color.WHITE, 0.15)
	tween.tween_interval(0.55)
	tween.tween_property(_event_banner, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.tween_callback(func() -> void: _event_banner.visible = false)


func _show_play_preview(card_id: StringName) -> void:
	var definition := CardDatabase.get_card(card_id)
	if definition == null:
		return
	_play_preview.configure(definition)
	_play_preview.name = "PlayedCardPreview"
	_play_preview.visible = true
	if _animations:
		_play_preview.modulate = Color(1, 1, 1, 0)
		_play_preview.create_tween().tween_property(_play_preview, "modulate", Color.WHITE, 0.2)
	else:
		_play_preview.modulate = Color.WHITE


func _target_global_center(iid: int) -> Vector2:
	var piece := _find_piece(iid)
	if piece != null:
		return piece.get_global_rect().get_center()
	if iid == _plr_hero.hero_instance_id():
		return _plr_hero.portrait_center()
	if iid == _opp_hero.hero_instance_id():
		return _opp_hero.portrait_center()
	if _last_rects.has(iid):
		return (_last_rects[iid] as Rect2).get_center()
	return Vector2(-1, -1)


func _animate_attack(attacker_id: int, target_id: int) -> void:
	if not _animations:
		return
	var piece := _find_piece(attacker_id)
	var to := _target_global_center(target_id)
	if piece == null or to.x < 0.0:
		return
	var direction := (to - piece.get_global_rect().get_center()).limit_length(48.0)
	var tween := piece.create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(piece.visual, "position", direction, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece.visual, "position", Vector2.ZERO, 0.18).set_ease(Tween.EASE_IN)


func _float_damage(target_id: int, to_health: int, to_armor: int) -> void:
	if not _animations:
		return
	var at := _target_global_center(target_id)
	if at.x < 0.0:
		return
	var local := _effects.get_global_transform().affine_inverse() * at
	if to_health > 0:
		_float_text(local, "−%d" % to_health, Color("c8443a"), 0.0)
	if to_armor > 0:
		_float_text(local, "броня −%d" % to_armor, VisualTokens.COLOR_STEEL_700, 34.0)


func _float_text(at: Vector2, text_value: String, color: Color, offset_y: float) -> void:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 46 if offset_y == 0.0 else 26)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", VisualTokens.COLOR_STONE_050)
	label.add_theme_constant_override("outline_size", 8)
	if _display_font != null:
		label.add_theme_font_override("font", _display_font)
	_effects.add_child(label)
	label.size = label.get_combined_minimum_size()
	label.position = at + Vector2(-label.size.x * 0.5, offset_y - label.size.y * 0.5)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 0.8)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.8).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


func _spawn_ghost(rect: Rect2, card_id: StringName) -> void:
	var ghost := Control.new()
	ghost.name = "DeathGhost"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = _effects.get_global_transform().affine_inverse() * rect.position
	ghost.size = rect.size
	var definition := CardDatabase.get_card(card_id)
	var accent := NulmerisEmblems.faction_color(definition.faction) if definition != null else VisualTokens.COLOR_STEEL_500
	ghost.draw.connect(func() -> void:
		var s := ghost.size
		ghost.draw_rect(Rect2(Vector2(4, s.y * 0.2), s - Vector2(8, s.y * 0.2)), Color(VisualTokens.COLOR_STONE_300, 0.7))
		ghost.draw_line(Vector2(s.x * 0.3, s.y * 0.25), Vector2(s.x * 0.55, s.y * 0.6), accent, 4.0, true)
		ghost.draw_line(Vector2(s.x * 0.55, s.y * 0.6), Vector2(s.x * 0.45, s.y * 0.9), accent, 4.0, true)
		ghost.draw_line(Vector2(s.x * 0.55, s.y * 0.6), Vector2(s.x * 0.8, s.y * 0.7), accent, 3.0, true))
	_effects.add_child(ghost)
	var tween := ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost, "modulate", Color(1, 1, 1, 0), 0.45)
	tween.tween_property(ghost, "position:y", ghost.position.y + 18.0, 0.45)
	tween.chain().tween_callback(ghost.queue_free)


func _pulse(target: Control) -> void:
	if not _animations or target == null or not target.visible:
		return
	target.pivot_offset = target.size * 0.5
	var tween := target.create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", Vector2(1.12, 1.12), 0.14)
	tween.tween_property(target, "scale", Vector2.ONE, 0.2)


## Subtle targeting arc from the selected source to the pointer; gold over a legal
## target, muted steel elsewhere (the invalid-target distinction).
func _draw_effects() -> void:
	if not _is_targeting() or _pointer.x < 0.0:
		return
	var inverse := _effects.get_global_transform().affine_inverse()
	var source := Vector2(-1, -1)
	if _ui_state == UIState.ATTACKER_SELECTED:
		var piece := _find_piece(_selected_attacker_id)
		if piece != null:
			source = inverse * piece.get_global_rect().get_center()
	elif _ui_state == UIState.HERO_POWER_TARGET:
		source = inverse * _hero_power_btn.get_global_rect().get_center()
	else:
		var card := _hand_box.get_node_or_null("HandCard_%d" % _selected_card_id) as Control
		if card != null:
			source = inverse * card.get_global_rect().get_center()
	if source.x < 0.0:
		return
	var legal := false
	for iid: int in _valid_targets:
		var center := _target_global_center(iid)
		if center.x >= 0.0 and (inverse * center).distance_to(_pointer) < 90.0:
			legal = true
			break
	var color := Color(VisualTokens.COLOR_GOLD_300, 0.95) if legal else Color(VisualTokens.COLOR_STEEL_500, 0.7)
	var control := (source + _pointer) * 0.5 + Vector2(0, -minf(220.0, source.distance_to(_pointer) * 0.3))
	var points := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		points.append(source.lerp(control, t).lerp(control.lerp(_pointer, t), t))
	for i in range(0, points.size() - 1, 2):
		_effects.draw_line(points[i], points[i + 1], color, 6.0, true)
	_effects.draw_arc(_pointer, 22.0, 0, TAU, 32, color, 4.0, true)
	if not legal:
		_effects.draw_line(_pointer + Vector2(-12, -12), _pointer + Vector2(12, 12), color, 4.0, true)
		_effects.draw_line(_pointer + Vector2(-12, 12), _pointer + Vector2(12, -12), color, 4.0, true)


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
#  HELPERS
# ==============================================================================

func _clear(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
