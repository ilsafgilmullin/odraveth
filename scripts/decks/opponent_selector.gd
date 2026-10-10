class_name OpponentSelector
extends RefCounted
## Weighted random selection of a concrete opponent HERO before a match.
## The exact same hero_id (mirror match) gets ~10%; the remaining ~90% is shared
## equally by every other eligible hero, so several heroes per faction are
## supported without hard-coded per-faction shares. Selection happens before any
## presentation; the Opponent Search animation only reveals the result.

const TOTAL_WEIGHT := 1000
const MIRROR_WEIGHT := 100


## Integer weights per eligible hero (deterministic canonical order).
static func weights(player_hero: StringName, eligible: Array[StringName]) -> Dictionary:
	var result := {}
	if eligible.is_empty():
		return result
	var others: Array[StringName] = []
	for hero: StringName in eligible:
		if hero != player_hero and not others.has(hero):
			others.append(hero)
	var has_mirror := eligible.has(player_hero)
	if others.is_empty():
		result[player_hero] = TOTAL_WEIGHT
		return result
	var shared := TOTAL_WEIGHT - (MIRROR_WEIGHT if has_mirror else 0)
	if has_mirror:
		result[player_hero] = MIRROR_WEIGHT
	var base := floori(float(shared) / float(others.size()))
	var remainder := shared - base * others.size()
	for i in others.size():
		result[others[i]] = base + (1 if i < remainder else 0)
	return result


static func pick(player_hero: StringName, eligible: Array[StringName], rng: MatchRng) -> StringName:
	var table := weights(player_hero, eligible)
	if table.is_empty():
		return &""
	var roll := rng.next_int(TOTAL_WEIGHT)
	var cursor := 0
	for hero: StringName in _ordered(eligible, table):
		cursor += int(table[hero])
		if roll < cursor:
			return hero
	return _ordered(eligible, table)[-1]


## Setup-time selection with its own seeded DeterministicRng (never the match's RNG instance).
static func pick_with_seed(player_hero: StringName, seed_value: int,
		eligible: Array[StringName] = PlayerSetupData.HERO_IDS) -> StringName:
	return pick(player_hero, eligible, DeterministicRng.new(seed_value))


static func _ordered(eligible: Array[StringName], table: Dictionary) -> Array[StringName]:
	var ordered: Array[StringName] = []
	for hero: StringName in eligible:
		if table.has(hero) and not ordered.has(hero):
			ordered.append(hero)
	return ordered
