extends RefCounted
## Behaviour of each of the 40 approved cards in MatchEngine. Every test names
## the cards it covers (_case); the run fails unless all 40 are covered.
## docs/CARD_TEST_COVERAGE.md lists card id -> test functions.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")
const ScriptedRng := preload("res://tests/engine/scripted_rng.gd")
const K := HeroCatalog.KEZHARYN
const V := HeroCatalog.VHORAZEL
const S := HeroCatalog.SYRRAVETH
const T := HeroCatalog.TAZHYRION
const TEMPER := &"khevaruun_temper_rite"

var _check: Callable
var _cards: Node
var f: MatchFixture
## Card id -> names of the tests covering it.
var coverage: Dictionary = {}
var _case_name := ""


func _init(check: Callable, _expect_errors: Callable, cards: Node) -> void:
	_check = check
	_cards = cards
	f = MatchFixture.new(cards)


func run() -> void:
	for method in get_method_list():
		var name: String = method["name"]
		if name.begins_with("test_"):
			_case_name = name
			call(name)
	_case_name = "coverage"
	var missing := PackedStringArray()
	for id in _cards.get_card_ids():
		if not coverage.has(StringName(id)):
			missing.append(id)
	_ok(missing.is_empty() and coverage.size() == 40, "every approved card has behavioural tests (%d/40) %s" % [
		coverage.size(), missing])
	var doc := FileAccess.get_file_as_string("res://docs/CARD_TEST_COVERAGE.md")
	var undocumented := PackedStringArray()
	for card_id: StringName in coverage:
		for test_name: String in coverage[card_id]:
			if not doc.contains("| `%s` |" % card_id) or not doc.contains(test_name):
				undocumented.append("%s -> %s" % [card_id, test_name])
	_ok(undocumented.is_empty(), "docs/CARD_TEST_COVERAGE.md lists every card test %s" % [undocumented])


func _ok(condition: bool, description: String) -> void:
	_check.call(condition, "%s: %s" % [_case_name.trim_prefix("test_"), description])


func _cover(card_ids: Array[StringName]) -> void:
	for card_id in card_ids:
		if not coverage.has(card_id):
			coverage[card_id] = []
		if _case_name not in coverage[card_id]:
			coverage[card_id].append(_case_name)


func _resolve() -> void:
	f.engine._resolver.step()
	f.engine._resolver.drain()


# --- ASHRAVAEL -------------------------------------------------------------------

func test_bloodsworn() -> void:
	_cover([&"ashravael_bloodsworn"])
	var engine := f.scenario(K, T)
	var plain := f.hand(0, &"ashravael_bloodsworn")
	engine.play_card(0, plain)
	_ok(f.creature(plain).get_attack() == 2, "no hero damage this turn -> base attack 2")
	var ally := f.board(0, &"neutral_vantrel_duskling")
	engine.use_hero_power(0, ally)
	var boosted := f.hand(0, &"ashravael_bloodsworn")
	engine.play_card(0, boosted)
	_ok(f.creature(boosted).get_attack() == 3, "hero damaged this turn -> +1 attack")
	f.pass_to(0)
	_ok(f.creature(boosted).get_attack() == 3, "the +1 has no stated duration: kept while on the board")


func test_cinderclaw() -> void:
	_cover([&"ashravael_cinderclaw"])
	var engine := f.scenario(K, T)
	var claw := f.board(0, &"ashravael_cinderclaw")
	var ally := f.board(0, &"neutral_vantrel_duskling")
	engine.use_hero_power(0, ally)
	_ok(f.creature(claw).get_attack() == 3, "damage to the hero or another creature does not count")
	var wisp := f.board(1, &"nerqathen_gravewisp")
	engine.attack(0, claw, wisp)
	_ok(f.creature(claw).get_attack() == 4, "surviving damage to itself -> +1 attack")
	var killer := f.board(1, &"neutral_rivenshade_grazer")
	engine.end_turn(0)
	engine.attack(1, killer, claw)
	var frenzies := f.events_of(MatchEvent.TRIGGER_RESOLVED).filter(
		func(event: Dictionary) -> bool: return event["card"] == "ashravael_cinderclaw")
	_ok(f.creature(claw) == null and frenzies.size() == 1, "damage that kills it gives nothing")


func test_emberbound() -> void:
	_cover([&"ashravael_emberbound"])
	var engine := f.scenario(K, T)
	var ember := f.board(0, &"ashravael_emberbound")
	engine.use_hero_power(0, ember)
	_ok(f.creature(ember).get_attack() == 6, "hero damage in own turn -> +1 (with +2 of the ability)")
	engine._resolver.damage_hero(0, 1, {"kind": "TEST"})
	_resolve()
	engine._resolver.damage_hero(0, 1, {"kind": "TEST"})
	_resolve()
	_ok(f.creature(ember).get_attack() == 7, "at most 2 times per turn")
	engine.end_turn(0)
	_ok(f.creature(ember).get_attack() == 3, "until the end of the turn")
	var attacker := f.board(1, &"neutral_vantrel_duskling")
	engine.attack(1, attacker, f.hero_id(0))
	_ok(f.creature(ember).get_attack() == 3, "hero damage in the opponent's turn gives nothing")


