class_name MatchCommand
extends RefCounted
## One player decision sent to MatchEngine. Plain data, safe to record and replay.

enum Kind { MULLIGAN, PLAY_CARD, USE_HERO_POWER, USE_IMPULSE_SHARD, ATTACK, END_TURN, CHOOSE }

## Choice keys.
const CHOICE_SOUL_SHARDS := "soul_shards_to_spend"
const CHOICE_OPTION := "option"

var kind: Kind = Kind.END_TURN
var player: int = -1
## PLAY_CARD: instance id of the hand card. ATTACK: instance id of the attacker.
var source_id: int = 0
## Target instance id (creature or hero); 0 = no target.
var target_id: int = 0
## MULLIGAN: instance ids of the hand cards to replace.
var replace_ids: Array[int] = []
## Player choices, e.g. {"soul_shards_to_spend": 2} or {"option": <instance id>}.
var choices: Dictionary = {}


static func mulligan(player_index: int, ids: Array[int]) -> MatchCommand:
	var command := _make(Kind.MULLIGAN, player_index)
	command.replace_ids = ids.duplicate()
	return command


static func play_card(player_index: int, card_id: int, target: int = 0, card_choices: Dictionary = {}) -> MatchCommand:
	var command := _make(Kind.PLAY_CARD, player_index)
	command.source_id = card_id
	command.target_id = target
	command.choices = card_choices.duplicate(true)
	return command


static func use_hero_power(player_index: int, target: int = 0) -> MatchCommand:
	var command := _make(Kind.USE_HERO_POWER, player_index)
	command.target_id = target
	return command


static func use_impulse_shard(player_index: int) -> MatchCommand:
	return _make(Kind.USE_IMPULSE_SHARD, player_index)


static func attack(player_index: int, attacker_id: int, target: int) -> MatchCommand:
	var command := _make(Kind.ATTACK, player_index)
	command.source_id = attacker_id
	command.target_id = target
	return command


static func end_turn(player_index: int) -> MatchCommand:
	return _make(Kind.END_TURN, player_index)


static func choose(player_index: int, option_id: int) -> MatchCommand:
	var command := _make(Kind.CHOOSE, player_index)
	command.choices = {CHOICE_OPTION: option_id}
	return command


static func _make(command_kind: Kind, player_index: int) -> MatchCommand:
	var command := MatchCommand.new()
	command.kind = command_kind
	command.player = player_index
	return command


## Inverse of to_dictionary() (replays, logs).
static func from_dictionary(data: Dictionary) -> MatchCommand:
	var command := _make(Kind[data["kind"]] as Kind, int(data["player"]))
	command.source_id = int(data.get("source_id", 0))
	command.target_id = int(data.get("target_id", 0))
	command.replace_ids.assign(data.get("replace_ids", []).map(func(id: Variant) -> int: return int(id)))
	for key: Variant in data.get("choices", {}):
		command.choices[key] = int(data["choices"][key])
	return command


func to_dictionary() -> Dictionary:
	return {
		"kind": Kind.find_key(kind), "player": player, "source_id": source_id, "target_id": target_id,
		"replace_ids": replace_ids.duplicate(), "choices": choices.duplicate(true),
	}
