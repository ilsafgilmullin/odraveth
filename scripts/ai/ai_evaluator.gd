class_name AiEvaluator
extends RefCounted
## Bounded, deterministic command scoring over sanitized observation data.
## No future-state simulation is performed.

const SCORE_LETHAL := 1000000
const SCORE_SELF_LETHAL := -900000


static func score_command(observation: Dictionary, command: MatchCommand,
		legal_commands: Array[MatchCommand], difficulty: AiDifficulty.Level) -> Dictionary:
	var components: Dictionary = {}
	match command.kind:
		MatchCommand.Kind.END_TURN:
			components["END_TURN"] = 0
		MatchCommand.Kind.ATTACK:
			_score_attack(observation, command, difficulty, components)
		MatchCommand.Kind.PLAY_CARD:
			_score_play(observation, command, difficulty, components)
		MatchCommand.Kind.USE_HERO_POWER:
			_score_hero_power(observation, command, legal_commands, difficulty, components)
		MatchCommand.Kind.USE_IMPULSE_SHARD:
			_score_impulse(observation, difficulty, components)
		_:
			components["BASE"] = 0
	return {"total": _sum(components), "components": components}


static func estimate_definition_value(definition: Dictionary, difficulty: AiDifficulty.Level) -> int:
	var value := 0
	match String(definition.get("type", "")):
		"CREATURE":
			value += int(definition.get("attack", 0)) * _w(difficulty, 6, 9, 10)
			value += int(definition.get("health", 0)) * _w(difficulty, 5, 7, 8)
			value += int(definition.get("armor", 0)) * _w(difficulty, 5, 9, 11)
		"ARTIFACT":
			value += int(definition.get("charges", 0)) * _w(difficulty, 7, 12, 15)
		"SPELL":
			value += 8
	for effect: Dictionary in definition.get("effects", []):
		var trigger_weight := _trigger_weight(String(effect.get("trigger", "")), difficulty)
		value += _effect_static_value(effect, difficulty) * trigger_weight / 100
	value -= int(definition.get("cost", 0)) * _w(difficulty, 2, 3, 3)
	return value


static func synergy_score(definitions: Array, difficulty: AiDifficulty.Level) -> int:
	if difficulty != AiDifficulty.Level.STRATEGIST:
		return 0
	var has_artifact := false
	var wants_artifact := false
	var damages_own_hero := false
	var reacts_to_hero_damage := false
	var gains_shards := false
	var spends_shards := false
	var creates_cost_disruption := false
	var reacts_to_increased_cost := false
	for definition: Dictionary in definitions:
		if definition.get("type", "") == "ARTIFACT":
			has_artifact = true
		for effect: Dictionary in definition.get("effects", []):
			if effect.get("trigger", "") == "OWN_HERO_DAMAGED":
				reacts_to_hero_damage = true
			if effect.get("trigger", "") == "OPPONENT_PAYS_INCREASED_COST":
				reacts_to_increased_cost = true
			for condition: Dictionary in effect.get("conditions", []):
				if condition.get("type", "") == "OWN_ACTIVE_ARTIFACT":
					wants_artifact = true
			for action: Dictionary in effect.get("actions", []):
				match String(action.get("type", "")):
					"DEAL_DAMAGE":
						damages_own_hero = damages_own_hero or action.get("target", "") == "OWN_HERO"
					"GAIN_SOUL_SHARDS":
						gains_shards = true
					"SPEND_SOUL_SHARDS":
						spends_shards = true
					"INCREASE_NEXT_OPPONENT_CARD_COST", "INCREASE_PLAYED_CARD_COST":
						creates_cost_disruption = true
	var score := 0
	if has_artifact and wants_artifact:
		score += 28
	if damages_own_hero and reacts_to_hero_damage:
		score += 24
	if gains_shards and spends_shards:
		score += 24
	if creates_cost_disruption and reacts_to_increased_cost:
		score += 24
	return score


