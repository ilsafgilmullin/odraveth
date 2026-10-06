extends RefCounted
## Builds matches and board situations for engine tests.
##
## start() plays a real setup. scenario() then puts the match into a known
## position by editing the state directly (white-box set-up only); everything
## the tests check happens through public MatchEngine commands.

const ScriptedRng := preload("res://tests/engine/scripted_rng.gd")
## Filler card for decks in scenarios: a vanilla neutral creature.
const FILLER := &"neutral_vantrel_duskling"

var cards: Node
var engine: MatchEngine


func _init(card_database: Node) -> void:
	cards = card_database


## A legal 30-card deck for [param hero]: every own-faction card and every
## neutral card at its deck limit, minus the last neutral copy.
func deck_for(hero: StringName) -> Array[String]:
	var faction: String = HeroCatalog.HEROES[hero]["faction"]
	var own: Array[String] = []
	var neutral: Array[String] = []
	for card: CardDefinition in cards.get_all_cards():
		var key: String = Faction.Id.find_key(card.faction)
		for _copy in card.deck_limit:
			if key == faction:
				own.append(String(card.id))
			elif key == "NEUTRAL":
				neutral.append(String(card.id))
	own.append_array(neutral)
	own.resize(GameRules.DECK_SIZE)
	return own


func configs(hero_a: StringName, hero_b: StringName) -> Array:
	return [{"hero": hero_a, "deck": deck_for(hero_a)}, {"hero": hero_b, "deck": deck_for(hero_b)}]


## A set-up match in the mulligan phase.
func setup(hero_a: StringName, hero_b: StringName, rng: MatchRng) -> MatchEngine:
	engine = MatchEngine.new(cards, rng)
	engine.setup(configs(hero_a, hero_b))
	return engine


## A match in turn 1 after both players kept their hands.
func start(hero_a: StringName, hero_b: StringName, rng: MatchRng) -> MatchEngine:
	setup(hero_a, hero_b, rng)
	engine.submit_mulligan(engine.state.first_player, [])
	engine.submit_mulligan(engine.state.opponent_of(engine.state.first_player), [])
	return engine


## Turn 1 of player 0 with empty hands and boards, 10 energy (also in later
## turns), decks of [param deck_size] filler cards and no Impulse Shard.
func scenario(hero_a: StringName = HeroCatalog.KEZHARYN, hero_b: StringName = HeroCatalog.TAZHYRION,
		deck_size: int = 20) -> MatchEngine:
	start(hero_a, hero_b, ScriptedRng.new([0]))
	for side in engine.state.players:
		side.hand.clear()
		side.board.clear()
		side.graveyard.clear()
		side.deck.clear()
		for _index in deck_size:
			side.deck.append(new_card(side.index, FILLER))
		side.impulse_shard_available = false
		side.energy_max = 10
		side.energy_current = 10
		# Past turns, so the next own turns keep 10 max energy.
		side.turns_started = maxi(side.turns_started, 10)
	engine.state.events.clear()
	return engine


func player(index: int) -> PlayerState:
	return engine.state.players[index]


func new_card(owner: int, card_id: StringName) -> CardInstance:
	return engine._resolver.new_card(owner, card_id)


## Adds a card to the hand; returns its instance id.
func hand(owner: int, card_id: StringName) -> int:
	var card := new_card(owner, card_id)
	player(owner).hand.append(card)
	return card.instance_id


## Puts a creature on the board; [param ready] = it can attack this turn.
func board(owner: int, card_id: StringName, ready: bool = true) -> int:
	var unit := CreatureInstance.create(engine.state.take_id(), new_card(owner, card_id), engine.state.turn_number)
	if ready:
		unit.entered_turn = 0
	player(owner).board.append(unit)
	refresh()
	return unit.instance_id


func artifact(owner: int, card_id: StringName) -> int:
	var artifact_instance := ArtifactInstance.create(new_card(owner, card_id))
	player(owner).active_artifact = artifact_instance
	refresh()
	return artifact_instance.instance_id


## Puts cards on top of the deck (first id = top card); returns their ids.
func deck_top(owner: int, card_ids: Array) -> Array[int]:
	var ids: Array[int] = []
	var cards_on_top: Array[CardInstance] = []
	for card_id: Variant in card_ids:
		var card := new_card(owner, StringName(str(card_id)))
		cards_on_top.append(card)
		ids.append(card.instance_id)
	cards_on_top.reverse()
	for card in cards_on_top:
		player(owner).deck.push_front(card)
	return ids


## A dead creature card in the graveyard.
func graveyard(owner: int, card_id: StringName) -> int:
	var card := new_card(owner, card_id)
	player(owner).graveyard.append(card)
	return card.instance_id


func creature(id: int) -> CreatureInstance:
	return engine.state.find_creature(id)


func hero_id(index: int) -> int:
	return player(index).hero_instance_id


func refresh() -> void:
	engine._resolver.recalculate_statics()


## Events of [param type] logged so far.
func events_of(type: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event in engine.state.events:
		if event["type"] == type:
			found.append(event)
	return found


## Ends turns until player [param index] is active again.
func pass_to(index: int) -> void:
	engine.end_turn(engine.state.active_player)
	if engine.state.active_player != index:
		engine.end_turn(engine.state.active_player)
