class_name Battle
extends RefCounted

## 战斗状态。
enum BattleState {
	PLAYER_TURN,
	ENEMY_TURN,
	PLAYER_WON,
	PLAYER_LOST,
}

signal battle_ended(victory: bool)
signal turn_changed(is_player_turn: bool)
signal hand_updated
signal energy_updated
signal skill_used(skill_name: String)
signal ai_decision_requested(context: Dictionary)
signal boss_phase_changed(phase_name: String)

const BASE_DRAW := 5
const BASE_ENERGY := 3
const MAX_HAND_SIZE := 10

var player: Character
var enemy: Character
var enemy_resource: Resource

var energy: int = BASE_ENERGY
var max_energy: int = BASE_ENERGY
var turn_count: int = 1
var state: BattleState = BattleState.PLAYER_TURN

var _effect_processor: CardEffectProcessor
var _enemy_intent: Dictionary = {}
var _enemy_delay: int = 0
var _reveal_intent: bool = false
var _skill_used_this_battle: bool = false
var _law_passive_used: bool = false
var _boss_current_phase: int = 0
var _thesis_clip_ready: bool = true
var _pending_ai_context: Dictionary = {}


func _init(p_player: Character, p_enemy_resource: Resource) -> void:
	player = p_player
	enemy_resource = p_enemy_resource
	enemy = Character.new(p_enemy_resource.id, p_enemy_resource.name, p_enemy_resource.hp)
	_effect_processor = CardEffectProcessor.new(self)
	_effect_processor.intent_revealed.connect(reveal_intent)
	# 专注≥8：最大能量 +1；精英徽章再 +1
	max_energy = BASE_ENERGY + (1 if GameState.get_effective_stat("专注") >= 8 else 0)
	if GameState.has_relic("elite_badge"):
		max_energy += 1
	energy = max_energy
	_apply_battle_start_relics()
	_start_player_turn()
	# 表达≥7：开局揭示意图
	if GameState.get_effective_stat("表达") >= 7:
		reveal_intent()


func _apply_battle_start_relics() -> void:
	if GameState.has_relic("flash_drive"):
		player.draw_cards(1, MAX_HAND_SIZE)
	if GameState.has_relic("lucky_eraser"):
		_remove_body_debuffs(player)
		for status_id in player.statuses.keys():
			if Status.is_debuff(status_id):
				player.remove_status(status_id)
				break


func play_card(card_index: int) -> bool:
	if not can_play_card(card_index):
		return false

	var card: Resource = player.hand[card_index]
	var cost := get_card_cost(card_index)

	energy -= cost
	if GameState.has_relic("thesis_clip") and _thesis_clip_ready and card.cost > 0:
		_thesis_clip_ready = false
	player.hand.remove_at(card_index)
	player.discard_pile.append(card)
	GameState.run_cards_played += 1

	_effect_processor.process_card(card, player, enemy)

	# 科学计算器：攻击额外伤害
	if GameState.has_relic("scientific_calculator") and str(card.type) == "attack":
		enemy.take_damage(2)
		GameState.run_damage_dealt += 2

	# 医学被动：攻击有概率弱点打击
	if player.major_id == "medicine" and card.type == "attack" and randf() < 0.3:
		enemy.take_damage(3)

	# 艺术被动：控制牌概率额外抽牌
	if player.major_id == "arts" and str(card.type) == "control" and randf() < 0.3:
		player.draw_cards(1, MAX_HAND_SIZE)

	# 敌人反击姿态
	if card.type == "attack" and enemy.has_status("counter"):
		_apply_damage_to_player(enemy.get_status_stacks("counter") * 3)
		enemy.remove_status("counter")

	energy_updated.emit()
	hand_updated.emit()

	_check_end_conditions()
	_update_boss_phase()
	return true


func can_play_card(card_index: int) -> bool:
	if state != BattleState.PLAYER_TURN:
		return false
	if card_index < 0 or card_index >= player.hand.size():
		return false
	return get_card_cost(card_index) <= energy