func test_gorebrand() -> void:
	_cover([&"ashravael_gorebrand"])
	var engine := f.scenario(K, T)
	var enemy := f.board(1, &"neutral_vantrel_duskling")
	var card := f.hand(0, &"ashravael_gorebrand")
	engine.play_card(0, card, enemy)
	var damage := f.events_of(MatchEvent.DAMAGE_DEALT)
	_ok(f.player(0).hero_health == 29 and f.creature(enemy).health == 1 and int(damage[0]["target_id"]) == f.hero_id(0),
		"hero takes 1, then the chosen enemy creature 2")

	engine = f.scenario(K, T)
	enemy = f.board(1, &"neutral_vantrel_duskling")
	card = f.hand(0, &"ashravael_gorebrand")
	f.player(0).hero_health = 1
	engine.play_card(0, card, enemy)
	_ok(engine.is_over() and engine.get_winner() == 1 and f.creature(enemy).health == 3,
		"if the self-damage ends the match, the enemy takes nothing")

	engine = f.scenario(K, T)
	card = f.hand(0, &"ashravael_gorebrand")
	_ok(engine.play_card(0, card).ok and f.player(0).hero_health == 29, "without enemy creatures it is still played")


func test_warfiend() -> void:
	_cover([&"ashravael_warfiend"])
	var engine := f.scenario(K, T)
	var enemy := f.board(1, &"neutral_vantrel_duskling")
	var calm := f.hand(0, &"ashravael_warfiend")
	f.player(0).hero_health = 16
	engine.play_card(0, calm)
	_ok(not f.creature(calm).has_keyword("ONSLAUGHT") and engine.attack(0, calm, enemy).error == ActionResult.CANNOT_ATTACK,
		"hero above 15 health: no Onslaught")
	f.player(0).hero_health = 15
	f.refresh()
	_ok(f.creature(calm).has_keyword("ONSLAUGHT") and engine.get_valid_attack_targets(0, calm) == [enemy],
		"hero at 15 or less: Onslaught (enemy creatures only in the entry turn)")

	engine = f.scenario(K, T)
	var fiend := f.board(0, &"ashravael_warfiend")
	var first := f.board(1, &"neutral_vantrel_duskling")
	var second := f.board(1, &"neutral_vantrel_duskling")
	engine.attack(0, fiend, first)
	_ok(engine.attack(0, fiend, second).error == ActionResult.CANNOT_ATTACK, "hero not damaged: one attack only")

	engine = f.scenario(K, T)
	fiend = f.board(0, &"ashravael_warfiend")
	first = f.board(1, &"neutral_vantrel_duskling")
	second = f.board(1, &"neutral_vantrel_duskling")
	var third := f.board(1, &"neutral_vantrel_duskling")
	engine.use_hero_power(0, fiend)
	engine.attack(0, fiend, first)
	_ok(engine.attack(0, fiend, second).ok, "hero damaged this turn: a second attack after the first")
	_ok(engine.attack(0, fiend, third).error == ActionResult.CANNOT_ATTACK, "at most 2 attacks per turn")


func test_blood_tithe() -> void:
	_cover([&"ashravael_blood_tithe"])
	var engine := f.scenario(K, T)
	var card := f.hand(0, &"ashravael_blood_tithe")
	engine.play_card(0, card)
	_ok(f.player(0).hero_health == 28 and f.player(0).hand.size() == 2, "hero takes 2, then draws 2")
	var damage_seq := int(f.events_of(MatchEvent.DAMAGE_DEALT)[0]["seq"])
	_ok(damage_seq < int(f.events_of(MatchEvent.CARD_DRAWN)[0]["seq"]), "damage before the draw")

	engine = f.scenario(K, T)
	card = f.hand(0, &"ashravael_blood_tithe")
	f.player(0).hero_health = 2
	engine.play_card(0, card)
	_ok(engine.is_over() and f.player(0).hand.is_empty() and f.events_of(MatchEvent.CARD_DRAWN).is_empty(),
		"if the hero dies there is no draw")


