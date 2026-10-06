class_name TargetRules
extends RefCounted
## Pure targeting and attack rules shared by command validation and resolution.
##
## A card has at most one chosen target, used by every CHOSEN_* reference of its
## play effects (ON_PLAY for spells, ENTER_BATTLE for creatures).
## Spells and hero abilities with a chosen target need a valid one to be used.
## A creature whose Enter Battle needs a target must get one when any exists;
## with no valid target it is played and that part of the ability does nothing.

const CHOSEN_KINDS: Array[String] = ["CHOSEN_ALLY_CREATURE", "CHOSEN_OTHER_ALLY_CREATURE", "CHOSEN_ENEMY_CREATURE"]


## Effects resolved when [param definition] is played from hand.
static func play_effects(definition: CardDefinition) -> Array[CardEffectSpec]:
	var trigger := &"ON_PLAY" if definition.card_type == CardEnums.Type.SPELL else &"ENTER_BATTLE"
	var result: Array[CardEffectSpec] = []
	for effect in definition.effects:
		if effect.trigger == trigger:
			result.append(effect)
	return result


## The CHOSEN_* target kind of the card's play effects, or "".
static func chosen_target_kind(definition: CardDefinition) -> String:
	for effect in play_effects(definition):
		for action in effect.actions:
			if String(action.get("target", "")) in CHOSEN_KINDS:
				return action["target"]
	return ""


## Valid ids for a chosen target of [param kind] for [param player_index].
static func chosen_targets(state: MatchState, player_index: int, kind: String) -> Array[int]:
	var ids: Array[int] = []
	var side := state.players[state.opponent_of(player_index)] if kind == "CHOSEN_ENEMY_CREATURE" \
		else state.players[player_index]
	for creature in side.board:
		ids.append(creature.instance_id)
	return ids


## True if the card returns a creature to the board (needs a free slot and a dead ally).
static func returns_creature(definition: CardDefinition) -> bool:
	return play_effects(definition).any(func(effect: CardEffectSpec) -> bool:
		return effect.actions.any(func(action: Dictionary) -> bool: return action["type"] == "RETURN_TO_BOARD"))


## The last friendly creature that died and is still in the graveyard, or null.
static func last_died_creature(state: MatchState, player_index: int) -> CardInstance:
	var graveyard := state.players[player_index].graveyard
	for index in range(graveyard.size() - 1, -1, -1):
		if graveyard[index].definition.card_type == CardEnums.Type.CREATURE:
			return graveyard[index]
	return null


## Maximum of an optional SPEND_SOUL_SHARDS (up_to) in the play effects, or -1.
static func optional_soul_shard_spend(definition: CardDefinition) -> int:
	for effect in play_effects(definition):
		for action in effect.actions:
			if action["type"] == "SPEND_SOUL_SHARDS" and action.has("up_to"):
				return int(action["up_to"])
	return -1


## Sum of mandatory SPEND_SOUL_SHARDS amounts in the play effects.
static func mandatory_soul_shard_spend(definition: CardDefinition) -> int:
	var total := 0
	for effect in play_effects(definition):
		for action in effect.actions:
			if action["type"] == "SPEND_SOUL_SHARDS" and action.has("amount"):
				total += int(action["amount"])
	return total


## Why [param creature] cannot attack now, or "" if it can.
static func attack_block_reason(state: MatchState, creature: CreatureInstance) -> String:
	if creature.attacks_this_turn >= creature.max_attacks_this_turn:
		return "no attacks left this turn"
	if creature.attack_blocked_turn == state.turn_number:
		return "deferred (Отложение) this turn"
	if creature.entered_turn == state.turn_number and not creature.has_keyword("ONSLAUGHT"):
		return "entered the board this turn"
	return ""


## Valid attack targets of [param creature]: «Провокация» forces PROVOKE
## creatures; in the turn it entered, «Натиск» allows only enemy creatures.
static func attack_targets(state: MatchState, creature: CreatureInstance) -> Array[int]:
	var targets: Array[int] = []
	if not attack_block_reason(state, creature).is_empty():
		return targets
	var enemy := state.players[state.opponent_of(creature.owner)]
	var provokers := enemy.board.filter(func(other: CreatureInstance) -> bool: return other.has_keyword("PROVOKE"))
	var candidates: Array = provokers if not provokers.is_empty() else enemy.board
	for other: CreatureInstance in candidates:
		targets.append(other.instance_id)
	var entered_now := creature.entered_turn == state.turn_number
	if provokers.is_empty() and not entered_now:
		targets.append(enemy.hero_instance_id)
	return targets
