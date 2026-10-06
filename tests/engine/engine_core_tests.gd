extends RefCounted
## MatchEngine core rules: setup, mulligan, energy, Impulse Shard, hand limit,
## Rift, board limit, combat, armor, deaths, outcome, rejected commands,
## determinism and safety limits.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")
const ScriptedRng := preload("res://tests/engine/scripted_rng.gd")
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL
const S := HeroCatalog.SYRRAVETH
const T := HeroCatalog.TAZHYRION

var _check: Callable
var _expect_errors: Callable
var _cards: Node
var f: MatchFixture


func _init(check: Callable, expect_errors: Callable, cards: Node) -> void:
	_check = check
	_expect_errors = expect_errors
	_cards = cards
	f = MatchFixture.new(cards)


func run() -> void:
	_test_setup()
	_test_mulligan()
	_test_energy_and_impulse()
	_test_hand_limit()
	_test_rift()
	_test_board_limit()
	_test_combat()
	_test_deaths()
	_test_outcome()
	_test_artifacts()
	_test_mandatory_play_targets()
	_test_cost_modifier_ordering()
	_test_snapshot_is_a_copy()
	_test_rejected_commands_do_not_mutate()
	_test_engine_safety()
	_test_rng_isolation()


func _ok(condition: bool, description: String) -> void:
	_check.call(condition, description)


# --- Setup ---------------------------------------------------------------------

func _test_setup() -> void:
	var engine := f.setup(K, T, DeterministicRng.new(7))
	var state := engine.state
	var first := state.first_player
	var second := state.opponent_of(first)
	_ok(state.phase == MatchState.Phase.MULLIGAN, "setup: valid 30-card decks start the mulligan phase")
	_ok(state.players[first].hand.size() == 3 and state.players[second].hand.size() == 4,
		"setup: starting hands 3 (first) and 4 (second)")
	_ok(state.players[first].deck.size() == 27 and state.players[second].deck.size() == 26, "setup: decks 27 / 26 after the deal")
	_ok(state.players[second].impulse_shard_available and not state.players[first].impulse_shard_available,
		"setup: only the second player has the Impulse Shard")
	_ok(state.players[0].hero_health == 30 and state.players[1].hero_health == 30
		and state.players[0].soul_shards == 0, "setup: heroes 30 health, 0 Soul Shards")

	var again := MatchFixture.new(_cards).setup(K, T, DeterministicRng.new(7))
	_ok(JSON.stringify(again.snapshot()) == JSON.stringify(engine.snapshot()),
		"setup: the same seed gives the same first player, deck order and hands")
	_ok(MatchFixture.new(_cards).setup(K, T, ScriptedRng.new([1])).state.first_player == 1,
		"setup: the RNG decides the first player")
	var firsts := [0, 0]
	for seed in 200:
		firsts[MatchFixture.new(_cards).setup(K, T, DeterministicRng.new(seed)).state.first_player] += 1
	_ok(firsts[0] > 70 and firsts[1] > 70, "setup: first player is 50/50 over 200 seeds %s" % [firsts])

	var invalid := {
		"29 cards": [f.deck_for(K).slice(0, 29), K],
		"31 cards": [f.deck_for(K) + ["neutral_vantrel_duskling"], K],
		"wrong faction": [_replace_first(f.deck_for(K), "dumoryss_thoughtscar"), K],
		"3 copies of a common card": [_replace_first(_replace_first(f.deck_for(K), "ashravael_bloodsworn"),
			"ashravael_bloodsworn", 1), K],
		"2 copies of a legendary card": [_replace_first(f.deck_for(K), "ashravael_warfiend"), K],
		"unknown card": [_replace_first(f.deck_for(K), "test_unknown"), K],
		"deck faction not matching the hero": [f.deck_for(K), V],
	}
	for label: String in invalid:
		var bad := MatchEngine.new(_cards, DeterministicRng.new(1))
		var deck: Array = invalid[label][0]
		var result := bad.setup([{"hero": invalid[label][1], "deck": deck}, {"hero": T, "deck": f.deck_for(T)}])
		_ok(not result.ok and result.error == ActionResult.INVALID_SETUP and bad.state.phase == MatchState.Phase.SETUP
			and bad.state.players.is_empty(), "setup: rejects %s (%s)" % [label, result.message])


