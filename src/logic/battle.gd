class_name Battle
extends RefCounted

const WorldBattleRuleFactory := preload("res://src/logic/rules/world_battle_rule_factory.gd")

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
signal character_resource_updated
signal world_rule_feedback(text: String)
signal world_choice_requested(context: Dictionary)

const BASE_DRAW := 5
const BASE_ENERGY := 3
const MAX_HAND_SIZE := 10
const UNANSWERED_ATTACK_MULTIPLIER := 5.0
const INTENT_RESPONSE_TYPES := {
	"attack": "defense",
	"heavy_attack": "defense",
	"bleed_attack": "defense",
	"ask_algorithm": "defense",
	"resume_challenge": "defense",
	"question_method": "defense",
	"desk_reject": "defense",
	"stack_pressure": "control",
	"ask_ethics": "control",
	"praise_then_pressure": "control",
	"reject_core_card": "control",
	"demand_revision": "control",
	"hand_limit": "control",
	"charge": "control",
	"shield": "attack",
	"heal": "attack",
	"silent_observe": "attack",
}
const ELITE_AFFIXES := {
	"iron_wall": {
		"name": "铁壁开题",
		"description": "开战获得 14 点护盾。",
	},
	"rapid_fire": {
		"name": "连环追问",
		"description": "所有直接伤害 +3。",
	},
	"high_pressure": {
		"name": "高压入场",
		"description": "玩家开战获得 2 层压力。",
	},
	"counter_review": {
		"name": "反制评审",
		"description": "开战获得 2 层反击。",
	},
}
const DEFENSE_WINDOW_ACTIONS: Array[String] = [
	"attack",
	"heavy_attack",
	"stack_pressure",
	"ask_algorithm",
	"ask_ethics",
	"resume_challenge",
	"praise_then_pressure",
	"reject_core_card",
	"demand_revision",
	"question_method",
	"desk_reject",
	"hand_limit",
	"bleed_attack",
]

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
var _boss_current_phase: int = 0
var _pending_ai_context: Dictionary = {}
var _ai_request_serial: int = 0
var _next_hand_limit: int = MAX_HAND_SIZE
var _next_draw_override: int = -1
var _turn_card_types: Array[String] = []
var _defense_window_open := false
var _defense_outcome := "miss"
var _incoming_damage_multiplier := 1.0
var _next_energy_bonus := 0
var _elite_affix_id := ""
var _elite_damage_bonus := 0
var _difficulty_damage_bonus := 0
var _rng: RandomNumberGenerator
var _world_rules: RefCounted
var _battle_finished_notified := false
var _world_choice_context: Dictionary = {}
var _intent_response_met := false


func _init(p_player: Character, p_enemy_resource: Resource) -> void:
	player = p_player
	enemy_resource = p_enemy_resource
	_world_rules = WorldBattleRuleFactory.create(_get_current_world_rule_set_id())
	var encounter_index := GameState.run_battles_won
	_rng = GameState.make_run_rng("battle:%s" % p_enemy_resource.id, encounter_index)
	var difficulty := GameState.get_difficulty_info()
	var scaled_enemy_hp := maxi(1, int(round(
		float(p_enemy_resource.hp) * float(difficulty.get("enemy_hp_multiplier", 1.0))
	)))
	scaled_enemy_hp = maxi(1, _world_rules.modify_enemy_max_hp(self, p_enemy_resource, scaled_enemy_hp))
	enemy = Character.new(p_enemy_resource.id, p_enemy_resource.name, scaled_enemy_hp)
	_difficulty_damage_bonus = maxi(0, int(difficulty.get("enemy_damage_bonus", 0)))
	var starting_pressure := maxi(0, int(difficulty.get("starting_pressure", 0)))
	if starting_pressure > 0:
		player.add_status("pressure", starting_pressure)
	_select_and_apply_elite_affix()
	_effect_processor = CardEffectProcessor.new(self)
	# 专注≥8：最大能量 +1；世界规则可追加额外能量。
	max_energy = BASE_ENERGY + (1 if GameState.get_effective_stat("专注") >= 8 else 0)
	max_energy += _world_rules.get_starting_energy_bonus(self)
	energy = max_energy
	_apply_battle_start_modifiers()
	if not player.is_alive():
		state = BattleState.PLAYER_LOST
		return
	_start_player_turn()
	# 表达≥7：开局揭示意图
	if GameState.get_effective_stat("表达") >= 7:
		reveal_intent()


