class_name CardArtResolver
extends RefCounted
## Unique-art contract: one optional resource per exact card ID.
## No generic faction/type art fallback is permitted.

const ART_ROOT := "res://assets/cards"
const EXTENSIONS := ["webp", "png", "svg"]


static func art_path(card_id: StringName) -> String:
	var safe_id := String(card_id)
	for extension: String in EXTENSIONS:
		var candidate := "%s/%s.%s" % [ART_ROOT, safe_id, extension]
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


static func resolve(card_id: StringName) -> Texture2D:
	var path := art_path(card_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D
