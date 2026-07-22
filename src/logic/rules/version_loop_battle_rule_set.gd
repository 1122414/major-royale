extends "res://src/logic/rules/battle_rule_set.gd"

## 版本回环的第一轮规则：公告影响整场战斗，维护时钟推进世界节奏。

const NOTICE_LIGHTWEIGHT := "lightweight_update"
const NOTICE_NUMERIC := "numeric_inflation"
const NOTICE_FIXED := "known_issue_fix"

var _lightweight_discount_available := true


func get_id() -> String:
	return "version_loop"


func on_battle_started(battle) -> void:
	if _get_notice_id() == NOTICE_FIXED:
		# 抗压会抵消下一次完整负面施加，正好对应“第一个自身负面无效”。
		battle.player.add_status("resistance", 1)


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


func modify_card_damage(_battle, card: Resource, _caster, _target, amount: int) -> int:
	if _get_notice_id() == NOTICE_NUMERIC and int(card.cost) >= 2:
		return amount + 4
	return amount


func _get_notice_id() -> String:
	return str(GameState.get_world_run_state_value("patch_notice_id", NOTICE_LIGHTWEIGHT))
