class_name BattleLaunchConfig
extends RefCounted
## Match launch parameters passed to BattleScene via route params.

const PARAM_KEY := "launch_config"

var player_hero: StringName = &""
var player_deck: Array = []
var opponent_hero: StringName = &""
var opponent_deck: Array = []
@warning_ignore("enum_variable_without_default")
var ai_difficulty: AiDifficulty.Level
var rng_seed: int = 0


static func create(p_hero: StringName, p_deck: Array, o_hero: StringName, o_deck: Array,
		difficulty: AiDifficulty.Level, seed_value: int = 0) -> BattleLaunchConfig:
	var cfg := BattleLaunchConfig.new()
	cfg.player_hero = p_hero
	cfg.player_deck = p_deck.duplicate()
	cfg.opponent_hero = o_hero
	cfg.opponent_deck = o_deck.duplicate()
	cfg.ai_difficulty = difficulty
	cfg.rng_seed = seed_value if seed_value != 0 else _generate_seed()
	return cfg


## Temporary technical launch fixture until player decks and prebattle choices
## are implemented. This is not an approved product preset deck.
static func technical_dev_config(card_source: Object) -> BattleLaunchConfig:
	var p_hero := HeroCatalog.KEZHARYN
	var o_hero := HeroCatalog.VHORAZEL
	return create(p_hero, _build_deck(p_hero, card_source),
		o_hero, _build_deck(o_hero, card_source), AiDifficulty.Level.NOVICE)


## Kept for existing integration callers; always a technical fixture.
static func default_config(card_source: Object) -> BattleLaunchConfig:
	return technical_dev_config(card_source)


static func _build_deck(hero_id: StringName, card_source: Object) -> Array:
	var faction := HeroCatalog.faction_of(hero_id)
	var eligible: Array[CardDefinition] = []
	for card_id_str: String in card_source.get_card_ids():
		var definition: CardDefinition = card_source.get_card(StringName(card_id_str))
		if definition != null and (definition.faction == faction or definition.faction == Faction.Id.NEUTRAL):
			eligible.append(definition)
	eligible.sort_custom(func(a: CardDefinition, b: CardDefinition) -> bool: return a.cost < b.cost)
	var deck: Array = []
	var counts: Dictionary = {}
	var safety: int = 0
	while deck.size() < GameRules.DECK_SIZE and safety < 10:
		for definition: CardDefinition in eligible:
			if deck.size() >= GameRules.DECK_SIZE:
				break
			var count: int = counts.get(definition.id, 0)
			if count < definition.deck_limit:
				deck.append(definition.id)
				counts[definition.id] = count + 1
		safety += 1
	return deck


static func _generate_seed() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
