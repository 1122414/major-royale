class_name FallbackAI
extends RefCounted

## Godot 端规则 AI 兜底。

static func decide(context: Dictionary) -> Dictionary:
	var allowed_actions: Array = context.get("allowed_actions", [])
	if allowed_actions.is_empty():
		return {
			"action_id": "attack",
			"intent_text": "敌人失去了思考能力，只能普通攻击。",
			"ending_flag": "",
		}

	var player_major: String = context.get("player_major", "")
	var player_hp: int = context.get("player_hp", 100)
	var enemy_name: String = context.get("enemy", "")

	var chosen: String = allowed_actions[0]

	if "ai_interviewer" in enemy_name or "面试官" in enemy_name:
		if player_major == "计算机" and "ask_algorithm" in allowed_actions:
			chosen = "ask_algorithm"
		elif player_hp < 20 and "resume_challenge" in allowed_actions:
			chosen = "resume_challenge"
		elif "ask_ethics" in allowed_actions:
			chosen = "ask_ethics"
	elif "paper_reviewer" in enemy_name or "审稿人" in enemy_name:
		if "question_method" in allowed_actions:
			chosen = "question_method"
		elif "reject_core_card" in allowed_actions:
			chosen = "reject_core_card"

	var action_names := {
		"ask_algorithm": "算法追问",
		"ask_ethics": "职业伦理",
		"resume_challenge": "简历质疑",
		"praise_then_pressure": "先夸后压",
		"silent_observe": "沉默观察",
		"reject_core_card": "拒绝核心卡",
		"demand_revision": "要求大修",
		"question_method": "质疑方法",
		"accept_minor": "小修接收",
		"desk_reject": "直接拒稿",
	}

	return {
		"action_id": chosen,
		"intent_text": "敌人使用了规则兜底行动：%s。" % action_names.get(chosen, chosen),
		"ending_flag": "",
	}
