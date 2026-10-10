class_name BootScreen
extends Control
## Stage 7 boot: native splash (plain stone colour, no engine branding) → Gates of
## Nulmeris with real weighted loading → ODRAVETH reveal → Main Menu.
## Progress advances only when a real step finishes. A failure stops on a safe
## error with «ПОВТОРИТЬ»; the uninitialised Main Menu is never entered.

const STATUS_LINES := {
	&"wake": "Пробуждение Цитадели…",
	&"save": "Проверяем сохранения…",
	&"cards": "Загрузка карт Нулмериса…",
	&"mechanisms": "Настраиваем древние механизмы…",
	&"gates": "Открываем врата Нулмериса…",
}
## Rare dry lines, shown in place of the mechanisms line now and then.
const DRY_LINES: Array[String] = ["Ключ найден. Не спрашивайте где.", "Одно кольцо сопротивляется. Как обычно.",
	"Хранитель утверждает, что так и было задумано.", "Нулмерис на месте. Можно входить."]
const DRY_CHANCE := 0.2
## Step id and its share of the progress bar.
const STEPS := [[&"wake", 1.0], [&"save", 3.0], [&"cards", 5.0], [&"mechanisms", 2.0], [&"gates", 1.0]]
const MIN_STEP_SECONDS := 0.32
const REVEAL_SECONDS := 1.2

enum State { LOADING, FAILED, REVEAL, DONE }

var state: State = State.LOADING
var cards_dir := CardDatabase.DEFAULT_CARDS_DIR
## Real completed weight / total weight (never advanced by a timer alone).
var progress := 0.0
var shown_progress := 0.0
var status_label: Label
var note_label: Label
var retry_button: Button
var gates: BootGatesView
var wordmark: BrandWordmark
var fast := false
## False only for QA screenshots that pose a frame without running the steps.
var autostart := true

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fast = DisplayServer.get_name() == "headless"
	_rng.randomize()
	_build()
	# Deferred so the boot screen is fully in the tree before work starts.
	if autostart:
		run.call_deferred()


func _build() -> void:
	UiKit.apply_root_theme(self)
	var background := ColorRect.new()
	background.color = Color("e4ddd0")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	gates = BootGatesView.new()
	gates.name = "Gates"
	gates.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(gates)
	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", VisualTokens.SPACE_2)
	safe.add_child(col)
	wordmark = BrandWordmark.new()
	wordmark.name = "BootWordmark"
	wordmark.text = "ODRAVETH"
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wordmark.add_theme_font_size_override("font_size", 96)
	var display_font := load(UiKit.DISPLAY_FONT_PATH) as Font
	if display_font != null:
		wordmark.add_theme_font_override("font", display_font)
	wordmark.modulate = Color(1, 1, 1, 0)
	wordmark.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(wordmark)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 30)
	status_label.add_theme_color_override("font_color", VisualTokens.COLOR_STEEL_900)
	col.add_child(status_label)
	note_label = Label.new()
	note_label.name = "Note"
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.add_theme_font_size_override("font_size", 24)
	note_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	note_label.visible = false
	col.add_child(note_label)
	retry_button = UiKit.make_button("ПОВТОРИТЬ", UiKit.ButtonRole.PRIMARY)
	retry_button.name = "RetryButton"
	retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_button.visible = false
	retry_button.pressed.connect(retry)
	col.add_child(retry_button)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)


func _process(delta: float) -> void:
	shown_progress = move_toward(shown_progress, progress, delta * 1.6) if not fast else progress
	gates.progress = shown_progress
	gates.queue_redraw()


func _total_weight() -> float:
	var total := 0.0
	for step: Array in STEPS:
		total += float(step[1])
	return total


## Runs the real boot steps. Each step is awaited before progress moves on.
func run() -> void:
	state = State.LOADING
	progress = 0.0
	note_label.visible = false
	retry_button.visible = false
	gates.failed = false
	var done := 0.0
	for step: Array in STEPS:
		var id: StringName = step[0]
		status_label.text = STATUS_LINES[id]
		if id == &"mechanisms" and _rng.randf() < DRY_CHANCE:
			status_label.text = DRY_LINES[_rng.randi_range(0, DRY_LINES.size() - 1)]
		var started := Time.get_ticks_msec()
		var error := await _run_step(id)
		if error != OK:
			_fail(id, error)
			return
		await _hold_since(started)
		done += float(step[1])
		progress = done / _total_weight()
	await _reveal()
	state = State.DONE
	SceneRouter.reset_to(Routes.MAIN_MENU)


func _run_step(id: StringName) -> Error:
	match id:
		&"save":
			AppState.initialize()
			if AppState._save_manager.last_load_status in [SaveManager.LoadStatus.CORRUPTED,
					SaveManager.LoadStatus.READ_FAILED, SaveManager.LoadStatus.UNSUPPORTED_VERSION]:
				note_label.text = "Сохранение не удалось прочитать полностью: используются безопасные настройки."
				note_label.visible = true
		&"cards":
			var error := CardDatabase.load_directory(cards_dir)
			if error != OK:
				return error
			if CardDatabase.get_all_cards().is_empty():
				return ERR_FILE_CORRUPT
		&"mechanisms":
			var menu := ResourceLoader.load(Routes.scene_path(Routes.MAIN_MENU))
			if menu == null:
				return ERR_CANT_OPEN
	await get_tree().process_frame
	return OK


func _hold_since(started_msec: int) -> void:
	if fast:
		return
	var left := MIN_STEP_SECONDS - float(Time.get_ticks_msec() - started_msec) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left).timeout


func _fail(id: StringName, error: Error) -> void:
	state = State.FAILED
	gates.failed = true
	push_warning("Boot: step %s failed: %s." % [id, error_string(error)])
	status_label.text = "Не удалось открыть врата Нулмериса"
	note_label.text = "Не загрузились данные карт. Попробуйте ещё раз; сохранения не изменены." if id == &"cards" \
		else "Не удалось подготовить главное меню. Попробуйте ещё раз."
	note_label.visible = true
	retry_button.visible = true


func retry() -> void:
	if state == State.FAILED:
		run()


func _reveal() -> void:
	state = State.REVEAL
	status_label.text = ""
	note_label.visible = false
	if fast:
		gates.opening = 1.0
		wordmark.modulate = Color.WHITE
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(gates, "opening", 1.0, REVEAL_SECONDS)
	tween.tween_property(wordmark, "modulate", Color.WHITE, REVEAL_SECONDS * 0.6).set_delay(REVEAL_SECONDS * 0.4)
	await tween.finished
	await get_tree().create_timer(0.45).timeout


## Back during boot does nothing (there is nowhere safe to go yet).
func handle_back_request() -> bool:
	return true