func get_card_cost(card_index: int) -> int:
	if card_index < 0 or card_index >= player.hand.size():
		return 0
	var card: Resource = player.hand[card_index]
	var cost: int = card.cost
	if GameState.has_relic("thesis_clip") and _thesis_clip_ready:
		cost = maxi(0, cost - 1)
	return cost


func use_active_skill() -> bool:
	if state != BattleState.PLAYER_TURN or _skill_used_this_battle:
		return false

	var major: MajorResource = Config.majors.get(player.major_id)
	if major == null:
		return false

	var skill_id: String = major.active_skill.get("id", "")
	match skill_id:
		"code_injection":
			# 计算机：注入 Bug + 抽牌 + 揭示意图（纯增益向控场）
			enemy.add_status("bug", 2)
			player.draw_cards(1, MAX_HAND_SIZE)
			reveal_intent()
			skill_used.emit("代码注入")
		"objection":
			# 法学：打断行动 + 护盾 + 举证失败
			_enemy_intent = {"id": "stunned", "description": "被异议打断，本回合无法行动。", "value": 0}
			enemy.add_status("举证失败", 1)
			player.gain_shield(6)
			skill_used.emit("异议！")
		"emergency_suture":
			# 医学：强力治疗 + 清负面 + 抗压
			player.heal(15)
			_remove_body_debuffs(player)
			player.add_status("resistance", 1)
			skill_used.emit("紧急缝合")
		"leverage":
			# 金融：临时能量 + 肾上腺素（不再上压力）
			energy += 1
			player.add_status("adrenaline", 1)
			player.gain_shield(3)
			skill_used.emit("杠杆加仓")
		"inspiration":
			# 艺术：抽牌 + 清压力 + 小护盾
			player.draw_cards(2, MAX_HAND_SIZE)
			if player.has_status("pressure"):
				var stacks := player.get_status_stacks("pressure")
				player.remove_status("pressure")
				if stacks > 1:
					player.add_status("pressure", stacks - 1)
			player.gain_shield(4)
			skill_used.emit("灵感爆发")
		_:
			return false

	_skill_used_this_battle = true
	energy_updated.emit()
	hand_updated.emit()
	_check_end_conditions()
	return true


func _remove_body_debuffs(character: Character) -> void:
	var body_debuffs := ["bleed", "pressure"]
	for status_id in body_debuffs:
		character.remove_status(status_id)


func end_player_turn() -> void:
	if state != BattleState.PLAYER_TURN:
		return

	player.discard_hand()
	state = BattleState.ENEMY_TURN
	turn_changed.emit(false)
	_execute_enemy_turn()


