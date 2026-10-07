class_name CardArtResolver
extends RefCounted
## Unique-art contract: one optional resource per exact card ID.
## No generic faction/type art fallback is permitted.

const ART_ROOT := "res://assets/cards"
const EXTENSIONS := ["webp", "png", "svg"]

static var _path_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}


static func art_path(card_id: StringName) -> String:
	if _path_cache.has(card_id):
		return _path_cache[card_id]
	var safe_id := String(card_id)
	for extension: String in EXTENSIONS:
		var candidate := "%s/%s.%s" % [ART_ROOT, safe_id, extension]
		if ResourceLoader.exists(candidate):
			_path_cache[card_id] = candidate
			return candidate
	_path_cache[card_id] = ""
	return ""


static func resolve(card_id: StringName) -> Texture2D:
	if _texture_cache.has(card_id):
		return _texture_cache[card_id] as Texture2D
	var path := art_path(card_id)
	if path.is_empty():
		_texture_cache[card_id] = null
		return null
	var texture := load(path) as Texture2D
	_texture_cache[card_id] = texture
	return texture
