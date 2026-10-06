class_name CardEffectSpec
extends RefCounted
## Declarative description of one card ability. Stage 1 only loads and validates
## it; nothing executes it. Identifiers come from EffectVocabulary.

var effect_id: StringName
## Keyword label of the ability (EffectVocabulary.KEYWORDS), or empty.
var keyword: StringName
var trigger: StringName
## Each condition: {"type": <CONDITIONS id>, ...parameters}.
var conditions: Array[Dictionary] = []
## Each action, in text order: {"type": <ACTIONS id>, ...parameters}.
var actions: Array[Dictionary] = []
## Optional limits, e.g. {"per_turn": 1}.
var limits: Dictionary = {}


## Deep copy: changing it never affects the original.
func copy() -> CardEffectSpec:
	var result := CardEffectSpec.new()
	result.effect_id = effect_id
	result.keyword = keyword
	result.trigger = trigger
	result.conditions = conditions.duplicate(true)
	result.actions = actions.duplicate(true)
	result.limits = limits.duplicate(true)
	return result