func test_cinder_oath() -> void:
	_cover([&"ashravael_cinder_oath"])
	var engine := f.scenario(K, T)
	var ally := f.board(0, &"neutral_vantrel_duskling")
	var card := f.hand(0, &"ashravael_cinder_oath")
	_ok(engine.play_card(0, card).error == ActionResult.TARGET_REQUIRED, "needs a friendly creature")
	engine.play_card(0, card, ally)
	_ok(f.creature(ally).get_attack() == 5 and f.creature(ally).has_keyword("ONSLAUGHT"), "+3 attack and Onslaught")
	engine.end_turn(0)
	_ok(f.creature(ally).health == 2 and f.creature(ally).get_attack() == 2 and not f.creature(ally).has_keyword("ONSLAUGHT"),
		"at the end of the turn it takes 1 damage; buffs expire")

	engine = f.scenario(K, T)
	ally = f.board(0, &"neutral_vantrel_duskling")
	card = f.hand(0, &"ashravael_cinder_oath")
	var wall := f.board(1, &"neutral_rivenshade_grazer")
	engine.play_card(0, card, ally)
	engine.attack(0, ally, wall)
	_ok(f.creature(ally) == null and engine.end_turn(0).ok and f.player(1).hero_health == 30,
		"if the creature died before the end of the turn, the delayed damage does nothing")


func test_furnace_sigil() -> void:
	_cover([&"ashravael_furnace_sigil"])
	var engine := f.scenario(K, T)
	var card := f.hand(0, &"ashravael_furnace_sigil")
	var first := f.board(0, &"neutral_vantrel_duskling")
	var second := f.board(0, &"neutral_mireglass_wanderer")
	engine.play_card(0, card)
	engine._resolver.rng = ScriptedRng.new([1])
	engine.use_hero_power(0, first)
	var sigil := f.player(0).active_artifact
	_ok(sigil.charges == 2 and f.creature(second).get_attack() == 2 and f.creature(second).max_health == 3
		and f.creature(first).max_health == 3, "first hero damage of the turn: -1 charge, random ally +1/+1")
	engine._resolver.damage_hero(0, 1, {"kind": "TEST"})
	_resolve()
	_ok(sigil.charges == 2, "only the first hero damage per turn")
	engine.end_turn(0)
	engine.attack(1, f.board(1, &"neutral_vantrel_duskling"), f.hero_id(0))
	_ok(sigil.charges == 1, "also in the opponent's turn")

	engine = f.scenario(K, T)
	f.artifact(0, &"ashravael_furnace_sigil")
	f.player(0).active_artifact.charges = 1
	engine._resolver.damage_hero(0, 1, {"kind": "TEST"})
	_resolve()
	_ok(f.player(0).active_artifact == null and f.events_of(MatchEvent.ARTIFACT_EXPIRED).size() == 1
		and f.events_of(MatchEvent.CHARGES_SPENT).size() == 1,
		"no friendly creature: the charge is still spent (action order), 0 charges -> removed")


# --- NERQATHEN -------------------------------------------------------------------

func test_gravewisp() -> void:
	_cover([&"nerqathen_gravewisp"])
	var engine := f.scenario(V, T)
	var wisp := f.board(0, &"nerqathen_gravewisp")
	engine.attack(0, wisp, f.board(1, &"neutral_rivenshade_grazer"))
	_ok(f.player(0).soul_shards == 1, "Last Breath: +1 Soul Shard")


func test_pale_binder() -> void:
	_cover([&"nerqathen_pale_binder"])
	var engine := f.scenario(V, T)
	var plain := f.hand(0, &"nerqathen_pale_binder")
	engine.play_card(0, plain)
	_ok(f.creature(plain).armor == 0, "no Soul Shard -> no armor")
	f.player(0).soul_shards = 1
	var armored := f.hand(0, &"nerqathen_pale_binder")
	engine.play_card(0, armored)
	_ok(f.creature(armored).armor == 1 and f.creature(armored).max_armor == 1 and f.player(0).soul_shards == 1,
		"with 1 Soul Shard: +1 armor, the shard is not spent")


func test_bone_cantor() -> void:
	_cover([&"nerqathen_bone_cantor"])
	f.scenario(V, T)
	var cantor := f.board(0, &"nerqathen_bone_cantor")
	var first := f.board(0, &"neutral_vantrel_duskling")
	var second := f.board(0, &"neutral_vantrel_duskling")
	f.creature(first).health = 0
	_resolve()
	_ok(f.creature(cantor).get_attack() == 3, "first friendly death of the turn -> permanent +1 attack")
	f.creature(second).health = 0
	_resolve()
	_ok(f.creature(cantor).get_attack() == 3, "only once per turn")
	f.pass_to(0)
	_ok(f.creature(cantor).get_attack() == 3, "the bonus is permanent")