func _replace_first(deck: Array[String], card_id: String, skip: int = 0) -> Array[String]:
	var copy := deck.duplicate()
	copy[skip] = card_id
	return copy


# --- Mulligan --------------------------------------------------------------------

func _test_mulligan() -> void:
	var engine := f.setup(K, T, DeterministicRng.new(11))
	var state := engine.state
	var first := state.first_player
	var second := state.opponent_of(first)
	var first_hand := _ids(state.players[first].hand)
	var first_deck := _ids(state.players[first].deck)
	var second_hand := _ids(state.players[second].hand)
	var second_deck := _ids(state.players[second].deck)

	_ok(engine.end_turn(first).error == ActionResult.WRONG_PHASE, "mulligan: turn commands are rejected before it ends")
	_ok(engine.submit_mulligan(first, [99999]).error == ActionResult.INVALID_CHOICE, "mulligan: a card not in hand is rejected")
	_ok(engine.submit_mulligan(first, []).ok and state.phase == MatchState.Phase.MULLIGAN,
		"mulligan: the match waits for both players")
	_ok(engine.submit_mulligan(first, []).error == ActionResult.ALREADY_USED, "mulligan: only one mulligan per player")
	var replaced: Array[int] = [second_hand[1]]
	_ok(engine.submit_mulligan(second, replaced).ok and state.phase == MatchState.Phase.TURN,
		"mulligan: after both decisions the first turn starts")
	_ok(_ids(state.players[first].hand).slice(0, 3) == first_hand
		and _ids(state.players[first].deck) == first_deck.slice(1),
		"mulligan: keeping the hand changes nothing (no shuffle)")
	var new_second_hand := _ids(state.players[second].hand)
	_ok(new_second_hand.size() == 4 and second_hand[1] not in new_second_hand
		and new_second_hand[3] == second_deck[0], "mulligan: one card replaced by the top card of the deck")
	_ok(second_hand[1] in _ids(state.players[second].deck) and state.players[second].deck.size() == 26,
		"mulligan: the replaced card went back into the deck")
	_ok(state.players[second].impulse_shard_available, "mulligan: the Impulse Shard is not used by the mulligan")

	engine = f.setup(K, T, DeterministicRng.new(12))
	state = engine.state
	first = state.first_player
	var hand_before := _ids(state.players[first].hand)
	var deck_before := _ids(state.players[first].deck)
	engine.submit_mulligan(first, hand_before.duplicate())
	engine.submit_mulligan(state.opponent_of(first), [])
	var hand_after := _ids(state.players[first].hand).slice(0, 3)
	_ok(hand_after == deck_before.slice(0, 3), "mulligan: the whole hand is redrawn from the cards above the deck")
	_ok(hand_before.all(func(id: int) -> bool: return id not in hand_after),
		"mulligan: replaced cards cannot come back in the same redraw")
	var unshuffled := deck_before.slice(3) + hand_before
	var deck_now := _ids(state.players[first].deck)
	deck_now.push_front(_ids(state.players[first].hand)[3])
	var deck_now_sorted := deck_now.duplicate()
	deck_now_sorted.sort()
	var expected_sorted := unshuffled.duplicate()
	expected_sorted.sort()
	_ok(deck_now_sorted == expected_sorted and deck_now != unshuffled,
		"mulligan: replaced cards are returned after the redraw and the deck is shuffled")
	_ok(engine.submit_mulligan(first, []).error == ActionResult.WRONG_PHASE, "mulligan: rejected once the match is running")


func _ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card in cards:
		ids.append(card.instance_id)
	return ids


# --- Energy, Impulse Shard ---------------------------------------------------------

