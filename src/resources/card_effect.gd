class_name CardEffect
extends Resource

## 卡牌效果定义。

@export var type: String = ""       ## 效果类型：damage, shield, heal, draw, energy, status, purge, etc.
@export var value: int = 0          ## 基础数值
@export var target: String = "enemy"  ## 目标：enemy, self, all_enemies
@export var status_id: String = ""  ## 状态 ID（当 type 为 status 时）
@export var status_stacks: int = 1  ## 状态层数
@export var params: Dictionary = {} ## 额外参数


static func from_dict(data: Dictionary) -> Resource:
	var effect := CardEffect.new()
	effect.type = data.get("type", "")
	effect.value = data.get("value", 0)
	effect.target = data.get("target", "enemy")
	effect.status_id = data.get("status_id", "")
	effect.status_stacks = data.get("status_stacks", 1)
	effect.params = data.get("params", {})
	return effect
