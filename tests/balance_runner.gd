extends Node
## 多专业、多种子、全难度的纯逻辑长局模拟，用真实战斗与奖励规则发现数值断层。

const MAJORS: Array[String] = ["computer", "law", "medicine", "finance", "arts"]
const SEEDS_PER_MAJOR := 8
const MAX_TURNS_PER_BATTLE := 40
const SKILL_PROFILES := [
	{"id": "skilled", "name": "熟练操作", "perfect": 0.35, "dodge": 0.3, "brace": 0.2},
	{"id": "regular", "name": "普通操作", "perfect": 0.18, "dodge": 0.22, "brace": 0.2},
	{"id": "cards_only", "name": "纯卡牌", "perfect": 0.0, "dodge": 0.0, "brace": 0.0},
	{"id": "random_cards", "name": "乱点卡牌", "perfect": 0.0, "dodge": 0.0, "brace": 0.0, "random_cards": true, "use_active_skill": false},
	{"id": "random_tap", "name": "乱点全流程", "perfect": 0.0, "dodge": 0.0, "brace": 0.0, "random_cards": true, "random_choices": true, "use_active_skill": false},
]
const ENCOUNTERS := [
	{"location": "teaching", "area": "classroom", "enemy": "gpa_anxiety"},
	{"location": "teaching", "area": "classroom", "enemy": "ai_interviewer"},
	{"location": "library", "area": "library", "enemy": "seat_grabber"},
	{"location": "library", "area": "library", "enemy": "paper_reviewer"},
	{"location": "dorm", "area": "dorm", "enemy": "all_nighter"},
	{"location": "dorm", "area": "dorm", "enemy": "all_nighter_king"},
	{"location": "cafeteria", "area": "cafeteria", "enemy": "client_phantom"},
	{"location": "sports", "area": "playground", "enemy": "sports_student"},
	{"location": "sports", "area": "playground", "enemy": "sports_ace"},
	{"location": "sports", "area": "playground", "enemy": "employment_pressure"},
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_ai_enabled := Settings.ai_enabled
	var previous_action_window_scale := Settings.action_window_scale
	var previous_save_enabled := GameState.run_save_enabled
	Settings.ai_enabled = false
	Settings.action_window_scale = 1.0
	GameState.run_save_enabled = false
	Achievements.save_enabled = false
	MetaProgression.save_enabled = false
	MetaProgression.reset_profile()

	var baseline_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var started_at := Time.get_ticks_usec()
	var reports := {}
	var simulated_runs := 0
	for profile in SKILL_PROFILES:
		for difficulty in GameState.DIFFICULTY_CATALOG.size():
			var report := _new_report()
			for major_id in MAJORS:
				report.major_clears[major_id] = 0
				for seed_offset in SEEDS_PER_MAJOR:
					var seed := 51000 + difficulty * 1000 + MAJORS.find(major_id) * 100 + seed_offset
					var result := _simulate_run(major_id, seed, difficulty, profile)
					_record_result(report, major_id, result)
					simulated_runs += 1
					if simulated_runs % 20 == 0:
						await get_tree().process_frame
			var report_key := "%s:%d" % [profile.id, difficulty]
			reports[report_key] = report
			_print_report(difficulty, report, str(profile.name))

	for _frame in 4:
		await get_tree().process_frame
	var memory_growth := int(Performance.get_monitor(Performance.MEMORY_STATIC)) - baseline_memory
	var elapsed_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
	print("BALANCE: 共模拟 %d 局 / %d 场上限，静态内存增长 %.2f MiB，耗时 %.1f ms" % [
		simulated_runs,
		simulated_runs * ENCOUNTERS.size(),
		float(memory_growth) / 1048576.0,
		elapsed_ms,
	])

	assert(
		simulated_runs == MAJORS.size() * SEEDS_PER_MAJOR * GameState.DIFFICULTY_CATALOG.size() * SKILL_PROFILES.size(),
		"长局模拟矩阵不完整"
	)
	for report_key in reports:
		var report: Dictionary = reports[report_key]
		assert(int(report.turn_caps) == 0, "%s 出现无法结束的战斗" % report_key)
		var is_random_tap: bool = report_key.begins_with("random_")
		assert(
			float(report.turns) / float(maxi(1, int(report.battles))) < (13.0 if is_random_tap else 8.0),
			"%s 场均回合过长，存在牌组停滞风险" % report_key
		)
	for profile in SKILL_PROFILES:
		var previous_clears := SEEDS_PER_MAJOR * MAJORS.size()
		for difficulty in GameState.DIFFICULTY_CATALOG.size():
			var report: Dictionary = reports["%s:%d" % [profile.id, difficulty]]
			assert(int(report.clears) <= previous_clears, "%s 的挑战阶梯通关率不应逆向上升" % profile.name)
			previous_clears = int(report.clears)

	assert(int(reports["skilled:0"].clears) == 40, "熟练操作下五专业应稳定通过标准生存")
	assert(int(reports["regular:0"].clears) >= 36, "普通操作下标准生存不应形成新手数值墙")
	assert(int(reports["cards_only:0"].clears) >= 26, "标准生存应保留纯卡牌构筑的通关路径")
	assert(int(reports["random_cards:0"].clears) <= 16, "标准生存不应允许乱点卡牌稳定通关")
	assert(int(reports["random_tap:0"].clears) <= 16, "标准生存不应允许乱点流程稳定通关")
	assert(int(reports["skilled:3"].clears) >= 16 and int(reports["skilled:3"].clears) <= 24, "最高挑战对熟练操作的目标通关率应为 40%–60%")
	for major_id in MAJORS:
		assert(int(reports["skilled:3"].major_clears[major_id]) >= 3, "最高挑战中专业失去熟练通关路径: %s" % major_id)
	assert(int(reports["regular:3"].clears) >= 6 and int(reports["regular:3"].clears) <= 14, "最高挑战对普通操作的目标通关率应为 15%–35%")
	assert(int(reports["cards_only:3"].clears) <= 4, "最高挑战应显著要求动作应对")
	assert(int(reports["random_cards:3"].clears) <= 1, "最高挑战不应允许乱点卡牌通关")
	assert(int(reports["random_tap:3"].clears) <= 1, "最高挑战不应允许乱点流程通关")
	assert(
		int(reports["regular:3"].clears) - int(reports["random_cards:3"].clears) >= 5,
		"最高挑战的答辩动作收益不足以改变通关结果"
	)
	assert(memory_growth <= 8 * 1024 * 1024, "480 局纯逻辑模拟后静态内存增长过高")

	Settings.ai_enabled = previous_ai_enabled
	Settings.action_window_scale = previous_action_window_scale
	GameState.run_save_enabled = previous_save_enabled
	MetaProgression.reset_profile()
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)


