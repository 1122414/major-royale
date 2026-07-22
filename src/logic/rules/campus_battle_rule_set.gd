extends "res://src/logic/rules/battle_rule_set.gd"

## 校园世界的专业被动、主动技与遗物效果。数值保持与旧战斗逻辑一致。

var _thesis_clip_ready := true
var _law_passive_used := false


func get_id() -> String:
	return "campus"


func get_starting_energy_bonus(_battle) -> int:
	return 1 if GameState.has_relic("elite_badge") else 0


func on_battle_started(battle) -> void:
	if GameState.has_relic("flash_drive"):
		battle.player.draw_cards(1, battle.MAX_HAND_SIZE)
	if GameState.has_relic("lucky_eraser"):
		_remove_body_debuffs(battle.player)
		for status_id in battle.player.statuses.keys():
			if Status.is_debuff(status_id):
				battle.player.remove_status(status_id)
				break


func get_card_cost(_battle, card: Resource, base_cost: int) -> int:
	if GameState.has_relic("thesis_clip") and _thesis_clip_ready and card.cost > 0:
		return maxi(0, base_cost - 1)
	return base_cost


func on_card_played(battle, card: Resource, shield_before_card: int) -> void:
	if GameState.has_relic("thesis_clip") and _thesis_clip_ready and card.cost > 0:
		_thesis_clip_ready = false
	if GameState.has_relic("scientific_calculator") and str(card.type) == "attack":
		battle.deal_direct_damage_to_enemy(2)
	if GameState.has_relic("risk_terminal") and str(card.type) == "attack" and shield_before_card >= 10:
		battle.deal_direct_damage_to_enemy(4)
	if GameState.has_relic("red_pen") and str(card.type) == "control":
		battle.player.gain_shield(3)
	if GameState.has_relic("rubber_duck") and str(card.type) == "skill" and battle.get_turn_card_type_count("skill") == 1:
		battle.player.draw_cards(1, battle.MAX_HAND_SIZE)
	if GameState.has_relic("backstage_pass") and str(card.type) == "control" and battle.get_turn_card_type_count("control") == 1:
		battle.energy += 1

	if battle.player.major_id == "medicine" and card.type == "attack" and battle.roll_chance(0.3):
		battle.deal_direct_damage_to_enemy(3)
	if battle.player.major_id == "arts" and str(card.type) == "control" and battle.roll_chance(0.3):
		battle.player.draw_cards(1, battle.MAX_HAND_SIZE)


func use_active_skill(battle) -> String:
	var major = Config.characters.get(battle.player.major_id)
	if major == null:
		return ""
	match str(major.active_skill.get("id", "")):
		"code_injection":
			battle.enemy.add_status("bug", 2)
			battle.player.draw_cards(1, battle.MAX_HAND_SIZE)
			battle.reveal_intent()
			return "代码注入"
		"objection":
			battle.set_enemy_intent({"id": "stunned", "description": "被异议打断，本回合无法行动。", "value": 0})
			battle.enemy.add_status("举证失败", 1)
			battle.player.gain_shield(6)
			return "异议！"
		"emergency_suture":
			battle.player.heal(15)
			_remove_body_debuffs(battle.player)
			battle.player.add_status("resistance", 1)
			return "紧急缝合"
		"leverage":
			battle.energy += 1
			battle.player.add_status("adrenaline", 1)
			battle.player.gain_shield(3)
			return "杠杆加仓"
		"inspiration":
			battle.player.draw_cards(2, battle.MAX_HAND_SIZE)
			battle.player.remove_status("pressure", 1)
			battle.player.gain_shield(4)
			return "灵感爆发"
	return ""


func on_player_turn_started(battle) -> void:
	_thesis_clip_ready = true
	if GameState.has_relic("coffee_thermos"):
		battle.player.gain_shield(2)
	if battle.turn_count == 1 and GameState.has_relic("sticky_notes"):
		battle.player.gain_shield(5)


func modify_player_draw(battle, draw_amount: int, has_draw_override: bool) -> int:
	if not has_draw_override and battle.player.major_id == "computer" and battle.player.hp < battle.player.max_hp * 0.4:
		return draw_amount + 1
	return draw_amount


func modify_pressure_damage_multiplier(_battle, multiplier: float) -> float:
	if GameState.has_relic("noise_cancelling"):
		return 1.0 + (multiplier - 1.0) * 0.5
	return multiplier


func modify_shield_amount(battle, caster, _target, amount: int) -> int:
	if caster == battle.player and caster.major_id == "finance":
		return amount + 2
	return amount


func modify_heal_amount(battle, caster, _target, amount: int) -> int:
	if caster == battle.player and GameState.has_relic("field_kit"):
		return amount + 3
	return amount


func after_heal(battle, caster, target, actual_healed: int, requested_heal: int) -> void:
	if caster == battle.player and target == battle.player and GameState.has_relic("field_kit"):
		target.gain_shield(maxi(0, requested_heal - actual_healed))


func on_player_damaged(battle) -> void:
	if battle.player.major_id == "law" and not _law_passive_used and battle.player.hp <= 0:
		battle.player.hp = 1
		battle.player.gain_shield(10)
		_law_passive_used = true


func _remove_body_debuffs(character: Character) -> void:
	for status_id in ["bleed", "pressure"]:
		character.remove_status(status_id)
