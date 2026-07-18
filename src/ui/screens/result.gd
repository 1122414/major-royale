extends Control
## 战斗/游戏结算场景。

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton


func _ready() -> void:
	var victory: bool = GameState.player_stats.get("last_battle_victory", false)
	var was_ai: bool = GameState.player_stats.get("last_enemy_was_ai", false)
	var ending_flag: String = str(GameState.player_stats.get("last_ending_flag", ""))
	var enemy_id: String = str(GameState.player_stats.get("current_enemy_id", ""))
	var is_run_end: bool = (not victory) or enemy_id == "employment_pressure"

	if victory:
		if enemy_id == "employment_pressure":
			title_label.text = "唯一上岸者"
			desc_label.text = "你通过了终极答辩，成为赛场中的唯一上岸者。"
			continue_button.text = "查看通关总结 ▶"
		elif was_ai:
			title_label.text = "AI 遭遇胜利"
			desc_label.text = "你击败了 AI Native 敌人。%s" % _ending_text(ending_flag)
			continue_button.text = "领取奖励 ▶"
		else:
			title_label.text = "胜利"
			desc_label.text = "你击败了敌人，可以领取奖励。"
			continue_button.text = "领取奖励 ▶"
		AudioManager.play_sfx("win")
		AudioManager.play_bgm_for_phase("victory")
	else:
		title_label.text = "失败"
		if was_ai and ending_flag != "":
			desc_label.text = "你倒下了。%s" % _ending_text(ending_flag)
		else:
			desc_label.text = "你倒下了，本局结束。"
		continue_button.text = "查看本局总结 ▶"
		AudioManager.play_sfx("lose")
		AudioManager.play_bgm_for_phase("menu")

	continue_button.pressed.connect(_on_continue.bind(is_run_end))
	continue_button.grab_focus()


func _ending_text(flag: String) -> String:
	match flag:
		"tech_pressure": return "结局标记：技术施压。"
		"elegant_rebuttal": return "结局标记：优雅 rebuttal。"
		"delay_shadow": return "结局标记：延毕阴影。"
		"": return ""
	return "结局标记：%s。" % flag


func _on_continue(is_run_end: bool) -> void:
	AudioManager.play_sfx("click")
	if is_run_end:
		GameState.change_screen(GameState.Screen.RUN_SUMMARY)
	else:
		GameState.change_screen(GameState.Screen.REWARD)
