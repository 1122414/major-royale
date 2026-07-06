class_name MajorResource
extends Resource

## 专业资源定义。

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var stats: Dictionary = {}  ## 八维属性
@export var active_skill: Dictionary = {}
@export var passive_skill: Dictionary = {}
@export var starter_deck: Array[String] = []


static func from_dict(data: Dictionary) -> Resource:
	var major := MajorResource.new()
	major.id = data.get("id", "")
	major.name = data.get("name", "")
	major.description = data.get("description", "")
	major.stats = data.get("stats", {})
	major.active_skill = data.get("active_skill", {})
	major.passive_skill = data.get("passive_skill", {})

	var deck: Array = data.get("starter_deck", [])
	for card_id in deck:
		major.starter_deck.append(str(card_id))
	return major