func _apply_battle_start_modifiers() -> void:
	player.draw_cards(GameState.get_meta_effect("opening_draw"), MAX_HAND_SIZE)
	_world_rules.on_battle_started(self)


func play_card(card_index: int) -> bool:
	if not can_play_card(card_index):
		return false

	var card: Resource = player.hand[card_index]
	var cost := get_card_cost(card_index)
	var shield_before_card := player.shield

	energy -= cost
	player.hand.remove_at(card_index)
	if bool(card.exhausts):
		player.exhaust_pile.append(card)
	else:
		player.discard_pile.append(card)
	GameState.run_cards_played += 1
	_turn_card_types.append(str(card.type))
	if _is_card_intent_response(card):
		_intent_response_met = true

	_effect_processor.process_card(card, player, enemy)
	_world_rules.on_card_played(self, card, shield_before_card)

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
	if state != BattleState.PLAYER_TURN or _defense_window_open or has_world_choice_pending():
		return false
	if card_index < 0 or card_index >= player.hand.size():
		return false
	return get_card_cost(card_index) <= energy


func get_card_cost(card_index: int) -> int:
	if card_index < 0 or card_index >= player.hand.size():
		return 0
	var card: Resource = player.hand[card_index]
	return maxi(0, _world_rules.get_card_cost(self, card, card.cost))


func use_active_skill() -> bool:
	if state != BattleState.PLAYER_TURN or _skill_used_this_battle or _defense_window_open or has_world_choice_pending():
		return false

	var skill_name: String = str(_world_rules.use_active_skill(self))
	if skill_name.is_empty():
		return false

	_skill_used_this_battle = true
	skill_used.emit(skill_name)
	energy_updated.emit()
	hand_updated.emit()
	_check_end_conditions()
	return true


func end_player_turn() -> void:
	if state != BattleState.PLAYER_TURN or has_world_choice_pending():
		return

	_world_rules.on_player_turn_ended(self)
	if state != BattleState.PLAYER_TURN:
		return
	_defense_window_open = false
	# 肾上腺素是本回合攻击强化，不得跨回合永久累积。
	player.remove_status("adrenaline")
	player.discard_hand()
	state = BattleState.ENEMY_TURN
	turn_changed.emit(false)
	_execute_enemy_turn()


func begin_defense_window() -> Dictionary:
	if state != BattleState.PLAYER_TURN or _defense_window_open:
		return {"enabled": false}
	var intent_id := get_enemy_intent_id()
	if intent_id not in DEFENSE_WINDOW_ACTIONS:
		return {"enabled": false}

	var control_cards := 0
	var defense_cards := 0
	for card_type in _turn_card_types:
		if card_type in ["control", "skill"]:
			control_cards += 1
		elif card_type == "defense":
			defense_cards += 1

	var expression := GameState.get_effective_stat("表达")
	var focus := GameState.get_effective_stat("专注")
	var pressure := player.get_status_stacks("pressure")
	var duration := clampf(1.45 + float(expression) * 0.055 + float(control_cards) * 0.12 - float(pressure) * 0.055, 0.85, 2.5)
	var challenge_scale := float(GameState.get_difficulty_info().get("action_window_multiplier", 1.0))
	duration = clampf(duration * challenge_scale * clampf(Settings.action_window_scale, 0.75, 2.0), 0.65, 5.0)
	var perfect_width := clampf(0.055 + float(focus) * 0.006 + float(control_cards) * 0.022, 0.07, 0.22)
	perfect_width = clampf(perfect_width * challenge_scale, 0.055, 0.22)
	var danger_lane := _rng.randi_range(0, 2)
	_defense_window_open = true
	return {
		"enabled": true,
		"intent_id": intent_id,
		"danger_lane": danger_lane,
		"duration": duration,
		"perfect_center": 0.72,
		"perfect_width": perfect_width,
		"brace_shield": 2 + defense_cards * 2,
		"counter_damage": 3 + _turn_card_types.size() + control_cards,
		"control_cards": control_cards,
		"defense_cards": defense_cards,
	}