func _new_report() -> Dictionary:
	return {
		"runs": 0,
		"clears": 0,
		"battles": 0,
		"turns": 0,
		"turn_caps": 0,
		"hp_ratio_sum": 0.0,
		"major_clears": {},
		"failure_encounters": {},
	}


func _record_result(report: Dictionary, major_id: String, result: Dictionary) -> void:
	report.runs += 1
	report.battles += int(result.get("battles", 0))
	report.turns += int(result.get("turns", 0))
	if bool(result.get("clear", false)):
		report.clears += 1
		report.major_clears[major_id] += 1
		report.hp_ratio_sum += float(result.get("hp_ratio", 0.0))
	else:
		var encounter := str(result.get("failure_encounter", "unknown"))
		report.failure_encounters[encounter] = int(report.failure_encounters.get(encounter, 0)) + 1
	if bool(result.get("turn_cap", false)):
		report.turn_caps += 1


func _print_report(difficulty: int, report: Dictionary, profile_name: String) -> void:
	var clear_rate := float(report.clears) / float(maxi(1, int(report.runs)))
	var average_turns := float(report.turns) / float(maxi(1, int(report.battles)))
	var average_hp := float(report.hp_ratio_sum) / float(maxi(1, int(report.clears)))
	print("BALANCE: %s / %s %d/%d 通关（%.1f%%），场均 %.2f 回合，通关剩余生命 %.1f%%，专业 %s，失败点 %s" % [
		profile_name,
		GameState.get_difficulty_name(difficulty),
		report.clears,
		report.runs,
		clear_rate * 100.0,
		average_turns,
		average_hp * 100.0,
		str(report.major_clears),
		str(report.failure_encounters),
	])


