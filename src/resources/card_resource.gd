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

	var effect_dicts: Array = data.get("effects", [])
	for effect_dict in effect_dicts:
		if effect_dict is Dictionary:
			card.effects.append(CardEffectScript.from_dict(effect_dict))
	return card
