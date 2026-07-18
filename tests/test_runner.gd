extends Node
## Godot 自动化测试运行器。

const MajorResource := preload("res://src/resources/major_resource.gd")
const CardResource := preload("res://src/resources/card_resource.gd")
const BattleHandLayout := preload("res://src/ui/widgets/battle_hand_layout.gd")
const RelicCatalog := preload("res://src/logic/relic.gd")
const CampusRouteScript := preload("res://src/logic/campus_route.gd")

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
	_test_campus_route_coverage()

	print("TEST: 所有 Godot 数据加载测试通过")

	print("TEST: 开始校园探索竖切测试")
	await _test_campus_world()
	await _test_reward_growth_loop()
	print("TEST: 校园探索竖切测试通过")
	print("TEST: 开始完整交付界面回归")
	await _test_delivery_screen_flow()
	await _test_settings_overlay_preserves_run_scene()
	print("TEST: 完整交付界面回归通过")

	print("TEST: 开始战斗逻辑测试")
	_test_battle_core()
	_test_battle_presentation()
	_test_professional_asset_coverage()
	_test_card_effect_and_cost_feedback()
	_test_ai_decision_whitelist()
	_test_rule_integrity_regressions()
	_test_defense_window_core()
	_test_reward_determinism_and_uniqueness()
	await _test_ai_native_presentation()
	await _test_defense_window_presentation()
	print("TEST: 所有战斗逻辑测试通过")

	print("TEST: 开始局内状态回归测试")
	_test_all_preset_majors_startable()
	_test_run_state_persistence()
	_test_run_save_roundtrip()
	_test_ai_first_turn_request()
	await _test_accessibility_and_controller_inputs()
	await _test_event_defeat_does_not_revive()
	print("TEST: 局内状态回归测试通过")

	print("TEST: 开始自定义专业测试")
	_test_custom_major()
	print("TEST: 自定义专业测试通过")

	Config.majors.erase("custom_test")
	GameState.player_stats.erase("battle_player")
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
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


func _test_campus_route_coverage() -> void:
	var routed_ids := CampusRouteScript.all_route_enemy_ids()
	routed_ids.append(CampusRouteScript.BOSS_ID)
	assert(routed_ids.size() == Config.enemies.size(), "校园路线应覆盖全部已配置敌人")
	var unique_ids := {}
	for enemy_id in routed_ids:
		assert(Config.enemies.has(enemy_id), "校园路线引用了不存在的敌人: %s" % enemy_id)
		assert(not unique_ids.has(enemy_id), "同一敌人不应重复占用多个路线节点: %s" % enemy_id)
		unique_ids[enemy_id] = true
	for enemy_id in Config.enemies:
		assert(enemy_id in routed_ids, "已配置敌人必须存在真实可达路线: %s" % enemy_id)

	var defeated: Array[Dictionary] = []
	for location_id in CampusRouteScript.LOCATION_ORDER:
		for expected_id in CampusRouteScript.LOCATION_ROUTES[location_id]:
			assert(
				CampusRouteScript.next_enemy_id(location_id, defeated) == expected_id,
				"%s 路线应按顺序解锁 %s" % [location_id, expected_id]
			)
			defeated.append({"id": expected_id})
	assert(CampusRouteScript.is_finale_ready(defeated), "击败五区 9 名竞争者后应解锁终局")
	assert(
		CampusRouteScript.next_enemy_id("sports", defeated) == CampusRouteScript.BOSS_ID,
		"终局应在操场接入就业压力 Boss"
	)


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