func test_mourning_husk() -> void:
	_cover([&"nerqathen_mourning_husk"])
	var engine := f.scenario(T, V)
	var husk := f.board(1, &"nerqathen_mourning_husk")
	var attacker := f.board(0, &"neutral_rivenshade_grazer")
	f.board(1, &"neutral_vantrel_duskling")
	_ok(engine.get_valid_attack_targets(0, attacker) == [husk], "Provocation")
	f.creature(husk).health = 1
	engine.attack(0, attacker, husk)
	_ok(f.player(1).soul_shards == 1, "Last Breath: its owner gets 1 Soul Shard")


func test_soulmonger() -> void:
	_cover([&"nerqathen_soulmonger"])
	var engine := f.scenario(V, T)
	f.player(0).soul_shards = 2
	var card := f.hand(0, &"nerqathen_soulmonger")
	_ok(engine.play_card(0, card).error == ActionResult.INVALID_CHOICE, "the player must choose how many shards to spend")
	_ok(engine.play_card(0, card, 0, {MatchCommand.CHOICE_SOUL_SHARDS: 3}).error == ActionResult.INVALID_CHOICE,
		"cannot choose more than the current shards")
	engine.play_card(0, card, 0, {MatchCommand.CHOICE_SOUL_SHARDS: 2})
	var monger := f.creature(card)
	_ok(monger.get_attack() == 7 and monger.max_health == 9 and monger.armor == 0 and f.player(0).soul_shards == 0,
		"spending 2: +2/+2, no armor")

	engine = f.scenario(V, T)
	f.player(0).soul_shards = 5
	card = f.hand(0, &"nerqathen_soulmonger")
	_ok(engine.play_card(0, card, 0, {MatchCommand.CHOICE_SOUL_SHARDS: 4}).error == ActionResult.INVALID_CHOICE,
		"at most 3")
	engine.play_card(0, card, 0, {MatchCommand.CHOICE_SOUL_SHARDS: 3})
	monger = f.creature(card)
	_ok(monger.get_attack() == 8 and monger.max_health == 10 and monger.armor == 1 and f.player(0).soul_shards == 2,
		"spending exactly 3: +3/+3 and +1 armor")

	engine = f.scenario(V, T)
	f.player(0).soul_shards = 3
	card = f.hand(0, &"nerqathen_soulmonger")
	engine.play_card(0, card, 0, {MatchCommand.CHOICE_SOUL_SHARDS: 0})
	_ok(f.creature(card).get_attack() == 5 and f.player(0).soul_shards == 3, "spending 0 is allowed")


func test_soul_harvest() -> void:
	_cover([&"nerqathen_soul_harvest"])
	var engine := f.scenario(V, T)
	var wisp := f.board(0, &"nerqathen_gravewisp")
	var enemy := f.board(1, &"neutral_vantrel_duskling")
	var card := f.hand(0, &"nerqathen_soul_harvest")
	_ok(engine.play_card(0, card).error == ActionResult.TARGET_REQUIRED
		and engine.play_card(0, card, enemy).error == ActionResult.INVALID_TARGET, "needs a friendly creature")
	engine.play_card(0, card, wisp)
	var shard_events := f.events_of(MatchEvent.SOUL_SHARDS_CHANGED)
	_ok(f.creature(wisp) == null and f.player(0).soul_shards == 3 and f.player(0).hand.size() == 1,
		"destroys it (Last Breath +1), then +2 shards and draws 1")
	_ok(int(shard_events[0]["after"]) == 1 and int(shard_events[1]["after"]) == 3,
		"the death (and Last Breath) resolves before the gain")


func test_second_burial() -> void:
	_cover([&"nerqathen_second_burial"])
	var engine := f.scenario(V, T)
	var card := f.hand(0, &"nerqathen_second_burial")
	_ok(engine.play_card(0, card).error == ActionResult.INVALID_TARGET, "no friendly creature died -> cannot be played")
	var husk := f.board(0, &"nerqathen_mourning_husk")
	f.creature(husk).attack_bonus = 2
	f.creature(husk).health = 0
	_resolve()
	engine.play_card(0, card)
	var back := f.player(0).board[0]
	_ok(back.card.card_id() == &"nerqathen_mourning_husk" and back.health == 1 and back.max_health == 5
		and back.get_attack() == 3 and back.armor == 1 and back.instance_id != husk,
		"the last dead ally returns as a new instance with 1 health, base stats, no old modifiers")
	_ok(f.events_of(MatchEvent.TRIGGER_RESOLVED).size() == 1 and engine.attack(0, back.instance_id, f.hero_id(1)).error
		== ActionResult.CANNOT_ATTACK, "no Enter Battle; it entered this turn")

	engine = f.scenario(V, T)
	f.graveyard(0, &"nerqathen_gravewisp")
	for _index in 7:
		f.board(0, &"neutral_vantrel_duskling")
	_ok(engine.play_card(0, f.hand(0, &"nerqathen_second_burial")).error == ActionResult.BOARD_FULL,
		"rejected with a full board")