static func synergy_with_hand(definition: Dictionary, hand: Array, difficulty: AiDifficulty.Level) -> int:
	if difficulty != AiDifficulty.Level.STRATEGIST:
		return 0
	var definitions: Array = [definition]
	for card: Dictionary in hand:
		definitions.append(card["definition"])
	return synergy_score(definitions, difficulty)


static func threat_value(creature: Dictionary, difficulty: AiDifficulty.Level) -> int:
	var value := int(creature.get("attack", 0)) * _w(difficulty, 5, 10, 12)
	value += (int(creature.get("health", 0)) + int(creature.get("armor", 0))) * _w(difficulty, 2, 4, 5)
	var keywords: Array = creature.get("keywords", [])
	if "PROVOKE" in keywords:
		value += _w(difficulty, 5, 20, 25)
	if int(creature.get("max_attacks_this_turn", 1)) > 1:
		value += _w(difficulty, 5, 25, 35)
	return value


static func _score_attack(observation: Dictionary, command: MatchCommand,
		difficulty: AiDifficulty.Level, components: Dictionary) -> void:
	var attacker := _find_creature(observation["own"]["board"], command.source_id)
	if attacker.is_empty():
		components["INVALID_CONTEXT"] = -100000
		return
	var enemy_hero: Dictionary = observation["opponent"]["hero"]
	if command.target_id == int(enemy_hero["instance_id"]):
		var damage := int(attacker["attack"])
		if damage >= int(enemy_hero["health"]):
			components["LETHAL"] = SCORE_LETHAL
			components["HERO_DAMAGE"] = damage * 20
			return
		components["HERO_DAMAGE"] = damage * _w(difficulty, 13, 11, 10)
		if difficulty != AiDifficulty.Level.NOVICE:
			components["PUBLIC_THREAT"] = -_board_attack(observation["opponent"]["board"]) * _w(difficulty, 0, 1, 2)
		return
	var defender := _find_creature(observation["opponent"]["board"], command.target_id)
	if defender.is_empty():
		components["INVALID_CONTEXT"] = -100000
		return
	var attack := int(attacker["attack"])
	var defender_durability := int(defender["health"]) + int(defender["armor"])
	var attacker_durability := int(attacker["health"]) + int(attacker["armor"])
	var counter := int(defender["attack"])
	var defender_dies := attack >= defender_durability
	var attacker_dies := counter >= attacker_durability
	components["TRADE_VALUE"] = attack * _w(difficulty, 3, 4, 4)
	if defender_dies:
		components["THREAT_REMOVAL"] = threat_value(defender, difficulty)
		components["TRADE_VALUE"] += _w(difficulty, 12, 35, 45)
	if attacker_dies:
		components["PRESERVE_CREATURE"] = -threat_value(attacker, difficulty)
	elif difficulty != AiDifficulty.Level.NOVICE:
		components["PRESERVE_CREATURE"] = _w(difficulty, 0, 12, 20)
	if difficulty == AiDifficulty.Level.STRATEGIST:
		components["WASTED_DAMAGE"] = -maxi(0, attack - defender_durability) * 3


