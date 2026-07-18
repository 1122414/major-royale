class_name EventHandler
extends RefCounted

## 处理地图事件效果（读写 GameState 一局持久化状态）。

const StatLex := preload("res://src/logic/stat_lexicon.gd")

signal event_resolved(message: String)

var player_stats: Dictionary


func _init(stats: Dictionary) -> void:
	player_stats = stats


func apply_event(event: EventResource, choice_index: int = -1) -> String:
	var effects: Array[Dictionary] = []
	if choice_index >= 0 and choice_index < event.choices.size():
		effects = event.choices[choice_index].get("effects", [])
	else:
		effects = event.effects

	var messages: Array[String] = []
	for effect in effects:
		messages.append(_apply_effect(effect))
	return "\n".join(messages)


func apply_rest() -> String:
	var heal_amount := 15 + int(GameState.get_effective_stat("资源") / 2)
	# 学分可兑换额外回复
	if GameState.credits >= 20:
		GameState.credits -= 10
		heal_amount += 5
	var healed := GameState.heal_run(heal_amount)
	var full := GameState.run_hp >= GameState.run_max_hp
	Achievements.try_after_rest(full)
	return "【补给】恢复 %d 生命（当前 %d/%d）。学分余额 %d。" % [
		healed, GameState.run_hp, GameState.run_max_hp, GameState.credits
	]


func _apply_effect(effect: Dictionary) -> String:
	var type: String = effect.get("type", "")
	var value: int = effect.get("value", 0)

	if type == "heal":
		var healed := GameState.heal_run(value)
		Achievements.try_after_rest(GameState.run_hp >= GameState.run_max_hp)
		return "【恢复】生命 +%d（当前 %d/%d）" % [healed, GameState.run_hp, GameState.run_max_hp]
	elif type == "damage":
		var dealt := GameState.damage_run(value)
		return "【受伤】生命 -%d（当前 %d/%d）" % [dealt, GameState.run_hp, GameState.run_max_hp]
	elif type == "spirit_damage":
		GameState.lose_spirit_run(value)
		return "【精神】精神 -%d（当前 %d/%d）" % [value, GameState.run_spirit, GameState.run_max_spirit]
	elif type == "stat_up":
		var stat_name: String = effect.get("stat", "")
		var stats: Dictionary = GameState.permanent_stats
		stats[stat_name] = int(stats.get(stat_name, 0)) + value
		GameState.permanent_stats = stats
		if stat_name == "体能":
			GameState.run_max_hp += 3 * value
			GameState.run_hp += 3 * value
		elif stat_name == "抗压":
			GameState.run_max_spirit += 5 * value
			GameState.run_spirit += 5 * value
		return "【属性】%s +%d\n　↳ %s" % [stat_name, value, StatLex.stat_text(stat_name)]
	elif type == "status":
		var status_id: String = effect.get("status_id", "")
		var stacks: int = effect.get("status_stacks", 1)
		GameState.add_pending_buff(status_id, stacks)
		var info := Status.get_status_info(status_id)
		return "【状态】下场战斗获得 %s ×%d\n　↳ %s" % [
			info.get("name", status_id), stacks, info.get("description", "")
		]
	elif type == "advance_pressure":
		GameState.run_progress += value
		return "【压力圈】进度 +%d（当前 %d，非Boss敌伤+%d%%）" % [
			value, GameState.run_progress, mini(40, GameState.run_progress * 5)
		]
	elif type == "credits":
		GameState.credits += value
		return "【学分】+%d（当前 %d）" % [value, GameState.credits]
	elif type == "credit_points":
		GameState.credit_points += value
		return "【信用点】+%d（当前 %d）" % [value, GameState.credit_points]
	else:
		return "无效果"


static func pick_random_event(area_id: String, rng: RandomNumberGenerator) -> EventResource:
	var candidates: Array[EventResource] = []
	for event_id in Config.events:
		var event: EventResource = Config.events[event_id]
		if event.area == area_id or event.area.is_empty():
			candidates.append(event)
	if candidates.is_empty():
		return null
	return candidates[rng.randi() % candidates.size()]
