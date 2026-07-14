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
@export var phases: Array[Dictionary] = []  ## Boss 阶段配置
@export var specialty: String = ""          ## 特长一句话
@export var traits: Array[String] = []      ## 标签
@export var weakness: String = ""           ## 弱点说明
@export var spirit_weak: bool = false       ## 受到伤害 +30%


static func from_dict(data: Dictionary) -> Resource:
	var enemy := EnemyResource.new()
	enemy.id = data.get("id", "")
	enemy.name = data.get("name", "")
	enemy.enemy_type = data.get("type", "normal")
	enemy.hp = data.get("hp", 30)
	enemy.actions = _to_dict_array(data.get("actions", []))
	enemy.is_ai_native = enemy.enemy_type == "ai_native"
	enemy.ai_prompt_key = data.get("ai_prompt_key", "")
	enemy.phases = _to_dict_array(data.get("phases", []))
	enemy.specialty = data.get("specialty", "")
	enemy.weakness = data.get("weakness", "")
	enemy.spirit_weak = bool(data.get("spirit_weak", false))
	enemy.traits.clear()
	for t in data.get("traits", []):
		enemy.traits.append(str(t))
	return enemy


static func _to_dict_array(arr: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in arr:
		if item is Dictionary:
			result.append(item)
	return result
