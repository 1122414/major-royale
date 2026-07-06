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


func _init(p_player: Character, p_enemy_resource: Resource) -> void:
	player = p_player
	enemy_resource = p_enemy_resource
	enemy = Character.new(p_enemy_resource.id, p_enemy_resource.name, p_enemy_resource.hp)
	_effect_processor = CardEffectProcessor.new(self)
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
	energy_updated.emit()
	hand_updated.emit()

	_check_end_conditions()
	return true


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

	# 结算流血等持续伤害
	if enemy.has_status("bleed"):
		enemy.take_damage(enemy.get_status_stacks("bleed") * Status.STATUS_DATABASE["bleed"].get("tick_damage", 3))

	# 执行意图
	var action := _enemy_intent
	match action.get("id", ""):
		"attack":
			var damage: int = action.get("value", 5)
			if enemy.has_status("charged"):
				damage *= 2
				enemy.remove_status("charged")
			player.take_damage(damage)
		"shield":
			enemy.gain_shield(action.get("value", 5))
		"heal":
			enemy.heal(action.get("value", 5))
		"stack_pressure":
			player.add_status("pressure", action.get("value", 1))
		"counter":
			enemy.add_status("counter", action.get("value", 1))
		"charge":
			enemy.add_status("charged", 1)

	_check_end_conditions()
	if state == BattleState.PLAYER_WON or state == BattleState.PLAYER_LOST:
		return

	_end_enemy_turn()


func _end_enemy_turn() -> void:
	turn_count += 1
	_start_player_turn()


func _start_player_turn() -> void:
	state = BattleState.PLAYER_TURN
	energy = max_energy
	player.reset_shield()
	player.draw_cards(BASE_DRAW, MAX_HAND_SIZE)
	_decide_enemy_intent()
	turn_changed.emit(true)
	energy_updated.emit()
	hand_updated.emit()


func _decide_enemy_intent() -> void:
	var actions: Array = enemy_resource.actions
	if actions.is_empty():
		_enemy_intent = {"id": "attack", "value": 5}
		return

	var action := actions[randi() % actions.size()] as Dictionary
	_enemy_intent = action.duplicate()
	_reveal_intent = false


func get_enemy_intent_text() -> String:
	if not _reveal_intent:
		return _enemy_intent.get("description", "敌人正在准备行动...")
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