func _simulate_run(major_id: String, seed: int, difficulty: int, profile: Dictionary) -> Dictionary:
	GameState.start_run(major_id, seed, difficulty)
	var total_turns := 0
	var battles_won := 0
	for encounter_index in ENCOUNTERS.size():
		var encounter: Dictionary = ENCOUNTERS[encounter_index]
		GameState.run_progress += 1
		_resolve_event(str(encounter.area), str(encounter.location), profile)
		GameState.run_events_resolved += 1
		GameState.day_count = maxi(GameState.day_count, 1 + int(GameState.run_events_resolved / 3))
		if GameState.run_hp <= 0:
			return _failed_result(battles_won, total_turns, str(encounter.enemy), false)

		var enemy_id := str(encounter.enemy)
		GameState.player_stats["current_enemy_id"] = enemy_id
		var battle_result := _simulate_battle(enemy_id, profile)
		total_turns += int(battle_result.turns)
		if not bool(battle_result.victory):
			return _failed_result(
				battles_won,
				total_turns,
				enemy_id,
				bool(battle_result.get("turn_cap", false))
			)

		var battle: Battle = battle_result.battle
		GameState.sync_from_battle_character(battle.player)
		var enemy: EnemyResource = Config.enemies[enemy_id]
		GameState.record_enemy_defeat(enemy.id, enemy.name, enemy.enemy_type)
		battles_won += 1
		if encounter_index < ENCOUNTERS.size() - 1:
			_claim_best_reward(profile)

	return {
		"clear": true,
		"battles": battles_won,
		"turns": total_turns,
		"hp_ratio": float(GameState.run_hp) / float(maxi(1, GameState.run_max_hp)),
		"failure_encounter": "",
		"turn_cap": false,
	}


func _failed_result(battles_won: int, turns: int, enemy_id: String, turn_cap: bool) -> Dictionary:
	return {
		"clear": false,
		"battles": battles_won,
		"turns": turns,
		"hp_ratio": 0.0,
		"failure_encounter": enemy_id,
		"turn_cap": turn_cap,
	}


func _resolve_event(area_id: String, location_id: String, profile: Dictionary) -> void:
	var rng := GameState.make_run_rng(
		"campus_event:%s" % location_id,
		GameState.run_events_resolved + GameState.day_count * 100
	)
	var event := EventHandler.pick_random_event(area_id, rng)
	if event == null:
		return
	var choice_index := _pick_random_event_choice(event, rng) if bool(profile.get("random_choices", false)) else _pick_event_choice(event)
	var handler := EventHandler.new(GameState.player_stats)
	handler.apply_event(event, choice_index)


func _pick_event_choice(event: EventResource) -> int:
	if event.choices.is_empty():
		return -1
	var best_index := 0
	var best_score := -INF
	for i in event.choices.size():
		var score := 0.0
		for effect in event.choices[i].get("effects", []):
			score += _score_event_effect(effect)
		if score > best_score:
			best_score = score
			best_index = i
	return best_index


func _pick_random_event_choice(event: EventResource, rng: RandomNumberGenerator) -> int:
	if event.choices.is_empty():
		return -1
	return rng.randi() % event.choices.size()


func _score_event_effect(effect: Dictionary) -> float:
	var value := float(effect.get("value", 0))
	match str(effect.get("type", "")):
		"heal": return value * (3.0 if GameState.run_hp < GameState.run_max_hp * 0.65 else 0.5)
		"damage": return -value * 3.0
		"spirit_damage": return -value * 1.5
		"stat_up": return value * 18.0
		"status": return 12.0 + float(effect.get("status_stacks", 1)) * 2.0
		"advance_pressure": return -value * 12.0
		"credits", "credit_points": return value * 0.2
		"set_flag": return 10.0
		"relic": return 35.0
	return 0.0


