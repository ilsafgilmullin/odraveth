class_name PlayerState
extends RefCounted
## Runtime state of one side of a match. No UI state.

var index: int
var hero_id: StringName
## Target id of the hero (heroes are ids 1 and 2).
var hero_instance_id: int
@warning_ignore("enum_variable_without_default")
var faction: Faction.Id
var hero_health: int = GameRules.HERO_STARTING_HEALTH
var energy_max: int = 0
var energy_current: int = 0
var soul_shards: int = GameRules.STARTING_SOUL_SHARDS
## Index 0 is the top of the deck.
var deck: Array[CardInstance] = []
var hand: Array[CardInstance] = []
## Left-to-right order of the board.
var board: Array[CreatureInstance] = []
var active_artifact: ArtifactInstance = null
var graveyard: Array[CardInstance] = []
## Cards drawn into a full hand: removed from the match without any trigger.
var burned: Array[CardInstance] = []
var rift_damage_next: int = GameRules.RIFT_FIRST_DAMAGE
var hero_power_used_this_turn := false
var impulse_shard_available := false
var hero_damaged_this_turn := false
var friendly_creature_died_this_turn := false
## Own turns started so far (energy growth).
var turns_started: int = 0
var mulligan_done := false
## Pending "next card" cost increases created by the opponent, oldest first:
## {"seq", "source": "DISTORTION" | <card id>, "amount", "only_cost_at_most", "cost_cap"}.
var incoming_cost_modifiers: Array[Dictionary] = []


func find_in_hand(card_id: int) -> CardInstance:
	for card in hand:
		if card.instance_id == card_id:
			return card
	return null


func find_on_board(creature_id: int) -> CreatureInstance:
	for creature in board:
		if creature.instance_id == creature_id:
			return creature
	return null


func clone() -> PlayerState:
	var copy := PlayerState.new()
	copy.index = index
	copy.hero_id = hero_id
	copy.hero_instance_id = hero_instance_id
	copy.faction = faction
	copy.hero_health = hero_health
	copy.energy_max = energy_max
	copy.energy_current = energy_current
	copy.soul_shards = soul_shards
	copy.deck.assign(deck.map(func(card: CardInstance) -> CardInstance: return card.clone()))
	copy.hand.assign(hand.map(func(card: CardInstance) -> CardInstance: return card.clone()))
	copy.board.assign(board.map(func(creature: CreatureInstance) -> CreatureInstance: return creature.clone()))
	copy.active_artifact = active_artifact.clone() if active_artifact != null else null
	copy.graveyard.assign(graveyard.map(func(card: CardInstance) -> CardInstance: return card.clone()))
	copy.burned.assign(burned.map(func(card: CardInstance) -> CardInstance: return card.clone()))
	copy.rift_damage_next = rift_damage_next
	copy.hero_power_used_this_turn = hero_power_used_this_turn
	copy.impulse_shard_available = impulse_shard_available
	copy.hero_damaged_this_turn = hero_damaged_this_turn
	copy.friendly_creature_died_this_turn = friendly_creature_died_this_turn
	copy.turns_started = turns_started
	copy.mulligan_done = mulligan_done
	copy.incoming_cost_modifiers = incoming_cost_modifiers.duplicate(true)
	return copy


func snapshot() -> Dictionary:
	return {
		"index": index, "hero": String(hero_id), "hero_id": hero_instance_id, "hero_health": hero_health,
		"energy_max": energy_max, "energy_current": energy_current, "soul_shards": soul_shards,
		"deck": deck.map(func(card: CardInstance) -> Dictionary: return card.snapshot()),
		"hand": hand.map(func(card: CardInstance) -> Dictionary: return card.snapshot()),
		"board": board.map(func(creature: CreatureInstance) -> Dictionary: return creature.snapshot()),
		"active_artifact": active_artifact.snapshot() if active_artifact != null else {},
		"graveyard": graveyard.map(func(card: CardInstance) -> Dictionary: return card.snapshot()),
		"burned": burned.map(func(card: CardInstance) -> Dictionary: return card.snapshot()),
		"rift_damage_next": rift_damage_next, "hero_power_used_this_turn": hero_power_used_this_turn,
		"impulse_shard_available": impulse_shard_available, "hero_damaged_this_turn": hero_damaged_this_turn,
		"friendly_creature_died_this_turn": friendly_creature_died_this_turn, "turns_started": turns_started,
		"mulligan_done": mulligan_done, "incoming_cost_modifiers": incoming_cost_modifiers.duplicate(true),
	}
