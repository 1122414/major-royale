extends Node
## Godot 自动化测试运行器。

const MajorResource := preload("res://src/resources/major_resource.gd")
const CardResource := preload("res://src/resources/card_resource.gd")

func _ready() -> void:
	print("TEST: 开始 Godot 数据加载测试")

	assert(not Config.majors.is_empty(), "专业数据未加载")
	assert(Config.majors.size() == 5, "专业数量应为 5")
	for major_id in ["computer", "law", "medicine", "finance", "arts"]:
		assert(Config.majors.has(major_id), "缺少专业: %s" % major_id)

	var computer: MajorResource = Config.majors["computer"]
	assert(computer != null, "计算机专业未加载")
	assert(computer.name == "计算机", "计算机专业名称错误")
	assert(computer.stats.has("学识"), "计算机专业缺少学识属性")

	assert(not Config.cards.is_empty(), "卡牌数据未加载")
	assert(Config.cards.size() == 108, "卡牌数量应为 108")
	assert(Config.cards.has("strike"), "缺少通用攻击牌")
	assert(Config.cards.has("bug_generate"), "缺少计算机专属卡")

	assert(not Config.enemies.is_empty(), "敌人数据未加载")
	assert(Config.enemies.has("gpa_anxiety"), "缺少普通敌人")

	assert(not Config.events.is_empty(), "事件数据未加载")

	print("TEST: 所有 Godot 数据加载测试通过")

	print("TEST: 开始校园探索竖切测试")
	await _test_campus_world()
	print("TEST: 校园探索竖切测试通过")

	print("TEST: 开始战斗逻辑测试")
	_test_battle_core()
	print("TEST: 所有战斗逻辑测试通过")

	print("TEST: 开始局内状态回归测试")
	_test_all_preset_majors_startable()
	_test_run_state_persistence()
	_test_ai_first_turn_request()
	print("TEST: 局内状态回归测试通过")

	print("TEST: 开始自定义专业测试")
	_test_custom_major()
	print("TEST: 自定义专业测试通过")

	get_tree().quit(0)


func _test_battle_core() -> void:
	GameState.start_run("computer")
	var player := Character.new("player", "玩家", 60, true)
	player.major_id = "computer"

	# 使用通用攻击牌和防御牌测试
	player.deck.append(Config.cards["strike"])
	player.deck.append(Config.cards["defend"])
	player.draw_pile = player.deck.duplicate()
	player.shuffle_draw_pile()

	var enemy_res = Config.enemies["gpa_anxiety"]
	var battle := Battle.new(player, enemy_res)

	assert(battle.state == Battle.BattleState.PLAYER_TURN, "战斗初始应为玩家回合")
	assert(player.hand.size() == 2, "玩家应抽 2 张牌")
	assert(battle.energy == 3, "玩家初始能量应为 3")

	# 找到一张可出的攻击牌并打出
	var played := false
	for i in player.hand.size():
		var card: CardResource = player.hand[i]
		if card.cost <= battle.energy and card.type == "attack":
			played = battle.play_card(i)
			break
	assert(played, "应成功打出一张攻击牌")

	battle.end_player_turn()
	assert(battle.state == Battle.BattleState.PLAYER_TURN, "敌人回合结束后应回到玩家回合")


