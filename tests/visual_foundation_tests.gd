extends RefCounted
## Stage 7A reusable visual foundation checks.

var check: Callable
var tree: SceneTree


func _init(check_fn: Callable, game_tree: SceneTree) -> void:
	check = check_fn
	tree = game_tree


func _ok(value: bool, description: String) -> void:
	check.call(value, "visual foundation: " + description)


func run() -> void:
	_test_resources()
	_test_typography()
	_test_responsive_metrics()
	await _test_component_preview()


func _test_resources() -> void:
	var theme_path := "res://assets/ui/visual_alpha/theme/visual_alpha_theme.tres"
	_ok(ProjectSettings.get_setting("gui/theme/custom") == "res://assets/ui/placeholder_theme.tres",
		"bootstrap project Theme remains import-safe")
	_ok(UiKit.THEME_PATH == theme_path, "UI kit exposes the shared Stage 7A Theme")
	for path in [
		theme_path,
		"res://assets/ui/visual_alpha/fonts/NotoSerif-Regular.ttf",
		"res://assets/ui/visual_alpha/fonts/NotoSerif-SemiBold.ttf",
		"res://assets/ui/visual_alpha/icons/check.svg",
		"res://assets/ui/visual_alpha/icons/chevron_down.svg",
		"res://assets/ui/visual_alpha/icons/status_diamond.svg",
	]:
		_ok(ResourceLoader.exists(path), "%s resolves" % path)
	var theme := load(theme_path) as Theme
	_ok(theme != null and theme.default_font != null and theme.default_font_size >= 30,
		"shared Theme loads with readable default typography")


func _test_typography() -> void:
	var body := load("res://assets/ui/visual_alpha/fonts/NotoSerif-Regular.ttf") as Font
	var display := load("res://assets/ui/visual_alpha/fonts/NotoSerif-SemiBold.ttf") as Font
	var sample := "Нулмерис — Ёж, Цитадель, Соперник"
	var body_missing := ""
	var display_missing := ""
	for character in sample:
		var code := character.unicode_at(0)
		if not body.has_char(code):
			body_missing += character
		if not display.has_char(code):
			display_missing += character
	_ok(body_missing.is_empty(), "body font covers Cyrillic sample (missing '%s')" % body_missing)
	_ok(display_missing.is_empty(), "display font covers Cyrillic sample (missing '%s')" % display_missing)


func _test_responsive_metrics() -> void:
	_ok(ResponsiveLayout.collection_columns(1500) == 4, "narrow landscape prepares 4-column grid")
	_ok(ResponsiveLayout.collection_columns(1920) == 5, "1920 width prepares 5-column grid")
	_ok(ResponsiveLayout.collection_columns(2400) == 6, "legacy width-only helper remains stable")
	_ok(ResponsiveLayout.collection_columns_for_size(Vector2(1600, 900)) == 4, "Collection size-aware 1600x900 uses 4 columns")
	_ok(ResponsiveLayout.collection_columns_for_size(Vector2(1920, 1080)) == 5, "Collection size-aware 1920x1080 uses 5 columns")
	_ok(ResponsiveLayout.collection_columns_for_size(Vector2(2400, 1080)) == 5, "Collection treats 2400x1080 as very-wide phone with 5 columns")
	_ok(ResponsiveLayout.collection_columns_for_size(Vector2(2800, 1752)) == 6, "Collection treats 2800x1752 as tablet/large landscape with 6 columns")
	_ok(ResponsiveLayout.outer_margin(2400) > ResponsiveLayout.outer_margin(1920),
		"wide landscape increases shared outer margin")
	var compact := Control.new()
	ResponsiveLayout.enforce_touch_target(compact)
	_ok(compact.custom_minimum_size.x >= 64 and compact.custom_minimum_size.y >= 64,
		"minimum Android touch target is at least 64x64")
	compact.free()


func _test_component_preview() -> void:
	var packed := load("res://scenes/common/ui_kit_preview.tscn") as PackedScene
	var preview := packed.instantiate() as UiKitPreview if packed != null else null
	_ok(preview != null, "UI kit validation scene instantiates")
	if preview == null:
		return
	tree.root.add_child(preview)
	await tree.process_frame
	for component_name in [
		"DisplayTitle", "PrimaryButton", "SecondaryButton", "SubtleButton", "CompactBattleButton", "IconButton",
		"FilterChip", "Switch", "Select", "TextField", "SegmentedControl", "Panel", "Modal",
		"HeroPortraitFrame", "CardFrameBase", "StatusMarker", "ScrollView",
	]:
		_ok(preview.find_child(component_name, true, false) != null, "%s component exists" % component_name)
	var display := preview.find_child("DisplayTitle", true, false) as Label
	var primary := preview.find_child("PrimaryButton", true, false) as Button
	var filter := preview.find_child("FilterChip", true, false) as Button
	var select := preview.find_child("Select", true, false) as OptionButton
	_ok(preview.theme != null and display.get_theme_font("font") != null and display.get_theme_font_size("font_size") >= 52,
		"display typography is applied at UI-root after import")
	_ok(primary.custom_minimum_size.y >= 64 and primary.get_theme_stylebox("pressed").get_border_width(SIDE_LEFT) >
		primary.get_theme_stylebox("normal").get_border_width(SIDE_LEFT),
		"primary pressed/selected silhouette changes beyond colour")
	_ok(filter.toggle_mode and filter.button_pressed and filter.icon != null,
		"filter selected state includes a check mark, not colour alone")
	_ok(select.custom_minimum_size.y >= 64 and select.get_theme_icon("arrow") != null,
		"dropdown has comfortable target and reusable arrow asset")
	preview.queue_free()
	await tree.process_frame
