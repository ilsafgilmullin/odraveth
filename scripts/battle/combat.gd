class_name Combat
extends RefCounted
## Attacks (docs/PRODUCT_BASELINE.md section 5.4). Creature vs creature damage is
## simultaneous: both amounts are taken before either is dealt. A hero never
## strikes back.


static func attack(resolver: MatchResolver, attacker_id: int, target_id: int) -> void:
	var state := resolver.state
	var attacker := state.find_creature(attacker_id)
	attacker.attacks_this_turn += 1
	resolver.emit(MatchEvent.ATTACK_DECLARED, {"attacker_id": attacker_id, "target_id": target_id,
		"attack_number": attacker.attacks_this_turn})
	var hero_owner := state.hero_owner(target_id)
	if hero_owner >= 0:
		resolver.damage_hero(hero_owner, attacker.get_attack(), {"kind": "ATTACK", "source_id": attacker_id})
	else:
		var defender := state.find_creature(target_id)
		var to_defender := attacker.get_attack()
		var to_attacker := defender.get_attack()
		resolver.damage_creature(defender, to_defender, {"kind": "ATTACK", "source_id": attacker_id})
		resolver.damage_creature(attacker, to_attacker, {"kind": "ATTACK", "source_id": target_id})
		resolver.queue_trigger(&"SELF_SURVIVED_CREATURE_ATTACK", {"creature_id": target_id, "attacker_id": attacker_id})
	resolver.queue_trigger(&"AFTER_SELF_ATTACK", {"creature_id": attacker_id, "target_id": target_id})
	if resolver.step():
		resolver.drain()
