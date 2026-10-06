extends RefCounted
## Manual development benchmark. Not a CI timing assertion.

const MatchFixture := preload("res://tests/engine/match_fixture.gd")


static func run(cards: Node, iterations: int = 500) -> Dictionary:
	var fixture := MatchFixture.new(cards)
	var engine := fixture.scenario(HeroCatalog.KEZHARYN, HeroCatalog.TAZHYRION)
	fixture.hand(0, &"ashravael_blood_tithe")
	fixture.hand(0, &"ashravael_cinder_oath")
	fixture.hand(0, &"neutral_vantrel_duskling")
	fixture.board(0, &"neutral_mireglass_wanderer")
	fixture.board(1, &"khevaruun_ironwarden")
	var observation := engine.get_observation(0)
	var legal := engine.get_legal_commands(0)
	var controller := AiController.new(AiDifficulty.Level.STRATEGIST)
	var started := Time.get_ticks_usec()
	for _index in iterations:
		controller.decide(observation, legal)
	var elapsed := Time.get_ticks_usec() - started
	return {
		"iterations": iterations,
		"legal_commands": legal.size(),
		"elapsed_usec": elapsed,
		"average_usec": float(elapsed) / maxi(iterations, 1),
	}