func _test_energy_and_impulse() -> void:
	var engine := f.start(K, T, ScriptedRng.new([0]))
	var p0 := f.player(0)
	var p1 := f.player(1)
	_ok(engine.state.active_player == 0 and p0.energy_max == 1 and p0.energy_current == 1,
		"energy: the first turn starts with 1 energy")
	_ok(engine.use_impulse_shard(0).error == ActionResult.NOT_AVAILABLE, "impulse: the first player has none")
	engine.end_turn(0)
	_ok(p1.energy_max == 1 and p1.energy_current == 1, "energy: the second player's first turn also starts with 1")
	_ok(engine.use_impulse_shard(0).error == ActionResult.NOT_YOUR_TURN, "impulse: not usable in the opponent's turn")
	_ok(engine.use_impulse_shard(1).ok and p1.energy_current == 2 and p1.energy_max == 1,
		"impulse: +1 temporary energy, max energy unchanged")
	_ok(engine.use_impulse_shard(1).error == ActionResult.NOT_AVAILABLE, "impulse: usable once per match")
	engine.end_turn(1)
	_ok(p1.energy_current == 0, "energy: unused energy (incl. the Impulse Shard's) is lost at the end of the turn")
	_ok(p0.energy_max == 2 and p0.energy_current == 2, "energy: +1 max energy on the next own turn and full refill")
	p0.energy_current = 0
	engine.end_turn(0)
	engine.end_turn(1)
	_ok(p0.energy_max == 3 and p0.energy_current == 3, "energy: refilled to max at the start of the own turn")
	for _turn in 20:
		engine.end_turn(engine.state.active_player)
	_ok(p0.energy_max == 10 and p1.energy_max == 10, "energy: max energy is capped at 10")

	engine = f.start(K, T, ScriptedRng.new([0]))
	engine.end_turn(0)
	f.player(1).energy_max = 10
	f.player(1).energy_current = 10
	_ok(engine.use_impulse_shard(1).ok and f.player(1).energy_current == 11 and f.player(1).energy_max == 10,
		"impulse: at 10 max energy it gives a temporary 11th point")


# --- Hand, Rift, board ---------------------------------------------------------------

func _test_hand_limit() -> void:
	var engine := f.scenario()
	for _index in 10:
		f.hand(0, &"neutral_rivenshade_grazer")
	var top := f.deck_top(0, ["nerqathen_gravewisp"])
	engine.end_turn(0)
	engine.end_turn(1)
	var p0 := f.player(0)
	_ok(p0.hand.size() == 10 and p0.burned.size() == 1 and p0.burned[0].instance_id == top[0],
		"hand: drawing with 10 cards in hand burns the card")
	_ok(f.events_of(MatchEvent.CARD_BURNED).size() == 1 and p0.soul_shards == 0 and p0.graveyard.is_empty(),
		"hand: a burned card is not played, discarded or killed (no Last Breath)")


func _test_rift() -> void:
	var engine := f.scenario(K, T, 0)
	var p1 := f.player(1)
	engine.end_turn(0)
	_ok(p1.hero_health == 29 and p1.rift_damage_next == 2 and p1.hero_damaged_this_turn,
		"rift: the first draw from an empty deck deals 1 (counts as hero damage)")
	engine.end_turn(1)
	engine.end_turn(0)
	_ok(p1.hero_health == 27, "rift: the second deals 2")
	engine.end_turn(1)
	engine.end_turn(0)
	_ok(p1.hero_health == 24 and p1.rift_damage_next == 4, "rift: then 3 (it never resets)")
	p1.hero_health = 4
	engine.end_turn(1)
	engine.end_turn(0)
	_ok(engine.is_over() and engine.get_winner() == 0 and p1.hero_health == 0, "rift: can kill the hero and end the match")


func _test_board_limit() -> void:
	var engine := f.scenario()
	for _index in 7:
		f.board(0, &"neutral_vantrel_duskling")
	var card := f.hand(0, &"neutral_mireglass_wanderer")
	var before := JSON.stringify(engine.snapshot())
	var result := engine.play_card(0, card)
	_ok(result.error == ActionResult.BOARD_FULL and JSON.stringify(engine.snapshot()) == before,
		"board: the 8th creature is rejected without changes")


# --- Combat, armor -------------------------------------------------------------------