func resolve_defense_window(outcome: String, context: Dictionary) -> bool:
	if not _defense_window_open or state != BattleState.PLAYER_TURN:
		return false
	if outcome not in ["perfect", "dodge", "brace", "miss"]:
		outcome = "miss"
	_defense_window_open = false
	_defense_outcome = outcome
	match outcome:
		"perfect":
			GameState.run_perfect_rebuttals += 1
			Achievements.try_after_defense_window(outcome)
			_next_energy_bonus = 1
			var counter_damage := maxi(1, int(context.get("counter_damage", 3)))
			GameState.run_damage_dealt += enemy.take_damage(counter_damage)
			_check_end_conditions()
			if state != BattleState.PLAYER_TURN:
				return true
		"dodge":
			GameState.run_successful_dodges += 1
			_incoming_damage_multiplier = 0.5
		"brace":
			_incoming_damage_multiplier = 0.75
			player.gain_shield(maxi(0, int(context.get("brace_shield", 2))))
		_:
			_incoming_damage_multiplier = 1.0
	end_player_turn()
	return true


func is_defense_window_open() -> bool:
	return _defense_window_open


func _execute_enemy_turn() -> void:
	if state != BattleState.ENEMY_TURN:
		return

	# 延迟处理
	if _enemy_delay > 0:
		_enemy_delay -= 1
		_end_enemy_turn()
		return

	# 被眩晕或 Bug 导致行动失败；Bug 叠层会真实提高失败率。
	if _enemy_intent.get("id", "") == "stunned" or (enemy.has_status("bug") and _rng.randf() < get_bug_failure_chance()):
		_enemy_intent = {}
		_end_enemy_turn()
		return

	# 结算流血等持续伤害
	if enemy.has_status("bleed"):
		var bleed_damage := enemy.get_status_stacks("bleed") * int(Status.STATUS_DATABASE["bleed"].get("tick_damage", 3))
		GameState.run_damage_dealt += enemy.take_damage(bleed_damage)
		enemy.remove_status("bleed", 1)
		_check_end_conditions()
		if state != BattleState.ENEMY_TURN:
			return

	# 精准反驳会完全打断本次敌方行动；反击伤害已在窗口确认时结算。
	if _defense_outcome == "perfect":
		_end_enemy_turn()
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
			if enemy.has_status("charged"):
				damage *= 2
				enemy.remove_status("charged")
			if enemy.has_status("举证失败"):
				damage = maxi(1, damage / 2)
				enemy.remove_status("举证失败")
			_apply_damage_to_player(damage)
		"shield":
			enemy.gain_shield(_get_responded_recovery_value(int(action.get("value", 5))))
		"heal":
			enemy.heal(_get_responded_recovery_value(int(action.get("value", 5))))
		"stack_pressure":
			var pressure_value := int(action.get("value", 1)) + (1 if _is_unanswered_control() else 0)
			if _enemy_control_connects():
				player.add_status("pressure", pressure_value)
		"ask_algorithm":
			if _enemy_control_connects():
				player.add_status("pressure", 2 + (1 if _is_unanswered_control() else 0))
			_apply_damage_to_player(5)
		"ask_ethics":
			if _enemy_control_connects():
				player.add_status("pressure", 1 + (1 if _is_unanswered_control() else 0))
		"resume_challenge":
			if _enemy_control_connects():
				player.lose_spirit(10)
			_apply_damage_to_player(4)
		"praise_then_pressure":
			player.draw_cards(1)
			if _enemy_control_connects():
				player.add_status("pressure", 2 + (1 if _is_unanswered_control() else 0))
		"silent_observe":
			enemy.gain_shield(_get_responded_recovery_value(8))
		"reject_core_card":
			if _enemy_control_connects():
				player.add_status("pressure", 2 + (1 if _is_unanswered_control() else 0))
		"demand_revision":
			# 敌方行动发生在玩家弃牌之后，改为限制下一回合抽牌才会真实生效。
			if _enemy_control_connects():
				_next_draw_override = 1 if _is_unanswered_control() else 2
		"question_method":
			if _enemy_control_connects():
				player.add_status("pressure", 2 + (1 if _is_unanswered_control() else 0))
			_apply_damage_to_player(3)
		"accept_minor":
			enemy.gain_shield(8)
			player.add_status("resistance", 1)
		"desk_reject":
			_apply_damage_to_player(12)
			enemy.add_status("vulnerable", 1)
		"charge":
			if _is_unanswered_control():
				enemy.add_status("charged", maxi(1, int(action.get("value", 1))))
			else:
				enemy.add_status("vulnerable", 1)
		"counter":
			enemy.add_status("counter", maxi(1, int(action.get("value", 2))))
		"defend":
			enemy.gain_shield(action.get("value", 8))
		"hand_limit":
			# 敌方行动发生在玩家弃牌之后，限制下一回合的实际手牌上限。
			var limit: int = int(action.get("value", 3))
			if _enemy_control_connects():
				_next_hand_limit = mini(_next_hand_limit, maxi(1, limit))
				player.add_status("pressure", 1)
		"bleed_attack":
			_apply_damage_to_player(action.get("value", 4))
			if _enemy_control_connects():
				player.add_status("bleed", 1)

	_check_end_conditions()
	if state == BattleState.PLAYER_WON or state == BattleState.PLAYER_LOST:
		return

	_end_enemy_turn()