static func _score_play(observation: Dictionary, command: MatchCommand,
		difficulty: AiDifficulty.Level, components: Dictionary) -> void:
	var card := _find_card(observation["own"].get("hand", []), command.source_id)
	if card.is_empty():
		components["INVALID_CONTEXT"] = -100000
		return
	var definition: Dictionary = card["definition"]
	var cost := int(card.get("current_cost", definition.get("cost", 0)))
	components["BOARD_VALUE"] = estimate_definition_value(definition, difficulty)
	components["ENERGY_EFFICIENCY"] = -cost * _w(difficulty, 1, 2, 2)
	if difficulty == AiDifficulty.Level.STRATEGIST:
		components["SYNERGY_SETUP"] = _strategic_setup_synergy(definition, observation)
	if definition.get("type", "") == "CREATURE":
		var board_count := (observation["own"]["board"] as Array).size()
		if difficulty == AiDifficulty.Level.STRATEGIST and board_count >= GameRules.MAX_CREATURES_PER_SIDE - 1:
			components["BOARD_SPACE"] = -35
	var shards_spent := int(command.choices.get(MatchCommand.CHOICE_SOUL_SHARDS, 0))
	for effect: Dictionary in definition.get("effects", []):
		var trigger := String(effect.get("trigger", ""))
		var factor := 100 if trigger == "ON_PLAY" or trigger == "ENTER_BATTLE" else _trigger_weight(trigger, difficulty)
		var effect_score := _score_effect(observation, command, effect, shards_spent, difficulty, components)
		if factor < 100:
			effect_score = effect_score * factor / 100
		components["SYNERGY"] = int(components.get("SYNERGY", 0)) + effect_score
	if shards_spent > 0:
		var reserve_weight := _w(difficulty, 1, 4, 7)
		var pressure := _board_attack(observation["opponent"]["board"]) - _board_attack(observation["own"]["board"])
		if difficulty == AiDifficulty.Level.STRATEGIST and pressure <= 0:
			reserve_weight += 20
		components["RESOURCE_VALUE"] = int(components.get("RESOURCE_VALUE", 0)) - shards_spent * reserve_weight


static func _score_effect(observation: Dictionary, command: MatchCommand, effect: Dictionary,
		shards_spent: int, difficulty: AiDifficulty.Level, components: Dictionary) -> int:
	var value := 0
	if not _known_conditions_allow(observation, command, effect.get("conditions", [])):
		return 0
	for action: Dictionary in effect.get("actions", []):
		if not _known_conditions_allow(observation, command, action.get("conditions", [])):
			continue
		var multiplier := shards_spent if action.get("multiplier", "") == "SOUL_SHARDS_SPENT" else 1
		match String(action.get("type", "")):
			"MODIFY_STATS":
				var stats := int(action.get("attack", 0)) * _w(difficulty, 8, 11, 12)
				stats += int(action.get("health", 0)) * _w(difficulty, 6, 8, 9)
				stats += int(action.get("armor", 0)) * _w(difficulty, 7, 10, 12)
				value += stats * multiplier
			"DEAL_DAMAGE":
				var amount := int(action.get("amount", 0))
				if action.get("target", "") == "OWN_HERO":
					var health := int(observation["own"]["hero"]["health"])
					if amount >= health:
						components["SELF_DAMAGE_RISK"] = SCORE_SELF_LETHAL
					else:
						value -= amount * _w(difficulty, 8, 14, 18)
				else:
					value += amount * _w(difficulty, 8, 13, 14)
					var target := _target_creature(observation, command.target_id)
					if not target.is_empty() and amount >= int(target["health"]) + int(target["armor"]):
						value += threat_value(target, difficulty)
			"DRAW_CARDS":
				var amount := int(action.get("amount", 0))
				value += amount * _w(difficulty, 9, 22, 30)
				var overflow := maxi(0, int(observation["own"]["hand_count"]) - 1 + amount - GameRules.MAX_HAND_SIZE)
				if overflow > 0:
					components["OVERDRAW_RISK"] = -overflow * _w(difficulty, 10, 35, 50)
			"GRANT_KEYWORD":
				value += _keyword_value(String(action.get("keyword", "")), difficulty)
			"GRANT_EXTRA_ATTACK":
				value += int(action.get("amount", 0)) * _w(difficulty, 18, 45, 60)
			"DESTROY":
				var target := _target_creature(observation, command.target_id)
				value += threat_value(target, difficulty) if not target.is_empty() else _w(difficulty, 12, 30, 35)
			"RETURN_TO_BOARD":
				value += _w(difficulty, 15, 35, 45)
			"RESTORE_ARMOR":
				var target := _target_creature(observation, command.target_id)
				if not target.is_empty():
					value += (int(target["max_armor"]) - int(target["armor"])) * _w(difficulty, 4, 10, 12)
			"GAIN_SOUL_SHARDS":
				var room := GameRules.MAX_SOUL_SHARDS - int(observation["own"]["soul_shards"])
				value += mini(room, int(action.get("amount", 0))) * _w(difficulty, 5, 10, 13)
			"SPEND_SOUL_SHARDS":
				value -= shards_spent * _w(difficulty, 1, 3, 5)
			"INCREASE_NEXT_OPPONENT_CARD_COST", "INCREASE_PLAYED_CARD_COST":
				value += int(action.get("amount", 0)) * _w(difficulty, 5, 14, 20)
			"CREATE_ECHO_IN_HAND":
				value += _w(difficulty, 10, 25, 38)
			"LOOK_AT_TOP_CARDS":
				value += int(action.get("amount", 0)) * _w(difficulty, 3, 7, 11)
	return value


