extends Node
## Godot 自动化测试运行器。

const MajorResource := preload("res://src/resources/major_resource.gd")
const CardResource := preload("res://src/resources/card_resource.gd")
const BattleHandLayout := preload("res://src/ui/widgets/battle_hand_layout.gd")

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
	await _test_reward_growth_loop()
	print("TEST: 校园探索竖切测试通过")

	print("TEST: 开始战斗逻辑测试")
	_test_battle_core()
	_test_battle_presentation()
	_test_card_effect_and_cost_feedback()
	_test_ai_decision_whitelist()
	await _test_ai_native_presentation()
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


func _test_battle_presentation() -> void:
	for card_count in [3, 5, 7, 10]:
		var layout := BattleHandLayout.calculate(card_count)
		assert(layout.start_x >= BattleHandLayout.AREA_LEFT, "%d 张牌不应越过左侧安全区" % card_count)
		assert(layout.start_x + layout.total_width <= BattleHandLayout.AREA_RIGHT + 0.01, "%d 张牌不应越过右侧安全区" % card_count)
		assert(layout.card_width > 0.0, "%d 张牌应具有有效宽度" % card_count)

	var packed := load("res://src/ui/widgets/battle_stage.tscn") as PackedScene
	assert(packed != null, "战斗舞台场景应可加载")
	var stage := packed.instantiate() as BattleStage
	add_child(stage)
	assert(stage.get_node_or_null("PlayerFigure") is TextureRect, "舞台应包含玩家立绘层")
	assert(stage.get_node_or_null("EnemyFigure") is TextureRect, "舞台应包含敌人立绘层")
	stage.queue_free()


func _test_card_effect_and_cost_feedback() -> void:
	GameState.start_run("computer")
	var player := GameState.create_battle_player()
	var battle := Battle.new(player, Config.enemies["gpa_anxiety"])

	player.hand = [Config.cards["defend"]]
	battle.energy = 1
	assert(battle.can_play_card(0), "能量充足时卡牌应处于可打出状态")
	assert(battle.play_card(0), "通用防御牌应可打出")
	assert(player.shield == 5, "通用防御牌应给玩家 5 点护盾")
	assert(battle.enemy.shield == 0, "通用防御牌不应错误地给敌人护盾")

	player.hand = [Config.cards["null_pointer"]]
	battle.energy = 0
	assert(not battle.can_play_card(0), "能量不足时卡牌应处于不可打出状态")
	assert(not battle.play_card(0), "能量不足时不应扣牌或结算效果")
	assert(player.hand.size() == 1, "拒绝出牌后手牌应保留")

	player.hand = [Config.cards["bug_generate"]]
	battle.energy = 1
	var hp_before := battle.enemy.hp
	assert(battle.play_card(0), "Bug 生成应可正常结算")
	assert(hp_before - battle.enemy.hp == 6, "Bug 生成应结算 4 基础伤害和 2 点学识加成")
	assert(battle.enemy.get_status_stacks("bug") == 1, "Bug 生成应施加 1 层 Bug")

	player.hand = [Config.cards["refactor"]]
	player.add_status("pressure", 1)
	battle.energy = 1
	assert(battle.play_card(0), "重构应可正常结算")
	assert(player.shield >= 6, "重构应获得至少 6 点护盾")
	assert(not player.has_status("pressure"), "重构应移除 1 个负面状态")


func _test_ai_decision_whitelist() -> void:
	GameState.start_run("computer")
	var battle := Battle.new(GameState.create_battle_player(), Config.enemies["ai_interviewer"])
	var allowed_ids: Array[String] = []
	for action in Config.enemies["ai_interviewer"].actions:
		allowed_ids.append(str(action.get("id", "")))
	assert(not battle.set_ai_decision("delete_player_save", "非法行动", ""), "AI 返回白名单外行动时必须拒绝")
	assert(battle.get_enemy_intent_id() in allowed_ids, "非法行动应回落到白名单策略")
	assert(battle.set_ai_decision("ask_algorithm", "准备算法追问。", ""), "白名单行动应被接受")
	assert(battle.get_enemy_intent_id() == "ask_algorithm", "合法行动应成为当前意图")


