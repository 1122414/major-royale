extends "res://src/logic/rules/battle_rule_set.gd"

## 版本回环的第一轮规则：公告影响整场战斗，维护时钟推进世界节奏。

const NOTICE_LIGHTWEIGHT := "lightweight_update"
const NOTICE_NUMERIC := "numeric_inflation"
const NOTICE_FIXED := "known_issue_fix"
const QIXU_ID := "qixu"
const PITY_KEY := "pity"
const LAST_OUTCOME_KEY := "last_random_outcome"
const FORCED_OUTCOME_KEY := "forced_random_outcome"

var _lightweight_discount_available := true
var _blank_lottery_tube_ready := true


func get_id() -> String:
	return "version_loop"


func on_battle_started(battle) -> void:
	if _get_notice_id() == NOTICE_FIXED:
		# 抗压会抵消下一次完整负面施加，正好对应“第一个自身负面无效”。
		battle.player.add_status("resistance", 1)
	if battle.player.major_id == QIXU_ID:
		GameState.set_character_run_state_value(PITY_KEY, 0)
		GameState.set_character_run_state_value(LAST_OUTCOME_KEY, "")
		GameState.set_character_run_state_value(FORCED_OUTCOME_KEY, "")
		_blank_lottery_tube_ready = true


func on_battle_finished(_battle, victory: bool) -> void:
	if not victory:
		return
	var maintenance_clock := GameState.add_world_run_state_int("maintenance_clock", 1)
	if maintenance_clock >= 4:
		GameState.set_world_run_state_value("maintenance_due", true)


func modify_enemy_max_hp(_battle, enemy_resource: Resource, base_max_hp: int) -> int:
	if _get_notice_id() == NOTICE_NUMERIC and str(enemy_resource.enemy_type) == "normal":
		return int(ceil(float(base_max_hp) * 1.2))
	return base_max_hp


func on_player_turn_started(_battle) -> void:
	_lightweight_discount_available = true


func modify_player_draw(_battle, draw_amount: int, has_draw_override: bool) -> int:
	if _get_notice_id() == NOTICE_LIGHTWEIGHT and not has_draw_override:
		return maxi(1, draw_amount - 1)
	return draw_amount


func get_card_cost(_battle, card: Resource, base_cost: int) -> int:
	if _get_notice_id() == NOTICE_LIGHTWEIGHT and _lightweight_discount_available and int(card.cost) == 1:
		return 0
	return base_cost


func on_card_played(_battle, card: Resource, _shield_before_card: int) -> void:
	if _get_notice_id() == NOTICE_LIGHTWEIGHT and int(card.cost) == 1:
		_lightweight_discount_available = false


