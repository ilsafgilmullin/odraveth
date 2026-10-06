extends RefCounted
## Keywords and modifier rules (docs/PRODUCT_BASELINE.md section 6.7):
## Enter Battle, Last Breath, Onslaught, Provocation, Frenzy, Deferral, Echo,
## durations, static abilities and per-turn limits.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL
const S := HeroCatalog.SYRRAVETH
const T := HeroCatalog.TAZHYRION

var _check: Callable
var f: MatchFixture


func _init(check: Callable, _expect_errors: Callable, cards: Node) -> void:
	_check = check
	f = MatchFixture.new(cards)


func run() -> void:
	_test_enter_battle()
	_test_last_breath()
	_test_onslaught()
	_test_provoke()
	_test_frenzy()
	_test_deferral()
	_test_echo()
	_test_durations()
	_test_static_abilities()
	_test_per_turn_limits()
	_test_timing()


func _ok(condition: bool, description: String) -> void:
	_check.call(condition, description)


func _test_enter_battle() -> void:
	var engine := f.scenario(K, T)
	var gorebrand := f.hand(0, &"ashravael_gorebrand")
	var victim := f.board(1, &"neutral_vantrel_duskling")
	engine.play_card(0, gorebrand, victim)
	_ok(f.player(0).hero_health == 29 and f.creature(victim).health == 1, "Enter Battle: fires after playing from hand")

	engine = f.scenario(V, T)
	f.graveyard(0, &"ashravael_gorebrand")
	var burial := f.hand(0, &"nerqathen_second_burial")
	engine.play_card(0, burial)
	_ok(f.player(0).board.size() == 1 and f.player(0).hero_health == 30
		and f.events_of(MatchEvent.TRIGGER_RESOLVED).is_empty(), "Enter Battle: not triggered by RETURN_TO_BOARD")


func _test_last_breath() -> void:
	var engine := f.scenario(V, T)
	var wisp := f.board(0, &"nerqathen_gravewisp")
	var wall := f.board(1, &"neutral_rivenshade_grazer")
	engine.attack(0, wisp, wall)
	_ok(f.player(0).soul_shards == 1 and f.creature(wisp) == null, "Last Breath: resolves after death and removal")
	var died := f.events_of(MatchEvent.CREATURE_DIED)[0] as Dictionary
	var gained := f.events_of(MatchEvent.SOUL_SHARDS_CHANGED)[0] as Dictionary
	_ok(int(died["seq"]) < int(gained["seq"]), "Last Breath: after CREATURE_DIED in the event log")


func _test_onslaught() -> void:
	var engine := f.scenario(K, T)
	var fresh := f.hand(0, &"neutral_vantrel_duskling")
	var oath := f.hand(0, &"ashravael_cinder_oath")
	var enemy := f.board(1, &"neutral_rivenshade_grazer")
	engine.play_card(0, fresh)
	engine.play_card(0, oath, fresh)
	_ok(f.creature(fresh).has_keyword("ONSLAUGHT"), "Onslaught: granted until the end of the turn")
	_ok(engine.get_valid_attack_targets(0, fresh) == [enemy], "Onslaught: in the entry turn only enemy creatures")
	_ok(engine.attack(0, fresh, f.hero_id(1)).error == ActionResult.INVALID_TARGET,
		"Onslaught: the enemy hero cannot be attacked in the entry turn")

	engine = f.scenario(K, T)
	fresh = f.hand(0, &"neutral_rivenshade_grazer")
	oath = f.hand(0, &"ashravael_cinder_oath")
	enemy = f.board(1, &"neutral_vantrel_duskling")
	engine.play_card(0, fresh)
	engine.play_card(0, oath, fresh)
	_ok(engine.attack(0, fresh, enemy).ok and f.creature(enemy) == null, "Onslaught: attacks an enemy creature at once")
	f.pass_to(0)
	_ok(not f.creature(fresh).has_keyword("ONSLAUGHT") and engine.attack(0, fresh, f.hero_id(1)).ok,
		"Onslaught: from the next own turn the creature attacks normally")


func _test_provoke() -> void:
	var engine := f.scenario(K, T)
	var attacker := f.board(0, &"neutral_rivenshade_grazer")
	var plain := f.board(1, &"neutral_vantrel_duskling")
	var warden := f.board(1, &"khevaruun_ironwarden")
	_ok(engine.get_valid_attack_targets(0, attacker) == [warden], "Provocation: attacks may only target PROVOKE creatures")
	var gorebrand := f.hand(0, &"ashravael_gorebrand")
	_ok(engine.play_card(0, gorebrand, plain).ok and f.creature(plain).health == 1,
		"Provocation: abilities may target other creatures")
	engine.attack(0, attacker, warden)
	f.pass_to(0)
	f.creature(warden).health = 0
	f.refresh()
	engine._resolver.step()
	_ok(f.creature(warden) == null and f.hero_id(1) in engine.get_valid_attack_targets(0, attacker),
		"Provocation: without a living PROVOKE creature the hero is attackable again")