func test_ossuary_bell() -> void:
	_cover([&"nerqathen_ossuary_bell"])
	var engine := f.scenario(V, T)
	engine.play_card(0, f.hand(0, &"nerqathen_ossuary_bell"))
	var bell := f.player(0).active_artifact
	for index in 4:
		var first := f.board(0, &"neutral_vantrel_duskling")
		var second := f.board(0, &"neutral_vantrel_duskling")
		f.creature(first).health = 0
		_resolve()
		f.creature(second).health = 0
		_resolve()
		if index == 0:
			_ok(bell.charges == 3 and f.player(0).soul_shards == 1, "first friendly death of a turn: -1 charge, +1 shard")
		f.pass_to(0)
	_ok(f.player(0).soul_shards == 4 and f.player(0).active_artifact == null, "once per turn; removed after 4 charges")


# --- DUMORYSS --------------------------------------------------------------------

func test_veilbreaker() -> void:
	_cover([&"dumoryss_veilbreaker"])
	var engine := f.scenario(S, T)
	var breaker := f.board(0, &"dumoryss_veilbreaker")
	engine.use_hero_power(0)
	engine.end_turn(0)
	engine.play_card(1, f.hand(1, &"khevaruun_platecaller"))
	_ok(f.creature(breaker).get_attack() == 1, "opponent card whose cost was not increased: nothing")
	engine.play_card(1, f.hand(1, &"neutral_vantrel_duskling"))
	_ok(f.creature(breaker).get_attack() == 2, "opponent plays a card made more expensive by you: +1 attack")
	engine.end_turn(1)
	_ok(f.creature(breaker).get_attack() == 2, "kept during your next turn")
	engine.end_turn(0)
	_ok(f.creature(breaker).get_attack() == 1, "until the end of your next turn")


func test_thoughtscar() -> void:
	_cover([&"dumoryss_thoughtscar"])
	var engine := f.scenario(S, T)
	engine.play_card(0, f.hand(0, &"dumoryss_thoughtscar"))
	engine.end_turn(0)
	var big := f.hand(1, &"khevaruun_platecaller")
	var small := f.hand(1, &"khevaruun_aegis_hound")
	_ok(engine.get_card_cost(1, big) == 4 and engine.get_card_cost(1, small) == 2,
		"the next opponent card costing 3 or less costs +1; more expensive cards are not affected")
	engine.play_card(1, big)
	engine.play_card(1, small)
	_ok(f.player(1).energy_current == 10 - 4 - 2 and f.player(1).incoming_cost_modifiers.is_empty(),
		"the 4-cost card did not use it; the cheap one paid +1")


func test_null_seer() -> void:
	_cover([&"dumoryss_null_seer"])
	var engine := f.scenario(S, T)
	var seer := f.board(0, &"dumoryss_null_seer")
	engine.use_hero_power(0)
	engine.play_card(0, f.hand(0, &"dumoryss_nullglass"))
	engine.end_turn(0)
	engine.play_card(1, f.hand(1, &"neutral_vantrel_duskling"))
	_ok(f.creature(seer).get_attack() == 3, "the opponent paid a cost increased by you: permanent +1 attack")
	engine.play_card(1, f.hand(1, &"neutral_kelvarn_relicbearer"))
	_ok(f.player(1).energy_current == 10 - 3 - 5 and f.creature(seer).get_attack() == 3,
		"a second increased cost in the same turn: at most once per turn")
	f.pass_to(0)
	_ok(f.creature(seer).get_attack() == 3, "the bonus is permanent")


func test_rift_scribe() -> void:
	_cover([&"dumoryss_rift_scribe"])
	var engine := f.scenario(S, T)
	var enemy := f.board(1, &"neutral_rivenshade_grazer")
	engine.play_card(0, f.hand(0, &"dumoryss_rift_scribe"), enemy)
	engine.end_turn(0)
	_ok(engine.attack(1, enemy, f.hero_id(0)).error == ActionResult.CANNOT_ATTACK, "Enter Battle: Deferral on the chosen enemy")
	f.pass_to(1)
	_ok(engine.attack(1, enemy, f.hero_id(0)).ok, "only for one owner turn")


func test_echo_leech() -> void:
	_cover([&"dumoryss_echo_leech"])
	var engine := f.scenario(S, V)
	f.board(0, &"dumoryss_echo_leech")
	engine.end_turn(0)
	engine.play_card(1, f.hand(1, &"neutral_vantrel_duskling"))
	_ok(f.player(0).hand.is_empty(), "opponent creatures do not create Echo")
	engine.play_card(1, f.hand(1, &"nerqathen_soul_harvest"), f.player(1).board[0].instance_id)
	var echo := f.player(0).hand[0]
	_ok(echo.is_echo and echo.card_id() == &"nerqathen_soul_harvest" and echo.echo_expires_turn == engine.state.turn_number + 1,
		"after the opponent's spell: an Echo of it until the end of your next turn")


