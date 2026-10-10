extends RefCounted
## Art production pipeline: every ASSET_MANIFEST slot is a drop-in file; when present it
## replaces the procedural layer without touching UI. Uses throwaway test images in
## user:// (never committed, never shown as art).

const DROP_ROOT := "user://art_dropin_test"
const SVG_SYMBOLS: Array[String] = ["res://assets/ui/brand/odraveth_o_mark.svg", "res://assets/ui/world/seal_of_nulmeris.svg",
	"res://assets/ui/factions/ashravael.svg", "res://assets/ui/factions/nerqathen.svg",
	"res://assets/ui/factions/dumoryss.svg", "res://assets/ui/factions/khevaruun.svg"]

var _check: Callable
var _tree: SceneTree


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	CardDatabase.load_directory()
	_test_registry()
	_test_symbols()
	_test_card_art_contract()
	_test_production_scenes()
	_test_source_lock()
	await _test_drop_in()


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "art pipeline: " + label)


func _test_registry() -> void:
	var expected := ["environments/citadel_guardian_terrace", "heroes/guardian_nulmeris", "environments/gates_of_nulmeris",
		"environments/citadel_hero_hall", "heroes/kezharyn", "heroes/vhorazel", "heroes/syrraveth", "heroes/tazhyrion",
		"environments/nulmeris_archive", "environments/citadel_deck_hall", "environments/citadel_staging_hall",
		"environments/citadel_convergence", "environments/citadel_arena", "environments/library_of_nulmeris",
		"environment_details/book_of_nulmeris", "environments/citadel_hall"]
	var bases: Array[String] = []
	for slot: StringName in ArtAssets.SLOTS:
		bases.append(String(ArtAssets.SLOTS[slot][0]))
	var all_present := true
	for base: String in expected:
		all_present = all_present and base in bases
	_ok(all_present, "every ASSET_MANIFEST raster path has a slot")
	for hero: StringName in PlayerSetupData.HERO_IDS:
		_ok(ArtAssets.SLOTS.has(ArtAssets.hero_slot(hero)), "portrait slot for %s" % hero)


func _test_symbols() -> void:
	for path: String in SVG_SYMBOLS:
		var texture := load(path) as Texture2D
		_ok(texture != null and texture.get_width() > 0, "symbol %s imports" % path.get_file())
	_ok(ProjectSettings.get_setting("application/config/icon") != "res://assets/ui/world/seal_of_nulmeris.svg",
		"the Seal of Nulmeris is not the app icon")


func _test_card_art_contract() -> void:
	var variants := {}
	var unique := true
	for card: CardDefinition in CardDatabase.get_all_cards():
		var path := CardArtResolver.art_path(card.id)
		_ok(path.is_empty() or path.begins_with("res://assets/cards/%s." % card.id),
			"%s resolves only its own art file" % card.id)
		var key := str(CardArtSlot.variant_for(card.id))
		unique = unique and not variants.has(key)
		variants[key] = true
	_ok(CardDatabase.get_all_cards().size() == 40 and unique,
		"all 40 card IDs get a distinct composition until their unique art exists")


func _test_production_scenes() -> void:
	var scene_slots: Array[StringName] = [&"guardian_terrace", &"gates", &"hero_hall", &"arena"]
	for slot: StringName in scene_slots:
		_ok(ArtAssets.SLOTS.has(slot), "scene slot %s is registered" % slot)
		var path := ArtAssets.path_of(slot)
		_ok(not path.is_empty(), "scene slot %s has a runtime file" % slot)
		_ok(ResourceLoader.exists(path), "scene slot %s runtime file exists in res://" % slot)
		var tex := ArtAssets.texture(slot)
		_ok(tex != null and tex.get_width() > 0, "scene slot %s loads as a valid texture" % slot)
	var backdrop := MainMenuBackdrop.new()
	_ok(not backdrop.is_processing(), "guardian_terrace art disables procedural backdrop processing")
	backdrop.free()
	var field := CitadelBattlefield.new()
	_ok(not field.is_processing(), "arena art disables procedural battlefield processing")
	field.free()
	ArtAssets.clear_cache()


func _test_source_lock() -> void:
	var locks := {
		"masters/approved_scenes/scene_nulmeris_terrace.jpeg": "74b7987190ad46e6fc2888020277ef31b2003eb1eaf71ce56ee854975f100022",
		"masters/approved_scenes/scene_nulmeris_gates.jpeg": "1a5e3236bc510a32874335dd0f5d4618e431dcc5cc5e09d9e74bf704bab1cdf9",
		"masters/approved_scenes/scene_hero_hall.jpeg": "03df042210cd3e0e85e99247f134f25468823721fcc60daf193b89ca27e27393",
		"masters/approved_scenes/scene_battle_arena.jpeg": "6471c767962740ccaa683c2292579ef2ae3e24afa40f0b08994cc41f70a56147",
		"masters/approved_scenes/reference_main_menu_guardian.jpeg": "94b172ba5eda460c61d545d124741c82f1426d74aa657ccfa3ac8b932f81427a",
	}
	for path: String in locks:
		var abs_path := ProjectSettings.globalize_path("res://%s" % path)
		var file := FileAccess.open(abs_path, FileAccess.READ)
		_ok(file != null, "source-lock: %s exists" % path.get_file())
		if file == null:
			continue
		var data := file.get_buffer(file.get_length())
		file.close()
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(data)
		var digest := ctx.finish().hex_encode()
		_ok(digest == locks[path], "source-lock: %s SHA-256 matches approved hash" % path.get_file())


func _write(base: String, size: Vector2i, alpha: bool) -> void:
	var path := "%s/%s.png" % [DROP_ROOT, base]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.5, 0.6, 0.0 if alpha else 1.0))
	image.fill_rect(Rect2i(size / 4, size / 2), Color(0.8, 0.3, 0.2))
	image.save_png(path)


func _cleanup() -> void:
	for slot: StringName in ArtAssets.SLOTS:
		var path := "%s/%s.png" % [DROP_ROOT, ArtAssets.SLOTS[slot][0]]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ArtAssets.override_root = ""
	ArtAssets.clear_cache()


func _test_drop_in() -> void:
	ArtAssets.override_root = DROP_ROOT
	ArtAssets.clear_cache()
	_ok(ArtAssets.has(&"guardian_terrace"), "guardian_terrace resolves from res:// even with empty override")
	_ok(ArtAssets.has(&"guardian"), "guardian resolves from res:// production art")
	_ok(ArtAssets.has(&"arena"), "arena resolves from res:// production art")
	var backdrop := MainMenuBackdrop.new()
	var guardian := GuardianPlaceholder.new()
	_tree.root.add_child(backdrop)
	_tree.root.add_child(guardian)
	_ok(not backdrop.is_processing() and not guardian.is_processing() and not guardian.is_temporary_asset(),
		"Main Menu terrace and Guardian art replace the procedural layers (no animated redraw)")
	var portrait := HeroPortraitPlaceholder.new()
	portrait.configure(HeroCatalog.SYRRAVETH)
	var other := HeroPortraitPlaceholder.new()
	other.configure(HeroCatalog.KEZHARYN)
	_ok(not portrait.is_temporary_asset() and not other.is_temporary_asset(),
		"hero portraits with production art are not temporary assets")
	var field := CitadelBattlefield.new()
	_tree.root.add_child(field)
	_ok(not field.is_processing(), "arena art replaces the procedural battlefield and its shimmer")
	await _tree.process_frame
	for node: Node in [backdrop, guardian, field]:
		node.queue_free()
	portrait.free()
	other.free()
	ArtAssets.override_root = ""
	ArtAssets.clear_cache()