func _enemy_control_connects() -> bool:
	return _defense_outcome != "dodge"


func _apply_damage_to_player(damage: int) -> void:
	damage += _elite_damage_bonus + _difficulty_damage_bonus
	# 敌人压力会削弱其所有直接伤害，每层 10%，最多 50%。
	var enemy_pressure := enemy.get_status_stacks("pressure")
	if enemy_pressure > 0:
		damage = int(round(float(damage) * (1.0 - minf(0.5, float(enemy_pressure) * 0.1))))
	# 玩家压力会让后续失误更危险；否则叠压只影响抽牌，难以形成真实的决策代价。
	var player_pressure := player.get_status_stacks("pressure")
	if player_pressure > 0:
		damage = int(round(float(damage) * (1.0 + minf(0.5, float(player_pressure) * 0.1))))
	if _is_unanswered_attack() and _defense_outcome == "miss":
		damage = int(round(float(damage) * UNANSWERED_ATTACK_MULTIPLIER))

	# 压力圈：每点进度 +5% 敌伤，上限 +40%（Boss 不受此加成）
	var enemy_id := str(GameState.player_stats.get("current_enemy_id", ""))
	var is_boss := enemy_id == "employment_pressure"
	if not is_boss:
		var mult := 1.0 + mini(0.4, float(GameState.run_progress) * 0.05)
		mult = _world_rules.modify_pressure_damage_multiplier(self, mult)
		damage = int(round(float(damage) * mult))

	damage = maxi(0, int(round(float(damage) * _incoming_damage_multiplier)))
	player.take_damage(damage)
	_world_rules.on_player_damaged(self)

	# 敌人反击
	if player.has_status("counter"):
		GameState.run_damage_dealt += enemy.take_damage(player.get_status_stacks("counter") * 3)
		player.remove_status("counter")


