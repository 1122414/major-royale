extends RefCounted

## 世界战斗规则接口。Battle 只调用这些稳定钩子，不感知具体世界、角色或遗物名称。

func get_id() -> String:
	return "default"


func get_starting_energy_bonus(_battle) -> int:
	return 0


func on_battle_started(_battle) -> void:
	pass


func get_card_cost(_battle, _card: Resource, base_cost: int) -> int:
	return base_cost


func on_card_played(_battle, _card: Resource, _shield_before_card: int) -> void:
	pass


func use_active_skill(_battle) -> String:
	return ""


func on_player_turn_started(_battle) -> void:
	pass


func modify_player_draw(_battle, draw_amount: int, _has_draw_override: bool) -> int:
	return draw_amount


func modify_pressure_damage_multiplier(_battle, multiplier: float) -> float:
	return multiplier


func modify_shield_amount(_battle, _caster, _target, amount: int) -> int:
	return amount


func modify_heal_amount(_battle, _caster, _target, amount: int) -> int:
	return amount


func after_heal(_battle, _caster, _target, _actual_healed: int, _requested_heal: int) -> void:
	pass


func on_player_damaged(_battle) -> void:
	pass