func _simulate_battle(enemy_id: String, profile: Dictionary) -> Dictionary:
	var player := GameState.create_battle_player()
	var battle := Battle.new(player, Config.enemies[enemy_id])
	var input_rng := GameState.make_run_rng("balance_input:%s" % enemy_id, GameState.run_battles_won)
	var turns := 0
	if bool(profile.get("use_active_skill", true)):
		battle.use_active_skill()
	while battle.state == Battle.BattleState.PLAYER_TURN and turns < MAX_TURNS_PER_BATTLE:
		turns += 1
		for _play in 30:
			var card_index := _pick_random_card_index(battle, input_rng) if bool(profile.get("random_cards", false)) else _pick_card_index(battle)
			if card_index < 0:
				break
			battle.play_card(card_index)
			if battle.state != Battle.BattleState.PLAYER_TURN:
				break
		if battle.state != Battle.BattleState.PLAYER_TURN:
			break
		var defense_context := battle.begin_defense_window()
		if bool(defense_context.get("enabled", false)):
			battle.resolve_defense_window(_pick_defense_outcome(input_rng, profile, defense_context), defense_context)
		else:
			battle.end_player_turn()
	return {
		"victory": battle.state == Battle.BattleState.PLAYER_WON,
		"battle": battle,
		"turns": turns,
		"turn_cap": turns >= MAX_TURNS_PER_BATTLE and battle.state == Battle.BattleState.PLAYER_TURN,
	}


func _pick_defense_outcome(rng: RandomNumberGenerator, profile: Dictionary, context: Dictionary) -> String:
	var roll := rng.randf()
	var precision_factor := clampf(float(context.get("perfect_width", 0.1)) / 0.1, 0.5, 1.5)
	var response_factor := clampf(float(context.get("duration", 1.7)) / 1.7, 0.5, 1.35)
	var perfect_chance := float(profile.get("perfect", 0.0)) * precision_factor
	var dodge_chance := float(profile.get("dodge", 0.0)) * response_factor
	var brace_chance := float(profile.get("brace", 0.0)) * response_factor
	if roll < perfect_chance:
		return "perfect"
	if roll < perfect_chance + dodge_chance:
		return "dodge"
	if roll < perfect_chance + dodge_chance + brace_chance:
		return "brace"
	return "miss"


func _pick_card_index(battle: Battle) -> int:
	var best_index := -1
	var best_score := -INF
	var response_index := -1
	var response_score := -INF
	for i in battle.player.hand.size():
		if not battle.can_play_card(i):
			continue
		var card = battle.player.hand[i]
		var score := _score_card(card, battle)
		if not battle.is_intent_response_met() and battle.is_card_recommended(card):
			if score > response_score:
				response_score = score
				response_index = i
		if score > best_score:
			best_score = score
			best_index = i
	return response_index if response_index >= 0 else best_index


func _pick_random_card_index(battle: Battle, rng: RandomNumberGenerator) -> int:
	var playable_indices: Array[int] = []
	for i in battle.player.hand.size():
		if battle.can_play_card(i):
			playable_indices.append(i)
	if playable_indices.is_empty():
		return -1
	return playable_indices[rng.randi() % playable_indices.size()]


func _score_card(card: Resource, battle: Battle = null) -> float:
	var score := 2.0 if int(card.cost) == 0 else 0.0
	for effect in card.effects:
		var value := float(effect.value)
		match str(effect.type):
			"damage": score += value * 5.0
			"conditional_damage":
				var conditional_value := value
				if battle != null and battle.enemy.has_status(str(effect.status_id)):
					conditional_value = float(effect.params.get("real_value", value * 2.0))
				score += conditional_value * 5.0
			"scaled_damage": score += value * 5.0 + 20.0
			"damage_per_debuff":
				var debuff_stacks := 1
				if battle != null:
					debuff_stacks = 0
					for status_id in battle.enemy.statuses:
						if Status.is_debuff(str(status_id)):
							debuff_stacks += battle.enemy.get_status_stacks(str(status_id))
				score += value * float(maxi(1, debuff_stacks)) * 5.0
			"shield": score += value * 2.2
			"heal":
				var missing_ratio := 1.0
				if battle != null:
					missing_ratio = 1.0 - float(battle.player.hp) / float(maxi(1, battle.player.max_hp))
				score += value * (1.0 + missing_ratio * 4.0)
			"draw": score += value * 8.0
			"energy": score += value * 10.0
			"delay": score += value * 22.0
			"status", "debuff", "buff": score += _score_status_effect(effect, battle)
			"purge": score += value * 5.0
			"reveal_intent": score += 2.0
	if str(card.type) == "finisher":
		score += 15.0
	return score / float(maxi(1, int(card.cost)))


