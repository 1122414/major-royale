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
	"rubber_duck": {
		"name": "橡皮鸭调试器",
		"desc": "【计算机】每回合第一张技能牌额外抽 1 张。",
		"rarity": "uncommon",
		"major_id": "computer",
	},
	"red_pen": {
		"name": "红笔批注",
		"desc": "【法学】每打出一张控制牌，获得 3 点护盾。",
		"rarity": "uncommon",
		"major_id": "law",
	},
	"field_kit": {
		"name": "随身诊疗箱",
		"desc": "【医学】卡牌治疗量 +3，溢出治疗转化为护盾。",
		"rarity": "rare",
		"major_id": "medicine",
	},
	"risk_terminal": {
		"name": "风险模型终端",
		"desc": "【金融】护盾不少于 10 时，攻击牌额外造成 4 点伤害。",
		"rarity": "rare",
		"major_id": "finance",
	},
	"backstage_pass": {
		"name": "后台通行证",
		"desc": "【艺术】每回合第一张控制牌返还 1 点能量。",
		"rarity": "uncommon",
		"major_id": "arts",
	},
	"blank_lottery_tube": {
		"name": "空白签筒",
		"desc": "【祈序】每场战斗第一次“歪”时，获得 1 保底与 4 点护盾。",
		"rarity": "uncommon",
		"major_id": "qixu",
		"world_id": "version_loop",
	},
}


static func get_info(relic_id: String) -> Dictionary:
	return RELICS.get(relic_id, {"name": relic_id, "desc": "未知遗物", "rarity": "common"})


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for id in RELICS.keys():
		out.append(str(id))
	return out


static func random_relic(
	rng: RandomNumberGenerator,
	elite_pool: bool = false,
	excluded: Array = [],
	major_id: String = "",
) -> String:
	var pool: Array[String] = []
	for id in RELICS.keys():
		if str(id) in excluded:
			continue
		var relic_world_id := str(RELICS[id].get("world_id", "campus"))
		if relic_world_id != GameState.current_world_id:
			continue
		var required_major := str(RELICS[id].get("major_id", ""))
		if not required_major.is_empty() and required_major != major_id:
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
			if str(id) in excluded:
				continue
			var relic_world_id := str(RELICS[id].get("world_id", "campus"))
			if relic_world_id != GameState.current_world_id:
				continue
			var required_major := str(RELICS[id].get("major_id", ""))
			if required_major.is_empty() or required_major == major_id:
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