static func _score_hero_power(observation: Dictionary, command: MatchCommand,
		legal_commands: Array[MatchCommand], difficulty: AiDifficulty.Level, components: Dictionary) -> void:
	var hero := String(observation["own"]["hero"]["id"])
	components["ENERGY_EFFICIENCY"] = -GameRules.HERO_ABILITY_COST * _w(difficulty, 2, 4, 4)
	match StringName(hero):
		HeroCatalog.KEZHARYN:
			var self_damage := HeroCatalog.value(HeroCatalog.KEZHARYN, "self_damage")
			if int(observation["own"]["hero"]["health"]) <= self_damage:
				components["SELF_DAMAGE_RISK"] = SCORE_SELF_LETHAL
				return
			var target := _find_creature(observation["own"]["board"], command.target_id)
			if target.is_empty():
				components["INVALID_CONTEXT"] = -100000
				return
			var can_attack := _has_attack_from(legal_commands, command.target_id)
			components["HERO_POWER"] = HeroCatalog.value(HeroCatalog.KEZHARYN, "attack_bonus") 				* _w(difficulty, 5, 13, 16) * (2 if can_attack else 1)
			components["SELF_DAMAGE_RISK"] = -self_damage * _w(difficulty, 4, 9, 12)
		HeroCatalog.VHORAZEL:
			var gain := HeroCatalog.value(HeroCatalog.VHORAZEL, "soul_shards_after_ally_death") 				if observation["own"]["friendly_creature_died_this_turn"] else HeroCatalog.value(HeroCatalog.VHORAZEL, "soul_shards")
			var room := GameRules.MAX_SOUL_SHARDS - int(observation["own"]["soul_shards"])
			components["HERO_POWER"] = mini(gain, room) * _w(difficulty, 5, 12, 15)
		HeroCatalog.SYRRAVETH:
			components["HERO_POWER"] = _w(difficulty, 6, 15, 23)
			if int(observation["opponent"]["hand_count"]) == 0:
				components["HERO_POWER"] -= _w(difficulty, 0, 8, 12)
		HeroCatalog.TAZHYRION:
			var target := _find_creature(observation["own"]["board"], command.target_id)
			components["HERO_POWER"] = _w(difficulty, 7, 16, 21)
			if not target.is_empty() and int(target["health"]) <= int(target["max_health"]) / 2:
				components["HERO_POWER"] += _w(difficulty, 0, 4, 8)


static func _score_impulse(observation: Dictionary, difficulty: AiDifficulty.Level, components: Dictionary) -> void:
	var energy := int(observation["own"]["energy_current"])
	var unlocks := 0
	for card: Dictionary in observation["own"].get("hand", []):
		if int(card.get("current_cost", 99)) == energy + GameRules.IMPULSE_SHARD_ENERGY:
			unlocks += 1
	if not observation["own"]["hero_power_used_this_turn"] and energy < GameRules.HERO_ABILITY_COST 			and energy + GameRules.IMPULSE_SHARD_ENERGY >= GameRules.HERO_ABILITY_COST:
		unlocks += 1
	components["RESOURCE_VALUE"] = unlocks * _w(difficulty, 8, 30, 38) if unlocks > 0 else _w(difficulty, 1, -30, -45)


