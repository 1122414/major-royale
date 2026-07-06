class_name RewardGenerator
extends RefCounted

## 奖励类型。
enum RewardType {
	CARD,
	STAT_UP,
	BUFF,
}

const STAT_NAMES: Array[String] = ["学识", "体能", "专注", "表达", "创造", "社交", "抗压", "资源"]
const BUFF_STATUS: Array[String] = ["shield", "resistance", "adrenaline"]


static func generate_rewards(major_id: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []

	# 卡牌奖励
	var card_pool := _get_card_pool(major_id)
	card_pool.shuffle()
	var card_candidates := card_pool.slice(0, mini(3, card_pool.size()))
	rewards.append({
		"type": RewardType.CARD,
		"label": "获得新卡",
		"options": card_candidates,
	})

	# 属性奖励
	var stat: String = STAT_NAMES[rng.randi() % STAT_NAMES.size()]
	rewards.append({
		"type": RewardType.STAT_UP,
		"label": "提升属性",
		"stat": stat,
		"value": 1,
	})

	# Buff 奖励
	var buff: String = BUFF_STATUS[rng.randi() % BUFF_STATUS.size()]
	rewards.append({
		"type": RewardType.BUFF,
		"label": "临时强化",
		"status_id": buff,
		"stacks": 2 if buff == "shield" else 1,
	})

	return rewards


static func _get_card_pool(major_id: String) -> Array:
	var pool := []
	# 通用卡
	for card_id in ["strike", "defend", "draw_card"]:
		var card = Config.cards.get(card_id)
		if card != null:
			pool.append(card)
	# 专业卡
	for card_id in Config.cards:
		var card = Config.cards[card_id]
		if card.major_id == major_id:
			pool.append(card)
	return pool
