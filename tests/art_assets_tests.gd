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
	var empty_portrait := HeroPortraitPlaceholder.new()
	_ok(not ArtAssets.has(&"guardian_terrace") and empty_portrait.is_temporary_asset(),
		"without files every slot keeps its procedural Visual Alpha layer")
	empty_portrait.free()
	_write("environments/citadel_guardian_terrace", Vector2i(96, 54), false)
	_write("heroes/guardian_nulmeris", Vector2i(40, 60), true)
	_write("heroes/syrraveth", Vector2i(30, 40), true)
	_write("environments/citadel_arena", Vector2i(96, 54), false)
	_write("environment_details/convergence_ring_outer", Vector2i(64, 64), true)
	ArtAssets.clear_cache()
	_ok(ArtAssets.has(&"guardian_terrace") and ArtAssets.texture(&"guardian").get_size() == Vector2(40, 60),
		"dropped files resolve through their manifest slot")
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
	_ok(not portrait.is_temporary_asset() and other.is_temporary_asset(),
		"a hero portrait is used only for its own hero; others keep the temporary niche")
	var field := CitadelBattlefield.new()
	_tree.root.add_child(field)
	_ok(not field.is_processing(), "arena art replaces the procedural battlefield and its shimmer")
	await _tree.process_frame
	for node: Node in [backdrop, guardian, field]:
		node.queue_free()
	portrait.free()
	other.free()
	_cleanup()
	_ok(not ArtAssets.has(&"guardian_terrace"), "removing the files restores the fallback")