func _test_professional_asset_coverage() -> void:
	var player_paths := [
		"res://assets/sprites/chars/player_cs.png",
		"res://assets/sprites/chars/player_law.png",
		"res://assets/sprites/chars/player_med.png",
		"res://assets/sprites/chars/player_finance.png",
		"res://assets/sprites/chars/player_arts.png",
	]
	for path in player_paths:
		assert(ResourceLoader.exists(path), "五专业应具备正式玩家立绘: %s" % path)

	var enemy_paths := [
		"res://assets/sprites/chars/enemy_anxiety.png",
		"res://assets/sprites/chars/enemy_seat_grabber.png",
		"res://assets/sprites/chars/enemy_all_nighter.png",
		"res://assets/sprites/chars/enemy_sports_student.png",
		"res://assets/sprites/chars/enemy_client_phantom.png",
		"res://assets/sprites/chars/enemy_all_nighter_elite.png",
		"res://assets/sprites/chars/enemy_sports_ace.png",
		"res://assets/sprites/chars/enemy_ai.png",
		"res://assets/sprites/chars/enemy_reviewer.png",
		"res://assets/sprites/chars/enemy_boss.png",
	]
	var unique_enemy_paths := {}
	for path in enemy_paths:
		assert(ResourceLoader.exists(path), "敌人应具备正式立绘: %s" % path)
		assert(not unique_enemy_paths.has(path), "不同敌人不应误用同一素材: %s" % path)
		unique_enemy_paths[path] = true

	for card_id in Config.cards:
		var path := "res://assets/sprites/cards/%s.png" % card_id
		assert(ResourceLoader.exists(path), "每张卡牌都应具备独立插画: %s" % path)
	assert(ResourceLoader.exists("res://assets/sprites/bg/battle_finale.png"), "终局战应具备专属背景")

	var card_packed := load("res://src/ui/widgets/card_view.tscn") as PackedScene
	var card_view := card_packed.instantiate() as PanelContainer
	card_view.setup(Config.cards["trial_delay"], 0)
	add_child(card_view)
	assert(card_view.focus_mode == Control.FOCUS_ALL, "卡牌应可通过键盘或手柄焦点选中")
	var icon_texture: TextureRect = card_view.get_node("Margin/VBox/IconTex")
	assert(icon_texture.texture.resource_path == "res://assets/sprites/cards/trial_delay.png", "卡牌应优先加载与自身 ID 对应的独立插画")
	var controller_activations: Array[int] = []
	card_view.card_clicked.connect(func(index: int) -> void: controller_activations.append(index))
	var accept_event := InputEventAction.new()
	accept_event.action = "ui_accept"
	accept_event.pressed = true
	card_view._on_gui_input(accept_event)
	assert(controller_activations == [0], "焦点卡牌应响应手柄确认操作")
	card_view.queue_free()

	var major_packed := load("res://src/ui/widgets/major_card.tscn") as PackedScene
	for major_id in ["computer", "law", "medicine", "finance", "arts"]:
		var major_card := major_packed.instantiate()
		major_card.setup(Config.majors[major_id])
		add_child(major_card)
		var representative := major_card.get_node_or_null("Margin/VBox/RepresentativeFrame/RepresentativeArt") as TextureRect
		assert(representative != null and representative.texture != null, "专业选择卡应展示代表立绘: %s" % major_id)
		major_card.queue_free()


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


