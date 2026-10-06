extends RefCounted
## The four hero abilities (docs/PRODUCT_BASELINE.md section 4).

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
	_test_common_rules()
	_test_kezharyn()
	_test_vhorazel()
	_test_syrraveth()
	_test_tazhyrion()


func _ok(condition: bool, description: String) -> void:
	_check.call(condition, description)


func _test_common_rules() -> void:
	_ok(HeroCatalog.HEROES.size() == 4 and GameRules.HERO_ABILITY_COST == 2, "hero abilities: four heroes, cost 2 energy")
	_ok(HeroCatalog.faction_of(K) == Faction.Id.ASHRAVAEL and HeroCatalog.faction_of(V) == Faction.Id.NERQATHEN
		and HeroCatalog.faction_of(S) == Faction.Id.DUMORYSS and HeroCatalog.faction_of(T) == Faction.Id.KHEVARUUN,
		"hero catalog: hero factions match the baseline")
	_ok(HeroCatalog.HEROES[K]["power_ru"] == "Кровавый приказ" and HeroCatalog.HEROES[V]["power_ru"] == "Извлечение"
		and HeroCatalog.HEROES[S]["power_ru"] == "Искажение" and HeroCatalog.HEROES[T]["power_ru"] == "Закалка"
		and HeroCatalog.HEROES[K]["name_ru"] == "Кежарин" and HeroCatalog.HEROES[V]["name_ru"] == "Вхоразель"
		and HeroCatalog.HEROES[S]["name_ru"] == "Сирравет" and HeroCatalog.HEROES[T]["name_ru"] == "Тажирион",
		"hero catalog: hero and ability names match the baseline")
	_ok(HeroCatalog.needs_friendly_target(K) and not HeroCatalog.needs_friendly_target(V)
		and not HeroCatalog.needs_friendly_target(S) and HeroCatalog.needs_friendly_target(T)
		and HeroCatalog.value(K, "self_damage") == 1 and HeroCatalog.value(K, "attack_bonus") == 2
		and HeroCatalog.value(V, "soul_shards") == 1 and HeroCatalog.value(V, "soul_shards_after_ally_death") == 2
		and HeroCatalog.value(S, "cost_increase") == 1 and HeroCatalog.value(S, "max_affected_cost") == 3
		and HeroCatalog.value(T, "armor") == 1, "hero catalog: ability numbers match the baseline")
	var engine := f.scenario(V, T)
	f.player(0).energy_current = 1
	_ok(engine.use_hero_power(0).error == ActionResult.NOT_ENOUGH_ENERGY, "hero abilities: need 2 energy")
	f.player(0).energy_current = 4
	_ok(engine.use_hero_power(0).ok and f.player(0).energy_current == 2 and f.player(0).hero_power_used_this_turn,
		"hero abilities: cost 2 energy and are marked used")
	_ok(engine.use_hero_power(0).error == ActionResult.ALREADY_USED, "hero abilities: once per own turn")
	_ok(engine.use_hero_power(1).error == ActionResult.NOT_YOUR_TURN, "hero abilities: only in the own turn")
	f.pass_to(0)
	_ok(engine.use_hero_power(0).ok, "hero abilities: available again in the next own turn")


func _test_kezharyn() -> void:
	var engine := f.scenario(K, T)
	var ally := f.board(0, &"neutral_vantrel_duskling")
	var enemy := f.board(1, &"neutral_vantrel_duskling")
	_ok(engine.use_hero_power(0).error == ActionResult.TARGET_REQUIRED, "Kezharyn: a friendly creature is required")
	_ok(engine.use_hero_power(0, enemy).error == ActionResult.INVALID_TARGET, "Kezharyn: an enemy creature is not a target")
	_ok(engine.use_hero_power(0, ally).ok and f.player(0).hero_health == 29 and f.creature(ally).get_attack() == 4
		and f.player(0).hero_damaged_this_turn, "Kezharyn: hero takes 1 damage, the creature gets +2 attack")
	_ok(engine.use_hero_power(0, ally).error == ActionResult.ALREADY_USED, "Kezharyn: once per turn")
	engine.end_turn(0)
	_ok(f.creature(ally).get_attack() == 2, "Kezharyn: the +2 attack lasts until the end of the turn")

	engine = f.scenario(K, T)
	ally = f.board(0, &"neutral_vantrel_duskling")
	f.player(0).hero_health = 1
	_ok(engine.use_hero_power(0, ally).ok and engine.is_over() and engine.get_winner() == 1
		and f.creature(ally).get_attack() == 2, "Kezharyn: usable at 1 health; if the hero dies the buff is not applied")

	engine = f.scenario(K, T)
	_ok(engine.use_hero_power(0).error == ActionResult.TARGET_REQUIRED, "Kezharyn: not usable without friendly creatures")


