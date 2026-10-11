extends RefCounted
## Hero Art V1 integration (docs/HERO_POSE_BRIEF_V1.md): head-safe portrait framing,
## per-hero idle layers within a particle budget, Hero Select selection/entrance
## behaviour with the «Анимации» preference on and off, and presentation isolation.

const TEST_SAVE := "user://odraveth_smoke_test/hero_visual_v1.json"
const FRAMES: Array[Vector2] = [Vector2(432, 350), Vector2(120, 120), Vector2(300, 420), Vector2(417, 477),
	Vector2(220, 250)]
const FX_SCRIPTS: Array[String] = ["res://scripts/ui/visual/hero_idle_fx.gd", "res://scripts/ui/hero_portrait_placeholder.gd",
	"res://scripts/ui/hero_select_card.gd"]

var _check: Callable
var _tree: SceneTree
var _saved_profile: Dictionary
var _saved_manager: SaveManager


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	_saved_profile = AppState.profile
	_saved_manager = AppState._save_manager
	AppState._save_manager = SaveManager.new(TEST_SAVE)
	_test_cover_region()
	_test_head_safe_framing()
	_test_particle_budget_and_isolation()
	await _test_hidden_portrait_is_idle()
	await _test_hero_select(true)
	await _test_hero_select(false)
	AppState.profile = _saved_profile
	AppState._save_manager = _saved_manager
	SceneRouter.reset_to(Routes.MAIN_MENU)
	await _wait(Routes.MAIN_MENU)


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "hero visual V1: " + label)


func _wait(route: StringName) -> bool:
	for _i in 120:
		await _tree.process_frame
		if SceneRouter.current_route == route and not SceneRouter.is_changing() and _tree.current_scene != null:
			return true
	return false


func _test_cover_region() -> void:
	var centre := ArtAssets.cover_region(Vector2(1000, 1400), Vector2(500, 400))
	_ok(is_equal_approx(centre.position.x, 0.0) and centre.position.y > 0.0
		and is_equal_approx(centre.size.x / centre.size.y, 500.0 / 400.0), "default cover crop stays centred")
	var top := ArtAssets.cover_region(Vector2(1000, 1400), Vector2(500, 400), Vector2(0.5, 0.0))
	_ok(is_equal_approx(top.position.y, 0.0) and is_equal_approx(top.size.x, 1000.0),
		"top-anchored cover crop keeps the top of the art")
	_ok(ArtAssets.cover_region(Vector2.ZERO, Vector2(10, 10)) == Rect2(), "degenerate sizes give an empty region")


## Every approved portrait keeps the full top of the art (the head) in wide, square and tall frames.
func _test_head_safe_framing() -> void:
	var portrait := HeroPortraitPlaceholder.new()
	var all_safe := true
	var headroom := true
	var failures := PackedStringArray()
	for hero: StringName in PlayerSetupData.HERO_IDS:
		var art := ArtAssets.texture(ArtAssets.hero_slot(hero))
		if art == null:
			failures.append("%s has no art" % hero)
			all_safe = false
			continue
		for frame: Vector2 in FRAMES:
			var layout := portrait.art_layout(art.get_size(), Rect2(Vector2.ZERO, frame))
			var region: Rect2 = layout["region"]
			var dest: Rect2 = layout["dest"]
			if region.position.y > 0.5 or region.size.y <= 0.0:
				all_safe = false
				failures.append("%s %s" % [hero, frame])
			headroom = headroom and dest.position.y >= frame.y * HeroPortraitPlaceholder.HEADROOM - 0.01 \
				and is_equal_approx(dest.end.y, frame.y)
	portrait.free()
	_ok(all_safe, "portrait crops never cut the top of the hero art %s" % failures)
	_ok(headroom, "portrait keeps headroom above the head and fills to the frame bottom")


func _test_particle_budget_and_isolation() -> void:
	var within := HeroIdleFx.MAX_PARTICLES <= 14
	var distinct := {}
	for hero: StringName in PlayerSetupData.HERO_IDS:
		var count := HeroIdleFx.particle_count(hero)
		within = within and count > 0 and count <= HeroIdleFx.MAX_PARTICLES
		distinct[hero] = count
	_ok(within, "every hero idle effect stays within %d primitives %s" % [HeroIdleFx.MAX_PARTICLES, distinct])
	_ok(HeroIdleFx.particle_count(&"UNKNOWN") == 0, "unknown hero ids draw no effect")
	var clean := true
	for path: String in FX_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		for token: String in ["randi(", "randf(", "randomize(", ".shuffle(", "MatchEngine", "BattleSession",
				"persist_profile", "HeroCatalog.value("]:
			clean = clean and not source.contains(token)
	_ok(clean, "hero visuals use no RNG, never touch the match, rules values or the save file")