func _test_frenzy() -> void:
	var engine := f.scenario(K, T)
	var claw := f.board(0, &"ashravael_cinderclaw")
	var poker := f.board(1, &"nerqathen_gravewisp")
	engine.attack(0, claw, poker)
	_ok(f.creature(claw).get_attack() == 4 and f.creature(claw).health == 1,
		"Frenzy: surviving its own damage gives +1 attack")
	engine._resolver.damage_creature(f.creature(claw), 0, {})
	f.creature(claw).health = 2
	engine._resolver.damage_creature(f.creature(claw), 1, {"kind": "TEST"})
	engine._resolver.step()
	engine._resolver.drain()
	_ok(f.creature(claw).get_attack() == 4, "Frenzy: only the first time per turn")
	f.pass_to(0)
	f.creature(claw).health = 2
	engine._resolver.damage_creature(f.creature(claw), 1, {"kind": "TEST"})
	engine._resolver.step()
	engine._resolver.drain()
	_ok(f.creature(claw).get_attack() == 5, "Frenzy: again in a later turn; the bonus is permanent")


func _test_deferral() -> void:
	var engine := f.scenario(S, T)
	var target := f.board(1, &"neutral_rivenshade_grazer")
	var moment := f.hand(0, &"dumoryss_fractured_moment")
	var second := f.hand(0, &"dumoryss_fractured_moment")
	engine.play_card(0, moment, target)
	engine.play_card(0, second, target)
	engine.end_turn(0)
	_ok(engine.attack(1, target, f.hero_id(0)).error == ActionResult.CANNOT_ATTACK,
		"Deferral: cannot attack during the owner's next turn")
	engine.end_turn(1)
	_ok(f.creature(target).attack_blocked_turn == -1 and not f.creature(target).deferral_pending,
		"Deferral: the status is removed when the blocked owner turn ends")
	engine.end_turn(0)
	_ok(engine.attack(1, target, f.hero_id(0)).ok, "Deferral: removed after that turn; repeating it did not extend it")


func _test_echo() -> void:
	var engine := f.scenario(S, K)
	var leech := f.board(0, &"dumoryss_echo_leech")
	engine.end_turn(0)
	var tithe := f.hand(1, &"ashravael_blood_tithe")
	var second_spell := f.hand(1, &"ashravael_blood_tithe")
	engine.play_card(1, tithe)
	var echoes := f.player(0).hand.filter(func(card: CardInstance) -> bool: return card.is_echo)
	_ok(echoes.size() == 1 and echoes[0].card_id() == &"ashravael_blood_tithe" and echoes[0].base_cost == 2,
		"Echo: the first opponent spell creates an Echo (base spell cost, at least 1)")
	engine.play_card(1, second_spell)
	_ok(f.player(0).hand.filter(func(card: CardInstance) -> bool: return card.is_echo).size() == 1,
		"Echo: only the first opponent spell per turn")
	engine.end_turn(1)
	_ok(f.player(0).find_in_hand(echoes[0].instance_id) != null, "Echo: still in hand during the owner's next turn")
	engine.end_turn(0)
	_ok(f.player(0).find_in_hand(echoes[0].instance_id) == null and f.events_of(MatchEvent.ECHO_EXPIRED).size() == 1,
		"Echo: disappears at the end of the owner's next turn")

	engine = f.scenario(S, K)
	leech = f.board(0, &"dumoryss_echo_leech")
	engine.end_turn(0)
	engine.play_card(1, f.hand(1, &"ashravael_blood_tithe"))
	engine.end_turn(1)
	var echo := f.player(0).hand.filter(func(card: CardInstance) -> bool: return card.is_echo)[0] as CardInstance
	var health_before := f.player(0).hero_health
	_ok(engine.play_card(0, echo.instance_id).ok and f.player(0).hero_health == health_before - 2
		and f.player(0).find_in_hand(echo.instance_id) == null
		and f.player(0).graveyard.all(func(card: CardInstance) -> bool: return not card.is_echo),
		"Echo: played like the spell, then leaves the match (not the graveyard)")

	engine = f.scenario(S, K)
	f.board(0, &"dumoryss_echo_leech")
	engine.use_hero_power(0)
	engine.end_turn(0)
	engine.play_card(1, f.hand(1, &"ashravael_blood_tithe"))
	var copied := f.player(0).hand.filter(func(card: CardInstance) -> bool: return card.is_echo)[0] as CardInstance
	_ok(f.player(1).energy_current == 10 - 3 and copied.base_cost == 2,
		"Echo: copies the base spell, not the opponent's increased cost")

	engine = f.scenario(S, K)
	leech = f.board(0, &"dumoryss_echo_leech")
	for _index in 10:
		f.hand(0, &"neutral_vantrel_duskling")
	engine.end_turn(0)
	engine.play_card(1, f.hand(1, &"ashravael_blood_tithe"))
	_ok(f.player(0).burned.size() == 1 and f.player(0).burned[0].is_echo and f.creature(leech) != null,
		"Echo: with a full hand it burns")