func _score_status_effect(effect: Resource, battle: Battle) -> float:
	var stacks := float(effect.status_stacks)
	var status_id := str(effect.status_id)
	if str(effect.target) == "self" or str(effect.type) == "buff":
		return stacks * (10.0 if status_id == "adrenaline" else 7.0)
	if battle != null and battle.enemy.has_status(status_id) and status_id in ["vulnerable", "bug"]:
		return 2.0
	var status_values := {
		"vulnerable": 42.0,
		"bug": 34.0,
		"举证失败": 30.0,
		"pressure": 24.0,
		"bleed": 22.0,
	}
	return float(status_values.get(status_id, 10.0)) * stacks


func _claim_best_reward(profile: Dictionary) -> void:
	var rng := GameState.make_run_rng("reward:%s" % GameState.player_major_id, GameState.run_battles_won)
	var rewards := RewardGenerator.generate_rewards(GameState.player_major_id, rng, GameState.last_reward_is_elite)
	if rewards.is_empty():
		return
	if bool(profile.get("random_choices", false)):
		var input_rng := GameState.make_run_rng("balance_reward_input:%s" % GameState.player_major_id, GameState.run_battles_won)
		_apply_reward(rewards[input_rng.randi() % rewards.size()], profile, input_rng)
		return
	var best_reward: Dictionary = rewards[0]
	var best_score := -INF
	for reward in rewards:
		var score := _score_reward(reward)
		if score > best_score:
			best_score = score
			best_reward = reward
	_apply_reward(best_reward, profile)


func _score_reward(reward: Dictionary) -> float:
	match int(reward.get("type", -1)):
		RewardGenerator.RewardType.CARD:
			var card_score := 0.0
			for card in reward.get("options", []):
				card_score = maxf(card_score, _score_card(card))
			return 35.0 + card_score
		RewardGenerator.RewardType.STAT_UP:
			return 48.0 + float(reward.get("value", 1)) * 10.0
		RewardGenerator.RewardType.BUFF:
			return 42.0
		RewardGenerator.RewardType.HEAL:
			var missing_hp := GameState.run_max_hp - GameState.run_hp
			return minf(float(missing_hp), float(reward.get("value", 0))) * 5.0
		RewardGenerator.RewardType.CREDITS:
			return 10.0
		RewardGenerator.RewardType.REMOVE_PRESSURE:
			return float(GameState.run_progress) * 7.0 + float(reward.get("value", 1)) * 8.0
		RewardGenerator.RewardType.RELIC:
			return 65.0
	return 0.0


func _apply_reward(reward: Dictionary, profile: Dictionary = {}, rng: RandomNumberGenerator = null) -> void:
	match int(reward.get("type", -1)):
		RewardGenerator.RewardType.CARD:
			var options: Array = reward.get("options", [])
			if options.is_empty():
				return
			if bool(profile.get("random_choices", false)) and rng != null:
				GameState.add_card_to_deck(str(options[rng.randi() % options.size()].id))
				return
			var best_card = options[0]
			var best_score := _score_card(best_card)
			for card in options.slice(1):
				var score := _score_card(card)
				if score > best_score:
					best_score = score
					best_card = card
			GameState.add_card_to_deck(str(best_card.id))
		RewardGenerator.RewardType.STAT_UP:
			var stat_name := str(reward.get("stat", ""))
			var value := int(reward.get("value", 1))
			GameState.permanent_stats[stat_name] = int(GameState.permanent_stats.get(stat_name, 0)) + value
			if stat_name == "体能":
				GameState.run_max_hp += value * 3
				GameState.run_hp += value * 3
			elif stat_name == "抗压":
				GameState.run_max_spirit += value * 5
				GameState.run_spirit += value * 5
		RewardGenerator.RewardType.BUFF:
			GameState.add_pending_buff(str(reward.get("status_id", "")), int(reward.get("stacks", 1)))
		RewardGenerator.RewardType.HEAL:
			GameState.heal_run(int(reward.get("value", 0)))
		RewardGenerator.RewardType.CREDITS:
			GameState.credits += int(reward.get("credits", 0))
			GameState.credit_points += int(reward.get("credit_points", 0))
		RewardGenerator.RewardType.REMOVE_PRESSURE:
			GameState.run_progress = maxi(0, GameState.run_progress - int(reward.get("value", 0)))
		RewardGenerator.RewardType.RELIC:
			GameState.add_relic(str(reward.get("relic_id", "")))
