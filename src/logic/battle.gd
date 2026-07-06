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


func _init(p_player: Character, p_enemy_resource: Resource) -> void:
	player = p_player
	enemy_resource = p_enemy_resource
	enemy = Character.new(p_enemy_resource.id, p_enemy_resource.name, p_enemy_resource.hp)
	_effect_processor = CardEffectProcessor.new(self)
	_effect_processor.intent_revealed.connect(reveal_intent)
	_start_player_turn()


func play_card(card_index: int) -> bool:
	if state != BattleState.PLAYER_TURN:
		return false
	if card_index < 0 or card_index >= player.hand.size():
		return false

	var card: Resource = player.hand[card_index]
	if card.cost > energy:
		return false

	energy -= card.cost
	player.hand.remove_at(card_index)
	player.discard_pile.append(card)

	_effect_processor.process_card(card, player, enemy)

	# 医学被动：攻击有概率弱点打击
	if player.major_id == "medicine" and card.type == "attack" and randf() < 0.3:
		enemy.take_damage(3)

	energy_updated.emit()
	hand_updated.emit()

	_check_end_conditions()
	_update_boss_phase()
	return true


func use_active_skill() -> bool:
	if state != BattleState.PLAYER_TURN or _skill_used_this_battle:
		return false

	var major: MajorResource = Config.majors.get(player.major_id)
	if major == null:
		return false

	var skill_id: String = major.active_skill.get("id", "")
	match skill_id:
		"code_injection":
			enemy.add_status("bug", 2)
			enemy.add_status("pressure", 1)
			skill_used.emit("代码注入")
		"objection":
			_enemy_intent = {"id": "stunned", "description": "被异议打断，本回合无法行动。", "value": 0}
			enemy.add_status("举证失败", 1)
			skill_used.emit("异议！")
		"emergency_suture":
			player.heal(12)
			_remove_body_debuffs(player)
			skill_used.emit("紧急缝合")
		_:
			return false

	_skill_used_this_battle = true
	energy_updated.emit()
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

	_check_end_conditions()
	if state == BattleState.PLAYER_WON or state == BattleState.PLAYER_LOST:
		return

	_end_enemy_turn()


func _apply_damage_to_player(damage: int) -> void:
	var previous_hp := player.hp
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

	# 计算机被动：生命低于 40% 时额外抽 1 张牌
	var draw_amount := BASE_DRAW
	if player.major_id == "computer" and player.hp < player.max_hp * 0.4:
		draw_amount += 1
		player.lose_spirit(5)

	# 压力影响：每 4 层压力少抽 1 张
	var pressure := player.get_status_stacks("pressure")
	draw_amount = maxi(1, draw_amount - pressure / 4)

	player.draw_cards(draw_amount, MAX_HAND_SIZE)
	_decide_enemy_intent()
	_update_boss_phase()
	turn_changed.emit(true)
	energy_updated.emit()
	hand_updated.emit()


func _decide_enemy_intent() -> void:
	var actions := _get_current_enemy_actions()
	if actions.is_empty():
		_enemy_intent = {"id": "attack", "value": 5}
		return

	var action := actions[randi() % actions.size()] as Dictionary
	_enemy_intent = action.duplicate()
	_reveal_intent = false


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