func _test_durations() -> void:
	var engine := f.scenario(K, T)
	var ally := f.board(0, &"neutral_vantrel_duskling")
	engine.use_hero_power(0, ally)
	_ok(f.creature(ally).get_attack() == 4, "duration END_OF_TURN: active during the turn")
	engine.end_turn(0)
	_ok(f.creature(ally).get_attack() == 2, "duration END_OF_TURN: expired at the end of the turn")

	engine = f.scenario(V, T)
	var cantor := f.board(0, &"nerqathen_bone_cantor")
	var doomed := f.board(0, &"nerqathen_gravewisp")
	f.creature(doomed).health = 0
	engine._resolver.step()
	engine._resolver.drain()
	f.pass_to(0)
	f.pass_to(0)
	_ok(f.creature(cantor).get_attack() == 3, "duration permanent («постоянный»): lasts while on the board")


func _test_static_abilities() -> void:
	var engine := f.scenario(K, T)
	var bearer := f.board(0, &"neutral_kelvarn_relicbearer")
	_ok(f.creature(bearer).get_attack() == 3, "static: no active artifact, no bonus")
	f.artifact(0, &"ashravael_furnace_sigil")
	for _index in 5:
		f.refresh()
	_ok(f.creature(bearer).get_attack() == 4, "static: +1 attack while an artifact is active, never stacking")
	f.player(0).active_artifact = null
	f.refresh()
	_ok(f.creature(bearer).get_attack() == 3, "static: the bonus disappears with the condition")

	engine = f.scenario(K, T)
	var wayfarer := f.board(0, &"neutral_orryxian_wayfarer")
	for _index in 5:
		f.refresh()
	_ok(f.creature(wayfarer).armor == 1 and f.creature(wayfarer).max_armor == 1,
		"static: Orryxian Wayfarer alone has +1 armor, not stacking on recalculation")
	var friend := f.hand(0, &"neutral_mireglass_wanderer")
	engine.play_card(0, friend)
	_ok(f.creature(wayfarer).armor == 0 and f.creature(wayfarer).max_armor == 0, "static: removed when another creature arrives")


func _test_per_turn_limits() -> void:
	var engine := f.scenario(K, T)
	var ember := f.board(0, &"ashravael_emberbound")
	for _index in 3:
		engine._resolver.damage_hero(0, 1, {"kind": "TEST"})
		engine._resolver.step()
		engine._resolver.drain()
	_ok(f.creature(ember).get_attack() == 5, "limits.per_turn: Emberbound gains +1 at most twice per turn")


## WHEN abilities resolve inside the causing action, AFTER ones once it is done.
func _test_timing() -> void:
	var engine := f.scenario(K, T)
	f.artifact(0, &"ashravael_furnace_sigil")
	var ember := f.board(0, &"ashravael_emberbound")
	var tithe := f.hand(0, &"ashravael_blood_tithe")
	engine.play_card(0, tithe)
	var resolved := f.events_of(MatchEvent.TRIGGER_RESOLVED).map(func(event: Dictionary) -> String: return event["card"])
	var draws := f.events_of(MatchEvent.CARD_DRAWN)
	var furnace_seq := int(f.events_of(MatchEvent.TRIGGER_RESOLVED)[0]["seq"])
	var ember_seq := int(f.events_of(MatchEvent.TRIGGER_RESOLVED)[1]["seq"])
	_ok(resolved == ["ashravael_furnace_sigil", "ashravael_emberbound"], "timing: WHEN before AFTER")
	_ok(furnace_seq < int(draws[0]["seq"]) and ember_seq > int(draws[1]["seq"]),
		"timing: WHEN («когда») resolves before the spell continues, AFTER («после») once it finished")
	_ok(f.creature(ember) != null, "timing: Emberbound stayed on the board")
