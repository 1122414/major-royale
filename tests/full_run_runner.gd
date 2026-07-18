extends Node
## 独立整局回归：让控制器常驻 SceneTree 根节点，驱动真实场景切换直到通关。

const SCENE_TIMEOUT_FRAMES := 360

var _previous_ai_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_full_game")


func _run_full_game() -> void:
	_previous_ai_enabled = Settings.ai_enabled
	Settings.ai_enabled = false

	var menu := (load("res://src/ui/screens/menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	menu.get_node("MenuSidebar/Margin/VBox/StartButton").pressed.emit()

	var major_select = await _wait_for_scene("MajorSelectScreen")
	major_select._preview_major("computer")
	major_select.get_node("SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/StartSelectedButton").pressed.emit()

	var campus = await _wait_for_scene("CampusExploreScreen")
	var route := [
		{"hotspot": "Teaching", "enemy": "gpa_anxiety"},
		{"hotspot": "Teaching", "enemy": "ai_interviewer"},
		{"hotspot": "Library", "enemy": "seat_grabber"},
		{"hotspot": "Library", "enemy": "paper_reviewer"},
		{"hotspot": "Dorm", "enemy": "all_nighter"},
		{"hotspot": "Dorm", "enemy": "all_nighter_king"},
		{"hotspot": "Cafeteria", "enemy": "client_phantom"},
		{"hotspot": "Sports", "enemy": "sports_student"},
		{"hotspot": "Sports", "enemy": "sports_ace"},
	]
	for encounter in route:
		await _resolve_hotspot(campus, str(encounter.hotspot), true)
		await _win_current_battle(str(encounter.enemy))
		await _continue_result_to_reward()
		campus = await _claim_reward_and_return()

	await _resolve_hotspot(campus, "Sports", true)
	await _win_current_battle("employment_pressure")
	var result = await _wait_for_scene("ResultScreen")
	assert(result.get_node("VBoxContainer/TitleLabel").text == "唯一上岸者", "Boss 胜利应进入唯一上岸者结算")
	result.get_node("VBoxContainer/ContinueButton").pressed.emit()

	var summary = await _wait_for_scene("RunSummaryScreen")
	assert("通过了终极答辩" in summary.get_node("Scroll/BodyLabel").text, "整局通关总结应记录终极答辩")
	assert(GameState.run_battles_won == 10, "整局应完成五区 9 场资格战与 1 场 Boss 战")
	assert(GameState.campus_visited_locations.size() == 5, "整局应实际访问五个校园热点")
	assert(GameState.run_events_resolved == 10, "整局应为每场路线遭遇结算一次热点事件")
	summary.get_node("ContinueButton").pressed.emit()
	await _wait_for_scene("MenuScreen")

	print("TEST: 新游戏到唯一上岸者整局回归通过")
	Settings.ai_enabled = _previous_ai_enabled
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)


func _resolve_hotspot(campus: Node, hotspot_name: String, expects_battle: bool) -> void:
	var hotspot := campus.get_node("World/Hotspots/%s" % hotspot_name) as CampusHotspot
	assert(hotspot != null, "缺少校园热点：%s" % hotspot_name)
	campus._on_hotspot_activated(hotspot)
	assert(campus.hud.event_panel.visible, "%s 应打开事件选择面板" % hotspot.display_name)
	campus._on_event_choice_selected(0)
	assert(campus.hud.event_title.text == "事件结果", "%s 应显示事件结果" % hotspot.display_name)
	campus._on_event_continue_requested()
	if expects_battle:
		await _wait_for_scene("BattleScreen")
	else:
		await get_tree().process_frame
		assert(get_tree().current_scene == campus, "%s 事件结束后应留在同一校园场景" % hotspot.display_name)
		assert(campus.player.controls_enabled, "%s 事件结束后应恢复移动" % hotspot.display_name)


func _win_current_battle(expected_enemy_id: String) -> void:
	var screen = await _wait_for_scene("BattleScreen")
	assert(str(screen._enemy_res.id) == expected_enemy_id, "战斗敌人与热点流程不一致")
	var battle: Battle = screen._battle
	battle.enemy.hp = 1
	battle.player.hand = [Config.cards["strike"]]
	battle.energy = 3
	screen._on_card_clicked(0)
	await _wait_for_scene("ResultScreen")
	assert(GameState.player_stats.get("last_battle_victory", false), "整局回归中的战斗应正常判定胜利")


func _continue_result_to_reward() -> void:
	var result = await _wait_for_scene("ResultScreen")
	result.get_node("VBoxContainer/ContinueButton").pressed.emit()
	await _wait_for_scene("RewardScreen")


func _claim_reward_and_return() -> Node:
	var reward = await _wait_for_scene("RewardScreen")
	reward._apply_reward({
		"type": RewardGenerator.RewardType.CREDITS,
		"credits": 1,
		"credit_points": 1,
	})
	reward._finish_choice("整局回归奖励已领取")
	reward.get_node("ContinueButton").pressed.emit()
	return await _wait_for_scene("CampusExploreScreen")


func _wait_for_scene(scene_name: String) -> Node:
	for _frame in SCENE_TIMEOUT_FRAMES:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current.name == scene_name:
			return current
	assert(false, "等待场景超时：%s" % scene_name)
	return null
