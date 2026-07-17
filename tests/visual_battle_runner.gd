extends Node
## 战斗界面人工验收入口：提供稳定的计算机专业普通战斗初始状态。


func _ready() -> void:
	GameState.start_run("computer")
	GameState.player_stats["current_enemy_id"] = "gpa_anxiety"
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/battle.tscn")