static func _strategic_setup_synergy(definition: Dictionary, observation: Dictionary) -> int:
	var candidate_artifact := definition.get("type", "") == "ARTIFACT"
	var candidate_self_damage := false
	var candidate_shard_gain := false
	var candidate_shard_spend := false
	var candidate_cost_disruption := false
	for effect: Dictionary in definition.get("effects", []):
		for action: Dictionary in effect.get("actions", []):
			match String(action.get("type", "")):
				"DEAL_DAMAGE":
					candidate_self_damage = candidate_self_damage or action.get("target", "") == "OWN_HERO"
				"GAIN_SOUL_SHARDS":
					candidate_shard_gain = true
				"SPEND_SOUL_SHARDS":
					candidate_shard_spend = true
				"INCREASE_NEXT_OPPONENT_CARD_COST", "INCREASE_PLAYED_CARD_COST":
					candidate_cost_disruption = true

	var wants_artifact := false
	var reacts_hero_damage := false
	var reacts_increased_cost := false
	var visible_shard_gain := false
	var visible_shard_spend := false
	var visible_definitions: Array = []
	for creature: Dictionary in observation["own"]["board"]:
		visible_definitions.append(creature["definition"])
	for card: Dictionary in observation["own"].get("hand", []):
		if card["definition"]["id"] != definition["id"]:
			visible_definitions.append(card["definition"])
	for other: Dictionary in visible_definitions:
		for effect: Dictionary in other.get("effects", []):
			if effect.get("trigger", "") == "OWN_HERO_DAMAGED":
				reacts_hero_damage = true
			if effect.get("trigger", "") == "OPPONENT_PAYS_INCREASED_COST":
				reacts_increased_cost = true
			for condition: Dictionary in effect.get("conditions", []):
				if condition.get("type", "") == "OWN_ACTIVE_ARTIFACT":
					wants_artifact = true
			for action: Dictionary in effect.get("actions", []):
				if action.get("type", "") == "GAIN_SOUL_SHARDS":
					visible_shard_gain = true
				if action.get("type", "") == "SPEND_SOUL_SHARDS":
					visible_shard_spend = true
	var score := 0
	if candidate_artifact and wants_artifact:
		score += 28
	if candidate_self_damage and reacts_hero_damage:
		score += 24
	if candidate_cost_disruption and reacts_increased_cost:
		score += 24
	if candidate_shard_gain and visible_shard_spend:
		score += 20
	if candidate_shard_spend and visible_shard_gain:
		score += 20
	return score


static func _effect_static_value(effect: Dictionary, difficulty: AiDifficulty.Level) -> int:
	var value := 0
	for action: Dictionary in effect.get("actions", []):
		match String(action.get("type", "")):
			"MODIFY_STATS":
				value += int(action.get("attack", 0)) * _w(difficulty, 3, 6, 7)
				value += int(action.get("health", 0)) * _w(difficulty, 3, 5, 6)
				value += int(action.get("armor", 0)) * _w(difficulty, 3, 6, 7)
			"DEAL_DAMAGE":
				value += int(action.get("amount", 0)) * _w(difficulty, 3, 6, 7)
			"DRAW_CARDS":
				value += int(action.get("amount", 0)) * _w(difficulty, 4, 9, 12)
			"GAIN_SOUL_SHARDS":
				value += int(action.get("amount", 0)) * _w(difficulty, 3, 6, 8)
			"GRANT_EXTRA_ATTACK":
				value += int(action.get("amount", 0)) * _w(difficulty, 5, 12, 15)
			"INCREASE_NEXT_OPPONENT_CARD_COST", "INCREASE_PLAYED_CARD_COST":
				value += int(action.get("amount", 0)) * _w(difficulty, 3, 7, 10)
			"CREATE_ECHO_IN_HAND":
				value += _w(difficulty, 4, 10, 14)
			"DESTROY":
				value += _w(difficulty, 8, 16, 20)
	return value


