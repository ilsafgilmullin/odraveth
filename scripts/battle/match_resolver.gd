class_name MatchResolver
extends RefCounted
## Applies rule changes to a MatchState. Every atomic change (damage, draw,
## stat change...) is followed by step(): deaths, static abilities, outcome
## check, then WHEN triggers.
##
## Timing (docs/ARCHITECTURE.md section 9):
## - WHEN triggers resolve right after the atomic step that caused them. They are
##   never resolved re-entrantly: triggers caused while a WHEN trigger resolves
##   wait until it finishes.
## - AFTER triggers resolve once the causing command or trigger and its
##   immediate consequences are done (drain()).
## - Deaths of one step are processed together: active player's board left to
##   right, then the opponent's board.
## - A step that leaves a hero at 0 health ends the match; nothing else resolves.

const MAX_RESOLUTIONS_PER_COMMAND := 500

var state: MatchState
var rng: MatchRng
## Set when a safety limit is hit; MatchEngine then rolls the command back.
var engine_error := ""
## Trigger resolutions allowed per command (tests may lower it).
var max_resolutions := MAX_RESOLUTIONS_PER_COMMAND

var _card_source: Object
var _definitions: Dictionary = {}
var _draining_when := false
var _resolutions := 0


func _init(match_state: MatchState, match_rng: MatchRng, card_source: Object) -> void:
	state = match_state
	rng = match_rng
	_card_source = card_source


func begin_command() -> void:
	engine_error = ""
	_resolutions = 0
	_draining_when = false


## Immutable card definition by id (cached).
func definition(card_id: StringName) -> CardDefinition:
	if not _definitions.has(card_id):
		_definitions[card_id] = _card_source.get_card(card_id)
	return _definitions[card_id]


func new_card(owner: int, card_id: StringName) -> CardInstance:
	return CardInstance.create(state.take_id(), owner, definition(card_id))


func emit(type: StringName, data: Dictionary = {}) -> void:
	var event := data.duplicate(true)
	event["type"] = type
	event["seq"] = state.events.size() + 1
	event["turn"] = state.turn_number
	state.events.append(event)


# --- Steps and queues ------------------------------------------------------------

## True while resolution may go on: the match runs, no choice is pending, no error.
func can_continue() -> bool:
	return not state.is_over() and state.pending_choice.is_empty() and engine_error.is_empty()


## Ends an atomic step. Returns false when resolution must stop.
func step() -> bool:
	if not can_continue():
		return false
	process_deaths()
	recalculate_statics()
	if check_outcome():
		return false
	if not _draining_when:
		_drain_when()
	return can_continue()


## Resolves WHEN and then AFTER triggers until both queues are empty.
func drain() -> void:
	while can_continue():
		_drain_when()
		if not can_continue() or state.after_queue.is_empty():
			return
		if not _count_resolution():
			return
		_resolve_entry(state.after_queue.pop_front())


func queue_trigger(trigger: StringName, event: Dictionary) -> void:
	for entry in TriggerDispatcher.collect(state, trigger, event):
		if not entry["cost_phase"]:
			enqueue(entry)


func enqueue(entry: Dictionary) -> void:
	if entry["timing"] == "AFTER":
		state.after_queue.append(entry)
	else:
		state.when_queue.append(entry)


## The ability of a queue entry, or null when its source is gone.
func effect_for(entry: Dictionary) -> CardEffectSpec:
	var owner := state.players[int(entry["owner"])]
	var source_definition: CardDefinition = null
	match entry["source_kind"]:
		EffectContext.SOURCE_CREATURE:
			var creature := owner.find_on_board(int(entry["source_id"]))
			if creature != null and not creature.is_dead():
				source_definition = creature.definition()
		EffectContext.SOURCE_ARTIFACT:
			if owner.active_artifact != null and owner.active_artifact.instance_id == int(entry["source_id"]):
				source_definition = owner.active_artifact.definition()
		EffectContext.SOURCE_DEAD_CREATURE:
			source_definition = definition(entry["card_id"])
	if source_definition == null:
		return null
	return source_definition.effects[int(entry["effect_index"])]


func _drain_when() -> void:
	if _draining_when:
		return
	_draining_when = true
	while can_continue() and not state.when_queue.is_empty():
		if not _count_resolution():
			break
		_resolve_entry(state.when_queue.pop_front())
	_draining_when = false


