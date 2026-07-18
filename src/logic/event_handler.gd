class_name EventHandler
extends RefCounted

## 处理地图事件效果（读写 GameState 一局持久化状态）。

const StatLex := preload("res://src/logic/stat_lexicon.gd")
const RelicCat := preload("res://src/logic/relic.gd")

signal event_resolved(message: String)

var player_stats: Dictionary


func _init(stats: Dictionary) -> void:
	player_stats = stats


func apply_event(event: EventResource, choice_index: int = -1) -> String:
	var effects: Array[Dictionary] = []
	var raw_effects: Array = event.effects
	if choice_index >= 0 and choice_index < event.choices.size():
		raw_effects = event.choices[choice_index].get("effects", [])
	for effect in raw_effects:
		if effect is Dictionary:
			effects.append(effect)

	var messages: Array[String] = []
	for effect in effects:
		messages.append(_apply_effect(effect))
	GameState.add_event_flag("event:%s" % event.id)
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
	elif type == "set_flag":
		var flag_id := str(effect.get("flag", ""))
		GameState.add_event_flag(flag_id)
		return "【线索】%s" % str(effect.get("message", "这次选择会影响后续校园事件。"))
	elif type == "relic":
		var relic_id := str(effect.get("relic_id", ""))
		if not RelicCat.RELICS.has(relic_id):
			return "【遗物】未知遗物，未写入本局"
		var already_owned := GameState.has_relic(relic_id)
		GameState.add_relic(relic_id)
		var info := RelicCat.get_info(relic_id)
		return "【遗物】%s%s\n　↳ %s" % [
			info.get("name", relic_id),
			"（已持有）" if already_owned else "",
			info.get("desc", ""),
		]
	else:
		return "无效果"


static func pick_random_event(area_id: String, rng: RandomNumberGenerator) -> EventResource:
	var candidates: Array[EventResource] = []
	var priority_candidates: Array[EventResource] = []
	var completed_candidates: Array[EventResource] = []
	for event_id in Config.events:
		var event: EventResource = Config.events[event_id]
		if event.area != area_id and not event.area.is_empty():
			continue
		var requirements_met := true
		for required_flag in event.requires_flags:
			if not GameState.has_event_flag(required_flag):
				requirements_met = false
				break
		if not requirements_met:
			continue
		if GameState.has_event_flag("event:%s" % event.id):
			completed_candidates.append(event)
			continue
		candidates.append(event)
		if not event.priority_flags.is_empty():
			var priority_met := true
			for priority_flag in event.priority_flags:
				if not GameState.has_event_flag(priority_flag):
					priority_met = false
					break
			if priority_met:
				priority_candidates.append(event)
	if not priority_candidates.is_empty():
		candidates = priority_candidates
	if candidates.is_empty():
		candidates = completed_candidates
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: EventResource, b: EventResource) -> bool: return a.id < b.id)
	return candidates[rng.randi() % candidates.size()]
