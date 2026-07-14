class_name EventHandler
extends RefCounted

## 处理地图事件效果（读写 GameState 一局持久化状态）。

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
	var heal_amount := 15
	var healed := GameState.heal_run(heal_amount)
	return "在补给点休息，恢复了 %d 点生命。（当前 %d/%d）" % [healed, GameState.run_hp, GameState.run_max_hp]


func _apply_effect(effect: Dictionary) -> String:
	var type: String = effect.get("type", "")
	var value: int = effect.get("value", 0)

	if type == "heal":
		var healed := GameState.heal_run(value)
		return "恢复 %d 点生命。（当前 %d/%d）" % [healed, GameState.run_hp, GameState.run_max_hp]
	elif type == "damage":
		var dealt := GameState.damage_run(value)
		return "受到 %d 点伤害。（当前 %d/%d）" % [dealt, GameState.run_hp, GameState.run_max_hp]
	elif type == "spirit_damage":
		GameState.lose_spirit_run(value)
		return "失去 %d 点精神。（当前 %d/%d）" % [value, GameState.run_spirit, GameState.run_max_spirit]
	elif type == "stat_up":
		var stat_name: String = effect.get("stat", "")
		var stats: Dictionary = GameState.permanent_stats
		stats[stat_name] = int(stats.get(stat_name, 0)) + value
		GameState.permanent_stats = stats
		if stat_name == "体能":
			GameState.run_max_hp += 3 * value
		elif stat_name == "抗压":
			GameState.run_max_spirit += 5 * value
		return "%s +%d" % [stat_name, value]
	elif type == "status":
		var status_id: String = effect.get("status_id", "")
		var stacks: int = effect.get("status_stacks", 1)
		GameState.add_pending_buff(status_id, stacks)
		return "获得 %s x%d（下场战斗生效）" % [Status.get_status_info(status_id).get("name", status_id), stacks]
	elif type == "advance_pressure":
		GameState.run_progress += value
		return "压力圈推进，当前进度 %d" % GameState.run_progress
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