func _resolve_entry(entry: Dictionary) -> void:
	var effect := effect_for(entry)
	if effect != null:
		EffectExecutor.resolve(self, EffectContext.from_entry(entry, effect))


func _count_resolution() -> bool:
	_resolutions += 1
	if _resolutions <= max_resolutions:
		return true
	engine_error = "more than %d trigger resolutions in one command" % max_resolutions
	state.when_queue.clear()
	state.after_queue.clear()
	return false


# --- Deaths, statics, outcome ----------------------------------------------------

## Removes every dead creature (active player's board first), then queues
## LAST_BREATH and «ally died» triggers in the same order.
func process_deaths() -> void:
	var dead: Array[CreatureInstance] = []
	for player_index in state.player_order():
		for creature in state.players[player_index].board:
			if creature.is_dead():
				dead.append(creature)
	for creature in dead:
		var owner := state.players[creature.owner]
		owner.board.erase(creature)
		owner.graveyard.append(creature.card)
		owner.friendly_creature_died_this_turn = true
		emit(MatchEvent.CREATURE_DIED, {"creature_id": creature.instance_id, "card": String(creature.card.card_id()),
			"owner": creature.owner})
	for creature in dead:
		for entry in TriggerDispatcher.last_breath(creature):
			enqueue(entry)
		queue_trigger(&"ALLY_CREATURE_DIED", {"player": creature.owner, "creature_id": creature.instance_id})


## Recomputes «пока / если» abilities from scratch, so they never stack.
func recalculate_statics() -> void:
	for player_index in state.player_order():
		for creature in state.players[player_index].board:
			_apply_statics(creature)


## Ends the match when a hero has no health left. Returns true if it is over.
func check_outcome() -> bool:
	if state.is_over():
		return true
	var first_dead := state.players[0].hero_health <= 0
	var second_dead := state.players[1].hero_health <= 0
	if not first_dead and not second_dead:
		return false
	state.phase = MatchState.Phase.ENDED
	state.is_draw = first_dead and second_dead
	state.winner = -1 if state.is_draw else (1 if first_dead else 0)
	state.when_queue.clear()
	state.after_queue.clear()
	state.delayed_actions.clear()
	state.pending_choice = {}
	emit(MatchEvent.MATCH_ENDED, {"winner": state.winner, "draw": state.is_draw})
	return true


func _apply_statics(creature: CreatureInstance) -> void:
	var attack := 0
	var armor := 0
	var keywords: Array[String] = []
	for effect in creature.definition().effects:
		if effect.trigger != &"STATIC" or effect.actions.is_empty():
			continue
		var context := EffectContext.create(creature.owner, EffectContext.SOURCE_CREATURE, creature.instance_id,
			creature.card.card_id(), effect)
		if not EffectConditions.all_true(state, effect.conditions, context):
			continue
		for action in effect.actions:
			match String(action["type"]):
				"MODIFY_STATS":
					attack += int(action.get("attack", 0))
					armor += int(action.get("armor", 0))
				"GRANT_KEYWORD":
					keywords.append(String(action["keyword"]))
	if attack != creature.static_attack_bonus:
		creature.static_attack_bonus = attack
		emit(MatchEvent.STATS_CHANGED, {"creature_id": creature.instance_id, "static_attack_bonus": attack})
	if armor != creature.static_armor_bonus:
		var delta := armor - creature.static_armor_bonus
		creature.static_armor_bonus = armor
		creature.max_armor += delta
		creature.armor = creature.armor + delta if delta > 0 else mini(creature.armor, creature.max_armor)
		emit(MatchEvent.ARMOR_CHANGED, {"creature_id": creature.instance_id, "armor": creature.armor,
			"max_armor": creature.max_armor, "static": true})
	keywords.sort()
	if keywords != creature.static_keywords:
		creature.static_keywords = keywords
		emit(MatchEvent.KEYWORD_GRANTED, {"creature_id": creature.instance_id, "static_keywords": keywords.duplicate()})


# --- Damage --------------------------------------------------------------------