func _execute_enemy_turn() -> void:
	if state != BattleState.ENEMY_TURN:
		return

	# 延迟处理
	if _enemy_delay > 0:
		_enemy_delay -= 1
		_end_enemy_turn()
		return

	# 被眩晕或 Bug 导致行动失败
	if _enemy_intent.get("id", "") == "stunned" or (enemy.has_status("bug") and randf() < 0.25):
		_enemy_intent = {}
		_end_enemy_turn()
		return

	# 结算流血等持续伤害
	if enemy.has_status("bleed"):
		enemy.take_damage(enemy.get_status_stacks("bleed") * Status.STATUS_DATABASE["bleed"].get("tick_damage", 3))
		_check_end_conditions()
		if state != BattleState.ENEMY_TURN:
			return

	# 执行意图
	var action := _enemy_intent
	match action.get("id", ""):
		"attack":
			var damage: int = action.get("value", 5)
			if enemy.has_status("charged"):
				damage *= 2
				enemy.remove_status("charged")
			if enemy.has_status("举证失败"):
				damage = maxi(1, damage / 2)
				enemy.remove_status("举证失败")
			_apply_damage_to_player(damage)
		"heavy_attack":
			var damage: int = action.get("value", 10)
			if enemy.has_status("举证失败"):
				damage = maxi(1, damage / 2)
				enemy.remove_status("举证失败")
			_apply_damage_to_player(damage)
		"shield":
			enemy.gain_shield(action.get("value", 5))
		"heal":
			enemy.heal(action.get("value", 5))
		"stack_pressure":
			player.add_status("pressure", action.get("value", 1))
		"ask_algorithm":
			player.add_status("pressure", 2)
			_apply_damage_to_player(5)
		"ask_ethics":
			player.add_status("pressure", 1)
		"resume_challenge":
			player.lose_spirit(10)
			_apply_damage_to_player(4)
		"praise_then_pressure":
			player.draw_cards(1)
			player.add_status("pressure", 2)
		"silent_observe":
			enemy.gain_shield(8)
		"reject_core_card":
			player.add_status("pressure", 2)
		"demand_revision":
			player.discard_hand()
			player.draw_cards(2)
		"question_method":
			player.add_status("pressure", 2)
			_apply_damage_to_player(3)
		"accept_minor":
			enemy.gain_shield(8)
			player.add_status("resistance", 1)
		"desk_reject":
			_apply_damage_to_player(12)
			enemy.add_status("vulnerable", 1)
		"charge":
			enemy.add_status("charged", maxi(1, int(action.get("value", 1))))
		"counter":
			enemy.add_status("counter", maxi(1, int(action.get("value", 2))))
		"defend":
			enemy.gain_shield(action.get("value", 8))
		"hand_limit":
			# 群面混战：限制手牌，弃掉多余牌
			var limit: int = int(action.get("value", 3))
			while player.hand.size() > limit:
				var card = player.hand.pop_back()
				player.discard_pile.append(card)
			player.add_status("pressure", 1)
		"bleed_attack":
			_apply_damage_to_player(action.get("value", 4))
			player.add_status("bleed", 1)

	_check_end_conditions()
	if state == BattleState.PLAYER_WON or state == BattleState.PLAYER_LOST:
		return

	_end_enemy_turn()


func _apply_damage_to_player(damage: int) -> void:
	# 压力圈：每点进度 +5% 敌伤，上限 +40%（Boss 不受此加成）
	var enemy_id := str(GameState.player_stats.get("current_enemy_id", ""))
	var is_boss := enemy_id == "employment_pressure"
	if not is_boss:
		var mult := 1.0 + mini(0.4, float(GameState.run_progress) * 0.05)
		if GameState.has_relic("noise_cancelling"):
			mult = 1.0 + (mult - 1.0) * 0.5
		damage = int(round(float(damage) * mult))

	player.take_damage(damage)

	# 法学被动：首次致命伤保留 1 点生命
	if player.major_id == "law" and not _law_passive_used and player.hp <= 0:
		player.hp = 1
		player.gain_shield(10)
		_law_passive_used = true

	# 敌人反击
	if player.has_status("counter"):
		enemy.take_damage(player.get_status_stacks("counter") * 3)
		player.remove_status("counter")


func _end_enemy_turn() -> void:
	turn_count += 1
	_start_player_turn()


func _start_player_turn() -> void:
	state = BattleState.PLAYER_TURN
	energy = max_energy
	player.reset_shield()
	_thesis_clip_ready = true

	if GameState.has_relic("coffee_thermos"):
		player.gain_shield(2)
	if turn_count == 1 and GameState.has_relic("sticky_notes"):
		player.gain_shield(5)

	# 计算机被动：生命低于 40% 时额外抽 1 张（不再扣精神）
	var draw_amount := BASE_DRAW
	if player.major_id == "computer" and player.hp < player.max_hp * 0.4:
		draw_amount += 1

	# 压力影响：每 4 层压力少抽 1 张
	var pressure := player.get_status_stacks("pressure")
	draw_amount = maxi(1, draw_amount - pressure / 4)

	# 创造：额外抽牌概率
	var create_stat := GameState.get_effective_stat("创造")
	if randf() < float(create_stat) * 0.03:
		draw_amount += 1

	player.draw_cards(draw_amount, MAX_HAND_SIZE)
	_decide_enemy_intent()
	_update_boss_phase()
	turn_changed.emit(true)
	energy_updated.emit()
	hand_updated.emit()