func _test_campus_world() -> void:
	GameState.start_run("computer")
	var packed := load("res://src/ui/screens/campus_explore.tscn") as PackedScene
	assert(packed != null, "校园探索场景应可加载")
	var campus := packed.instantiate()
	add_child(campus)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player := campus.get_node("World/Player") as CampusPlayer
	var hotspots := campus.get_node("World/Hotspots")
	var hud := campus.get_node("HUD") as ExploreHUD
	assert(player != null, "校园场景应包含可移动玩家")
	assert(hotspots.get_child_count() == 5, "校园场景应接通五个建筑热点")
	assert(hud.main_title.text == "前往教学楼", "新局主目标应指向教学楼")
	var bag_button: Button = campus.get_node("HUD/TopBar/Margin/Row/BagButton")
	bag_button.pressed.emit()
	assert(hud.utility_panel.visible, "背包入口应打开基础面板")
	hud._close_utility()

	var start_position := player.global_position
	Input.action_press("move_up")
	for _frame in 6:
		await get_tree().physics_frame
	Input.action_release("move_up")
	assert(player.global_position.y < start_position.y, "玩家应能连续向上移动")

	player.global_position = Vector2(770, 500)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var prompt: PanelContainer = campus.get_node("HUD/InteractionPrompt")
	assert(prompt.visible, "靠近建筑热点时应显示 E 交互提示")

	player.global_position = Vector2(615, 260)
	Input.action_press("move_up")
	for _frame in 30:
		await get_tree().physics_frame
	Input.action_release("move_up")
	assert(player.global_position.y >= 185.0, "玩家不应穿过教学楼碰撞区")
	var teaching := hotspots.get_node("Teaching") as CampusHotspot
	assert(campus._prepare_hotspot_activation(teaching), "教学楼热点应准备普通战斗")
	assert(GameState.player_stats.get("current_enemy_id", "") == "gpa_anxiety", "教学楼应接入绩点焦虑者战斗")
	assert(hud.main_title.text == "前往图书馆", "完成教学楼后主目标应更新为图书馆")
	var pressure_zone: Polygon2D = campus.get_node("World/PressureZone")
	assert(pressure_zone.polygon.size() == 4, "压力增加后世界层应出现危险区")
	assert(hud.vignette.pressure == GameState.run_progress, "屏幕边缘压力反馈应与局内状态同步")

	var saved_position := player.global_position
	campus.queue_free()
	await get_tree().process_frame
	assert(GameState.campus_player_position.distance_to(saved_position) < 0.1, "返回校园时应恢复玩家位置")


func _test_custom_major() -> void:
	var custom := MajorResource.new()
	custom.id = "custom_test"
	custom.name = "测试专业"
	custom.description = "测试"
	custom.stats = {"学识": 10, "体能": 5, "专注": 5, "表达": 5, "创造": 5, "社交": 5, "抗压": 5, "资源": 5}
	custom.active_skill = {"id": "emergency_suture", "name": "紧急缝合", "description": "治疗"}
	custom.passive_skill = {"id": "anatomy_familiarity", "name": "人体结构熟悉", "description": "弱点"}
	custom.starter_deck = ["strike", "defend"]

	Config.majors[custom.id] = custom
	assert(Config.majors.has("custom_test"), "自定义专业应被加入配置")
	assert(Config.majors["custom_test"].name == "测试专业", "自定义专业名称错误")


func _test_run_state_persistence() -> void:
	GameState.start_run("computer")
	GameState.permanent_stats["体能"] = 1
	GameState.permanent_stats["抗压"] = 1
	GameState.run_max_hp += 3
	GameState.run_hp = GameState.run_max_hp
	GameState.run_max_spirit += 5
	GameState.run_spirit = GameState.run_max_spirit
	var expected_max_hp := GameState.run_max_hp
	var expected_max_spirit := GameState.run_max_spirit

	var first_player := GameState.create_battle_player()
	assert(first_player.max_hp == expected_max_hp, "战斗角色不应重复叠加体能生命")
	assert(first_player.max_spirit == expected_max_spirit, "战斗角色不应重复叠加抗压精神")
	GameState.sync_from_battle_character(first_player)

	var second_player := GameState.create_battle_player()
	assert(second_player.max_hp == expected_max_hp, "跨战斗最大生命不应继续增长")
	assert(second_player.max_spirit == expected_max_spirit, "跨战斗最大精神不应继续增长")


func _test_all_preset_majors_startable() -> void:
	for major_id in ["computer", "law", "medicine", "finance", "arts"]:
		GameState.start_run(major_id)
		assert(GameState.player_major_id == major_id, "专业应能进入局内: %s" % major_id)
		assert(not GameState.deck_card_ids.is_empty(), "专业初始牌组不能为空: %s" % major_id)
		var player := GameState.create_battle_player()
		assert(player != null, "专业应能创建战斗角色: %s" % major_id)
		assert(player.deck.size() == GameState.deck_card_ids.size(), "专业卡组应完整加载: %s" % major_id)


func _test_ai_first_turn_request() -> void:
	var previous_ai_enabled := Settings.ai_enabled
	Settings.ai_enabled = true
	GameState.start_run("computer")
	var player := GameState.create_battle_player()
	var battle := Battle.new(player, Config.enemies["ai_interviewer"])
	var requests: Array[Dictionary] = []
	battle.ai_decision_requested.connect(func(context: Dictionary) -> void: requests.append(context))
	battle.request_current_ai_decision()
	assert(requests.size() == 1, "AI Native 首回合应在连接后补发决策请求")
	assert(not requests[0].get("allowed_actions", []).is_empty(), "AI 请求必须包含允许行动")
	Settings.ai_enabled = previous_ai_enabled