## Armor absorbs first, the rest goes to health. Queues SELF_DAMAGED and, when
## the last armor point is lost, SELF_ARMOR_DEPLETED. Call step() afterwards.
func damage_creature(creature: CreatureInstance, amount: int, source: Dictionary) -> void:
	if amount <= 0 or creature.is_dead():
		return
	var armor_before := creature.armor
	var absorbed := mini(creature.armor, amount)
	creature.armor -= absorbed
	creature.health -= amount - absorbed
	emit(MatchEvent.DAMAGE_DEALT, {"target_id": creature.instance_id, "amount": amount, "to_armor": absorbed,
		"to_health": amount - absorbed, "source": source})
	queue_trigger(&"SELF_DAMAGED", {"creature_id": creature.instance_id, "amount": amount})
	if armor_before > 0 and creature.armor == 0:
		queue_trigger(&"SELF_ARMOR_DEPLETED", {"creature_id": creature.instance_id})


## Heroes have no armor. Marks «герой получил урон в этом ходу» and queues
## OWN_HERO_DAMAGED. Call step() afterwards.
func damage_hero(player_index: int, amount: int, source: Dictionary) -> void:
	if amount <= 0:
		return
	var player := state.players[player_index]
	player.hero_health -= amount
	player.hero_damaged_this_turn = true
	emit(MatchEvent.DAMAGE_DEALT, {"target_id": player.hero_instance_id, "amount": amount, "to_armor": 0,
		"to_health": amount, "source": source})
	queue_trigger(&"OWN_HERO_DAMAGED", {"player": player_index, "amount": amount})


# --- Cards and zones -------------------------------------------------------------

## Draws one card. Full hand: the card burns. Empty deck: «Разлом» damage.
## Returns step().
func draw_card(player_index: int) -> bool:
	var player := state.players[player_index]
	if player.deck.is_empty():
		var amount := player.rift_damage_next
		player.rift_damage_next += GameRules.RIFT_DAMAGE_STEP
		emit(MatchEvent.RIFT_DAMAGE, {"player": player_index, "amount": amount})
		damage_hero(player_index, amount, {"kind": "RIFT"})
		return step()
	add_to_hand(player_index, player.deck.pop_front(), MatchEvent.CARD_DRAWN)
	return step()


## Puts a card into the hand, or burns it when the hand is full: a burned card
## leaves the match without being played, discarded or killed.
func add_to_hand(player_index: int, card: CardInstance, event_type: StringName) -> void:
	var player := state.players[player_index]
	if player.hand.size() >= GameRules.MAX_HAND_SIZE:
		player.burned.append(card)
		emit(MatchEvent.CARD_BURNED, {"player": player_index, "card_instance_id": card.instance_id,
			"card": String(card.card_id())})
		return
	player.hand.append(card)
	emit(event_type, {"player": player_index, "card_instance_id": card.instance_id, "card": String(card.card_id())})


func summon(card: CardInstance) -> CreatureInstance:
	var creature := CreatureInstance.create(card.instance_id, card, state.turn_number)
	state.players[card.owner].board.append(creature)
	emit(MatchEvent.CREATURE_ENTERED, {"creature_id": creature.instance_id, "card": String(card.card_id()),
		"owner": card.owner})
	recalculate_statics()
	return creature


## A new creature instance from the base definition with [param health] current
## health; nothing of the dead instance is kept.
func return_to_board(card: CardInstance, health: int) -> CreatureInstance:
	var player := state.players[card.owner]
	player.graveyard.erase(card)
	var creature := CreatureInstance.create(state.take_id(), card, state.turn_number)
	creature.health = mini(health, creature.max_health)
	player.board.append(creature)
	emit(MatchEvent.CREATURE_RETURNED, {"creature_id": creature.instance_id, "card": String(card.card_id()),
		"owner": card.owner, "health": creature.health})
	recalculate_statics()
	return creature


func destroy(creature: CreatureInstance) -> void:
	if creature.is_dead():
		return
	creature.destroyed = true
	emit(MatchEvent.CREATURE_DESTROYED, {"creature_id": creature.instance_id})


## The previous artifact leaves (not a death): its remaining charges are lost.
func play_artifact(card: CardInstance) -> void:
	var player := state.players[card.owner]
	if player.active_artifact != null:
		var old := player.active_artifact
		player.graveyard.append(old.card)
		emit(MatchEvent.ARTIFACT_REPLACED, {"player": card.owner, "old_id": old.instance_id,
			"old_card": String(old.card.card_id()), "lost_charges": old.charges, "new_id": card.instance_id})
	player.active_artifact = ArtifactInstance.create(card)
	emit(MatchEvent.ARTIFACT_PLAYED, {"player": card.owner, "artifact_id": card.instance_id,
		"card": String(card.card_id()), "charges": player.active_artifact.charges})
	recalculate_statics()