func _decide_enemy_intent() -> void:
	if enemy_resource.is_ai_native and Settings.ai_enabled:
		# 使用本地兜底作为默认意图，并触发 AI 请求
		var context := _build_ai_context()
		_pending_ai_context = context
		var fallback := FallbackAI.decide(context)
		_enemy_intent = fallback
		_enemy_intent["value"] = _map_ai_action_to_value(fallback["action_id"])
		ai_decision_requested.emit(context)
		return

	var actions := _get_current_enemy_actions()
	if actions.is_empty():
		_enemy_intent = {"id": "attack", "value": 5}
		return

	var action := actions[randi() % actions.size()] as Dictionary
	_enemy_intent = action.duplicate()
	_reveal_intent = false


func request_current_ai_decision() -> void:
	if state != BattleState.PLAYER_TURN or _pending_ai_context.is_empty():
		return
	ai_decision_requested.emit(_pending_ai_context.duplicate(true))


func set_ai_decision(action_id: String, intent_text: String, ending_flag: String) -> void:
	if state != BattleState.PLAYER_TURN:
		return
	_pending_ai_context.clear()
	_enemy_intent = {
		"id": action_id,
		"description": intent_text,
		"value": _map_ai_action_to_value(action_id),
		"ending_flag": ending_flag,
	}
	_reveal_intent = true


func _build_ai_context() -> Dictionary:
	var visible_status: Array[String] = []
	for status_id in player.statuses.keys():
		visible_status.append(status_id)

	var last_actions: Array[String] = []
	for card in player.discard_pile.slice(-3, player.discard_pile.size()):
		last_actions.append(card.name)

	var allowed_actions: Array[String] = []
	for action in enemy_resource.actions:
		allowed_actions.append(action.get("id", ""))

	return {
		"enemy": enemy_resource.name,
		"player_major": Config.majors[player.major_id].name if Config.majors.has(player.major_id) else player.major_id,
		"player_hp": player.hp,
		"player_spirit": player.spirit,
		"visible_player_status": visible_status,
		"last_player_actions": last_actions,
		"allowed_actions": allowed_actions,
		"prompt_key": enemy_resource.ai_prompt_key,
	}


func _map_ai_action_to_value(action_id: String) -> int:
	match action_id:
		"ask_algorithm", "resume_challenge", "heavy_attack", "desk_reject": return 10
		"question_method", "reject_core_card": return 5
		"ask_ethics", "praise_then_pressure", "silent_observe", "accept_minor", "demand_revision": return 0
	return 5


func _get_current_enemy_actions() -> Array:
	if enemy_resource.enemy_type != "boss":
		return enemy_resource.actions

	var phases: Array = enemy_resource.phases
	if phases.is_empty():
		return enemy_resource.actions

	var hp_ratio := float(enemy.hp) / float(enemy.max_hp)
	for i in phases.size():
		var phase := phases[i] as Dictionary
		var threshold: float = phase.get("threshold", 0.0)
		if hp_ratio >= threshold and i >= _boss_current_phase:
			if i != _boss_current_phase:
				_boss_current_phase = i
				boss_phase_changed.emit(phase.get("name", "阶段 %d" % (i + 1)))
			return phase.get("actions", [])
	var last_phase := phases[phases.size() - 1] as Dictionary
	return last_phase.get("actions", [])


func _update_boss_phase() -> void:
	if enemy_resource.enemy_type != "boss":
		return
	_get_current_enemy_actions()


func get_enemy_intent_text() -> String:
	return _enemy_intent.get("description", "敌人正在准备行动...")


func get_enemy_intent_id() -> String:
	return str(_enemy_intent.get("id", ""))


func delay_enemy(turns: int) -> void:
	_enemy_delay += turns


func reveal_intent() -> void:
	_reveal_intent = true


func _check_end_conditions() -> void:
	if not enemy.is_alive():
		state = BattleState.PLAYER_WON
		battle_ended.emit(true)
	elif not player.is_alive():
		state = BattleState.PLAYER_LOST
		battle_ended.emit(false)


func get_reward_card_ids() -> Array[String]:
	var candidates := ["strike", "defend", "draw_card"]
	return candidates