static func _known_conditions_allow(observation: Dictionary, command: MatchCommand, conditions: Array) -> bool:
	for condition: Dictionary in conditions:
		match String(condition.get("type", "")):
			"OWN_HERO_DAMAGED_THIS_TURN":
				if not observation["own"]["hero_damaged_this_turn"]:
					return false
			"OWN_HERO_HEALTH_AT_MOST":
				if int(observation["own"]["hero"]["health"]) > int(condition.get("value", 0)):
					return false
			"IS_OWN_TURN":
				if int(observation["active_player"]) != int(observation["viewer"]):
					return false
			"OWN_SOUL_SHARDS_AT_LEAST":
				if int(observation["own"]["soul_shards"]) < int(condition.get("value", 0)):
					return false
			"SOUL_SHARDS_SPENT_EQUALS":
				if int(command.choices.get(MatchCommand.CHOICE_SOUL_SHARDS, 0)) != int(condition.get("value", 0)):
					return false
			"TARGET_ARMOR_FULL", "TARGET_ARMOR_NOT_FULL":
				var target := _target_creature(observation, command.target_id)
				if target.is_empty():
					return false
				var full := int(target["armor"]) >= int(target["max_armor"])
				if condition["type"] == "TARGET_ARMOR_FULL" and not full:
					return false
				if condition["type"] == "TARGET_ARMOR_NOT_FULL" and full:
					return false
	return true


static func _keyword_value(keyword: String, difficulty: AiDifficulty.Level) -> int:
	match keyword:
		"ONSLAUGHT":
			return _w(difficulty, 8, 20, 24)
		"PROVOKE":
			return _w(difficulty, 5, 16, 20)
		"DEFERRAL":
			return _w(difficulty, 8, 24, 30)
		"FRENZY":
			return _w(difficulty, 5, 15, 19)
	return 0


static func _trigger_weight(trigger: String, difficulty: AiDifficulty.Level) -> int:
	if trigger == "ON_PLAY" or trigger == "ENTER_BATTLE":
		return 100
	if trigger == "STATIC":
		return _w(difficulty, 20, 55, 75)
	return _w(difficulty, 12, 45, 70)


static func _target_creature(observation: Dictionary, target_id: int) -> Dictionary:
	var own := _find_creature(observation["own"]["board"], target_id)
	return own if not own.is_empty() else _find_creature(observation["opponent"]["board"], target_id)


static func _find_creature(board: Array, instance_id: int) -> Dictionary:
	for creature: Dictionary in board:
		if int(creature["instance_id"]) == instance_id:
			return creature
	return {}


static func _find_card(hand: Array, instance_id: int) -> Dictionary:
	for card: Dictionary in hand:
		if int(card["instance_id"]) == instance_id:
			return card
	return {}


static func _has_attack_from(commands: Array[MatchCommand], source_id: int) -> bool:
	return commands.any(func(command: MatchCommand) -> bool:
		return command.kind == MatchCommand.Kind.ATTACK and command.source_id == source_id)


static func _board_attack(board: Array) -> int:
	var total := 0
	for creature: Dictionary in board:
		total += int(creature.get("attack", 0))
	return total


static func _sum(components: Dictionary) -> int:
	var total := 0
	for value: Variant in components.values():
		total += int(value)
	return total


static func _w(difficulty: AiDifficulty.Level, novice: int, tactician: int, strategist: int) -> int:
	match difficulty:
		AiDifficulty.Level.NOVICE:
			return novice
		AiDifficulty.Level.TACTICIAN:
			return tactician
		_:
			return strategist