func spend_charges(artifact: ArtifactInstance, amount: int) -> void:
	var spent := mini(amount, artifact.charges)
	artifact.charges -= spent
	emit(MatchEvent.CHARGES_SPENT, {"artifact_id": artifact.instance_id, "spent": spent, "charges": artifact.charges})


## Removes an artifact without charges (after its current ability resolved).
func expire_artifact_if_empty(artifact: ArtifactInstance) -> void:
	var player := state.players[artifact.owner]
	if player.active_artifact != artifact or artifact.charges > 0:
		return
	player.active_artifact = null
	player.graveyard.append(artifact.card)
	emit(MatchEvent.ARTIFACT_EXPIRED, {"player": artifact.owner, "artifact_id": artifact.instance_id,
		"card": String(artifact.card.card_id())})
	recalculate_statics()


# --- Resources and stats -----------------------------------------------------------

## Gains are capped at GameRules.MAX_SOUL_SHARDS; the excess is lost.
func gain_soul_shards(player_index: int, amount: int) -> void:
	var player := state.players[player_index]
	var before := player.soul_shards
	player.soul_shards = mini(GameRules.MAX_SOUL_SHARDS, before + amount)
	emit(MatchEvent.SOUL_SHARDS_CHANGED, {"player": player_index, "before": before, "after": player.soul_shards,
		"lost": before + amount - player.soul_shards})


## Returns false (and changes nothing) when there are not enough shards.
func spend_soul_shards(player_index: int, amount: int) -> bool:
	var player := state.players[player_index]
	if amount > player.soul_shards:
		return false
	if amount > 0:
		player.soul_shards -= amount
		emit(MatchEvent.SOUL_SHARDS_CHANGED, {"player": player_index, "before": player.soul_shards + amount,
			"after": player.soul_shards, "lost": 0})
	return true


## Attack change. END_OF_TURN / END_OF_YOUR_NEXT_TURN are temporary; anything
## else («постоянный» or no stated duration) lasts while the creature is on the board.
func add_attack(creature: CreatureInstance, amount: int, duration: String, duration_owner: int) -> void:
	match duration:
		"END_OF_TURN":
			creature.temporary_attack.append({"amount": amount, "expires_turn": state.turn_number})
		"END_OF_YOUR_NEXT_TURN":
			creature.temporary_attack.append({"amount": amount, "expires_turn": next_own_turn_end(duration_owner)})
		_:
			creature.attack_bonus += amount
	emit(MatchEvent.STATS_CHANGED, {"creature_id": creature.instance_id, "attack": amount, "duration": duration})


## "+N health": raises max and current health.
func add_health(creature: CreatureInstance, amount: int) -> void:
	creature.max_health += amount
	creature.health += amount
	emit(MatchEvent.STATS_CHANGED, {"creature_id": creature.instance_id, "health": amount})


## "+N armor": raises max and current armor. With [param cap] >= 0 the total
## armor this creature ever gains from [param source_card] is limited (Temper Rite).
func add_armor(creature: CreatureInstance, amount: int, source_card: StringName = &"", cap: int = -1) -> void:
	var gain := amount
	if cap >= 0:
		gain = clampi(cap - int(creature.armor_gained_from.get(source_card, 0)), 0, amount)
	if source_card != &"":
		creature.armor_gained_from[source_card] = int(creature.armor_gained_from.get(source_card, 0)) + gain
	creature.max_armor += gain
	creature.armor += gain
	emit(MatchEvent.ARMOR_CHANGED, {"creature_id": creature.instance_id, "armor": creature.armor,
		"max_armor": creature.max_armor, "gained": gain})


## Restores current armor up to max armor; [param amount] < 0 restores all lost armor.
func restore_armor(creature: CreatureInstance, amount: int) -> void:
	var restored := creature.max_armor if amount < 0 else mini(creature.max_armor, creature.armor + amount)
	if restored == creature.armor:
		return
	creature.armor = restored
	emit(MatchEvent.ARMOR_CHANGED, {"creature_id": creature.instance_id, "armor": creature.armor,
		"max_armor": creature.max_armor, "restored": true})


## Number of the turn at whose end "until the end of your next turn" expires.
func next_own_turn_end(owner: int) -> int:
	return state.turn_number + (2 if state.active_player == owner else 1)