func _test_combat() -> void:
	var engine := f.scenario()
	var attacker := f.board(0, &"ashravael_cinderclaw")
	var defender := f.board(1, &"neutral_vantrel_duskling")
	engine.attack(0, attacker, defender)
	var died := f.events_of(MatchEvent.CREATURE_DIED)
	_ok(died.size() == 2 and f.creature(attacker) == null and f.creature(defender) == null,
		"combat: 3/2 attacks 2/3 - simultaneous damage, both die")
	_ok(f.player(0).soul_shards == 0 and f.events_of(MatchEvent.TRIGGER_RESOLVED).is_empty(),
		"combat: Frenzy does not fire when the damage killed the creature")

	engine = f.scenario()
	var striker := f.board(0, &"neutral_rivenshade_grazer")
	var hero_target := f.hero_id(1)
	engine.attack(0, striker, hero_target)
	_ok(f.player(1).hero_health == 25 and f.creature(striker).health == 6, "combat: creature hits hero, no damage back")
	_ok(engine.attack(0, striker, hero_target).error == ActionResult.CANNOT_ATTACK, "combat: one attack per turn")
	var own := f.board(0, &"neutral_vantrel_duskling")
	_ok(engine.attack(0, own, f.hero_id(0)).error == ActionResult.INVALID_TARGET
		and engine.attack(0, own, striker).error == ActionResult.INVALID_TARGET, "combat: own hero and creatures are not targets")

	engine = f.scenario()
	var warden := f.board(1, &"khevaruun_ironwarden")
	var grazer := f.board(0, &"neutral_rivenshade_grazer")
	engine.attack(0, grazer, warden)
	var warden_state := f.creature(warden)
	_ok(warden_state.armor == 0 and warden_state.health == 1 and warden_state.max_armor == 2,
		"armor: 2 armor + 4 health takes 5 -> armor 0, health 1")

	engine = f.scenario()
	var fresh := f.hand(0, &"neutral_vantrel_duskling")
	engine.play_card(0, fresh)
	_ok(engine.attack(0, fresh, f.hero_id(1)).error == ActionResult.CANNOT_ATTACK,
		"combat: a creature cannot attack in the turn it entered")
	f.pass_to(0)
	_ok(engine.attack(0, fresh, f.hero_id(1)).ok, "combat: it attacks normally in the next own turn")


func _test_deaths() -> void:
	var engine := f.scenario(V, V)
	var mine := f.board(0, &"nerqathen_gravewisp")
	var theirs := f.board(1, &"nerqathen_gravewisp")
	f.creature(mine).health = 1
	f.creature(theirs).health = 1
	engine.attack(0, mine, theirs)
	var died := f.events_of(MatchEvent.CREATURE_DIED)
	var shards := f.events_of(MatchEvent.SOUL_SHARDS_CHANGED)
	_ok(died.size() == 2 and int(died[0]["creature_id"]) == mine and int(died[1]["creature_id"]) == theirs,
		"deaths: simultaneous deaths are processed active player first")
	_ok(shards.size() == 2 and int(shards[0]["player"]) == 0 and int(shards[1]["player"]) == 1,
		"deaths: Last Breath triggers resolve in the same order")
	_ok(f.player(0).graveyard.size() == 1 and f.player(1).graveyard.size() == 1,
		"deaths: each dead creature reaches the graveyard exactly once")


# --- Outcome ----------------------------------------------------------------------

func _test_outcome() -> void:
	var engine := f.scenario()
	f.player(1).hero_health = 5
	var grazer := f.board(0, &"neutral_rivenshade_grazer")
	engine.attack(0, grazer, f.hero_id(1))
	_ok(engine.is_over() and engine.get_winner() == 0 and not engine.is_draw()
		and f.events_of(MatchEvent.MATCH_ENDED).size() == 1, "outcome: hero at 0 health - the other player wins")
	var before := JSON.stringify(engine.snapshot())
	_ok(engine.end_turn(0).error == ActionResult.MATCH_ENDED and engine.use_hero_power(0).error == ActionResult.MATCH_ENDED
		and JSON.stringify(engine.snapshot()) == before and engine.get_winner() == 0,
		"outcome: commands after the end are rejected; the result never changes")

	engine = f.scenario()
	f.player(0).hero_health = 1
	var ally := f.board(0, &"neutral_vantrel_duskling")
	engine.use_hero_power(0, ally)
	_ok(engine.is_over() and engine.get_winner() == 1, "outcome: a player can lose by own damage")

	engine = f.scenario()
	f.player(0).hero_health = 2
	f.player(1).hero_health = 2
	engine._resolver.damage_hero(0, 3, {"kind": "TEST"})
	engine._resolver.damage_hero(1, 3, {"kind": "TEST"})
	engine._resolver.step()
	_ok(engine.is_over() and engine.is_draw() and engine.get_winner() == -1,
		"outcome: both heroes at 0 after one atomic step - draw (engine-level check)")


