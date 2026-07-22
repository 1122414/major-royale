class_name CardResource
extends Resource

## 卡牌资源定义。

const CardEffectScript := preload("res://src/resources/card_effect.gd")

@export var id: String = ""
@export var name: String = ""
@export var type: String = "attack"  ## attack, defense, skill, control, heal, finisher
@export var cost: int = 1
@export var rarity: String = "common"  ## common, uncommon, rare
@export var description: String = ""
@export var major_id: String = ""    ## 空表示通用卡
@export var world_id: String = ""    ## 空表示校园通用内容；非空时仅在对应世界奖励池出现
@export var archetype: String = ""   ## 专业内构筑方向
@export var generated: bool = false   ## 战斗内生成牌，不进入常规奖励池
@export var exhausts: bool = false   ## 本场战斗使用后不进入弃牌堆
@export var effects: Array[Resource] = []


static func from_dict(data: Dictionary) -> Resource:
	var card := CardResource.new()
	card.id = data.get("id", "")
	card.name = data.get("name", "")
	card.type = data.get("type", "attack")
	card.cost = data.get("cost", 1)
	card.rarity = data.get("rarity", "common")
	card.description = data.get("description", "")
	card.major_id = data.get("major_id", "")
	card.world_id = data.get("world_id", "")
	card.generated = bool(data.get("generated", false))
	# 所有 0 费牌默认消耗，阻断牌堆耗尽后的无限抽牌、回能或叠盾循环。
	card.exhausts = bool(data.get("exhaust", card.cost == 0))

	var effect_dicts: Array = data.get("effects", [])
	for effect_dict in effect_dicts:
		if effect_dict is Dictionary:
			card.effects.append(CardEffectScript.from_dict(effect_dict))
	card.archetype = str(data.get("archetype", _infer_archetype(card)))
	return card


static func _infer_archetype(card: Resource) -> String:
	if card == null or str(card.major_id).is_empty():
		return ""
	var effect_types: Array[String] = []
	var status_ids: Array[String] = []
	for effect in card.effects:
		effect_types.append(str(effect.type))
		var status_id := str(effect.status_id)
		if not status_id.is_empty():
			status_ids.append(status_id)
	match str(card.major_id):
		"computer":
			if "bug" in status_ids or "conditional_damage" in effect_types:
				return "Bug 爆破"
			if str(card.type) == "defense" or "purge" in effect_types:
				return "防火墙"
			return "高速循环"
		"law":
			if "举证失败" in status_ids or "damage_per_debuff" in effect_types:
				return "举证审判"
			if str(card.type) == "control" or "delay" in effect_types or "reveal_intent" in effect_types:
				return "庭审控场"
			return "辩护反击"
		"medicine":
			if "heal" in effect_types:
				return "急救续航"
			if str(card.type) in ["attack", "finisher"] or "bleed" in status_ids or "adrenaline" in status_ids:
				return "外科爆发"
			return "防疫抗压"
		"finance":
			if str(card.type) == "defense" or "shield" in effect_types or "heal" in effect_types:
				return "对冲护盾"
			if "vulnerable" in status_ids or "pressure" in status_ids or "bleed" in status_ids or "reveal_intent" in effect_types:
				return "做空压制"
			return "杠杆轮转"
		"arts":
			if str(card.type) == "control" or "pressure" in status_ids or "vulnerable" in status_ids or "reveal_intent" in effect_types:
				return "锐评控场"
			if str(card.type) in ["skill", "heal"] or "draw" in effect_types or "energy" in effect_types:
				return "灵感连锁"
			return "舞台爆发"
	return ""
