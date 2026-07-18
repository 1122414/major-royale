class_name RelicCatalog
extends RefCounted
## 遗物图鉴：战斗中被动增益，一局持久。

const RELICS := {
	"coffee_thermos": {
		"name": "保温咖啡杯",
		"desc": "每回合开始获得 2 点护盾。",
		"rarity": "common",
	},
	"flash_drive": {
		"name": "闪存盘",
		"desc": "战斗开始额外抽 1 张牌。",
		"rarity": "common",
	},
	"sticky_notes": {
		"name": "便利贴墙",
		"desc": "战斗开始获得 5 点护盾。",
		"rarity": "common",
	},
	"lucky_eraser": {
		"name": "幸运橡皮",
		"desc": "战斗开始清除 1 个负面状态。",
		"rarity": "uncommon",
	},
	"scientific_calculator": {
		"name": "科学计算器",
		"desc": "攻击牌额外造成 2 点伤害。",
		"rarity": "uncommon",
	},
	"noise_cancelling": {
		"name": "降噪耳机",
		"desc": "受到的压力圈加成伤害降低一半。",
		"rarity": "uncommon",
	},
	"gym_bracelet": {
		"name": "健身房手环",
		"desc": "获得时最大生命 +8，并回复 8 点。",
		"rarity": "rare",
	},
	"elite_badge": {
		"name": "精英徽章",
		"desc": "每场战斗最大能量 +1。",
		"rarity": "rare",
	},
	"thesis_clip": {
		"name": "论文票夹",
		"desc": "每回合第一次出牌费用 -1（最低 0）。",
		"rarity": "rare",
	},
	"mentor_letter": {
		"name": "导师推荐信",
		"desc": "战斗胜利学分与信用点额外 +50%。",
		"rarity": "elite",
	},
}


static func get_info(relic_id: String) -> Dictionary:
	return RELICS.get(relic_id, {"name": relic_id, "desc": "未知遗物", "rarity": "common"})


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for id in RELICS.keys():
		out.append(str(id))
	return out


static func random_relic(rng: RandomNumberGenerator, elite_pool: bool = false, excluded: Array = []) -> String:
	var pool: Array[String] = []
	for id in RELICS.keys():
		if str(id) in excluded:
			continue
		var r: String = str(RELICS[id].get("rarity", "common"))
		if elite_pool:
			if r in ["uncommon", "rare", "elite"]:
				pool.append(str(id))
		else:
			if r != "elite":
				pool.append(str(id))
	# 精英池耗尽时允许回落到未持有的普通遗物，但绝不重复发放已持有遗物。
	if pool.is_empty() and elite_pool:
		for id in RELICS.keys():
			if str(id) not in excluded:
				pool.append(str(id))
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


static func format_list(ids: Array) -> String:
	if ids.is_empty():
		return "遗物：无"
	var names: PackedStringArray = []
	for id in ids:
		names.append(str(get_info(str(id)).get("name", id)))
	return "遗物：%s" % "、".join(names)