# --- Artifacts, snapshot --------------------------------------------------------------

func _test_artifacts() -> void:
	var engine := f.scenario(K, T)
	var bearer := f.board(0, &"neutral_kelvarn_relicbearer")
	var sigil := f.hand(0, &"ashravael_furnace_sigil")
	var core := f.hand(0, &"khevaruun_bastion_core")
	engine.play_card(0, sigil)
	f.player(0).active_artifact.charges = 2
	engine.play_card(0, core)
	var replaced := f.events_of(MatchEvent.ARTIFACT_REPLACED)
	var p0 := f.player(0)
	_ok(p0.active_artifact.card.card_id() == &"khevaruun_bastion_core" and p0.active_artifact.charges == 3
		and p0.energy_current == 10 - 4 - 4, "artifacts: a new artifact is paid for and replaces the active one")
	_ok(replaced.size() == 1 and int(replaced[0]["lost_charges"]) == 2 and p0.graveyard.size() == 1
		and p0.graveyard[0].instance_id == sigil, "artifacts: the old one leaves with its remaining charges lost")
	_ok(f.events_of(MatchEvent.CREATURE_DIED).is_empty() and f.events_of(MatchEvent.TRIGGER_RESOLVED).is_empty()
		and f.creature(bearer).get_attack() == 4, "artifacts: a replacement is not a death and triggers nothing")


func _test_mandatory_play_targets() -> void:
	var engine := f.scenario(K, T)
	var enemy := f.board(1, &"neutral_vantrel_duskling")
	var gorebrand := f.hand(0, &"ashravael_gorebrand")
	_ok(engine.get_valid_play_targets(0, gorebrand) == [enemy],
		"targets: Gorebrand exposes its enemy creature as the mandatory target")
	_ok(engine.play_card(0, gorebrand, enemy).ok and f.player(0).hero_health == 29
		and f.creature(enemy).health == 1, "targets: Gorebrand plays normally with a valid enemy creature")

	engine = f.scenario(K, T)
	gorebrand = f.hand(0, &"ashravael_gorebrand")
	var before := JSON.stringify(engine.snapshot())
	var events_before := JSON.stringify(engine.get_events())
	var energy_before := f.player(0).energy_current
	var result := engine.play_card(0, gorebrand)
	_ok(not result.ok and result.error == ActionResult.TARGET_REQUIRED,
		"targets: Gorebrand is rejected when no enemy creature exists")
	_ok(JSON.stringify(engine.snapshot()) == before and JSON.stringify(engine.get_events()) == events_before,
		"targets: rejected Gorebrand preserves state, RNG and event log")
	_ok(f.player(0).find_in_hand(gorebrand) != null and f.player(0).energy_current == energy_before
		and f.player(0).hero_health == 30 and f.player(0).board.is_empty(),
		"targets: rejected Gorebrand stays in hand and changes no resources or board")
	_ok(engine.get_valid_play_targets(0, gorebrand).is_empty(),
		"targets: Gorebrand has no valid play targets when the enemy board is empty")
	var gorebrand_is_legal := engine.get_legal_commands(0).any(func(command: MatchCommand) -> bool:
		return command.kind == MatchCommand.Kind.PLAY_CARD and command.source_id == gorebrand)
	_ok(not gorebrand_is_legal, "targets: impossible Gorebrand PLAY_CARD is absent from legal commands")

	engine = f.scenario(T, K)
	var ally := f.board(0, &"neutral_vantrel_duskling")
	var platecaller := f.hand(0, &"khevaruun_platecaller")
	_ok(engine.get_valid_play_targets(0, platecaller) == [ally],
		"targets: Platecaller exposes only another allied creature")
	_ok(engine.play_card(0, platecaller).error == ActionResult.TARGET_REQUIRED,
		"targets: Platecaller requires the other ally to be selected")
	_ok(engine.play_card(0, platecaller, platecaller).error == ActionResult.INVALID_TARGET,
		"targets: Platecaller cannot target its own hand instance")
	_ok(engine.play_card(0, platecaller, ally).ok and f.creature(ally).armor == 1
		and f.creature(platecaller) != null, "targets: Platecaller plays with a valid other ally")

	engine = f.scenario(T, K)
	platecaller = f.hand(0, &"khevaruun_platecaller")
	before = JSON.stringify(engine.snapshot())
	events_before = JSON.stringify(engine.get_events())
	energy_before = f.player(0).energy_current
	result = engine.play_card(0, platecaller)
	_ok(not result.ok and result.error == ActionResult.TARGET_REQUIRED,
		"targets: Platecaller is rejected when no other ally exists")
	_ok(JSON.stringify(engine.snapshot()) == before and JSON.stringify(engine.get_events()) == events_before
		and f.player(0).find_in_hand(platecaller) != null and f.player(0).energy_current == energy_before
		and f.player(0).board.is_empty(), "targets: rejected Platecaller preserves state, RNG, hand and board")
	_ok(engine.get_valid_play_targets(0, platecaller).is_empty(),
		"targets: Platecaller has no valid targets without another ally")
	var platecaller_is_legal := engine.get_legal_commands(0).any(func(command: MatchCommand) -> bool:
		return command.kind == MatchCommand.Kind.PLAY_CARD and command.source_id == platecaller)
	_ok(not platecaller_is_legal, "targets: impossible Platecaller PLAY_CARD is absent from legal commands")

	for targeted_creature: StringName in [&"ashravael_gorebrand", &"dumoryss_rift_scribe", &"khevaruun_platecaller"]:
		engine = f.scenario(K, T)
		var card_id := f.hand(0, targeted_creature)
		var rejected := engine.play_card(0, card_id)
		_ok(not rejected.ok and rejected.error == ActionResult.TARGET_REQUIRED
			and f.player(0).find_in_hand(card_id) != null and f.player(0).board.is_empty(),
			"targets: mandatory CHOSEN_* creature bypass absent for %s" % targeted_creature)