func _test_rule_integrity_regressions() -> void:
	var status_target := Character.new("target", "测试目标", 30)
	status_target.add_status("resistance", 1)
	status_target.add_status("pressure", 3)
	assert(not status_target.has_status("pressure"), "抗压应抵消下一次完整的负面状态施加")
	assert(not status_target.has_status("resistance"), "抗压生效后应消耗一层")

	GameState.start_run("computer")
	GameState.add_pending_buff("shield", 8)
	GameState.add_pending_buff("resistance", 1)
	var buffed_player := GameState.create_battle_player()
	var buffed_battle := Battle.new(buffed_player, Config.enemies["gpa_anxiety"])
	assert(buffed_player.shield == 8, "临时护盾应作为真实护盾带入下一场战斗")
	assert(buffed_player.get_status_stacks("resistance") == 1, "临时抗压应带入下一场战斗")
	buffed_battle = null

	GameState.start_run("computer")
	var bleeding_player := GameState.create_battle_player()
	var bleeding_battle := Battle.new(bleeding_player, Config.enemies["gpa_anxiety"])
	bleeding_player.add_status("bleed", 2)
	bleeding_battle._enemy_intent = {"id": "shield", "value": 1}
	var hp_before_bleed := bleeding_player.hp
	bleeding_battle.end_player_turn()
	assert(hp_before_bleed - bleeding_player.hp == 6, "玩家流血应在下个玩家回合造成每层 3 点伤害")
	assert(bleeding_player.get_status_stacks("bleed") == 1, "玩家流血结算后应减少一层")

	GameState.start_run("computer")
	var limited_player := GameState.create_battle_player()
	limited_player.deck.clear()
	limited_player.draw_pile.clear()
	limited_player.discard_pile.clear()
	limited_player.hand.clear()
	for _i in 10:
		limited_player.draw_pile.append(Config.cards["strike"])
	var boss_battle := Battle.new(limited_player, Config.enemies["employment_pressure"])
	boss_battle._enemy_intent = {"id": "hand_limit", "value": 3}
	boss_battle.end_player_turn()
	assert(limited_player.hand.size() == 3, "Boss 手牌限制应约束下一玩家回合的实际抽牌")

	GameState.start_run("computer")
	var revision_player := GameState.create_battle_player()
	var reviewer_battle := Battle.new(revision_player, Config.enemies["paper_reviewer"])
	reviewer_battle._enemy_intent = {"id": "demand_revision"}
	reviewer_battle.end_player_turn()
	assert(revision_player.hand.size() == 2, "要求大修应把下一回合抽牌限制为 2 张")

	GameState.start_run("computer")
	GameState.run_damage_dealt = 0
	var damage_player := GameState.create_battle_player()
	var damage_battle := Battle.new(damage_player, Config.enemies["gpa_anxiety"])
	damage_battle.enemy.gain_shield(4)
	damage_player.hand = [Config.cards["strike"]]
	damage_battle.energy = 3
	var enemy_hp_before := damage_battle.enemy.hp
	assert(damage_battle.play_card(0), "伤害统计回归测试应能正常出牌")
	var actual_hp_loss := enemy_hp_before - damage_battle.enemy.hp
	assert(GameState.run_damage_dealt == actual_hp_loss, "伤害统计应只记录护盾结算后的实际生命损失")

	var previous_ai_enabled := Settings.ai_enabled
	Settings.ai_enabled = true
	GameState.start_run("computer")
	var ai_battle := Battle.new(GameState.create_battle_player(), Config.enemies["ai_interviewer"])
	var old_token := ai_battle.get_pending_ai_request_token()
	ai_battle._enemy_intent = {"id": "silent_observe"}
	ai_battle.end_player_turn()
	var current_token := ai_battle.get_pending_ai_request_token()
	var current_intent := ai_battle.get_enemy_intent_id()
	assert(current_token > old_token, "AI 每个回合应生成递增的请求标识")
	assert(not ai_battle.set_ai_decision("ask_algorithm", "过期响应", "", old_token), "过期 AI 响应不得覆盖当前回合")
	assert(ai_battle.get_enemy_intent_id() == current_intent, "拒绝过期 AI 响应后应保留当前安全意图")
	Settings.ai_enabled = previous_ai_enabled


func _test_reward_determinism_and_uniqueness() -> void:
	GameState.start_run("computer")
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 20260718
	rng_b.seed = 20260718
	var rewards_a := RewardGenerator.generate_rewards("computer", rng_a, true)
	var rewards_b := RewardGenerator.generate_rewards("computer", rng_b, true)
	assert(rewards_a == rewards_b, "相同种子应生成完全一致的奖励候选")

	var elite_card_pool := RewardGenerator._get_card_pool("computer", true)
	var card_ids := {}
	for card in elite_card_pool:
		assert(not card_ids.has(card.id), "精英卡池不应重复加入稀有卡: %s" % card.id)
		card_ids[card.id] = true

	GameState.run_relic_ids = RelicCatalog.all_ids()
	GameState.run_relic_ids.erase("mentor_letter")
	var relic_rng := RandomNumberGenerator.new()
	relic_rng.seed = 17
	for reward in RewardGenerator.generate_rewards("computer", relic_rng, true):
		if int(reward.get("type", -1)) == RewardGenerator.RewardType.RELIC:
			assert(str(reward.get("relic_id", "")) == "mentor_letter", "遗物奖励不得重复发放已持有遗物")


