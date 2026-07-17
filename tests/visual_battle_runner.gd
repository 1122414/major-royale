extends Node
## 战斗界面人工验收入口：提供稳定的计算机专业普通战斗初始状态。


func _ready() -> void:
	var enemy_id := "gpa_anxiety"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--enemy="):
			enemy_id = argument.trim_prefix("--enemy=")
		elif argument == "--offline-ai":
			Settings.ai_enabled = false
	GameState.start_run("computer")
	GameState.player_stats["current_enemy_id"] = enemy_id
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/battle.tscn")