func process_card_effect(battle, card: Resource, effect: Resource, caster, _target) -> bool:
	if caster != battle.player or caster.major_id != QIXU_ID:
		return false
	match str(effect.type):
		"random_damage":
			var outcome := _resolve_random_outcome(battle)
			var hit_value := int(effect.params.get("hit_value", effect.value))
			var damage := hit_value if outcome == "hit" else int(effect.value)
			damage += int(GameState.get_effective_stat("学识") / 3)
			damage = battle.modify_card_damage(card, caster, battle.enemy, damage)
			battle.deal_direct_damage_to_enemy(damage)
			return true
		"pity":
			_add_pity(battle, int(effect.value))
			return true
		"force_random":
			GameState.set_character_run_state_value(FORCED_OUTCOME_KEY, str(effect.params.get("outcome", "hit")))
			battle.notify_character_resource_updated()
			battle.notify_world_rule_feedback("概率已校准：下一次随机必定出货")
			return true
		"pity_damage":
			var cost := maxi(0, int(effect.params.get("pity_cost", 0)))
			var current_pity := _get_pity()
			var damage := int(effect.params.get("fallback_value", effect.value))
			if current_pity >= cost:
				GameState.add_character_run_state_int(PITY_KEY, -cost)
				damage = int(effect.params.get("hit_value", effect.value))
			damage += int(GameState.get_effective_stat("学识") / 3)
			damage = battle.modify_card_damage(card, caster, battle.enemy, damage)
			battle.deal_direct_damage_to_enemy(damage)
			battle.notify_character_resource_updated()
			return true
		"pity_shield":
			var required_pity := maxi(0, int(effect.params.get("pity_cost", 0)))
			var shield := int(effect.params.get("fallback_value", effect.value))
			if _get_pity() >= required_pity:
				GameState.add_character_run_state_int(PITY_KEY, -required_pity)
				shield = int(effect.params.get("hit_value", effect.value))
			caster.gain_shield(battle.modify_shield_amount(caster, caster, shield))
			battle.notify_character_resource_updated()
			return true
		"pity_draw":
			if _get_pity() >= int(effect.params.get("threshold", 0)):
				caster.draw_cards(maxi(0, int(effect.value)), battle.MAX_HAND_SIZE)
			return true
		"pity_threshold_set":
			var threshold := int(effect.params.get("threshold", 0))
			if _get_pity() >= threshold:
				GameState.set_character_run_state_value(PITY_KEY, int(effect.params.get("hit_value", 6)))
			else:
				_add_pity(battle, int(effect.value))
			battle.notify_character_resource_updated()
			return true
		"last_outcome_reward":
			if str(GameState.get_character_run_state_value(LAST_OUTCOME_KEY, "")) == "hit":
				battle.energy += int(effect.params.get("hit_energy", 1))
			else:
				_add_pity(battle, int(effect.params.get("miss_pity", effect.value)))
				caster.draw_cards(int(effect.params.get("miss_draw", 0)), battle.MAX_HAND_SIZE)
			return true
	return false


func modify_card_damage(_battle, card: Resource, _caster, _target, amount: int) -> int:
	if _get_notice_id() == NOTICE_NUMERIC and int(card.cost) >= 2:
		return amount + 4
	return amount


func use_active_skill(battle) -> String:
	if battle.player.major_id != QIXU_ID or _get_pity() < 2:
		return ""
	GameState.add_character_run_state_int(PITY_KEY, -2)
	GameState.set_character_run_state_value(FORCED_OUTCOME_KEY, "hit")
	battle.notify_character_resource_updated()
	battle.notify_world_rule_feedback("消耗 2 保底，下一次随机必定出货")
	return "概率校准"


func _resolve_random_outcome(battle) -> String:
	var forced := str(GameState.get_character_run_state_value(FORCED_OUTCOME_KEY, ""))
	var pity_before := _get_pity()
	var outcome := forced
	if outcome.is_empty():
		outcome = "hit" if pity_before >= 6 or battle.roll_chance(0.5) else "miss"
	GameState.set_character_run_state_value(FORCED_OUTCOME_KEY, "")
	if outcome == "miss":
		_add_pity(battle, 1)
		if _blank_lottery_tube_ready and GameState.has_relic("blank_lottery_tube"):
			_blank_lottery_tube_ready = false
			battle.player.gain_shield(battle.modify_shield_amount(battle.player, battle.player, 4))
			battle.notify_world_rule_feedback("歪了：空白签筒记录失败，获得 1 保底与 4 护盾")
		else:
			battle.notify_world_rule_feedback("歪了：失败记录为保底")
	else:
		if pity_before >= 6:
			GameState.set_character_run_state_value(PITY_KEY, 0)
		battle.notify_world_rule_feedback("出货：概率结算成功")
	GameState.set_character_run_state_value(LAST_OUTCOME_KEY, outcome)
	battle.notify_character_resource_updated()
	return outcome


func _add_pity(battle, amount: int) -> int:
	var pity := GameState.add_character_run_state_int(PITY_KEY, amount)
	battle.notify_character_resource_updated()
	return pity


func _get_pity() -> int:
	return int(GameState.get_character_run_state_value(PITY_KEY, 0))


func _get_notice_id() -> String:
	return str(GameState.get_world_run_state_value("patch_notice_id", NOTICE_LIGHTWEIGHT))
