class_name ArtAssets
extends RefCounted
## Drop-in registry for production art (docs/ART_DELIVERABLES.md, art-pack ASSET_MANIFEST).
## Every slot is an optional file under res://assets; when it is present (and imported)
## the screen draws it, otherwise the Visual Alpha procedural layer stays. Art never
## carries UI: buttons, names, numbers and rules stay live Godot controls.

const ROOT := "res://assets"
const EXTENSIONS := ["webp", "png", "svg", "jpg"]
## Slot id → path below ROOT without extension, and what the slot is for.
const SLOTS := {
	&"guardian_terrace": ["environments/citadel_guardian_terrace", "Main Menu background (no people, no UI)"],
	&"guardian": ["heroes/guardian_nulmeris", "Guardian of Nulmeris, transparent alpha"],
	&"gates": ["environments/gates_of_nulmeris", "Boot gates environment"],
	&"gates_left": ["environments/gates_left", "Boot left gate leaf, alpha"],
	&"gates_right": ["environments/gates_right", "Boot right gate leaf, alpha"],
	&"hero_hall": ["environments/citadel_hero_hall", "Hero Select hall"],
	&"hero_KEZHARYN": ["heroes/kezharyn", "Кежарин portrait, transparent 3:4/4:5"],
	&"hero_VHORAZEL": ["heroes/vhorazel", "Вхоразель portrait, transparent 3:4/4:5"],
	&"hero_SYRRAVETH": ["heroes/syrraveth", "Сирравет portrait (female), transparent 3:4/4:5"],
	&"hero_TAZHYRION": ["heroes/tazhyrion", "Тажирион portrait, transparent 3:4/4:5"],
	&"archive": ["environments/nulmeris_archive", "Collection archive"],
	&"deck_hall": ["environments/citadel_deck_hall", "Deck Builder hall"],
	&"staging_hall": ["environments/citadel_staging_hall", "Prebattle staging hall"],
	&"convergence": ["environments/citadel_convergence", "Opponent Search chamber"],
	&"convergence_ring_outer": ["environment_details/convergence_ring_outer", "Search outer ring, alpha"],
	&"convergence_ring_inner": ["environment_details/convergence_ring_inner", "Search inner ring, alpha"],
	&"arena": ["environments/citadel_arena", "Battlefield «Цитадель Нулмериса» (calm centre)"],
	&"library": ["environments/library_of_nulmeris", "Library of Nulmeris"],
	&"book": ["environment_details/book_of_nulmeris", "Book of Nulmeris, alpha, no baked text"],
	&"hall": ["environments/citadel_hall", "Settings / Progress hall"],
}

## Tests only: an extra directory (user://…) searched with plain image loading.
static var override_root := ""
static var _cache: Dictionary = {}


static func path_of(slot: StringName) -> String:
	if not SLOTS.has(slot):
		return ""
	var base: String = SLOTS[slot][0]
	for extension: String in EXTENSIONS:
		var candidate := "%s/%s.%s" % [ROOT, base, extension]
		if ResourceLoader.exists(candidate):
			return candidate
	if not override_root.is_empty():
		for extension: String in EXTENSIONS:
			var candidate := "%s/%s.%s" % [override_root, base, extension]
			if FileAccess.file_exists(candidate):
				return candidate
	return ""


static func texture(slot: StringName) -> Texture2D:
	if _cache.has(slot):
		return _cache[slot] as Texture2D
	var path := path_of(slot)
	var result: Texture2D = null
	if path.begins_with(ROOT):
		result = load(path) as Texture2D
	elif not path.is_empty():
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			result = ImageTexture.create_from_image(image)
	_cache[slot] = result
	return result


static func has(slot: StringName) -> bool:
	return texture(slot) != null


static func clear_cache() -> void:
	_cache.clear()


static func hero_slot(hero_id: StringName) -> StringName:
	return StringName("hero_%s" % String(hero_id))


## Fills [param rect] keeping aspect (crops overflow), like TextureRect «covered».
static func draw_cover(ci: CanvasItem, tex: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	var src_size := tex.get_size()
	if src_size.x <= 0.0 or src_size.y <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale := maxf(rect.size.x / src_size.x, rect.size.y / src_size.y)
	var visible := rect.size / scale
	var src := Rect2((src_size - visible) * 0.5, visible)
	ci.draw_texture_rect_region(tex, rect, src, modulate)


## Fits inside [param rect] keeping aspect; [param anchor] 0..1 places it (0.5,1 = bottom centre).
static func draw_fit(ci: CanvasItem, tex: Texture2D, rect: Rect2, anchor: Vector2 = Vector2(0.5, 1.0)) -> void:
	var src_size := tex.get_size()
	if src_size.x <= 0.0 or src_size.y <= 0.0:
		return
	var scale := minf(rect.size.x / src_size.x, rect.size.y / src_size.y)
	var dest_size := src_size * scale
	var pos := rect.position + (rect.size - dest_size) * anchor
	ci.draw_texture_rect(tex, Rect2(pos, dest_size), false)


## Present / Missing for every slot, for docs and the coverage test.
static func coverage() -> Dictionary:
	var report := {}
	for slot: StringName in SLOTS:
		report[slot] = path_of(slot)
	return report