func test_fractured_moment() -> void:
	_cover([&"dumoryss_fractured_moment"])
	var engine := f.scenario(S, T)
	var card := f.hand(0, &"dumoryss_fractured_moment")
	_ok(engine.play_card(0, card).error == ActionResult.TARGET_REQUIRED, "needs an enemy creature")
	var enemy := f.board(1, &"neutral_vantrel_duskling")
	engine.play_card(0, card, enemy)
	engine.end_turn(0)
	_ok(engine.attack(1, enemy, f.hero_id(0)).error == ActionResult.CANNOT_ATTACK, "Deferral: no attack in the owner's next turn")


func test_veil_tax() -> void:
	_cover([&"dumoryss_veil_tax"])
	var engine := f.scenario(S, T)
	engine.play_card(0, f.hand(0, &"dumoryss_veil_tax"))
	engine.end_turn(0)
	var grazer := f.hand(1, &"neutral_rivenshade_grazer")
	var cheap := f.hand(1, &"khevaruun_aegis_hound")
	_ok(engine.get_card_cost(1, grazer) == 7 and engine.get_card_cost(1, cheap) == 3, "the next opponent card costs +2")
	engine.play_card(1, cheap)
	_ok(engine.get_card_cost(1, grazer) == 5, "only one card")

	engine = f.scenario(S, T)
	engine.play_card(0, f.hand(0, &"dumoryss_veil_tax"))
	engine.end_turn(0)
	var pricey := f.hand(1, &"neutral_rivenshade_grazer")
	f.player(1).find_in_hand(pricey).base_cost = 9
	_ok(engine.get_card_cost(1, pricey) == 10, "the cost is capped at 10")


func test_nullglass() -> void:
	_cover([&"dumoryss_nullglass"])
	var engine := f.scenario(S, T)
	engine.play_card(0, f.hand(0, &"dumoryss_nullglass"))
	engine.end_turn(0)
	var cheap := f.hand(1, &"khevaruun_aegis_hound")
	var first := f.hand(1, &"neutral_kelvarn_relicbearer")
	var second := f.hand(1, &"neutral_kelvarn_relicbearer")
	_ok(engine.get_card_cost(1, cheap) == 1 and engine.get_card_cost(1, first) == 5,
		"opponent cards costing 4+ cost +1, cheaper ones not")
	engine.play_card(1, cheap)
	engine.play_card(1, first)
	_ok(f.player(0).active_artifact.charges == 2 and f.player(1).energy_current == 10 - 1 - 5,
		"the cost goes up, then 1 charge is spent")
	_ok(engine.get_card_cost(1, second) == 4, "only the first such card per turn")
	f.player(0).active_artifact.charges = 1
	f.pass_to(1)
	engine.play_card(1, second)
	_ok(f.player(0).active_artifact == null, "removed when its charges run out")


# --- KHEVARUUN -------------------------------------------------------------------

func test_aegis_hound() -> void:
	_cover([&"khevaruun_aegis_hound"])
	var engine := f.scenario(T, K)
	var hound := f.board(0, &"khevaruun_aegis_hound")
	var attacker := f.board(1, &"neutral_vantrel_duskling")
	engine.end_turn(0)
	engine.attack(1, attacker, hound)
	_ok(f.creature(hound).armor == 0 and f.creature(hound).health == 1 and f.creature(hound).definition().effects.is_empty(),
		"1/2/1 without abilities: armor absorbs first")


func test_shieldroot() -> void:
	_cover([&"khevaruun_shieldroot"])
	var engine := f.scenario(T, K)
	var root := f.board(0, &"khevaruun_shieldroot")
	var wisp := f.board(1, &"nerqathen_gravewisp")
	engine.attack(0, root, wisp)
	_ok(f.creature(root).armor == 0 and f.creature(root).get_attack() == 3, "armor destroyed -> +1 attack")
	engine.end_turn(0)
	_ok(f.creature(root).get_attack() == 2, "until the end of the turn")


func test_ironwarden() -> void:
	_cover([&"khevaruun_ironwarden"])
	var engine := f.scenario(K, T)
	var warden := f.board(1, &"khevaruun_ironwarden")
	f.board(1, &"neutral_vantrel_duskling")
	var attacker := f.board(0, &"neutral_rivenshade_grazer")
	_ok(engine.get_valid_attack_targets(0, attacker) == [warden], "Provocation")


