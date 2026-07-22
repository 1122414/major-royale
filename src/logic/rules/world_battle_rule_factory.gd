extends RefCounted

## 世界规则注册点。新增世界只需要在这里登记其规则集，不修改 Battle 的通用流程。

const DefaultBattleRuleSet := preload("res://src/logic/rules/battle_rule_set.gd")
const CampusBattleRuleSet := preload("res://src/logic/rules/campus_battle_rule_set.gd")
const VersionLoopBattleRuleSet := preload("res://src/logic/rules/version_loop_battle_rule_set.gd")


static func create(rule_set_id: String) -> RefCounted:
	match rule_set_id:
		"campus":
			return CampusBattleRuleSet.new()
		"version_loop":
			return VersionLoopBattleRuleSet.new()
		_:
			return DefaultBattleRuleSet.new()