func _test_defense_window_core() -> void:
	GameState.start_run("computer")
	var base_battle := Battle.new(GameState.create_battle_player(), Config.enemies["gpa_anxiety"])
	base_battle._enemy_intent = {"id": "attack", "value": 10}
	var base_context := base_battle.begin_defense_window()
	assert(base_context.get("enabled", false), "攻击意图应开启答辩窗口")
	assert(base_battle.is_defense_window_open(), "答辩窗口开启后应锁定出牌")
	assert(not base_battle.can_play_card(0), "答辩窗口中不得继续打出卡牌")

	GameState.start_run("computer")
	var control_battle := Battle.new(GameState.create_battle_player(), Config.enemies["gpa_anxiety"])
	control_battle._enemy_intent = {"id": "attack", "value": 10}
	control_battle._turn_card_types = ["control", "defense"]
	var control_context := control_battle.begin_defense_window()
	assert(
		float(control_context.get("perfect_width", 0.0)) > float(base_context.get("perfect_width", 0.0)),
		"控制牌应扩大精准反驳窗口"
	)
	assert(int(control_context.get("brace_shield", 0)) > int(base_context.get("brace_shield", 0)), "防御牌应强化正面招架")

	GameState.start_run("computer")
	var dodge_player := GameState.create_battle_player()
	var dodge_battle := Battle.new(dodge_player, Config.enemies["gpa_anxiety"])
	dodge_battle._enemy_intent = {"id": "attack", "value": 10}
	var dodge_context := dodge_battle.begin_defense_window()
	var dodge_hp_before := dodge_player.hp
	assert(dodge_battle.resolve_defense_window("dodge", dodge_context), "安全换位应能完成敌方回合")
	assert(dodge_hp_before - dodge_player.hp == 5, "安全换位应把直接伤害降低 50%")
	assert(GameState.run_successful_dodges == 1, "成功换位应写入本局动作统计")

	GameState.start_run("computer")
	var control_player := GameState.create_battle_player()
	var pressure_battle := Battle.new(control_player, Config.enemies["gpa_anxiety"])
	pressure_battle._enemy_intent = {"id": "stack_pressure", "value": 3}
	var pressure_context := pressure_battle.begin_defense_window()
	pressure_battle.resolve_defense_window("dodge", pressure_context)
	assert(not control_player.has_status("pressure"), "安全换位应避开敌方控制效果")

	GameState.start_run("computer")
	var perfect_player := GameState.create_battle_player()
	var perfect_battle := Battle.new(perfect_player, Config.enemies["gpa_anxiety"])
	perfect_battle._enemy_intent = {"id": "heavy_attack", "value": 12}
	perfect_battle._turn_card_types = ["attack", "control"]
	var perfect_context := perfect_battle.begin_defense_window()
	var perfect_hp_before := perfect_player.hp
	var enemy_hp_before := perfect_battle.enemy.hp
	perfect_battle.resolve_defense_window("perfect", perfect_context)
	assert(perfect_player.hp == perfect_hp_before, "精准反驳应完全打断敌方行动")
	assert(enemy_hp_before - perfect_battle.enemy.hp == int(perfect_context.get("counter_damage", 0)), "精准反驳应按本回合出牌形成反击")
	assert(perfect_battle.energy == perfect_battle.max_energy + 1, "精准反驳应奖励下一回合 1 点能量")
	assert(GameState.run_perfect_rebuttals == 1, "精准反驳应写入本局动作统计")

	GameState.start_run("computer")
	var passive_battle := Battle.new(GameState.create_battle_player(), Config.enemies["seat_grabber"])
	passive_battle._enemy_intent = {"id": "shield", "value": 8}
	assert(not passive_battle.begin_defense_window().get("enabled", false), "纯防御意图不应强制进入动作窗口")


