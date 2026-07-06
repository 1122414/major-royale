class_name EventHandler
extends RefCounted

## 处理地图事件效果。

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
	var player = GameState.player_stats.get("battle_player") as Character
	if player != null:
		player.heal(heal_amount)
	return "在补给点休息，恢复了 %d 点生命。" % heal_amount


func _apply_effect(effect: Dictionary) -> String:
	var type: String = effect.get("type", "")
	var value: int = effect.get("value", 0)
	var player = GameState.player_stats.get("battle_player") as Character

	if type == "heal":
		if player != null:
			player.heal(value)
		return "恢复 %d 点生命。" % value
	elif type == "damage":
		if player != null:
			player.take_damage(value)
		return "受到 %d 点伤害。" % value
	elif type == "spirit_damage":
		if player != null:
			player.lose_spirit(value)
		return "失去 %d 点精神。" % value
	elif type == "stat_up":
		var stat_name: String = effect.get("stat", "")
		var stats: Dictionary = player_stats.get("permanent_stats", {})
		stats[stat_name] = stats.get(stat_name, 0) + value
		player_stats["permanent_stats"] = stats
		return "%s +%d" % [stat_name, value]
	elif type == "status":
		var status_id: String = effect.get("status_id", "")
		var stacks: int = effect.get("status_stacks", 1)
		if player != null:
			player.add_status(status_id, stacks)
		return "获得 %s x%d" % [Status.get_status_info(status_id).get("name", status_id), stacks]
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
