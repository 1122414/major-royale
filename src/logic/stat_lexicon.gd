class_name StatLexicon
extends RefCounted
## 八维属性与资源说明（UI 悬停 / 帮助面板共用）。

const STAT_HELP := {
	"学识": "提升攻击牌伤害：每 3 点学识 +1 伤害。",
	"体能": "提升生命上限：每点体能 +3 最大生命。",
	"专注": "提升每回合能量：专注≥8 时最大能量 +1。",
	"表达": "提升控制效果：表达≥7 时开局额外揭示一次意图。",
	"创造": "提升灵感：每回合开始有概率（创造×3%）额外抽 1 张牌。",
	"社交": "提升信用点收益：战斗胜利与事件额外获得信用点。",
	"抗压": "提升精神上限：每点抗压 +5 最大精神，并略微抵抗压力。",
	"资源": "提升学分收益：战斗胜利与补给额外获得学分。",
}

const RESOURCE_HELP := {
	"学分": "校园学分。用于补给加量恢复；战斗胜利会获得。显示在探索顶栏。",
	"信用点": "社交信用。用于事件选项加成与成就门槛；战斗/社交事件可获得。显示在探索顶栏。",
	"压力": "压力圈进度（非状态层数）。每点使非 Boss 敌人伤害 +5%，上限 +40%；过高还会减少抽牌。显示在探索顶栏。",
}


static func stat_text(stat_name: String) -> String:
	return STAT_HELP.get(stat_name, "未知属性。")


static func resource_text(res_name: String) -> String:
	return RESOURCE_HELP.get(res_name, "未知资源。")


static func all_stats_block() -> String:
	var lines: PackedStringArray = []
	for k in STAT_HELP.keys():
		lines.append("【%s】%s" % [k, STAT_HELP[k]])
	return "\n".join(lines)


static func all_resources_block() -> String:
	var lines: PackedStringArray = []
	for k in RESOURCE_HELP.keys():
		lines.append("【%s】%s" % [k, RESOURCE_HELP[k]])
	return "\n".join(lines)
