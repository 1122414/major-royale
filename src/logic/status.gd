class_name Status
extends RefCounted

## 状态效果定义。

const STATUS_DATABASE := {
	"bug": {
		"name": "Bug",
		"description": "叠层后触发额外伤害或行动失败。",
		"is_debuff": true,
	},
	"举证失败": {
		"name": "举证失败",
		"description": "下一次攻击降低或被反制。",
		"is_debuff": true,
	},
	"vulnerable": {
		"name": "易伤",
		"description": "受到伤害增加 50%。",
		"is_debuff": true,
		"damage_multiplier": 1.5,
	},
	"bleed": {
		"name": "流血",
		"description": "每回合损失 3 点生命。",
		"is_debuff": true,
		"tick_damage": 3,
	},
	"pressure": {
		"name": "压力",
		"description": "精神下降，影响抽牌或事件判定。",
		"is_debuff": true,
	},
	"shield": {
		"name": "护盾",
		"description": "抵消伤害。",
		"is_debuff": false,
	},
	"resistance": {
		"name": "抗压",
		"description": "负面状态抵抗。",
		"is_debuff": false,
	},
	"adrenaline": {
		"name": "肾上腺素",
		"description": "攻击牌伤害提升。",
		"is_debuff": false,
	},
	"counter": {
		"name": "反击",
		"description": "受到攻击时反击。",
		"is_debuff": false,
	},
	"charged": {
		"name": "蓄力",
		"description": "下回合攻击增强。",
		"is_debuff": false,
	},
}


static func get_status_info(status_id: String) -> Dictionary:
	return STATUS_DATABASE.get(status_id, {
		"name": status_id,
		"description": "",
		"is_debuff": false,
	})


static func is_debuff(status_id: String) -> bool:
	return get_status_info(status_id).get("is_debuff", false)
