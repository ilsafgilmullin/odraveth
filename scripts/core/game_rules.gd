class_name GameRules
extends RefCounted
## Approved numeric match and deck rules, docs/PRODUCT_BASELINE.md sections 4-6.
##
## Code-side mirror of the product baseline for MatchEngine and deck
## validation. A value may change only together with PRODUCT_BASELINE.md after an
## explicit user decision; tests/smoke_test.gd guards the values.
##
## Intentionally absent: turn timer — there is none in the offline mode.

const HERO_STARTING_HEALTH := 30
const HERO_ABILITY_COST := 2

const DECK_SIZE := 30
const MAX_HAND_SIZE := 10
const FIRST_PLAYER_STARTING_HAND := 3
const SECOND_PLAYER_STARTING_HAND := 4
## One-time replacement of the starting cards before the match begins.
const STARTING_HAND_REPLACEMENTS := 1

const STARTING_MAX_ENERGY := 1
const MAX_ENERGY_GROWTH_PER_TURN := 1
const MAX_ENERGY_CAP := 10

## "Осколок импульса": the second player's single-use resource (not a card) that
## grants temporary energy until the end of the current turn.
const IMPULSE_SHARD_ENERGY := 1

## "Разлом": the first failed draw from an empty deck deals this damage to the
## hero, every next one deals [constant RIFT_DAMAGE_STEP] more (1, 2, 3, 4...).
const RIFT_FIRST_DAMAGE := 1
const RIFT_DAMAGE_STEP := 1

## Copies of one common / rare / epic card allowed in a deck.
const MAX_COPIES_PER_CARD := 2
## Copies of one legendary card allowed in a deck.
const MAX_COPIES_LEGENDARY := 1
const MAX_ACTIVE_ARTIFACTS := 1

## Creatures one player may have on their side of the board.
const MAX_CREATURES_PER_SIDE := 7

## «Осколки души»: Nerqathen resource, neither a card nor energy. Kept between
## turns, never below 0; a gain above the maximum is lost (9 + 2 = 10). Spent only
## by effects that say so; an effect whose mandatory shard cost exceeds the
## current amount cannot be activated.
const STARTING_SOUL_SHARDS := 0
const MAX_SOUL_SHARDS := 10


static func max_copies_in_deck(rarity: CardEnums.Rarity) -> int:
	return MAX_COPIES_LEGENDARY if rarity == CardEnums.Rarity.LEGENDARY else MAX_COPIES_PER_CARD
