class_name Character
extends RefCounted

## 战斗角色（玩家或敌人）。

var id: String = ""
var display_name: String = ""
var max_hp: int = 50
var hp: int = 50
var max_spirit: int = 100
var spirit: int = 100
var shield: int = 0
var major_id: String = ""  ## 仅玩家
var is_player: bool = false

## 状态 ID -> 层数
var statuses: Dictionary = {}

## 玩家牌组相关
var deck: Array[Resource] = []      ## 全部卡牌
var draw_pile: Array[Resource] = [] ## 抽牌堆
var hand: Array[Resource] = []      ## 手牌
var discard_pile: Array[Resource] = [] ## 弃牌堆
var exhaust_pile: Array[Resource] = [] ## 本场战斗已消耗的卡牌
var _rng: RandomNumberGenerator = null


func _init(p_id: String, p_name: String, p_max_hp: int, p_is_player: bool = false) -> void:
	id = p_id
	display_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	max_spirit = 100
	spirit = 100
	is_player = p_is_player


func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0

	# 易伤加成
	if statuses.has("vulnerable"):
		amount = int(amount * 1.5)

	var hp_before := hp

	# 护盾抵消
	if shield > 0:
		if shield >= amount:
			shield -= amount
			return 0
		else:
			amount -= shield
			shield = 0

	hp = maxi(hp - amount, 0)
	return hp_before - hp


func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := hp
	hp = mini(hp + amount, max_hp)
	return hp - before


func gain_shield(amount: int) -> void:
	shield += amount


func gain_spirit(amount: int) -> void:
	spirit = clampi(spirit + amount, 0, max_spirit)


func lose_spirit(amount: int) -> void:
	spirit = clampi(spirit - amount, 0, max_spirit)


func add_status(status_id: String, stacks: int) -> void:
	if status_id.is_empty() or stacks <= 0:
		return
	# 抗压抵消下一次完整的负面状态施加，避免同一次多层状态重复消耗。
	if Status.is_debuff(status_id) and has_status("resistance"):
		remove_status("resistance", 1)
		return
	if not statuses.has(status_id):
		statuses[status_id] = 0
	statuses[status_id] += stacks


func remove_status(status_id: String, stacks: int = -1) -> void:
	if not statuses.has(status_id):
		return
	if stacks < 0:
		statuses.erase(status_id)
	else:
		statuses[status_id] = maxi(statuses[status_id] - stacks, 0)
		if statuses[status_id] <= 0:
			statuses.erase(status_id)


func has_status(status_id: String) -> bool:
	return statuses.has(status_id) and statuses[status_id] > 0


func get_status_stacks(status_id: String) -> int:
	return statuses.get(status_id, 0)


func reset_shield() -> void:
	shield = 0


func is_alive() -> bool:
	return hp > 0


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func shuffle_draw_pile() -> void:
	if _rng == null:
		draw_pile.shuffle()
		return
	for i in range(draw_pile.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, i)
		var card := draw_pile[i]
		draw_pile[i] = draw_pile[swap_index]
		draw_pile[swap_index] = card


func draw_cards(amount: int, max_hand: int = 10) -> void:
	for i in amount:
		if hand.size() >= max_hand:
			break
		if draw_pile.is_empty():
			# 弃牌堆重洗
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			shuffle_draw_pile()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())


func discard_hand() -> void:
	for card in hand:
		discard_pile.append(card)
	hand.clear()
