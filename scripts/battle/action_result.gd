class_name ActionResult
extends RefCounted
## Result of a MatchEngine command. A rejected command never changes the match.

const NO_MATCH := &"NO_MATCH"
const INVALID_SETUP := &"INVALID_SETUP"
const MATCH_ENDED := &"MATCH_ENDED"
const WRONG_PHASE := &"WRONG_PHASE"
const NOT_YOUR_TURN := &"NOT_YOUR_TURN"
const CHOICE_PENDING := &"CHOICE_PENDING"
const UNKNOWN_CARD := &"UNKNOWN_CARD"
const NOT_ENOUGH_ENERGY := &"NOT_ENOUGH_ENERGY"
const NOT_ENOUGH_SOUL_SHARDS := &"NOT_ENOUGH_SOUL_SHARDS"
const TARGET_REQUIRED := &"TARGET_REQUIRED"
const INVALID_TARGET := &"INVALID_TARGET"
const INVALID_CHOICE := &"INVALID_CHOICE"
const BOARD_FULL := &"BOARD_FULL"
const ALREADY_USED := &"ALREADY_USED"
const NOT_AVAILABLE := &"NOT_AVAILABLE"
const CANNOT_ATTACK := &"CANNOT_ATTACK"
const ENGINE_ERROR := &"ENGINE_ERROR"

var ok := false
## Error code (constants above); empty when ok.
var error: StringName = &""
## Technical description for logs, not player-facing text.
var message := ""
## Events produced by the command (copies).
var events: Array[Dictionary] = []
## True when the command stopped at a player choice (MatchCommand.Kind.CHOOSE).
var awaiting_choice := false


static func success(produced: Array[Dictionary], waiting: bool = false) -> ActionResult:
	var result := ActionResult.new()
	result.ok = true
	result.events = produced
	result.awaiting_choice = waiting
	return result


static func failure(code: StringName, text: String = "") -> ActionResult:
	var result := ActionResult.new()
	result.error = code
	result.message = text
	return result