func _test_hidden_portrait_is_idle() -> void:
	var portrait := HeroPortraitPlaceholder.new()
	portrait.size = Vector2(300, 400)
	_tree.root.add_child(portrait)
	portrait.configure(HeroCatalog.SYRRAVETH)
	portrait.set_idle_effects(true, true)
	await _tree.process_frame
	_ok(portrait.is_processing() and portrait.animated, "an animated portrait processes while visible")
	portrait.visible = false
	var before := portrait.fx_time
	portrait._process(0.5)
	_ok(is_equal_approx(portrait.fx_time, before), "a hidden portrait does not advance or redraw its effect")
	portrait.set_idle_effects(true, false)
	_ok(not portrait.is_processing() and portrait.idle_effects, "animations off keeps a still effect frame without processing")
	portrait.queue_free()
	await _tree.process_frame


func _profile(animations: bool) -> Dictionary:
	var profile := PlayerSetupData.select_hero(SaveManager.create_default_data(), HeroCatalog.KEZHARYN)
	profile = PlayerSetupData.normalized(profile)
	profile["prebattle"][PlayerSetupData.ANIMATIONS] = animations
	return profile


func _test_hero_select(animations: bool) -> void:
	var mode := "animations on" if animations else "animations off"
	AppState.persist_profile(_profile(animations))
	SceneRouter.reset_to(Routes.HERO_SELECT)
	await _wait(Routes.HERO_SELECT)
	var scene := _tree.current_scene as HeroSelectScreen
	_ok(scene.animations_enabled == animations, "%s: Hero Select reads the saved preference" % mode)
	var first := scene.hero_buttons[HeroCatalog.KEZHARYN] as HeroSelectCard
	if animations:
		_ok(first.modulate.a < 1.0, "%s: cards fade in after opening" % mode)
	else:
		var all_opaque := true
		for hero: StringName in PlayerSetupData.HERO_IDS:
			all_opaque = all_opaque and is_equal_approx((scene.hero_buttons[hero] as HeroSelectCard).modulate.a, 1.0)
		_ok(all_opaque, "%s: no entrance fade" % mode)
	await _tree.create_timer(0.6).timeout
	_ok(is_equal_approx(first.modulate.a, 1.0), "%s: cards are fully visible after the entrance" % mode)
	for hero: StringName in PlayerSetupData.HERO_IDS:
		scene._choose(hero)
		var processing := PackedStringArray()
		for other: StringName in PlayerSetupData.HERO_IDS:
			var card := scene.hero_buttons[other] as HeroSelectCard
			if card.portrait.is_processing():
				processing.append(String(other))
		var card := scene.hero_buttons[hero] as HeroSelectCard
		_ok(card.portrait.idle_effects and card.glow > 0.0 and card.scale.x > 1.0,
			"%s: %s selection shows the idle character, glow and raised card" % [mode, hero])
		if animations:
			_ok(processing == PackedStringArray([String(hero)]), "%s: only the selected hero animates %s" % [mode, processing])
		else:
			_ok(processing.is_empty() and card._tween == null and is_equal_approx(card.glow, HeroSelectCard.GLOW_REST),
				"%s: nothing animates or tweens %s" % [mode, processing])
	var others_idle := true
	for hero: StringName in PlayerSetupData.HERO_IDS:
		if hero != HeroCatalog.TAZHYRION:
			var other := scene.hero_buttons[hero] as HeroSelectCard
			others_idle = others_idle and not other.portrait.idle_effects and is_equal_approx(other.glow, 0.0)
	_ok(others_idle, "%s: unselected cards carry no effect or glow" % mode)
	scene._confirm()
	_ok(await _wait(Routes.MAIN_MENU) and AppState.profile["selected_hero_id"] == String(HeroCatalog.TAZHYRION),
		"%s: confirmation still saves the chosen hero" % mode)