func _test_defense_window_presentation() -> void:
	var previous_ai_enabled := Settings.ai_enabled
	Settings.ai_enabled = false
	GameState.start_run("computer")
	GameState.player_stats["current_enemy_id"] = "gpa_anxiety"
	var packed := load("res://src/ui/screens/battle.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	screen._battle._enemy_intent = {"id": "attack", "value": 10, "description": "测试追问"}
	screen._on_end_turn()
	assert(screen.defense_window.visible, "结束回合遇到攻击意图时应展示答辩窗口")
	assert(screen._battle.state == Battle.BattleState.PLAYER_TURN, "答辩窗口确认前不得提前结算敌方行动")
	assert(screen.battle_stage.get_node("LaneZones").visible, "答辩窗口应在舞台显示三条站位区")
	var danger_lane := int(screen._defense_context.get("danger_lane", 1))
	screen._set_defense_lane((danger_lane + 1) % 3)
	screen._resolve_defense_window(true)
	assert(not screen.defense_window.visible, "确认站位后应关闭答辩窗口")
	assert(not screen.battle_stage.get_node("LaneZones").visible, "动作结算后应收起站位区")
	assert(screen._battle.state == Battle.BattleState.PLAYER_TURN, "动作结算后应正常进入下一玩家回合")
	screen.queue_free()
	await get_tree().process_frame
	Settings.ai_enabled = previous_ai_enabled


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
	screen._on_ai_decision_received("delete_player_save", "非法行动", "", "remote")
	var allowed_ids: Array[String] = []
	for action in Config.enemies["ai_interviewer"].actions:
		allowed_ids.append(str(action.get("id", "")))
	assert(screen._battle.get_enemy_intent_id() in allowed_ids, "AI 非法行动应在界面层回落到白名单策略")
	assert("安全策略已接管" in screen.get_node("AIChatBubble/BubbleVBox/AIStateLabel").text, "非法行动不应向玩家暴露技术错误")
	screen._on_ai_decision_failed()
	assert("离线策略已就绪" in screen.get_node("AIChatBubble/BubbleVBox/AIStateLabel").text, "AI 超时应切换为可继续战斗的离线策略")
	screen.queue_free()
	await get_tree().process_frame

	GameState.player_stats["current_enemy_id"] = "paper_reviewer"
	var reviewer_screen := packed.instantiate()
	add_child(reviewer_screen)
	await get_tree().process_frame
	assert(reviewer_screen.get_node("AIProfilePanel/ProfileVBox/ProfileTitle").text == "论文审稿人", "第二种 AI Native 应展示独立档案")
	assert("审稿意见遗物" in reviewer_screen.get_node("AIProfilePanel/ProfileVBox/LootPreview").text, "论文审稿人应展示独立掉落")
	assert(reviewer_screen._enemy_res.actions[0].get("id", "") != Config.enemies["ai_interviewer"].actions[0].get("id", ""), "两种 AI Native 应使用不同白名单行动")
	reviewer_screen.queue_free()
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

	var dorm := hotspots.get_node("Dorm") as CampusHotspot
	var events_before := GameState.run_events_resolved
	campus._pending_hotspot = dorm
	campus._pending_battle_after_event = campus._prepare_hotspot_activation(dorm)
	assert(campus._pending_battle_after_event, "首次宿舍路线应接入熬夜卷王")
	assert(GameState.player_stats.get("current_enemy_id", "") == "all_nighter", "宿舍首战敌人应正确")
	campus._open_hotspot_event(dorm)
	assert(hud.event_panel.visible, "宿舍热点应打开校园事件选择面板")
	campus._on_event_choice_selected(-1)
	assert(GameState.run_events_resolved == events_before + 1, "校园事件结算次数应写入局内状态")
	assert(hud.event_title.text == "事件结果", "选择后应显示事件结果反馈")
	campus._pending_battle_after_event = false
	campus._on_event_continue_requested()
	assert(not hud.event_panel.visible and player.controls_enabled, "取消排队战斗后应返回可移动校园")

	var library := hotspots.get_node("Library") as CampusHotspot
	assert(campus._prepare_hotspot_activation(library), "首次图书馆事件后应准备抢座学霸战")
	assert(GameState.player_stats.get("current_enemy_id", "") == "seat_grabber", "图书馆首战敌人应正确")
	var cafeteria := hotspots.get_node("Cafeteria") as CampusHotspot
	assert(campus._prepare_hotspot_activation(cafeteria), "食堂路线应接入甲方幻影")
	assert(GameState.player_stats.get("current_enemy_id", "") == "client_phantom", "食堂首战敌人应正确")
	var sports := hotspots.get_node("Sports") as CampusHotspot
	assert(campus._prepare_hotspot_activation(sports), "操场应先接入体育特长生资格战")
	assert(GameState.player_stats.get("current_enemy_id", "") == "sports_student", "操场首战敌人应正确")
	GameState.run_enemies_defeated.clear()
	for enemy_id in CampusRouteScript.all_route_enemy_ids():
		GameState.run_enemies_defeated.append({"id": enemy_id, "name": enemy_id, "type": "normal"})
	assert(campus._prepare_hotspot_activation(sports), "清空五区资格战后操场应解锁终局 Boss")
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


func _test_delivery_screen_flow() -> void:
	assert(
		GameState._screen_to_path(GameState.Screen.CAMPUS_EXPLORE) == "res://src/ui/screens/campus_explore.tscn",
		"局内探索状态应只指向可移动校园场景"
	)
	assert(not ResourceLoader.exists("res://src/ui/screens/map_explore.tscn"), "旧线性地图场景应已移除")

	var menu := (load("res://src/ui/screens/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	assert(menu.get_node("MenuSidebar/Margin/VBox/StartButton") is Button, "主菜单应提供开始游戏入口")
	assert(menu.get_node("MenuSidebar/Margin/VBox/AchievementsButton") is Button, "主菜单应提供成就入口")
	menu.queue_free()
	await get_tree().process_frame

	var major_select := (load("res://src/ui/screens/major_select.tscn") as PackedScene).instantiate()
	add_child(major_select)
	await get_tree().process_frame
	assert(major_select.get_node("SelectorPanel/Margin/VBox/CardsContainer").get_child_count() == 5, "专业选择应完整展示五个预设专业")
	major_select.queue_free()
	await get_tree().process_frame

	GameState.start_run("arts")
	GameState.player_stats["current_enemy_id"] = "employment_pressure"
	var boss_battle := Battle.new(GameState.create_battle_player(), Config.enemies["employment_pressure"])
	boss_battle.enemy.hp = 1
	boss_battle.player.hand = [Config.cards["strike"]]
	boss_battle.energy = 3
	assert(boss_battle.play_card(0), "终局 Boss 应可正常接收卡牌结算")
	assert(boss_battle.state == Battle.BattleState.PLAYER_WON, "终局 Boss 生命归零后应进入胜利状态")
	boss_battle = null

	GameState.player_stats["last_battle_victory"] = true
	GameState.player_stats["last_enemy_was_ai"] = false
	var result_screen := (load("res://src/ui/screens/result.tscn") as PackedScene).instantiate()
	add_child(result_screen)
	await get_tree().process_frame
	assert(result_screen.get_node("VBoxContainer/TitleLabel").text == "唯一上岸者", "终局胜利应进入唯一上岸者结算")
	assert("通关总结" in result_screen.get_node("VBoxContainer/ContinueButton").text, "终局结算应通向本局总结")
	result_screen.queue_free()
	await get_tree().process_frame

	GameState.player_stats["last_battle_victory"] = false
	var summary_screen := (load("res://src/ui/screens/run_summary.tscn") as PackedScene).instantiate()
	add_child(summary_screen)
	await get_tree().process_frame
	assert("战斗数据" in summary_screen.get_node("Scroll/BodyLabel").text, "本局总结应展示战斗统计")
	assert("通过了终极答辩" in summary_screen._build_summary(true), "通关总结应包含终极答辩文案")
	summary_screen.queue_free()
	await get_tree().process_frame

	var achievements_screen := (load("res://src/ui/screens/achievements.tscn") as PackedScene).instantiate()
	add_child(achievements_screen)
	await get_tree().process_frame
	assert(achievements_screen.get_node("Tabs").get_child_count() == 4, "成就页应按四个难度分组")
	assert(achievements_screen.get_node("Scroll/List").get_child_count() > 0, "成就页应展示成就项目")
	achievements_screen.queue_free()
	await get_tree().process_frame


func _test_settings_overlay_preserves_run_scene() -> void:
	GameState.start_run("computer")
	GameState.player_stats["current_enemy_id"] = "gpa_anxiety"
	var battle_screen := (load("res://src/ui/screens/battle.tscn") as PackedScene).instantiate()
	add_child(battle_screen)
	await get_tree().process_frame
	var battle_before: Battle = battle_screen._battle
	battle_before.energy = 1
	battle_before.enemy.hp -= 3
	var enemy_hp_before := battle_before.enemy.hp
	var hand_before := battle_before.player.hand.duplicate()

	GameState.current_screen = GameState.Screen.BATTLE
	GameState.change_screen(GameState.Screen.SETTINGS)
	await get_tree().process_frame
	var overlay := get_tree().current_scene.get_node_or_null("SettingsOverlay")
	assert(overlay != null, "局内设置应作为当前场景上的覆盖层打开")
	assert(get_tree().paused, "打开局内设置时应暂停背景场景")
	assert(battle_screen._battle == battle_before, "打开设置不应重建战斗对象")
	assert(battle_screen._battle.energy == 1, "打开设置不应重置当前能量")
	assert(battle_screen._battle.enemy.hp == enemy_hp_before, "打开设置不应重置敌人生命")
	assert(battle_screen._battle.player.hand == hand_before, "打开设置不应重抽当前手牌")

	GameState.return_from_settings()
	await get_tree().process_frame
	assert(not get_tree().paused, "关闭局内设置后应恢复暂停前状态")
	assert(GameState.current_screen == GameState.Screen.BATTLE, "关闭设置应返回来源场景状态")
	assert(is_instance_valid(battle_screen) and battle_screen._battle == battle_before, "关闭设置后应继续同一场战斗")
	battle_screen.queue_free()
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
	GameState.start_run(custom.id)
	var snapshot := GameState.create_run_save_snapshot(GameState.Screen.CAMPUS_EXPLORE)
	assert(snapshot.has("custom_major"), "自定义专业的一局存档应包含专业定义")
	Config.majors.erase(custom.id)
	assert(GameState.restore_run_save_snapshot(snapshot), "自定义专业应能从版本化存档恢复")
	assert(Config.majors.has(custom.id) and Config.majors[custom.id].name == custom.name, "恢复存档时应重建自定义专业")


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


func _test_run_save_roundtrip() -> void:
	GameState.start_run("finance")
	GameState.run_hp -= 11
	GameState.run_progress = 4
	GameState.day_count = 3
	GameState.permanent_stats["资源"] = 2
	GameState.pending_buffs.clear()
	GameState.pending_buffs.append({"status_id": "shield", "stacks": 6})
	GameState.run_relic_ids.clear()
	GameState.run_relic_ids.append("mentor_letter")
	GameState.campus_player_position = Vector2(734, 488)
	GameState.campus_visited_locations.clear()
	GameState.campus_visited_locations.append_array(["teaching", "library"])
	GameState.player_stats["current_enemy_id"] = "ai_interviewer"
	GameState.player_stats["battle_player"] = Character.new("temporary", "不可序列化对象", 10)
	var expected_hp := GameState.run_hp
	var expected_deck := GameState.deck_card_ids.duplicate()
	var snapshot := GameState.create_run_save_snapshot(GameState.Screen.BATTLE)
	assert(GameState.is_run_save_snapshot_valid(snapshot), "完整的一局快照应通过版本与内容校验")
	assert(not snapshot.player_stats.has("battle_player"), "存档不得写入运行时战斗对象")

	var future_snapshot := snapshot.duplicate(true)
	future_snapshot["version"] = GameState.RUN_SAVE_VERSION + 1
	assert(not GameState.is_run_save_snapshot_valid(future_snapshot), "未知未来版本存档应安全拒绝")
	var broken_deck_snapshot := snapshot.duplicate(true)
	broken_deck_snapshot["deck_card_ids"] = ["missing_card"]
	assert(not GameState.is_run_save_snapshot_valid(broken_deck_snapshot), "引用未知卡牌的损坏存档应安全拒绝")
	var broken_enemy_snapshot := snapshot.duplicate(true)
	broken_enemy_snapshot["player_stats"]["current_enemy_id"] = "missing_enemy"
	assert(not GameState.is_run_save_snapshot_valid(broken_enemy_snapshot), "战斗检查点引用未知敌人时应安全拒绝")

	GameState.start_run("computer")
	assert(GameState.restore_run_save_snapshot(snapshot), "版本化一局快照应可恢复")
	assert(GameState.player_major_id == "finance", "恢复后专业应与存档一致")
	assert(GameState.current_screen == GameState.Screen.BATTLE, "战斗前检查点应恢复为一场全新战斗")
	assert(GameState.run_hp == expected_hp and GameState.deck_card_ids == expected_deck, "恢复后生命与牌组应保持一致")
	assert(GameState.permanent_stats.get("资源", 0) == 2, "永久属性应进入存档")
	assert(GameState.pending_buffs == [{"status_id": "shield", "stacks": 6}], "待生效状态应进入存档")
	assert(GameState.campus_player_position == Vector2(734, 488), "校园位置应进入存档")


func _test_event_defeat_does_not_revive() -> void:
	GameState.start_run("computer")
	GameState.run_hp = 1
	var packed := load("res://src/ui/screens/campus_explore.tscn") as PackedScene
	var campus := packed.instantiate()
	add_child(campus)
	await get_tree().process_frame
	var lethal_event := EventResource.new()
	lethal_event.id = "test_lethal_event"
	lethal_event.name = "致死事件"
	lethal_event.description = "用于验证事件失败闭环。"
	lethal_event.effects = [{"type": "damage", "value": 2}]
	campus._current_event = lethal_event
	campus._pending_battle_after_event = true
	campus._on_event_choice_selected(-1)
	assert(GameState.run_hp == 0, "事件伤害应允许生命降至 0")
	assert(campus._pending_run_end_after_event, "事件致死后应进入本局结束流程")
	assert(not campus._pending_battle_after_event, "事件致死后不得继续进入已排队战斗")
	assert(GameState.create_battle_player().hp == 0, "创建战斗角色不得把 0 生命复活为 1")
	var continue_button := campus.hud.event_choices.get_child(0) as Button
	assert(continue_button != null and "查看本局总结" in continue_button.text, "事件致死结果应明确通向本局总结")
	campus.queue_free()
	await get_tree().process_frame


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


func _test_accessibility_and_controller_inputs() -> void:
	for action_name in ["move_left", "move_right", "move_up", "move_down", "interact", "pause_game"]:
		assert(InputMap.has_action(action_name), "缺少输入动作: %s" % action_name)
		var has_controller_event := false
		for input_event in InputMap.action_get_events(action_name):
			if input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion:
				has_controller_event = true
				break
		assert(has_controller_event, "输入动作应包含手柄映射: %s" % action_name)

	var previous_scale := Settings.action_window_scale
	GameState.start_run("computer")
	Settings.action_window_scale = 0.75
	var fast_battle := Battle.new(GameState.create_battle_player(), Config.enemies["gpa_anxiety"])
	fast_battle._enemy_intent = {"id": "attack", "value": 5}
	var fast_duration := float(fast_battle.begin_defense_window().get("duration", 0.0))
	GameState.start_run("computer")
	Settings.action_window_scale = 2.0
	var assisted_battle := Battle.new(GameState.create_battle_player(), Config.enemies["gpa_anxiety"])
	assisted_battle._enemy_intent = {"id": "attack", "value": 5}
	var assisted_duration := float(assisted_battle.begin_defense_window().get("duration", 0.0))
	assert(assisted_duration > fast_duration * 2.0, "辅助模式应显著延长答辩窗口反应时间")
	Settings.action_window_scale = previous_scale

	var settings_scene := (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()
	add_child(settings_scene)
	await get_tree().process_frame
	assert(settings_scene.action_window_option.item_count == 4, "设置应提供四档答辩窗口时长")
	assert(settings_scene.reduced_motion_check is CheckBox, "设置应提供减少动态效果开关")
	assert(settings_scene.vibration_check is CheckBox, "设置应提供手柄震动开关")
	assert(Settings.normalize_ai_server_url(" https://example.com/ ") == "https://example.com", "在线 AI 地址应去除空格与末尾斜杠")
	assert(Settings.normalize_ai_server_url("file:///tmp/server").is_empty(), "在线 AI 地址应拒绝非 HTTP 协议")
	assert(AIClient._http_request.body_size_limit == 64 * 1024, "在线 AI 响应体应设置大小上限")
	settings_scene.queue_free()
	await get_tree().process_frame
