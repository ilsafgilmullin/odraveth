class_name HeroPowers
extends RefCounted
## The four hero abilities (docs/PRODUCT_BASELINE.md section 4). Validation
## (own turn, once per turn, energy, target) happens in CommandValidator.


static func use(resolver: MatchResolver, player_index: int, target_id: int) -> void:
	var state := resolver.state
	var player := state.players[player_index]
	var hero := player.hero_id
	player.energy_current -= GameRules.HERO_ABILITY_COST
	player.hero_power_used_this_turn = true
	resolver.emit(MatchEvent.ENERGY_SPENT, {"player": player_index, "amount": GameRules.HERO_ABILITY_COST,
		"left": player.energy_current})
	resolver.emit(MatchEvent.HERO_POWER_USED, {"player": player_index, "hero": String(hero), "target_id": target_id})
	match hero:
		HeroCatalog.KEZHARYN:
			# «Кровавый приказ»: self-damage first; if it ends the match, no buff.
			resolver.damage_hero(player_index, HeroCatalog.value(hero, "self_damage"), {"kind": "HERO_POWER"})
			if not resolver.step():
				return
			var target := state.find_creature(target_id)
			if target != null and not target.is_dead():
				resolver.add_attack(target, HeroCatalog.value(hero, "attack_bonus"), "END_OF_TURN", player_index)
		HeroCatalog.VHORAZEL:
			# «Извлечение»: 2 shards if a friendly creature died this turn, else 1.
			var key := "soul_shards_after_ally_death" if player.friendly_creature_died_this_turn else "soul_shards"
			resolver.gain_soul_shards(player_index, HeroCatalog.value(hero, key))
		HeroCatalog.SYRRAVETH:
			# «Искажение»: one charge for the next opponent card costing <= 3.
			var modifier := {"seq": state.take_sequence(), "source": CostCalculator.DISTORTION,
				"source_owner": player_index, "amount": HeroCatalog.value(hero, "cost_increase"),
				"only_cost_at_most": HeroCatalog.value(hero, "max_affected_cost")}
			state.players[state.opponent_of(player_index)].incoming_cost_modifiers.append(modifier)
			resolver.emit(MatchEvent.COST_MODIFIER_ADDED, modifier.duplicate())
		HeroCatalog.TAZHYRION:
			# «Закалка»: +1 max and current armor.
			resolver.add_armor(state.find_creature(target_id), HeroCatalog.value(hero, "armor"))
	if resolver.step():
		resolver.drain()