func _append_cost_modifier(source: String, amount: int, only_cost_at_most: int = -1, cost_cap: int = -1) -> int:
	var modifier := {"seq": f.engine.state.take_sequence(), "source": source, "source_owner": 1, "amount": amount}
	if only_cost_at_most >= 0:
		modifier["only_cost_at_most"] = only_cost_at_most
	if cost_cap >= 0:
		modifier["cost_cap"] = cost_cap
	f.player(0).incoming_cost_modifiers.append(modifier)
	return int(modifier["seq"])


func _test_cost_modifier_ordering() -> void:
	var engine := f.scenario(K, T)
	_append_cost_modifier("dumoryss_thoughtscar", 1, 3)
	_append_cost_modifier("dumoryss_thoughtscar", 1, 3)
	var card := f.hand(0, &"neutral_vantrel_duskling")
	_ok(engine.get_card_cost(0, card) == 4, "cost: two Thoughtscar modifiers stack on cost 2 (2 -> 3 -> 4)")
	_ok(engine.play_card(0, card).ok and f.player(0).incoming_cost_modifiers.is_empty(),
		"cost: both Thoughtscar modifiers are consumed when both conditions pass")

	engine = f.scenario(K, T)
	_append_cost_modifier("dumoryss_thoughtscar", 1, 3)
	var second_thoughtscar := _append_cost_modifier("dumoryss_thoughtscar", 1, 3)
	card = f.hand(0, &"neutral_threnic_cartographer")
	_ok(engine.get_card_cost(0, card) == 4, "cost: Thoughtscar uses the running cost (3 -> 4, then second skips)")
	_ok(engine.play_card(0, card).ok and f.player(0).incoming_cost_modifiers.size() == 1
		and int(f.player(0).incoming_cost_modifiers[0]["seq"]) == second_thoughtscar,
		"cost: skipped second Thoughtscar remains pending")

	engine = f.scenario(K, T)
	_append_cost_modifier(CostCalculator.DISTORTION, 1, 3)
	var second_distortion := _append_cost_modifier(CostCalculator.DISTORTION, 1, 3)
	card = f.hand(0, &"neutral_vantrel_duskling")
	_ok(engine.get_card_cost(0, card) == 3, "cost: at most one Distortion applies to a played card")
	_ok(engine.play_card(0, card).ok and f.player(0).incoming_cost_modifiers.size() == 1
		and int(f.player(0).incoming_cost_modifiers[0]["seq"]) == second_distortion,
		"cost: additional Distortion remains pending for a later card")

	engine = f.scenario(K, T)
	_append_cost_modifier("dumoryss_thoughtscar", 1, 3)
	_append_cost_modifier(CostCalculator.DISTORTION, 1, 3)
	card = f.hand(0, &"neutral_threnic_cartographer")
	_ok(engine.get_card_cost(0, card) == 4, "cost: Thoughtscar created before Distortion is evaluated first")
	_ok(engine.play_card(0, card).ok and f.player(0).incoming_cost_modifiers.size() == 1
		and f.player(0).incoming_cost_modifiers[0]["source"] == CostCalculator.DISTORTION,
		"cost: FIFO leaves the newer Distortion pending after Thoughtscar raises 3 to 4")

	engine = f.scenario(K, T)
	_append_cost_modifier(CostCalculator.DISTORTION, 1, 3)
	_append_cost_modifier("dumoryss_thoughtscar", 1, 3)
	card = f.hand(0, &"neutral_threnic_cartographer")
	_ok(engine.get_card_cost(0, card) == 4, "cost: Distortion created before Thoughtscar is evaluated first")
	_ok(engine.play_card(0, card).ok and f.player(0).incoming_cost_modifiers.size() == 1
		and f.player(0).incoming_cost_modifiers[0]["source"] == "dumoryss_thoughtscar",
		"cost: FIFO leaves the newer Thoughtscar pending after Distortion raises 3 to 4")

	engine = f.scenario(K, T)
	var skipped_seq := _append_cost_modifier("dumoryss_thoughtscar", 1, 3)
	card = f.hand(0, &"neutral_sablequill_nomad")
	_ok(engine.get_card_cost(0, card) == 4, "cost: an ineligible expensive card is not modified")
	_ok(engine.play_card(0, card).ok and f.player(0).incoming_cost_modifiers.size() == 1
		and int(f.player(0).incoming_cost_modifiers[0]["seq"]) == skipped_seq,
		"cost: an ineligible card does not consume the pending modifier")

	engine = f.scenario(K, T)
	_append_cost_modifier("dumoryss_thoughtscar", 1, 3)
	_append_cost_modifier("dumoryss_veil_tax", 2, -1, 10)
	card = f.hand(0, &"neutral_threnic_cartographer")
	_ok(engine.get_card_cost(0, card) == 6, "cost: Thoughtscar then Veil Tax apply sequentially in FIFO order")
	_ok(engine.play_card(0, card).ok and f.player(0).incoming_cost_modifiers.is_empty(),
		"cost: compatible FIFO modifiers are consumed after the card is actually played")

	engine = f.scenario(K, T)
	_append_cost_modifier("dumoryss_veil_tax", 2, -1, 10)
	_append_cost_modifier("dumoryss_veil_tax", 2, -1, 10)
	card = f.hand(0, &"ashravael_warfiend")
	_ok(engine.get_card_cost(0, card) == 10, "cost: Veil Tax keeps its own cap 10 across FIFO modifiers")
	_ok(engine.play_card(0, card).ok and f.player(0).incoming_cost_modifiers.is_empty(),
		"cost: Veil Tax cap does not create a separate global consumption rule")


