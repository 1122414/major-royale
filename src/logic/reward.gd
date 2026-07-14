class_name RewardGenerator
extends RefCounted

const StatLex := preload("res://src/logic/stat_lexicon.gd")
const RelicCat := preload("res://src/logic/relic.gd")

## 奖励类型。
enum RewardType {
	CARD,
	STAT_UP,
	BUFF,
	HEAL,
	CREDITS,
	REMOVE_PRESSURE,
	RELIC,
}

const STAT_NAMES: Array[String] = ["学识", "体能", "专注", "表达", "创造", "社交", "抗压", "资源"]
const BUFF_STATUS: Array[String] = ["shield", "resistance", "adrenaline", "counter"]


static func generate_rewards(major_id: String, rng: RandomNumberGenerator, is_elite: bool = false) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []

	var card_pool := _get_card_pool(major_id, is_elite)
	card_pool.shuffle()
	var card_candidates := card_pool.slice(0, mini(3, card_pool.size()))
	rewards.append({
		"type": RewardType.CARD,
		"label": "精选新卡" if is_elite else "获得新卡",
		"options": card_candidates,
	})
	if is_elite or (card_pool.size() > 3 and rng.randf() < 0.7):
		var more := card_pool.slice(3, mini(6, card_pool.size()))
		if not more.is_empty():
			rewards.append({
				"type": RewardType.CARD,
				"label": "再选一张新卡",
				"options": more,
			})

	for _i in (3 if is_elite else 2):
		var stat: String = STAT_NAMES[rng.randi() % STAT_NAMES.size()]
		rewards.append({
			"type": RewardType.STAT_UP,
			"label": "提升属性",
			"stat": stat,
			"value": (2 if is_elite and rng.randf() < 0.5 else 1) + (1 if rng.randf() < 0.2 else 0),
			"hint": StatLex.stat_text(stat),
		})

	var buff: String = BUFF_STATUS[rng.randi() % BUFF_STATUS.size()]
	rewards.append({
		"type": RewardType.BUFF,
		"label": "临时强化",
		"status_id": buff,
		"stacks": 3 if is_elite and buff == "shield" else (2 if buff == "shield" else 1),
	})

	rewards.append({
		"type": RewardType.HEAL,
		"label": "补给恢复",
		"value": (18 if is_elite else 10) + rng.randi_range(0, 8),
	})
	rewards.append({
		"type": RewardType.CREDITS,
		"label": "资源补给",
		"credits": (30 if is_elite else 15) + rng.randi_range(0, 10),
		"credit_points": (40 if is_elite else 20) + rng.randi_range(0, 15),
	})
	if rng.randf() < (0.85 if is_elite else 0.6):
		rewards.append({
			"type": RewardType.REMOVE_PRESSURE,
			"label": "减压",
			"value": 2 if is_elite else 1 + rng.randi_range(0, 1),
		})

	# 遗物：普通战低概率；精英战必出且可选多件
	if is_elite:
		var relic_a := RelicCat.random_relic(rng, true)
		rewards.append({
			"type": RewardType.RELIC,
			"label": "精英遗物",
			"relic_id": relic_a,
		})
		var relic_b := RelicCat.random_relic(rng, true)
		if relic_b != relic_a:
			rewards.append({
				"type": RewardType.RELIC,
				"label": "精英遗物",
				"relic_id": relic_b,
			})
	elif rng.randf() < 0.35:
		rewards.append({
			"type": RewardType.RELIC,
			"label": "获得遗物",
			"relic_id": RelicCat.random_relic(rng, false),
		})

	rewards.shuffle()
	var count := mini(rewards.size(), 6 if is_elite else 5 + rng.randi_range(0, 1))
	# 精英战保证至少有一个遗物选项在展示里
	if is_elite:
		var has_relic := false
		for r in rewards.slice(0, count):
			if r.type == RewardType.RELIC:
				has_relic = true
				break
		if not has_relic:
			for i in rewards.size():
				if rewards[i].type == RewardType.RELIC:
					rewards[0] = rewards[i]
					break
	return rewards.slice(0, count)


static func _get_card_pool(major_id: String, prefer_rare: bool = false) -> Array:
	var pool := []
	var rares := []
	for card_id in Config.cards:
		var card = Config.cards[card_id]
		if str(card.major_id) != "" and str(card.major_id) != major_id:
			continue
		if prefer_rare and str(card.rarity) in ["uncommon", "rare"]:
			rares.append(card)
		pool.append(card)
	if prefer_rare and not rares.is_empty():
		return rares + pool
	return pool