func _test_ai_native_presentation() -> void:
	var previous_ai_enabled := Settings.ai_enabled
	Settings.ai_enabled = false
	GameState.start_run("computer")
	GameState.player_stats["current_enemy_id"] = "ai_interviewer"
	var packed := load("res://src/ui/screens/battle.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	assert(screen.get_node("AIBanner").visible, "AI 精英战应显示顶部警示横幅")
	assert(screen.get_node("AIProfilePanel").visible, "AI 精英战应显示敌人档案")
	assert(screen.get_node("AIChatBubble").visible, "AI 精英战应显示策略气泡")
	assert(screen.get_node("Arena/AIPressureZone").visible, "AI 精英战应显示舞台压力区")
	assert(screen.get_node("AIActionsPanel/ActionsVBox/ActionsList").get_child_count() == 5, "AI 精英战应显示完整白名单行动")
	var state_text: String = screen.get_node("AIChatBubble/BubbleVBox/AIStateLabel").text
	assert("离线策略已就绪" in state_text, "AI 关闭时应明确展示可继续战斗的离线策略")
	screen.queue_free()
	await get_tree().process_frame
	Settings.ai_enabled = previous_ai_enabled


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

	var dorm := hotspots.get_node("Dorm") as CampusHotspot
	var events_before := GameState.run_events_resolved
	campus._pending_hotspot = dorm
	campus._pending_battle_after_event = campus._prepare_hotspot_activation(dorm)
	campus._open_hotspot_event(dorm)
	assert(hud.event_panel.visible, "宿舍热点应打开校园事件选择面板")
	campus._on_event_choice_selected(-1)
	assert(GameState.run_events_resolved == events_before + 1, "校园事件结算次数应写入局内状态")
	assert(hud.event_title.text == "事件结果", "选择后应显示事件结果反馈")
	campus._on_event_continue_requested()
	assert(not hud.event_panel.visible and player.controls_enabled, "普通事件结束后应返回可移动校园")

	var library := hotspots.get_node("Library") as CampusHotspot
	assert(campus._prepare_hotspot_activation(library), "首次图书馆事件后应准备 AI 面试官精英战")
	assert(GameState.player_stats.get("current_enemy_id", "") == "ai_interviewer", "图书馆应接入 AI 面试官")
	var cafeteria := hotspots.get_node("Cafeteria") as CampusHotspot
	assert(not campus._prepare_hotspot_activation(cafeteria), "食堂应作为纯事件与补给热点")
	var sports := hotspots.get_node("Sports") as CampusHotspot
	assert(campus._prepare_hotspot_activation(sports), "完成四区准备后操场应解锁终局 Boss")
	assert(GameState.player_stats.get("current_enemy_id", "") == "employment_pressure", "操场终局应接入就业压力 Boss")
	var pressure_zone: Polygon2D = campus.get_node("World/PressureZone")
	assert(pressure_zone.polygon.size() == 4, "压力增加后世界层应出现危险区")
	assert(hud.vignette.pressure == GameState.run_progress, "屏幕边缘压力反馈应与局内状态同步")

	var saved_position := player.global_position
	campus.queue_free()
	await get_tree().process_frame
	assert(GameState.campus_player_position.distance_to(saved_position) < 0.1, "返回校园时应恢复玩家位置")


func _test_reward_growth_loop() -> void:
	GameState.start_run("computer")
	GameState.campus_player_position = Vector2(734, 488)
	var saved_position := GameState.campus_player_position
	var packed := load("res://src/ui/screens/reward.tscn") as PackedScene
	var reward_screen := packed.instantiate()
	add_child(reward_screen)
	await get_tree().process_frame

	var max_hp_before := GameState.run_max_hp
	reward_screen._apply_reward({
		"type": RewardGenerator.RewardType.STAT_UP,
		"stat": "体能",
		"value": 1,
	})
	assert(GameState.run_max_hp == max_hp_before + 3, "体能奖励应只增加一次最大生命")
	reward_screen._apply_reward({
		"type": RewardGenerator.RewardType.RELIC,
		"relic_id": "mentor_letter",
	})
	assert(GameState.has_relic("mentor_letter"), "遗物奖励应写入本局背包")
	var deck_before := GameState.deck_card_ids.size()
	reward_screen._on_card_picked("null_pointer")
	assert(GameState.deck_card_ids.size() == deck_before + 1, "卡牌奖励应加入当前牌组")
	assert(GameState.campus_player_position == saved_position, "奖励选择不应改写返回校园位置")
	assert("牌库 %d" % GameState.deck_card_ids.size() in reward_screen.run_summary.text, "奖励页顶部摘要应同步最新牌组")
	reward_screen.queue_free()
	await get_tree().process_frame


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
