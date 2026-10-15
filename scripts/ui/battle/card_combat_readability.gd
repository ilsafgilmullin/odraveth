class_name CardCombatReadability
extends RefCounted
## Presentation of public observations only. Readiness is supplied by legal commands.
## This adapter never authorises an attack or inspects MatchEngine internals.

const KEYWORD_HELP := {
	"PROVOKE": "Провокация: атаки существ должны быть направлены на существ с Провокацией. Заклинания и способности могут выбирать другие допустимые цели.",
	"ONSLAUGHT": "Натиск: в ход появления позволяет атаковать вражеских существ, но не героя. Доступность конкретной атаки определяется текущими целями.",
	"DEFERRAL": "Отложение: существо не может атаковать во время следующего хода своего владельца. Повторное наложение не продлевает блокировку.",
	"FRENZY": "Неистовство: первый раз за ход после получения урона существо получает постоянный +1 к атаке, если остаётся на поле.",
}


static func keyword_help(card: CardDefinition) -> PackedStringArray:
	var lines := PackedStringArray()
	for effect: CardEffectSpec in card.effects:
		var keyword := String(effect.keyword)
		if KEYWORD_HELP.has(keyword) and String(KEYWORD_HELP[keyword]) not in lines:
			lines.append(KEYWORD_HELP[keyword])
	return lines


static func states(creature: Dictionary, turn: int, can_attack: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var keywords: Array = creature.get("keywords", [])
	if "PROVOKE" in keywords:
		result.append(_state("provoke", "Провокация", KEYWORD_HELP["PROVOKE"], "shield", true))
	if bool(creature.get("deferral_pending", false)):
		result.append(_state("deferral_pending", "Отложение · ожидание",
			"Блокировка начнётся в следующий ход владельца; сейчас Отложение ещё не запрещает атаку.", "clock", false))
	if int(creature.get("attack_blocked_turn", -1)) == turn and turn >= 0:
		result.append(_state("deferral_active", "Отложение · атака запрещена",
			"Атаковать нельзя до окончания текущего хода владельца.", "lock", true))
	var definition: Dictionary = creature.get("definition", {})
	var has_frenzy := false
	for effect: Dictionary in definition.get("effects", []):
		if String(effect.get("keyword", "")) == "FRENZY":
			has_frenzy = true
	if has_frenzy:
		var used := bool(creature.get("frenzy_used_this_turn", false))
		result.append(_state("frenzy_used" if used else "frenzy_available",
			"Неистовство · сработало" if used else "Неистовство · доступно",
			"В этом ходу уже дало +1 к атаке. Бонус постоянный; повторное срабатывание в этом ходу недоступно."
			if used else KEYWORD_HELP["FRENZY"], "flame", used))
	if "ONSLAUGHT" in keywords:
		result.append(_state("onslaught", "Натиск", KEYWORD_HELP["ONSLAUGHT"], "sword", true))
	else:
		for effect: Dictionary in definition.get("effects", []):
			for action: Dictionary in effect.get("actions", []):
				if action.get("type") == "GRANT_KEYWORD" and action.get("keyword") == "ONSLAUGHT" \
						and String(effect.get("trigger", "")) == "STATIC":
					result.append(_state("onslaught_conditional", "Натиск · условие не выполнено",
						"Натиск сейчас не действует. Условие указано в полном тексте карты.", "sword", false))
	for bonus: Dictionary in creature.get("temporary_attack", []):
		var expires := int(bonus.get("expires_turn", -1))
		if expires >= turn:
			result.append(_state("temporary_attack", "Временная атака %+d" % int(bonus.get("amount", 0)),
				"Прибавка %+d действует до конца хода №%d." % [int(bonus.get("amount", 0)), expires], "bonus", true))
	if can_attack:
		var remaining := maxi(0, int(creature.get("max_attacks_this_turn", 1)) - int(creature.get("attacks_this_turn", 0)))
		result.append(_state("attack_ready", "Готово атаковать · %d" % remaining,
			"Есть допустимые цели атаки. Осталось атак: %d. Натиск в ход появления не разрешает атаку героя." % remaining,
			"sword", true))
	return result


static func describe(creature: Dictionary, turn: int, can_attack: bool) -> String:
	var lines := PackedStringArray()
	lines.append("Сейчас: атака %d · здоровье %d/%d · броня %d/%d" % [
		int(creature.get("attack", 0)), int(creature.get("health", 0)), int(creature.get("max_health", 0)),
		int(creature.get("armor", 0)), int(creature.get("max_armor", 0))])
	for state: Dictionary in states(creature, turn, can_attack):
		lines.append("%s — %s" % [state["label"], state["description"]])
	if not can_attack:
		lines.append("Сейчас нет доступной атаки: учитываются ход владельца, появление, использованные атаки, Отложение и допустимые цели.")
	return "\n\n".join(lines)


static func _state(id: String, label: String, description: String, glyph: String, active: bool) -> Dictionary:
	return {"id": id, "label": label, "description": description, "glyph": glyph, "active": active}


static func draw_glyph(canvas: CanvasItem, glyph: String, center: Vector2, radius: float, ink: Color) -> void:
	var width := maxf(1.8, radius * 0.18)
	match glyph:
		"shield":
			var p := PackedVector2Array([Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(0.6, 0.3), Vector2(0, 0.9), Vector2(-0.6, 0.3), Vector2(-0.7, -0.7)])
			for i in p.size():
				p[i] = center + p[i] * radius
			canvas.draw_polyline(p, ink, width, true)
		"clock":
			canvas.draw_arc(center, radius * 0.8, 0, TAU, 24, ink, width, true)
			canvas.draw_line(center, center + Vector2(0, -radius * 0.5), ink, width, true)
			canvas.draw_line(center, center + Vector2(radius * 0.4, 0.2 * radius), ink, width, true)
		"lock":
			canvas.draw_arc(center - Vector2(0, radius * 0.25), radius * 0.45, PI, TAU, 12, ink, width, true)
			canvas.draw_rect(Rect2(center + Vector2(-0.65, -0.05) * radius, Vector2(1.3, 0.9) * radius), ink, false, width)
			canvas.draw_line(center, center + Vector2(0, radius * 0.5), ink, width)
		"flame":
			var p := PackedVector2Array([Vector2(0, -0.9), Vector2(0.25, -0.2), Vector2(0.5, -0.5), Vector2(0.65, 0.35), Vector2(0, 0.85), Vector2(-0.6, 0.4), Vector2(-0.5, -0.2), Vector2(-0.15, 0.1), Vector2(0, -0.9)])
			for i in p.size():
				p[i] = center + p[i] * radius
			canvas.draw_polyline(p, ink, width, true)
		"bonus":
			canvas.draw_line(center - Vector2(radius * 0.6, 0), center + Vector2(radius * 0.6, 0), ink, width * 1.4, true)
			canvas.draw_line(center - Vector2(0, radius * 0.6), center + Vector2(0, radius * 0.6), ink, width * 1.4, true)
		_: # Sword: recognisable blade, guard and grip; no ambiguous tiny letter.
			canvas.draw_line(center + Vector2(-0.6, 0.7) * radius, center + Vector2(0.6, -0.7) * radius, ink, width * 1.4, true)
			canvas.draw_line(center + Vector2(-0.6, 0.0) * radius, center + Vector2(0.1, 0.6) * radius, ink, width, true)
			canvas.draw_line(center + Vector2(0.6, -0.7) * radius, center + Vector2(0.6, -0.25) * radius, ink, width, true)
