class_name OpponentSearchScreen
extends Control
## Stage 7 Opponent Search: the opponent hero is already chosen by
## OpponentSelector and stored in the BattleLaunchConfig. This screen only
## reveals its FACTION through the Citadel mechanism; it never changes the config
## and never shows the hero portrait or name (revealed later in Mulligan).

enum Phase { ACTIVATING, CYCLING, LOCKING, FOUND, LEAVING }

const ACTIVATION := 0.8
const CYCLE_END := 3.4
const LOCK_END := 4.0
const FOUND_HOLD := 2.2
const FOUND_HOLD_STILL := 1.6

var route_params: Dictionary = {}
var config: BattleLaunchConfig
var target_faction: Faction.Id = Faction.Id.NEUTRAL
var phase: Phase = Phase.ACTIVATING
var elapsed := 0.0
var animations_enabled := true

var mechanism: CitadelMechanismView
var title_label: Label
var subtitle_label: Label
var found_label: Label
var faction_label: Label
var proceed_button: Button
var cancel_button: Button

var _switch_times: Array[float] = []
var _start_index := 0
var _lock_from_outer := 0.0
var _lock_from_inner := 0.0
var _found_at := 0.0


func apply_route_params(params: Dictionary) -> void:
	route_params = params


func _ready() -> void:
	UiKit.apply_root_theme(self)
	var backdrop := CitadelBackdrop.create(CitadelBackdrop.Mood.CHAMBER, &"convergence")
	add_child(backdrop)
	var cfg: Variant = route_params.get(BattleLaunchConfig.PARAM_KEY)
	config = cfg as BattleLaunchConfig if cfg is BattleLaunchConfig else null
	_build_ui()
	if config == null or not HeroCatalog.has_hero(config.opponent_hero):
		_show_missing_config()
		set_process(false)
		return
	target_faction = HeroCatalog.faction_of(config.opponent_hero)
	animations_enabled = bool(config.presentation_options.get(PlayerSetupData.ANIMATIONS, true))
	_plan_cycle()
	if not animations_enabled:
		_enter_found(true)
	set_process(true)