func _end_enemy_turn() -> void:
	if enemy.has_status("pressure"):
		enemy.remove_status("pressure", 1)
	_defense_outcome = "miss"
	_incoming_damage_multiplier = 1.0
	turn_count += 1
	_start_player_turn()


func _start_player_turn() -> void:
	state = BattleState.PLAYER_TURN
	energy = max_energy + _next_energy_bonus
	_next_energy_bonus = 0
	_turn_card_types.clear()
	_intent_response_met = false
	# 首回合保留事件或奖励带入的开场护盾，此后护盾按回合正常清空。
	if turn_count > 1:
		player.reset_shield()

	if player.has_status("bleed"):
		var bleed_damage := player.get_status_stacks("bleed") * int(Status.STATUS_DATABASE["bleed"].get("tick_damage", 3))
		player.take_damage(bleed_damage)
		player.remove_status("bleed", 1)
		_check_end_conditions()
		if state != BattleState.PLAYER_TURN:
			return

	_world_rules.on_player_turn_started(self)

	var has_draw_override := _next_draw_override >= 0
	var draw_amount := _next_draw_override if has_draw_override else BASE_DRAW
	_next_draw_override = -1
	draw_amount = _world_rules.modify_player_draw(self, draw_amount, has_draw_override)

	# 压力影响：每 4 层压力少抽 1 张
	var pressure := player.get_status_stacks("pressure")
	draw_amount = maxi(1, draw_amount - pressure / 4)

	# 创造：额外抽牌概率
	var create_stat := GameState.get_effective_stat("创造")
	if not has_draw_override and _rng.randf() < float(create_stat) * 0.03:
		draw_amount += 1

	var hand_limit := _next_hand_limit
	_next_hand_limit = MAX_HAND_SIZE
	player.draw_cards(draw_amount, hand_limit)
	_decide_enemy_intent()
	_update_boss_phase()
	turn_changed.emit(true)
	energy_updated.emit()
	hand_updated.emit()


func _decide_enemy_intent() -> void:
	if enemy_resource.is_ai_native and Settings.ai_enabled:
		# 使用本地兜底作为默认意图，并触发 AI 请求
		_ai_request_serial += 1
		var context := _build_ai_context()
		context["request_token"] = _ai_request_serial
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

	var action := _pick_weighted_action(actions)
	_enemy_intent = action.duplicate()
	_reveal_intent = false


func _pick_weighted_action(actions: Array) -> Dictionary:
	var total_weight := 0
	for action in actions:
		total_weight += maxi(0, int((action as Dictionary).get("weight", 1)))
	if total_weight <= 0:
		return actions[_rng.randi() % actions.size()] as Dictionary
	var roll := _rng.randi_range(1, total_weight)
	for action in actions:
		roll -= maxi(0, int((action as Dictionary).get("weight", 1)))
		if roll <= 0:
			return action as Dictionary
	return actions.back() as Dictionary


func request_current_ai_decision() -> void:
	if state != BattleState.PLAYER_TURN or _pending_ai_context.is_empty():
		return
	ai_decision_requested.emit(_pending_ai_context.duplicate(true))


func set_ai_decision(action_id: String, intent_text: String, ending_flag: String, request_token: int = -1) -> bool:
	if state != BattleState.PLAYER_TURN or _defense_window_open:
		return false
	if request_token >= 0 and request_token != get_pending_ai_request_token():
		return false
	var allowed_actions: Array[String] = []
	for action in _get_current_enemy_actions():
		allowed_actions.append(str(action.get("id", "")))
	if action_id not in allowed_actions:
		var context := _pending_ai_context.duplicate(true) if not _pending_ai_context.is_empty() else _build_ai_context()
		var fallback := FallbackAI.decide(context)
		_pending_ai_context.clear()
		_enemy_intent = {
			"id": str(fallback.get("action_id", allowed_actions[0] if not allowed_actions.is_empty() else "attack")),
			"description": str(fallback.get("intent_text", "策略已切换为安全行动。")),
			"value": _map_ai_action_to_value(str(fallback.get("action_id", "attack"))),
			"ending_flag": "",
		}
		_reveal_intent = true
		return false
	_pending_ai_context.clear()
	_enemy_intent = {
		"id": action_id,
		"description": intent_text,
		"value": _map_ai_action_to_value(action_id),
		"ending_flag": ending_flag,
	}
	_reveal_intent = true
	return true


