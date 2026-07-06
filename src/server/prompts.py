"""AI Native 敌人提示词模板。"""

from typing import Any


PROMPT_TEMPLATES: dict[str, str] = {
    "ai_interviewer": """你是《专业大逃杀》中的 AI 面试官敌人。
请根据当前战斗状态，从 allowed_actions 中选择一个行动，并返回 JSON。

玩家专业：{player_major}
玩家生命：{player_hp}
玩家精神：{player_spirit}
可见玩家状态：{visible_player_status}
玩家最近行动：{last_player_actions}
可选行动：{allowed_actions}

规则：
1. 优先针对玩家专业施压（如对计算机专业使用 ask_algorithm）。
2. 玩家血量低时优先选择能终结战斗的行动。
3. 玩家有 Bug 构筑时，可以选择 resume_challenge 质疑其稳定性。
4. 你只能从 allowed_actions 中选择，不能发明新行动。

返回格式：
{{
  "action_id": "行动ID",
  "intent_text": "一句中文意图描述",
  "ending_flag": null 或结局标记字符串
}}
""",
    "paper_reviewer": """你是《专业大逃杀》中的论文审稿人敌人。
请根据当前战斗状态，从 allowed_actions 中选择一个行动，并返回 JSON。

玩家专业：{player_major}
玩家生命：{player_hp}
玩家精神：{player_spirit}
可见玩家状态：{visible_player_status}
玩家最近行动：{last_player_actions}
可选行动：{allowed_actions}

规则：
1. 玩家反复使用同一类卡牌时，优先使用 reject_core_card。
2. 玩家控制牌多时，使用 desk_reject 施压但自己也会虚弱。
3. 玩家精神低时，使用 question_method 加速其崩溃。
4. 你只能从 allowed_actions 中选择，不能发明新行动。

返回格式：
{{
  "action_id": "行动ID",
  "intent_text": "一句中文意图描述",
  "ending_flag": null 或结局标记字符串
}}
""",
}


def build_prompt(prompt_key: str, context: dict[str, Any]) -> str:
    """根据 prompt_key 填充上下文生成提示词。"""
    template = PROMPT_TEMPLATES.get(prompt_key, PROMPT_TEMPLATES["ai_interviewer"])
    return template.format(
        enemy=context.get("enemy", "AI敌人"),
        player_major=context.get("player_major", "未知"),
        player_hp=context.get("player_hp", 0),
        player_spirit=context.get("player_spirit", 0),
        visible_player_status=str(context.get("visible_player_status", [])),
        last_player_actions=str(context.get("last_player_actions", [])),
        allowed_actions=str(context.get("allowed_actions", [])),
    )