func _test_snapshot_is_a_copy() -> void:
	var engine := f.scenario(K, T)
	engine.play_card(0, f.hand(0, &"neutral_vantrel_duskling"))
	var snapshot := engine.snapshot()
	var text := JSON.stringify(snapshot)
	snapshot["players"][0]["hero_health"] = 1
	snapshot["players"][0]["board"][0]["health"] = 99
	(snapshot["players"][0]["deck"] as Array).clear()
	var events := engine.get_events()
	events.clear()
	_ok(JSON.stringify(engine.snapshot()) == text and f.player(0).hero_health == 30 and engine.state.events.size() > 0
		and f.player(0).board[0].health == 3 and f.player(0).deck.size() == 20,
		"snapshot: changing a snapshot or the event copies never changes the match")


# --- Rejected commands -------------------------------------------------------------

func _test_rejected_commands_do_not_mutate() -> void:
	var engine := f.scenario()
	var provoker := f.board(1, &"khevaruun_ironwarden")
	var other := f.board(1, &"neutral_vantrel_duskling")
	var attacker := f.board(0, &"neutral_rivenshade_grazer")
	var expensive := f.hand(0, &"ashravael_warfiend")
	var spell := f.hand(0, &"ashravael_cinder_oath")
	var oath_target := f.board(0, &"neutral_mireglass_wanderer")
	f.player(0).energy_current = 2
	engine.use_hero_power(0, oath_target)
	f.player(0).energy_current = 5
	var cases := [
		["wrong player", MatchCommand.end_turn(1), ActionResult.NOT_YOUR_TURN],
		["mulligan during a turn", MatchCommand.mulligan(0, []), ActionResult.WRONG_PHASE],
		["not enough energy", MatchCommand.play_card(0, expensive), ActionResult.NOT_ENOUGH_ENERGY],
		["unknown hand card", MatchCommand.play_card(0, 99999), ActionResult.UNKNOWN_CARD],
		["missing spell target", MatchCommand.play_card(0, spell), ActionResult.TARGET_REQUIRED],
		["spell target of the wrong side", MatchCommand.play_card(0, spell, provoker), ActionResult.INVALID_TARGET],
		["hero ability twice", MatchCommand.use_hero_power(0, oath_target), ActionResult.ALREADY_USED],
		["Impulse Shard of the first player", MatchCommand.use_impulse_shard(0), ActionResult.NOT_AVAILABLE],
		["attack ignoring «Провокация»", MatchCommand.attack(0, attacker, other), ActionResult.INVALID_TARGET],
		["attack hero past «Провокация»", MatchCommand.attack(0, attacker, f.hero_id(1)), ActionResult.INVALID_TARGET],
		["attack with an enemy creature", MatchCommand.attack(0, provoker, attacker), ActionResult.CANNOT_ATTACK],
		["choice without a pending choice", MatchCommand.choose(0, 1), ActionResult.WRONG_PHASE],
	]
	for test_case: Array in cases:
		var before := JSON.stringify(engine.snapshot())
		var events_before := engine.state.events.size()
		var result := engine.execute(test_case[1])
		_ok(not result.ok and result.error == test_case[2] and JSON.stringify(engine.snapshot()) == before
			and engine.state.events.size() == events_before,
			"rejected without changes: %s (%s)" % [test_case[0], result.error])
	var preview := engine.validate(MatchCommand.attack(0, attacker, provoker))
	_ok(preview.ok and f.creature(provoker).health == 4, "validate() checks a legal command without applying it")


