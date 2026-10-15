class_name WarmMaterials
extends RefCounted
## Original recovered bitmaps remain intact. Small imported regions are scaled
## once into cached runtime textures; nine-patch margins never stretch corners.

const WOOD := "res://assets/recovered_warm/wood_ui.webp"
const PARCHMENT := "res://assets/recovered_warm/parchment_ui.webp"
static var _textures: Dictionary = {}


static func box(wood: bool, tint: Color = Color.WHITE, content_x: float = 24.0, content_y: float = 16.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _texture(WOOD if wood else PARCHMENT)
	style.modulate_color = tint
	style.texture_margin_left = 52.0 if wood else 28.0
	style.texture_margin_right = 52.0 if wood else 28.0
	style.texture_margin_top = 22.0
	style.texture_margin_bottom = 22.0
	style.content_margin_left = content_x
	style.content_margin_right = content_x
	style.content_margin_top = content_y
	style.content_margin_bottom = content_y
	return style


static func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path] as Texture2D
	var imported := load(path) as Texture2D
	if imported == null:
		return null
	var image := imported.get_image()
	if image == null or image.is_empty():
		return null
	# Crop only the transparent source padding, not painted corners.
	var source := Rect2i(0, 108, 2172, 473) if path == WOOD else Rect2i(0, 43, 1774, 800)
	image = image.get_region(source)
	image.resize(512, 160 if path == WOOD else 256, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture


static func paper_texture() -> Texture2D:
	return _texture(PARCHMENT)
