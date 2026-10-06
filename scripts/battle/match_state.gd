class_name MatchState
extends RefCounted
## Complete runtime state of one match. Plain data plus runtime instances; it
## holds no rules. Owned by one MatchEngine, never by an autoload.
##
## Queue entries, delayed actions, modifiers and choices reference instances by
## id, so clone() is a straightforward deep copy.

enum Phase { SETUP, MULLIGAN, TURN, ENDED }

var phase: Phase = Phase.SETUP
var players: Array[PlayerState] = []
var first_player: int = -1
var active_player: int = -1
## Global turn counter: 1 = first player's first turn, 2 = second player's first turn, ...
var turn_number: int = 0
## -1 while the match runs or when it ended in a draw.
var winner: int = -1
var is_draw := false
var next_instance_id: int = 1
var next_sequence: int = 1
## Player index -> instance ids chosen for the mulligan.
var mulligan_choices: Dictionary = {}
## Delayed actions: {"seq", "turn", "kind": "DAMAGE", "target_id", "amount", "owner", "card_id"}.
var delayed_actions: Array[Dictionary] = []
## Pending player choice: {"player", "kind", "options": [ids], "keep_on_top": int}.
var pending_choice: Dictionary = {}
## Trigger queues: {"timing", "source_kind", "source_id", "owner", "card_id", "effect_index", "event"}.
var when_queue: Array[Dictionary] = []
var after_queue: Array[Dictionary] = []
var events: Array[Dictionary] = []


func is_over() -> bool:
	return phase == Phase.ENDED


func opponent_of(player_index: int) -> int:
	return 1 - player_index


func take_id() -> int:
	var id := next_instance_id
	next_instance_id += 1
	return id


func take_sequence() -> int:
	var sequence := next_sequence
	next_sequence += 1
	return sequence


## Creature on either board, or null.
func find_creature(creature_id: int) -> CreatureInstance:
	for player in players:
		var creature := player.find_on_board(creature_id)
		if creature != null:
			return creature
	return null


## Player whose hero has [param target_id], or -1.
func hero_owner(target_id: int) -> int:
	for player in players:
		if player.hero_instance_id == target_id:
			return player.index
	return -1


## Board order used for simultaneous events: active player first, then the opponent.
func player_order() -> Array[int]:
	var first := active_player if active_player >= 0 else 0
	return [first, 1 - first]


## Deep copy. [param with_events] = false skips the event log (rollback keeps
## the log and only truncates it).
func clone(with_events: bool = true) -> MatchState:
	var copy := MatchState.new()
	copy.phase = phase
	copy.players.assign(players.map(func(player: PlayerState) -> PlayerState: return player.clone()))
	copy.first_player = first_player
	copy.active_player = active_player
	copy.turn_number = turn_number
	copy.winner = winner
	copy.is_draw = is_draw
	copy.next_instance_id = next_instance_id
	copy.next_sequence = next_sequence
	copy.mulligan_choices = mulligan_choices.duplicate(true)
	copy.delayed_actions = delayed_actions.duplicate(true)
	copy.pending_choice = pending_choice.duplicate(true)
	copy.when_queue = when_queue.duplicate(true)
	copy.after_queue = after_queue.duplicate(true)
	if with_events:
		copy.events = events.duplicate(true)
	return copy


## Canonical, deterministic plain-data view of the state (no events).
func snapshot() -> Dictionary:
	return {
		"phase": Phase.find_key(phase), "turn_number": turn_number, "first_player": first_player,
		"active_player": active_player, "winner": winner, "is_draw": is_draw,
		"next_instance_id": next_instance_id, "next_sequence": next_sequence,
		"players": players.map(func(player: PlayerState) -> Dictionary: return player.snapshot()),
		"mulligan_choices": mulligan_choices.duplicate(true), "delayed_actions": delayed_actions.duplicate(true),
		"pending_choice": pending_choice.duplicate(true), "when_queue": when_queue.duplicate(true),
		"after_queue": after_queue.duplicate(true),
	}