func _test_engine_safety() -> void:
	var engine := f.scenario()
	var attacker := f.board(0, &"neutral_rivenshade_grazer")
	f.board(1, &"ashravael_cinderclaw")
	engine._resolver.max_resolutions = 0
	var before := JSON.stringify(engine.snapshot())
	_expect_errors.call(true)
	var result := engine.attack(0, attacker, f.player(1).board[0].instance_id)
	_expect_errors.call(false)
	_ok(result.error == ActionResult.ENGINE_ERROR and JSON.stringify(engine.snapshot()) == before,
		"safety: exceeding the resolution limit returns ENGINE_ERROR and rolls the command back")
	engine._resolver.max_resolutions = MatchResolver.MAX_RESOLUTIONS_PER_COMMAND
	_ok(engine.attack(0, attacker, f.player(1).board[0].instance_id).ok, "safety: the engine keeps working after a rollback")


## Match logic must not use global randomness (only MatchRng).
func _test_rng_isolation() -> void:
	var offenders := PackedStringArray()
	for directory in ["res://scripts/battle", "res://scripts/heroes", "res://scripts/decks"]:
		for file_name in DirAccess.get_files_at(directory):
			if file_name.get_extension() != "gd" or file_name == "deterministic_rng.gd":
				continue
			var lines := FileAccess.get_file_as_string(directory.path_join(file_name)).split("\n")
			var source := "\n".join(Array(lines).filter(func(line: String) -> bool: return not line.strip_edges().begins_with("#")))
			for forbidden in ["randi(", "randf(", "randomize(", "randi_range(", "randf_range(", "RandomNumberGenerator", "shuffle()"]:
				if source.contains(forbidden):
					offenders.append("%s: %s" % [file_name, forbidden])
	_ok(offenders.is_empty(), "determinism: no global randomness in the match code %s" % [offenders])
