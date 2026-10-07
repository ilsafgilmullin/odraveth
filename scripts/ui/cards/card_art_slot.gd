class_name CardArtSlot
extends Control
## Artwork slot with exact-card resolver and deterministic non-final fallback.

var card_id: StringName = &""
var card_type: CardEnums.Type = CardEnums.Type.CREATURE
var faction: Faction.Id = Faction.Id.NEUTRAL
var resolved_path := ""
var uses_placeholder := true

var _texture_rect: TextureRect
var _placeholder_label: Label
var _accent := VisualTokens.COLOR_STEEL_500


func _ready() -> void:
	_ensure_children()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(presentation: CardPresentation) -> void:
	if presentation == null:
		return
	_ensure_children()
	card_id = presentation.id
	card_type = presentation.card_type
	faction = presentation.faction
	_accent = presentation.faction_accent
	resolved_path = CardArtResolver.art_path(card_id)
	var texture := CardArtResolver.resolve(card_id)
	uses_placeholder = texture == null
	_texture_rect.texture = texture
	_texture_rect.visible = texture != null
	_placeholder_label.visible = texture == null
	_placeholder_label.text = "АРТ · ВРЕМЕННО\n%s\n%s" % [
		String(card_id), presentation.type_key,
	]
	queue_redraw()


func _ensure_children() -> void:
	if _texture_rect != null:
		return
	clip_contents = true
	_texture_rect = TextureRect.new()
	_texture_rect.name = "ResolvedArtwork"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_placeholder_label = Label.new()
	_placeholder_label.name = "ArtworkFallbackLabel"
	_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placeholder_label.add_theme_font_size_override("font_size", 16)
	_placeholder_label.add_theme_color_override("font_color", VisualTokens.COLOR_MUTED)
	_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placeholder_label)


func _draw() -> void:
	if not uses_placeholder:
		return
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("d7d1c5"))
	for i in 5:
		var x := s.x * (0.12 + 0.19 * float(i))
		draw_line(Vector2(x, 0), Vector2(x - s.x * 0.18, s.y), Color(_accent, 0.12), 3.0)
	draw_line(Vector2(0, s.y * 0.12), Vector2(s.x, s.y * 0.12), Color(_accent, 0.45), 3.0)
	draw_line(Vector2(0, s.y * 0.88), Vector2(s.x, s.y * 0.88), Color(VisualTokens.COLOR_STEEL_700, 0.22), 2.0)
