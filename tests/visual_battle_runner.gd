extends Node
## 战斗界面人工验收入口：提供可指定专业与敌人的稳定初始状态。


func _ready() -> void:
	var enemy_id := "gpa_anxiety"
	var major_id := "computer"
	var screenshot_path := ""
	var show_defense_window := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--enemy="):
			enemy_id = argument.trim_prefix("--enemy=")
		elif argument.begins_with("--major="):
			major_id = argument.trim_prefix("--major=")
		elif argument.begins_with("--screenshot="):
			screenshot_path = argument.trim_prefix("--screenshot=")
		elif argument == "--offline-ai":
			Settings.ai_enabled = false
		elif argument == "--defense-window":
			show_defense_window = true
	GameState.start_run(major_id)
	GameState.player_stats["current_enemy_id"] = enemy_id
	_open_battle.call_deferred(screenshot_path, show_defense_window)


func _open_battle(screenshot_path: String, show_defense_window: bool) -> void:
	var packed := load("res://src/ui/screens/battle.tscn") as PackedScene
	var battle_screen := packed.instantiate()
	add_child(battle_screen)
	if show_defense_window:
		battle_screen._battle._enemy_intent = {
			"id": "heavy_attack",
			"value": 12,
			"description": "高压追问：观察落点并选择应对。",
		}
		battle_screen._on_end_turn()
	if screenshot_path.is_empty():
		return
	for _frame in 4:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(screenshot_path)
	var error := image.save_jpg(absolute_path, 0.94)
	assert(error == OK, "视觉验收截图保存失败: %s" % absolute_path)
	print("VISUAL: 截图已保存到 %s" % absolute_path)
	battle_screen.queue_free()
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