func _test_vhorazel() -> void:
	var engine := f.scenario(V, T)
	engine.use_hero_power(0)
	_ok(f.player(0).soul_shards == 1, "Vhorazel: +1 Soul Shard normally")
	f.pass_to(0)
	var doomed := f.board(0, &"nerqathen_pale_binder")
	var killer := f.board(1, &"neutral_rivenshade_grazer")
	engine.attack(0, doomed, killer)
	_ok(f.player(0).friendly_creature_died_this_turn, "Vhorazel: a friendly creature died this turn")
	engine.use_hero_power(0)
	_ok(f.player(0).soul_shards == 3, "Vhorazel: +2 Soul Shards after a friendly death this turn")
	f.pass_to(0)
	engine.use_hero_power(0)
	_ok(f.player(0).soul_shards == 4, "Vhorazel: back to +1 in the next turn")
	f.pass_to(0)
	f.player(0).soul_shards = 9
	f.player(0).friendly_creature_died_this_turn = true
	engine.use_hero_power(0)
	var gained := f.events_of(MatchEvent.SOUL_SHARDS_CHANGED).back() as Dictionary
	_ok(f.player(0).soul_shards == 10 and int(gained["lost"]) == 1, "Vhorazel: 9 + 2 = 10, the excess is lost")


func _test_syrraveth() -> void:
	var engine := f.scenario(S, T)
	engine.use_hero_power(0)
	var big := f.hand(1, &"neutral_kelvarn_relicbearer")
	var small := f.hand(1, &"neutral_vantrel_duskling")
	_ok(f.player(1).incoming_cost_modifiers.size() == 1, "Syrraveth: the ability creates one distortion charge")
	f.pass_to(1)
	_ok(f.player(1).incoming_cost_modifiers.size() == 1 and engine.get_card_cost(1, big) == 4,
		"Syrraveth: the charge persists; a card costing more than 3 is not affected")
	engine.play_card(1, big)
	_ok(f.player(1).incoming_cost_modifiers.size() == 1 and f.player(1).energy_current == 6,
		"Syrraveth: playing a 4-cost card leaves the charge unused")
	_ok(engine.get_card_cost(1, small) == 3, "Syrraveth: the next card costing 3 or less costs +1")
	engine.play_card(1, small)
	_ok(f.player(1).incoming_cost_modifiers.is_empty() and f.player(1).energy_current == 3,
		"Syrraveth: the qualifying card pays +1 and uses the charge")

	engine = f.scenario(S, T)
	engine.use_hero_power(0)
	f.pass_to(0)
	engine.use_hero_power(0)
	var first := f.hand(1, &"neutral_vantrel_duskling")
	var second := f.hand(1, &"neutral_mireglass_wanderer")
	f.pass_to(1)
	_ok(f.player(1).incoming_cost_modifiers.size() == 2 and engine.get_card_cost(1, first) == 3,
		"Syrraveth: two charges do not stack on one card")
	engine.play_card(1, first)
	_ok(engine.get_card_cost(1, second) == 2 and f.player(1).incoming_cost_modifiers.size() == 1,
		"Syrraveth: the second charge waits for the next qualifying card")
	engine.play_card(1, second)
	_ok(f.player(1).incoming_cost_modifiers.is_empty(), "Syrraveth: each charge affected a different card")

	engine = f.scenario(S, T)
	engine.use_hero_power(0)
	var own := f.hand(0, &"neutral_vantrel_duskling")
	_ok(engine.get_card_cost(0, own) == 2, "Syrraveth: own cards are not affected")
	f.pass_to(1)
	var priced := f.hand(1, &"neutral_vantrel_duskling")
	f.player(1).energy_current = 2
	var before := JSON.stringify(engine.snapshot())
	_ok(engine.play_card(1, priced).error == ActionResult.NOT_ENOUGH_ENERGY and JSON.stringify(engine.snapshot()) == before,
		"Syrraveth: a card made unaffordable is rejected and the charge stays")


func _test_tazhyrion() -> void:
	var engine := f.scenario(T, K)
	_ok(engine.use_hero_power(0).error == ActionResult.TARGET_REQUIRED, "Tazhyrion: a friendly creature is required")
	var ally := f.board(0, &"khevaruun_aegis_hound")
	_ok(engine.use_hero_power(0, ally).ok and f.creature(ally).armor == 2 and f.creature(ally).max_armor == 2,
		"Tazhyrion: +1 max armor and +1 current armor")
