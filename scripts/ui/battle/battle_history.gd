class_name BattleHistory
extends RefCounted
## Russian battle history for the ИСТОРИЯ drawer. Lines are built only from
## MatchEvents plus names already public in the player's observation. Hidden
## information (opponent draws, burned or chosen cards) is never named.

const MAX_LINES := 200

var player_index := 0
var lines: PackedStringArray = []

var _names: Dictionary = {}


func _init(viewer: int = 0) -> void:
	player_index = viewer


## Remembers public names of heroes and creatures so later events (deaths) can name them.
func remember(observation: Dictionary) -> void:
	for side: String in ["own", "opponent"]:
		var data: Dictionary = observation.get(side, {})
		var hero: Dictionary = data.get("hero", {})
		var hero_id := StringName(str(hero.get("id", "")))
		if HeroCatalog.has_hero(hero_id):
			var hero_name: String = HeroCatalog.HEROES[hero_id]["name_ru"]
			_names[int(hero.get("instance_id", 0))] = hero_name if side == "opponent" else "%s (вы)" % hero_name
		for creature: Dictionary in data.get("board", []):
			_names[int(creature.get("instance_id", 0))] = _card_name(StringName(str(creature.get("card_id", ""))))


func add_events(events: Array) -> void:
	for event: Variant in events:
		if event is Dictionary:
			var text_line := describe(event as Dictionary)
			if not text_line.is_empty():
				lines.append(text_line)
	while lines.size() > MAX_LINES:
		lines.remove_at(0)


func describe(event: Dictionary) -> String:
	var kind: Variant = event.get("type")
	var own := int(event.get("player", -1)) == player_index
	match kind:
		MatchEvent.TURN_STARTED:
			return "— Ход %d · %s —" % [int(event.get("turn", 0)), "ваш" if own else "соперника"]
		MatchEvent.CARD_PLAYED:
			var card_name := _card_name(StringName(str(event.get("card_id", ""))))
			_names[int(event.get("card_instance_id", 0))] = card_name
			return ("Вы разыграли «%s»" if own else "Соперник разыграл «%s»") % card_name
		MatchEvent.CREATURE_ENTERED:
			_names[int(event.get("creature_id", 0))] = _card_name(StringName(str(event.get("card", ""))))
			return ""
		MatchEvent.CARD_DRAWN:
			if own:
				return "Вы взяли «%s»" % _card_name(StringName(str(event.get("card", ""))))
			return "Соперник взял карту"
		MatchEvent.CARD_BURNED:
			if own:
				return "Рука полна: «%s» сгорает" % _card_name(StringName(str(event.get("card", ""))))
			return "Рука соперника полна: карта сгорает"
		MatchEvent.RIFT_DAMAGE:
			return ("Разлом: вы получаете %d урона" if own else "Разлом: соперник получает %d урона") % int(event.get("amount", 0))
		MatchEvent.ATTACK_DECLARED:
			return "%s атакует: %s" % [_name_of(int(event.get("attacker_id", 0))), _name_of(int(event.get("target_id", 0)))]
		MatchEvent.DAMAGE_DEALT:
			var amount := int(event.get("amount", 0))
			if amount <= 0:
				return ""
			var target := _name_of(int(event.get("target_id", 0)))
			var to_armor := int(event.get("to_armor", 0))
			if to_armor > 0:
				return "%s: −%d (броня −%d)" % [target, amount, to_armor]
			return "%s: −%d" % [target, amount]
		MatchEvent.CREATURE_DIED:
			var dead := _card_name(StringName(str(event.get("card", ""))))
			return "%s погибает" % dead
		MatchEvent.HERO_POWER_USED:
			var hero_id := StringName(str(event.get("hero", "")))
			var power: String = HeroCatalog.HEROES[hero_id]["power_ru"] if HeroCatalog.has_hero(hero_id) else ""
			return ("Вы применили «%s»" if own else "Соперник применил «%s»") % power
		MatchEvent.IMPULSE_SHARD_USED:
			return "Вы использовали «Осколок импульса»" if own else "Соперник использовал «Осколок импульса»"
		MatchEvent.SOUL_SHARDS_CHANGED:
			var after := int(event.get("after", 0))
			if after == int(event.get("before", 0)):
				return ""
			return ("Ваши Осколки души: %d" if own else "Осколки души соперника: %d") % after
		MatchEvent.CHOICE_MADE:
			return "Вы сделали выбор" if own else ""
		MatchEvent.MATCH_ENDED:
			if bool(event.get("draw", false)):
				return "Бой завершён: ничья"
			return "Бой завершён: %s" % ("победа" if int(event.get("winner", -1)) == player_index else "поражение")
	return ""


func text() -> String:
	return "\n".join(lines)


func _name_of(instance_id: int) -> String:
	return String(_names.get(instance_id, "существо"))


func _card_name(card_id: StringName) -> String:
	var card := CardDatabase.get_card(card_id)
	return card.name_ru if card != null else "карта"