func fail_ai_decision(request_token: int) -> bool:
	if request_token < 0 or request_token != get_pending_ai_request_token():
		return false
	_pending_ai_context.clear()
	return true


func get_pending_ai_request_token() -> int:
	return int(_pending_ai_context.get("request_token", -1))


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
		"player_major": Config.characters[player.major_id].name if Config.characters.has(player.major_id) else player.major_id,
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


func get_intent_response_type() -> String:
	return str(INTENT_RESPONSE_TYPES.get(get_enemy_intent_id(), ""))


func is_intent_response_met() -> bool:
	return get_intent_response_type().is_empty() or _intent_response_met


func is_card_recommended(card: Resource) -> bool:
	if card == null:
		return false
	var response_type := get_intent_response_type()
	if response_type.is_empty():
		return str(card.type) in ["attack", "finisher"]
	return str(card.type) == response_type


func get_turn_guide() -> String:
	var response_type := get_intent_response_type()
	if response_type.is_empty():
		return "本回合：优先打出红色攻击牌，尽快结束战斗。"
	var type_name: String = str({"attack": "攻击", "defense": "防御", "control": "控制"}.get(response_type, response_type))
	if is_intent_response_met():
		return "本回合应对已完成：可以按你的构筑继续出牌。"
	if response_type == "defense":
		return "敌方即将造成伤害：优先打出【%s】牌，否则本次伤害 ×5。" % type_name
	if response_type == "control":
		return "敌方正在施压或蓄力：优先打出【%s】牌，可削弱这次意图。" % type_name
	return "敌方准备回复或设防：优先打出【%s】牌，可削弱这次意图。" % type_name


func _is_card_intent_response(card: Resource) -> bool:
	return card != null and str(card.type) == get_intent_response_type()


func _is_unanswered_attack() -> bool:
	return get_intent_response_type() == "defense" and not _intent_response_met


func _is_unanswered_control() -> bool:
	return get_intent_response_type() == "control" and not _intent_response_met


func _get_responded_recovery_value(value: int) -> int:
	if get_intent_response_type() == "attack" and _intent_response_met:
		return maxi(1, ceili(float(value) * 0.5))
	return value


func delay_enemy(turns: int) -> void:
	_enemy_delay += turns


func get_enemy_delay() -> int:
	return _enemy_delay


func consume_enemy_delay() -> int:
	var consumed := _enemy_delay
	_enemy_delay = 0
	return consumed


func get_cards_played_this_turn() -> int:
	return _turn_card_types.size()


func get_bug_failure_chance() -> float:
	return clampf(float(enemy.get_status_stacks("bug")) * 0.15, 0.0, 0.75)


func get_elite_affix_id() -> String:
	return _elite_affix_id


func get_elite_affix_text() -> String:
	if _elite_affix_id.is_empty():
		return ""
	var info: Dictionary = ELITE_AFFIXES.get(_elite_affix_id, {})
	return "%s：%s" % [info.get("name", _elite_affix_id), info.get("description", "")]


func get_rule_set_id() -> String:
	return _world_rules.get_id() if _world_rules != null else "default"


func get_turn_card_type_count(card_type: String) -> int:
	return _turn_card_types.count(card_type)


func roll_chance(chance: float) -> bool:
	return _rng.randf() < clampf(chance, 0.0, 1.0)