func _build_ui() -> void:
	var safe := SafeAreaContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", VisualTokens.SPACE_3)
	safe.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	cancel_button = UiKit.make_button("ОТМЕНА", UiKit.ButtonRole.SECONDARY)
	cancel_button.name = "BackButton"
	cancel_button.custom_minimum_size = Vector2(200, 72)
	cancel_button.pressed.connect(_cancel)
	header.add_child(cancel_button)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title_stack)
	title_label = _label("ПОИСК СОПЕРНИКА", VisualTokens.FONT_TITLE, VisualTokens.COLOR_STONE_050, true)
	title_label.name = "SearchTitle"
	title_stack.add_child(title_label)
	subtitle_label = _label("Механизмы Цитадели выбирают соперника", 26, Color("b9c9c9"))
	subtitle_label.name = "SearchSubtitle"
	title_stack.add_child(subtitle_label)
	var balance := Control.new()
	balance.custom_minimum_size = Vector2(200, 72)
	header.add_child(balance)

	mechanism = CitadelMechanismView.new()
	mechanism.name = "CitadelMechanism"
	mechanism.size_flags_vertical = SIZE_EXPAND_FILL
	mechanism.custom_minimum_size = Vector2(0, 420)
	layout.add_child(mechanism)

	var reveal := VBoxContainer.new()
	reveal.name = "Reveal"
	reveal.custom_minimum_size.y = 190
	reveal.add_theme_constant_override("separation", VisualTokens.SPACE_1)
	layout.add_child(reveal)
	found_label = _label("СОПЕРНИК НАЙДЕН", 54, VisualTokens.COLOR_STONE_050, true)
	found_label.name = "FoundLabel"
	found_label.modulate.a = 0.0
	reveal.add_child(found_label)
	faction_label = _label("", 40, VisualTokens.COLOR_GOLD_300, true)
	faction_label.name = "FactionLabel"
	faction_label.modulate.a = 0.0
	reveal.add_child(faction_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	reveal.add_child(actions)
	proceed_button = UiKit.make_button("К БОЮ", UiKit.ButtonRole.PRIMARY)
	proceed_button.name = "ProceedButton"
	proceed_button.custom_minimum_size = Vector2(320, 76)
	proceed_button.modulate.a = 0.0
	proceed_button.disabled = true
	proceed_button.pressed.connect(proceed)
	actions.add_child(proceed_button)


func _label(text_value: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		var font := load(UiKit.DISPLAY_FONT_PATH) as Font
		if font != null:
			label.add_theme_font_override("font", font)
	return label


func _plan_cycle() -> void:
	_switch_times.clear()
	var t := ACTIVATION
	var step := 0.11
	while t < CYCLE_END:
		_switch_times.append(t)
		t += step
		step *= 1.14
	var count := _switch_times.size()
	var target_index := CitadelMechanismView.SEAL_ORDER.find(target_faction)
	_start_index = posmod(target_index - (count - 1), CitadelMechanismView.SEAL_ORDER.size())


## Faction shown in the window at a given time of the search sequence.
func faction_at(time: float) -> int:
	var shown := -1
	for i in _switch_times.size():
		if time >= _switch_times[i]:
			shown = CitadelMechanismView.SEAL_ORDER[(_start_index + i) % CitadelMechanismView.SEAL_ORDER.size()]
	return shown


func _process(delta: float) -> void:
	elapsed += delta
	match phase:
		Phase.ACTIVATING, Phase.CYCLING:
			_animate_search()
		Phase.LOCKING:
			_animate_lock()
		Phase.FOUND:
			_animate_found(delta)
		_:
			pass


func _animate_search() -> void:
	var speed := clampf(elapsed / ACTIVATION, 0.0, 1.0)
	mechanism.glow = speed
	mechanism.outer_angle += 0.045 * speed
	mechanism.inner_angle -= 0.06 * speed
	if elapsed >= ACTIVATION:
		phase = Phase.CYCLING
		var shown := faction_at(elapsed)
		mechanism.shown_faction = shown
		mechanism.highlight_faction = shown
	if elapsed >= CYCLE_END:
		phase = Phase.LOCKING
		mechanism.shown_faction = target_faction
		mechanism.highlight_faction = target_faction
		_lock_from_outer = mechanism.outer_angle
		_lock_from_inner = mechanism.inner_angle
	mechanism.queue_redraw()


func _animate_lock() -> void:
	var t := clampf((elapsed - CYCLE_END) / (LOCK_END - CYCLE_END), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var goal := CitadelMechanismView.seal_angle(target_faction)
	var outer_goal := _lock_from_outer + wrapf(goal - _lock_from_outer, 0.0, TAU)
	mechanism.outer_angle = lerpf(_lock_from_outer, outer_goal, eased)
	mechanism.inner_angle = lerpf(_lock_from_inner, snappedf(_lock_from_inner, TAU / 12.0), eased)
	mechanism.lock_glow = eased
	mechanism.queue_redraw()
	if t >= 1.0:
		_enter_found(false)


func _enter_found(immediate: bool) -> void:
	phase = Phase.FOUND
	mechanism.glow = 1.0
	mechanism.lock_glow = 1.0
	mechanism.shown_faction = target_faction
	mechanism.highlight_faction = target_faction
	mechanism.outer_angle = CitadelMechanismView.seal_angle(target_faction)
	mechanism.queue_redraw()
	title_label.text = "ЦИТАДЕЛЬ НУЛМЕРИСА"
	title_label.add_theme_color_override("font_color", Color("b9c9c9"))
	title_label.add_theme_font_size_override("font_size", 40)
	subtitle_label.text = "Герой соперника откроется перед боем"
	faction_label.text = SetupUi.faction_name(target_faction).to_upper()
	faction_label.add_theme_color_override("font_color", NulmerisEmblems.faction_secondary(target_faction).lightened(0.2))
	proceed_button.disabled = false
	_found_at = elapsed
	if immediate:
		found_label.modulate.a = 1.0
		faction_label.modulate.a = 1.0
		proceed_button.modulate.a = 1.0


func _animate_found(delta: float) -> void:
	for control: Control in [found_label, faction_label, proceed_button]:
		control.modulate.a = minf(1.0, control.modulate.a + delta * 2.5)
	var hold := FOUND_HOLD if animations_enabled else FOUND_HOLD_STILL
	if elapsed - _found_at >= hold:
		proceed()


## Skips the presentation to the already-determined result (tap or tests).
func finish_now() -> void:
	if phase == Phase.LEAVING or config == null:
		return
	_enter_found(true)


func proceed() -> void:
	if phase == Phase.LEAVING or config == null:
		return
	phase = Phase.LEAVING
	set_process(false)
	SceneRouter.replace_with(Routes.BATTLE, {BattleLaunchConfig.PARAM_KEY: config})


func _gui_input(event: InputEvent) -> void:
	if phase in [Phase.ACTIVATING, Phase.CYCLING, Phase.LOCKING] and event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed:
		finish_now()


func handle_back_request() -> bool:
	_cancel()
	return true


func _cancel() -> void:
	if phase == Phase.LEAVING:
		return
	phase = Phase.LEAVING
	set_process(false)
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.PREBATTLE)


func _show_missing_config() -> void:
	title_label.text = "СОПЕРНИК НЕ ВЫБРАН"
	subtitle_label.text = "Вернитесь к подготовке к бою и начните поиск снова"
	cancel_button.text = "НАЗАД"
