class_name EnemyResource
extends Resource

## 敌人资源定义。

@export var id: String = ""
@export var name: String = ""
@export var enemy_type: String = "normal"  ## normal, elite, boss, ai_native
@export var hp: int = 30
@export var actions: Array[Dictionary] = []
@export var is_ai_native: bool = false
@export var ai_prompt_key: String = ""     ## AI Native 敌人使用的提示词键


static func from_dict(data: Dictionary) -> Resource:
	var enemy := EnemyResource.new()
	enemy.id = data.get("id", "")
	enemy.name = data.get("name", "")
	enemy.enemy_type = data.get("type", "normal")
	enemy.hp = data.get("hp", 30)
	enemy.actions = _to_dict_array(data.get("actions", []))
	enemy.is_ai_native = enemy.enemy_type == "ai_native"
	enemy.ai_prompt_key = data.get("ai_prompt_key", "")
	return enemy


static func _to_dict_array(arr: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in arr:
		if item is Dictionary:
			result.append(item)
	return result