func deal_direct_damage_to_enemy(amount: int) -> int:
	if enemy == null or amount <= 0:
		return 0
	var actual_damage := enemy.take_damage(amount)
	GameState.run_damage_dealt += actual_damage
	return actual_damage


func process_world_card_effect(card: Resource, effect: Resource, caster: Character, target: Character) -> bool:
	return _world_rules.process_card_effect(self, card, effect, caster, target)


func request_world_choice(context: Dictionary) -> bool:
	if has_world_choice_pending() or context.is_empty():
		return false
	var choices = context.get("choices", [])
	if choices is not Array or choices.is_empty():
		return false
	_world_choice_context = context.duplicate(true)
	world_choice_requested.emit(_world_choice_context.duplicate(true))
	return true


func has_world_choice_pending() -> bool:
	return not _world_choice_context.is_empty()


func resolve_world_choice(choice_id: String) -> bool:
	if not has_world_choice_pending():
		return false
	var context := _world_choice_context.duplicate(true)
	var allowed := false
	for choice in context.get("choices", []):
		if choice is Dictionary and str(choice.get("id", "")) == choice_id:
			allowed = true
			break
	if not allowed:
		return false
	_world_choice_context.clear()
	var resolved: bool = bool(_world_rules.resolve_world_choice(self, choice_id, context))
	if resolved:
		character_resource_updated.emit()
		hand_updated.emit()
	return resolved


func notify_character_resource_updated() -> void:
	character_resource_updated.emit()


func notify_world_rule_feedback(text: String) -> void:
	if not text.is_empty():
		world_rule_feedback.emit(text)


func set_enemy_intent(intent: Dictionary) -> void:
	_enemy_intent = intent.duplicate(true)


func modify_shield_amount(caster: Character, target: Character, amount: int) -> int:
	return _world_rules.modify_shield_amount(self, caster, target, amount)


func modify_card_damage(card: Resource, caster: Character, target: Character, amount: int) -> int:
	return _world_rules.modify_card_damage(self, card, caster, target, amount)


func modify_heal_amount(caster: Character, target: Character, amount: int) -> int:
	return _world_rules.modify_heal_amount(self, caster, target, amount)


func after_heal(caster: Character, target: Character, actual_healed: int, requested_heal: int) -> void:
	_world_rules.after_heal(self, caster, target, actual_healed, requested_heal)


func _get_current_world_rule_set_id() -> String:
	var world: Resource = Config.get_world(GameState.current_world_id)
	return str(world.rule_set_id) if world != null else ""


func _select_and_apply_elite_affix() -> void:
	if str(enemy_resource.enemy_type) != "elite":
		return
	var affix_ids: Array = ELITE_AFFIXES.keys()
	affix_ids.sort()
	var affix_rng := GameState.make_run_rng("elite_affix:%s:%s" % [enemy.id, GameState.player_major_id], GameState.run_battles_won)
	_apply_elite_affix(str(affix_ids[affix_rng.randi() % affix_ids.size()]))


func _apply_elite_affix(affix_id: String) -> void:
	_elite_affix_id = affix_id
	match affix_id:
		"iron_wall":
			enemy.gain_shield(14)
		"rapid_fire":
			_elite_damage_bonus = 3
		"high_pressure":
			player.add_status("pressure", 2)
		"counter_review":
			enemy.add_status("counter", 2)


func reveal_intent() -> void:
	_reveal_intent = true


func _check_end_conditions() -> void:
	if not enemy.is_alive():
		state = BattleState.PLAYER_WON
		_notify_battle_finished(true)
		battle_ended.emit(true)
	elif not player.is_alive():
		state = BattleState.PLAYER_LOST
		_notify_battle_finished(false)
		battle_ended.emit(false)


func _notify_battle_finished(victory: bool) -> void:
	if _battle_finished_notified:
		return
	_battle_finished_notified = true
	_world_rules.on_battle_finished(self, victory)


func get_reward_card_ids() -> Array[String]:
	var candidates := ["strike", "defend", "draw_card"]
	return candidates
