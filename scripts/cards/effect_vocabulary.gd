class_name EffectVocabulary
extends RefCounted
## Closed vocabulary of declarative card effect data (docs/ARCHITECTURE.md section 8).
##
## Identifiers only: nothing here executes an effect. Exact timing and the rules
## of keywords whose meaning the baseline does not define belong to the
## MatchEngine stage. Every identifier is used by at least one approved card
## (checked by the tests); a new one is added only for an approved card.
##
## Parameter kinds: "int+" integer >= 1, "int0" integer >= 0, "bool", "true"
## (must be true), "target", "duration", "keyword", "delay", "multiplier",
## "card_type". A leading "?" marks an optional parameter.

## Trigger -> card types allowed to use it.
const TRIGGERS := {
	"ON_PLAY": ["SPELL"],
	"ENTER_BATTLE": ["CREATURE"],
	"LAST_BREATH": ["CREATURE"],
	"SELF_DAMAGED": ["CREATURE"],
	"AFTER_SELF_ATTACK": ["CREATURE"],
	"SELF_ARMOR_DEPLETED": ["CREATURE"],
	"SELF_SURVIVED_CREATURE_ATTACK": ["CREATURE"],
	"OPPONENT_PAYS_INCREASED_COST": ["CREATURE"],
	"STATIC": ["CREATURE", "ARTIFACT"],
	"OWN_HERO_DAMAGED": ["CREATURE", "ARTIFACT"],
	"ALLY_CREATURE_DIED": ["CREATURE", "ARTIFACT"],
	"ALLY_CREATURE_PLAYED": ["CREATURE", "ARTIFACT"],
	"OPPONENT_PLAYS_CARD": ["CREATURE", "ARTIFACT"],
}

## Condition -> parameters.
const CONDITIONS := {
	"OWN_HERO_DAMAGED_THIS_TURN": {},
	"OWN_HERO_HEALTH_AT_MOST": {"value": "int0"},
	"IS_OWN_TURN": {},
	"FIRST_ATTACK_THIS_TURN": {},
	"OWN_SOUL_SHARDS_AT_LEAST": {"value": "int+"},
	"SOUL_SHARDS_SPENT_EQUALS": {"value": "int+"},
	"PLAYED_CARD_TYPE": {"card_type": "card_type"},
	"PLAYED_CARD_COST_AT_LEAST": {"value": "int0"},
	"PLAYED_CARD_COST_INCREASED_BY_YOU": {},
	"TARGET_ARMOR_FULL": {"target": "target"},
	"TARGET_ARMOR_NOT_FULL": {"target": "target"},
	"NO_OTHER_ALLY_CREATURES": {},
	"OWN_ACTIVE_ARTIFACT": {},
	"OWN_DECK_SIZE_AT_MOST": {"value": "int0"},
}

## Action -> parameters. Every action also accepts optional "conditions",
## checked right before that action resolves.
const ACTIONS := {
	"MODIFY_STATS": {
		"target": "target", "attack": "?int+", "health": "?int+", "armor": "?int+",
		"duration": "duration", "multiplier": "?multiplier", "armor_cap_from_this_card": "?int+",
	},
	"DEAL_DAMAGE": {"target": "target", "amount": "int+", "delay": "?delay"},
	"DRAW_CARDS": {"amount": "int+"},
	"GRANT_KEYWORD": {"target": "target", "keyword": "keyword", "duration": "duration"},
	"GRANT_EXTRA_ATTACK": {"target": "target", "amount": "int+", "max_attacks_per_turn": "int+"},
	"DESTROY": {"target": "target"},
	"RETURN_TO_BOARD": {"target": "target", "set_health": "int+", "enter_battle_triggers": "bool"},
	"RESTORE_ARMOR": {"target": "target", "amount": "?int+", "all_lost": "?true"},
	"SPEND_CHARGES": {"amount": "int+"},
	"GAIN_SOUL_SHARDS": {"amount": "int+"},
	"SPEND_SOUL_SHARDS": {"amount": "?int+", "up_to": "?int+"},
	"INCREASE_NEXT_OPPONENT_CARD_COST": {"amount": "int+", "only_cost_at_most": "?int0", "cost_cap": "?int+"},
	"INCREASE_PLAYED_CARD_COST": {"amount": "int+"},
	"CREATE_ECHO_IN_HAND": {"min_cost": "int+", "expires": "duration"},
	"LOOK_AT_TOP_CARDS": {"amount": "int+", "keep_on_top": "int+"},
}

## Actions that need exactly one of the listed parameters.
const EXACTLY_ONE_OF := {
	"SPEND_SOUL_SHARDS": ["amount", "up_to"],
	"RESTORE_ARMOR": ["amount", "all_lost"],
}

## Actions that need at least one of the listed parameters.
const AT_LEAST_ONE_OF := {
	"MODIFY_STATS": ["attack", "health", "armor"],
}

## Effect limits -> parameter kind.
const LIMITS := {
	"per_turn": "int+",
}

const TARGETS: Array[String] = [
	"SELF",
	"OWN_HERO",
	"CHOSEN_ALLY_CREATURE",
	"CHOSEN_OTHER_ALLY_CREATURE",
	"CHOSEN_ENEMY_CREATURE",
	"RANDOM_ALLY_CREATURE",
	"PLAYED_CREATURE",
	"LAST_DIED_ALLY_CREATURE",
]

## NOT_STATED: the approved card text gives no duration (open question Q-17).
const DURATIONS: Array[String] = [
	"END_OF_TURN",
	"END_OF_YOUR_NEXT_TURN",
	"OWNER_NEXT_TURN",
	"PERMANENT",
	"WHILE_ACTIVE",
	"NOT_STATED",
]

## Keyword labels: ONSLAUGHT «Натиск», PROVOKE «Провокация», DEFERRAL «Отложение»,
## FRENZY «Неистовство».
const KEYWORDS: Array[String] = ["ONSLAUGHT", "PROVOKE", "DEFERRAL", "FRENZY"]

const DELAYS: Array[String] = ["END_OF_TURN"]

const MULTIPLIERS: Array[String] = ["SOUL_SHARDS_SPENT"]