func test_platecaller() -> void:
	_cover([&"khevaruun_platecaller"])
	var engine := f.scenario(T, K)
	var ally := f.board(0, &"neutral_vantrel_duskling")
	var card := f.hand(0, &"khevaruun_platecaller")
	_ok(engine.play_card(0, card).error == ActionResult.TARGET_REQUIRED, "another friendly creature must be chosen")
	_ok(engine.play_card(0, card, card).error == ActionResult.INVALID_TARGET, "not itself")
	engine.play_card(0, card, ally)
	_ok(f.creature(ally).armor == 1 and f.creature(ally).max_armor == 1 and f.creature(card).armor == 1,
		"the chosen ally gets +1 armor")

	engine = f.scenario(T, K)
	card = f.hand(0, &"khevaruun_platecaller")
	_ok(engine.play_card(0, card).ok, "with no other friendly creature it is played without a target")


func test_wallforged() -> void:
	_cover([&"khevaruun_wallforged"])
	var engine := f.scenario(K, T)
	var wall := f.board(1, &"khevaruun_wallforged")
	var attacker := f.board(0, &"neutral_rivenshade_grazer")
	f.board(1, &"neutral_vantrel_duskling")
	_ok(engine.get_valid_attack_targets(0, attacker) == [wall], "Provocation")
	engine.attack(0, attacker, wall)
	_ok(f.creature(wall).armor == 1 and f.creature(wall).health == 5, "losing the last armor point restores 1 armor")
	engine._resolver.damage_creature(f.creature(wall), 1, {"kind": "TEST"})
	_resolve()
	_ok(f.creature(wall).armor == 0, "at most once per turn")


func test_temper_rite() -> void:
	_cover([&"khevaruun_temper_rite"])
	var engine := f.scenario(T, K)
	var ally := f.board(0, &"neutral_vantrel_duskling")
	for _index in 3:
		engine.play_card(0, f.hand(0, TEMPER), ally)
	var creature := f.creature(ally)
	_ok(creature.max_armor == 4 and creature.armor == 4 and int(creature.armor_gained_from[TEMPER]) == 4,
		"+2, +2, then +0: at most 4 armor from Temper Rite per creature")
	creature.armor = 0
	engine.play_card(0, f.hand(0, TEMPER), ally)
	_ok(creature.armor == 0, "losing armor does not reset the limit")

	engine = f.scenario(T, K)
	ally = f.board(0, &"neutral_vantrel_duskling")
	f.creature(ally).armor_gained_from[TEMPER] = 3
	engine.play_card(0, f.hand(0, TEMPER), ally)
	_ok(f.creature(ally).armor == 1, "with 1 point of the limit left it gives +1")


func test_iron_memory() -> void:
	_cover([&"khevaruun_iron_memory"])
	var engine := f.scenario(T, K)
	var warden := f.board(0, &"khevaruun_ironwarden")
	f.creature(warden).armor = 0
	engine.play_card(0, f.hand(0, &"khevaruun_iron_memory"), warden)
	_ok(f.creature(warden).armor == 2 and f.creature(warden).max_health == 4, "lost armor is restored to max armor")
	engine.play_card(0, f.hand(0, &"khevaruun_iron_memory"), warden)
	_ok(f.creature(warden).armor == 2 and f.creature(warden).max_health == 6 and f.creature(warden).health == 6,
		"armor already full: +2 health instead")


func test_bastion_core() -> void:
	_cover([&"khevaruun_bastion_core"])
	var engine := f.scenario(T, K)
	engine.play_card(0, f.hand(0, &"khevaruun_bastion_core"))
	var first := f.hand(0, &"neutral_vantrel_duskling")
	var second := f.hand(0, &"neutral_vantrel_duskling")
	engine.play_card(0, first)
	engine.play_card(0, second)
	_ok(f.creature(first).armor == 1 and f.creature(second).armor == 0 and f.player(0).active_artifact.charges == 2,
		"the first creature played in your turn gets +1 armor and uses a charge")
	f.player(0).active_artifact.charges = 1
	f.pass_to(0)
	engine.play_card(0, f.hand(0, &"neutral_vantrel_duskling"))
	_ok(f.player(0).active_artifact == null, "removed when its charges run out")


# --- NEUTRAL ----------------------------------------------------------------------

func test_mireglass_wanderer() -> void:
	_cover([&"neutral_mireglass_wanderer"])
	var engine := f.scenario(K, T)
	var alone := f.hand(0, &"neutral_mireglass_wanderer")
	engine.play_card(0, alone)
	_ok(f.creature(alone).max_health == 3 and f.creature(alone).health == 3, "no other friendly creature: +1 health")
	var crowded := f.hand(0, &"neutral_mireglass_wanderer")
	engine.play_card(0, crowded)
	_ok(f.creature(crowded).max_health == 2, "with another friendly creature: nothing")


