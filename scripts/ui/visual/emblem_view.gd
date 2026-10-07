class_name EmblemView
extends Control
## Draws one Visual Alpha symbol centred in its rect. Presentation only.

var kind: NulmerisEmblems.Kind = NulmerisEmblems.Kind.SEAL
var faction: Faction.Id = Faction.Id.NEUTRAL
var primary := VisualTokens.COLOR_STEEL_700
var secondary := VisualTokens.COLOR_GOLD_500
var cut := Color(0, 0, 0, 0)
var fill_ratio := 0.86


static func seal(color: Color = VisualTokens.COLOR_STEEL_700) -> EmblemView:
	var view := EmblemView.new()
	view.kind = NulmerisEmblems.Kind.SEAL
	view.primary = color
	view.secondary = VisualTokens.COLOR_MAGIC_300
	return view


static func o_mark(stone: Color = VisualTokens.COLOR_STEEL_700) -> EmblemView:
	var view := EmblemView.new()
	view.kind = NulmerisEmblems.Kind.O_MARK
	view.primary = stone
	view.secondary = VisualTokens.COLOR_GOLD_500
	return view


static func for_faction(faction_id: Faction.Id, background: Color = VisualTokens.COLOR_STONE_050) -> EmblemView:
	var view := EmblemView.new()
	view.kind = NulmerisEmblems.Kind.FACTION
	view.configure_faction(faction_id, background)
	return view


func configure_faction(faction_id: Faction.Id, background: Color = VisualTokens.COLOR_STONE_050) -> void:
	kind = NulmerisEmblems.Kind.FACTION
	faction = faction_id
	primary = NulmerisEmblems.faction_color(faction_id)
	secondary = NulmerisEmblems.faction_secondary(faction_id)
	cut = background
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 * fill_ratio
	if radius < 2.0:
		return
	var center := size * 0.5
	match kind:
		NulmerisEmblems.Kind.SEAL:
			NulmerisEmblems.draw_seal(self, center, radius, primary, secondary)
		NulmerisEmblems.Kind.O_MARK:
			NulmerisEmblems.draw_o_mark(self, center, radius, primary, secondary)
		_:
			NulmerisEmblems.draw_faction(self, faction, center, radius, primary, secondary, cut)