func test_vantrel_duskling() -> void:
	_cover([&"neutral_vantrel_duskling"])
	var engine := f.scenario(K, T)
	var card := f.hand(0, &"neutral_vantrel_duskling")
	engine.play_card(0, card)
	_ok(f.creature(card).get_attack() == 2 and f.creature(card).health == 3 and f.player(0).energy_current == 8
		and f.events_of(MatchEvent.TRIGGER_RESOLVED).is_empty(), "2/3 for 2 without abilities")


func test_threnic_cartographer() -> void:
	_cover([&"neutral_threnic_cartographer"])
	var engine := f.scenario(K, T)
	var top := f.deck_top(0, ["neutral_rivenshade_grazer", "ashravael_blood_tithe"])
	var card := f.hand(0, &"neutral_threnic_cartographer")
	var result := engine.play_card(0, card)
	_ok(result.ok and result.awaiting_choice and engine.state.pending_choice["options"] == top,
		"Enter Battle: shows the top 2 cards and waits for a choice")
	_ok(engine.end_turn(0).error == ActionResult.CHOICE_PENDING and engine.choose(0, 99999).error == ActionResult.INVALID_CHOICE,
		"other commands wait for the choice")
	engine.choose(0, top[1])
	var deck := f.player(0).deck
	_ok(deck[0].instance_id == top[1] and deck[deck.size() - 1].instance_id == top[0], "the chosen card stays on top, the other goes to the bottom")

	engine = f.scenario(K, T, 0)
	f.deck_top(0, ["neutral_rivenshade_grazer"])
	_ok(not engine.play_card(0, f.hand(0, &"neutral_threnic_cartographer")).awaiting_choice,
		"one card left: nothing to choose")


func test_orryxian_wayfarer() -> void:
	_cover([&"neutral_orryxian_wayfarer"])
	var engine := f.scenario(K, T)
	var wayfarer := f.hand(0, &"neutral_orryxian_wayfarer")
	engine.play_card(0, wayfarer)
	_ok(f.creature(wayfarer).armor == 1, "alone on its side: +1 armor (constant condition)")
	var other := f.board(0, &"neutral_vantrel_duskling")
	_ok(f.creature(wayfarer).armor == 0, "another creature: the bonus is gone")
	f.creature(other).health = 0
	_resolve()
	_ok(f.creature(wayfarer).armor == 1 and f.creature(wayfarer).max_armor == 1, "alone again: back, never stacking")


func test_sablequill_nomad() -> void:
	_cover([&"neutral_sablequill_nomad"])
	var engine := f.scenario(K, T)
	var nomad := f.board(1, &"neutral_sablequill_nomad")
	var first := f.board(0, &"neutral_vantrel_duskling")
	var second := f.board(0, &"neutral_vantrel_duskling")
	engine.attack(0, first, nomad)
	_ok(f.creature(nomad).max_health == 5 and f.creature(nomad).health == 3, "survived another creature's attack: +1 health")
	engine.attack(0, second, nomad)
	_ok(f.creature(nomad).max_health == 5, "at most once per turn")
	engine.end_turn(0)
	engine.attack(1, nomad, f.player(0).board[0].instance_id if not f.player(0).board.is_empty() else f.hero_id(0))
	_ok(f.creature(nomad).max_health == 5, "its own attacks do not count")


func test_kelvarn_relicbearer() -> void:
	_cover([&"neutral_kelvarn_relicbearer"])
	var engine := f.scenario(K, T)
	var bearer := f.board(0, &"neutral_kelvarn_relicbearer")
	_ok(f.creature(bearer).get_attack() == 3, "no active artifact: 3 attack")
	engine.play_card(0, f.hand(0, &"ashravael_furnace_sigil"))
	_ok(f.creature(bearer).get_attack() == 4, "with an active artifact: +1 attack")


func test_rivenshade_grazer() -> void:
	_cover([&"neutral_rivenshade_grazer"])
	var engine := f.scenario(K, T)
	var card := f.hand(0, &"neutral_rivenshade_grazer")
	engine.play_card(0, card)
	_ok(f.creature(card).get_attack() == 5 and f.creature(card).health == 6 and f.player(0).energy_current == 5,
		"5/6 for 5 without abilities")


func test_pale_meridian() -> void:
	_cover([&"neutral_pale_meridian"])
	var engine := f.scenario(K, T, 17)
	engine.play_card(0, f.hand(0, &"neutral_pale_meridian"))
	_ok(f.player(0).hand.size() == 1 and f.player(0).deck.size() == 16, "deck above 15 after the draw: 1 card")
	engine = f.scenario(K, T, 16)
	engine.play_card(0, f.hand(0, &"neutral_pale_meridian"))
	_ok(f.player(0).hand.size() == 2 and f.player(0).deck.size() == 14, "15 or fewer left after the first draw: 1 more")
