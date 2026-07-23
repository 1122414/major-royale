extends Node
## Godot 自动化测试运行器。

const MajorResource := preload("res://src/resources/major_resource.gd")
const CardResource := preload("res://src/resources/card_resource.gd")
const BattleHandLayout := preload("res://src/ui/widgets/battle_hand_layout.gd")
const RelicCatalog := preload("res://src/logic/relic.gd")
const CampusRouteScript := preload("res://src/logic/campus_route.gd")
const VersionLoopWorldState := preload("res://src/logic/rules/version_loop_world_state.gd")

func _ready() -> void:
	Achievements.save_enabled = false
	MetaProgression.save_enabled = false
	MetaProgression.reset_profile()
	print("TEST: 开始 Godot 数据加载测试")

	assert(not Config.majors.is_empty(), "专业数据未加载")
	assert(Config.characters == Config.majors, "角色兼容别名应与专业数据保持一致")
	assert(Config.majors.size() == 9, "角色档案应包含五个校园专业与版本回环四名角色")
	for major_id in ["computer", "law", "medicine", "finance", "arts"]:
		assert(Config.majors.has(major_id), "缺少专业: %s" % major_id)

	var computer: MajorResource = Config.majors["computer"]
	assert(computer != null, "计算机专业未加载")
	assert(computer.name == "计算机", "计算机专业名称错误")
	assert(computer.stats.has("学识"), "计算机专业缺少学识属性")

	assert(not Config.cards.is_empty(), "卡牌数据未加载")
	assert(Config.cards.size() == 342, "版本回环成熟卡池接入后卡牌数量应为 342")
	assert(Config.cards.has("strike"), "缺少通用攻击牌")
	assert(Config.cards.has("bug_generate"), "缺少计算机专属卡")
	_test_card_archetype_coverage()

	assert(not Config.enemies.is_empty(), "敌人数据未加载")
	assert(Config.enemies.has("gpa_anxiety"), "缺少普通敌人")

	assert(not Config.events.is_empty(), "事件数据未加载")
	_test_world_package_contract()
	_test_campus_route_coverage()

	print("TEST: 所有 Godot 数据加载测试通过")

	print("TEST: 开始校园探索竖切测试")
	await _test_campus_world()
	await _test_reward_growth_loop()
	print("TEST: 校园探索竖切测试通过")
	print("TEST: 开始完整交付界面回归")
	await _test_delivery_screen_flow()
	await _test_version_loop_scene_flow()
	await _test_settings_overlay_preserves_run_scene()
	print("TEST: 完整交付界面回归通过")

	print("TEST: 开始战斗逻辑测试")
	_test_battle_core()
	_test_battle_presentation()
	_test_professional_asset_coverage()
	_test_card_effect_and_cost_feedback()
	_test_specialization_rules()
	_test_world_rule_set_hooks()
	_test_version_loop_act_one_content()
	await _test_version_loop_act_three_content()
	await _test_version_loop_endings_and_mimo()
	_test_event_chains_and_relic_synergies()
	_test_elite_affix_variety()
	_test_ai_decision_whitelist()
	_test_rule_integrity_regressions()
	_test_defense_window_core()
	_test_reward_determinism_and_uniqueness()
	_test_seeded_run_reproducibility()
	_test_difficulty_ladder_rules()
	_test_meta_currency_profile()
	_test_persistent_talent_loadout()
	_test_persistent_equipment_loadout()
	_test_persistent_upgrade_tracks()
	await _test_ai_native_presentation()
	await _test_defense_window_presentation()
	print("TEST: 所有战斗逻辑测试通过")

	print("TEST: 开始局内状态回归测试")
	_test_all_preset_majors_startable()
	_test_run_state_persistence()
	_test_run_save_roundtrip()
	await _test_run_config_ui()
	_test_ai_first_turn_request()
	await _test_accessibility_and_controller_inputs()
	await _test_event_defeat_does_not_revive()
	print("TEST: 局内状态回归测试通过")

	print("TEST: 开始自定义专业测试")
	_test_custom_major()
	print("TEST: 自定义专业测试通过")

	Config.majors.erase("custom_test")
	GameState.player_stats.erase("battle_player")
	MetaProgression.reset_profile()
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)


func _test_world_package_contract() -> void:
	assert(Config.worlds.size() == 2 and Config.worlds.has("campus"), "校园和版本回环世界包应被加载")
	var campus: Resource = Config.get_world("campus")
	assert(campus != null and campus.name == "校园世界", "校园世界定义缺失")
	assert(campus.character_ids == ["computer", "law", "medicine", "finance", "arts"], "校园角色顺序错误")
	assert(campus.shared_card_ids.size() == 8 and "strike" in campus.shared_card_ids, "校园共享卡池定义错误")
	assert(campus.fragment_id == "selection_permission", "校园规则碎片定义错误")
	assert(campus.create_initial_run_state().is_empty(), "校园首版不应注入额外世界状态")
	assert(Config.get_character_world_id("computer") == "campus", "角色应能反查所属世界")
	var version_loop: Resource = Config.get_world("version_loop")
	assert(version_loop != null and version_loop.name == "版本回环", "版本回环世界定义缺失")
	assert(version_loop.is_playable(), "版本回环的角色与地图入口应可启动")
	assert(version_loop.character_ids == ["qixu", "feilan", "xunji", "mimo"], "版本回环应声明四名角色，界面再按发现状态过滤")
	var version_state: Dictionary = version_loop.sanitize_run_state({
		"patch_notice_id": "invalid_notice",
		"maintenance_clock": 99,
		"compensation_tickets": -1,
	})
	assert(version_state.get("patch_notice_id") == "lightweight_update", "版本公告应拒绝未知状态")
	assert(version_state.get("maintenance_clock") == 4, "维护时钟应按世界状态上限截断")
	assert(version_state.get("compensation_tickets") == 0, "补偿券不得为负数")
	assert(version_loop.get_rule_catalog_entries("patch_notices").size() == 3, "版本回环首轮应配置三条公告")
	assert(Config.get_character_world_id("qixu") == "version_loop" and Config.get_character_world_id("mimo") == "version_loop", "祈序、绯澜、循迹与弥默应归属版本回环世界")


func _test_meta_currency_profile() -> void:
	MetaProgression.reset_profile()
	var legacy_profile := {
		"version": 1,
		"gold": 27,
		"settled_runs": {},
	}
	assert(MetaProgression.restore_profile_snapshot(legacy_profile), "早期金币档案缺少成长字段时应安全迁移")
	assert(MetaProgression.get_gold() == 27, "迁移早期档案时不得丢失永久金币")
	assert(MetaProgression.get_equipped_talent_ids().is_empty(), "早期档案应为新增天赋字段补空值")
	assert(MetaProgression.is_world_unlocked("campus"), "V1档案迁移后校园世界必须默认开放")
	MetaProgression.reset_profile()
	assert(MetaProgression.grant_gold(50) == 50, "永久金币应可安全增加")
	assert(MetaProgression.spend_gold(18), "余额足够时应可消费永久金币")
	assert(MetaProgression.get_gold() == 32, "永久金币消费结果错误")
	assert(not MetaProgression.spend_gold(33), "余额不足时不得消费永久金币")

	var snapshot := MetaProgression.create_profile_snapshot()
	MetaProgression.reset_profile()
	assert(MetaProgression.restore_profile_snapshot(snapshot), "局外成长快照应可恢复")
	assert(MetaProgression.get_gold() == 32, "恢复后永久金币应保持")

	GameState.start_run("computer", 7717, 2)
	GameState.run_started_at = 10001
	GameState.run_battles_won = 3
	GameState.run_events_resolved = 2
	var first := MetaProgression.settle_current_run(false)
	var expected := 4 + 3 * 3 + 2 + 2 * 4
	assert(int(first.get("earned", -1)) == expected, "一局金币应按战斗、事件与难度结算")
	var balance_after_first := MetaProgression.get_gold()
	var repeated := MetaProgression.settle_current_run(false)
	assert(bool(repeated.get("already_settled", false)), "重复进入总结页应识别已结算局")
	assert(MetaProgression.get_gold() == balance_after_first, "同一局不得重复发放永久金币")
	var first_instance_id := GameState.run_instance_id
	GameState.start_run("computer", 7717, 2)
	assert(GameState.run_instance_id != first_instance_id, "快速重开同专业同种子时也必须生成独立结算标识")

	GameState.start_run("computer", 7718, 0)
	GameState.run_started_at = 10002
	var clearance := MetaProgression.record_world_clear("campus")
	assert(bool(clearance.get("new_fragment", false)), "首次校园通关应获得筛选许可")
	assert(MetaProgression.has_fragment("selection_permission"), "筛选许可应写入局外档案")
	assert(MetaProgression.is_world_unlocked("version_loop"), "首次校园通关应发现版本回环入口")
	assert(MetaProgression.get_world_clear_count("campus") == 1, "校园通关次数应累计")
	var repeated_clearance := MetaProgression.record_world_clear("campus")
	assert(bool(repeated_clearance.get("already_recorded", false)), "同一局重复结算不得重复记录世界通关")
	assert(MetaProgression.get_world_clear_count("campus") == 1, "重复结算不得增加世界通关次数")
	var world_snapshot := MetaProgression.create_profile_snapshot()
	MetaProgression.reset_profile()
	assert(MetaProgression.restore_profile_snapshot(world_snapshot), "世界碎片和入口状态应随局外档案恢复")
	assert(MetaProgression.has_fragment("selection_permission") and MetaProgression.is_world_unlocked("version_loop"), "恢复后不得丢失世界解锁")
	MetaProgression.reset_profile()


func _test_persistent_talent_loadout() -> void:
	MetaProgression.reset_profile()
	MetaProgression.grant_gold(200)
	assert(MetaProgression.purchase_talent("healthy_routine"), "金币足够时应能永久解锁天赋")
	assert(not MetaProgression.purchase_talent("healthy_routine"), "已解锁天赋不得重复购买")
	assert(MetaProgression.purchase_talent("organized_notes"), "应能解锁第二个天赋")
	assert(MetaProgression.equip_talent("healthy_routine"), "已解锁天赋应可装配")
	assert(MetaProgression.equip_talent("organized_notes"), "第二天赋槽应可装配")
	assert(not MetaProgression.equip_talent("pressure_drill"), "未解锁天赋不得装配")
	assert(MetaProgression.purchase_talent("pressure_drill"), "应能购买第三个备选天赋")
	assert(not MetaProgression.equip_talent("pressure_drill"), "两个天赋槽占满后不得继续装配")

	var snapshot := MetaProgression.create_profile_snapshot()
	MetaProgression.reset_profile()
	assert(MetaProgression.restore_profile_snapshot(snapshot), "天赋解锁与装配应随档案恢复")
	assert(MetaProgression.is_talent_unlocked("pressure_drill"), "未装配的已购天赋也应永久保留")
	assert(MetaProgression.get_equipped_talent_ids().size() == 2, "恢复后应保持两个天赋槽")

	var base_hp := 60 + int(Config.majors["computer"].stats.get("体能", 5)) * 3
	GameState.start_run("computer", 717, 0)
	assert(GameState.run_max_hp == base_hp + 6, "规律作息应在每局开场增加 6 点最大生命")
	var battle := Battle.new(GameState.create_battle_player(), Config.enemies["gpa_anxiety"])
	assert(battle.player.hand.size() >= Battle.BASE_DRAW + 1, "笔记归档应在每场战斗额外抽 1 张牌")

	MetaProgression.reset_profile()
	var frozen_battle := Battle.new(GameState.create_battle_player(), Config.enemies["gpa_anxiety"])
	assert(frozen_battle.player.hand.size() >= Battle.BASE_DRAW + 1, "本局天赋配置应在开局后锁定")
	MetaProgression.reset_profile()


func _test_persistent_equipment_loadout() -> void:
	MetaProgression.reset_profile()
	MetaProgression.grant_gold(300)
	for equipment_id in ["graphing_calculator", "sports_pin", "family_photo", "debate_medal"]:
		assert(MetaProgression.purchase_equipment(equipment_id), "金币足够时应能永久购买装备：%s" % equipment_id)
	assert(not MetaProgression.purchase_equipment("sports_pin"), "已拥有装备不得重复购买")
	assert(not MetaProgression.equip_equipment("portable_charger"), "未拥有装备不得装配")
	assert(MetaProgression.equip_equipment("graphing_calculator"), "工具槽应能装配图形计算器")
	assert(MetaProgression.equip_equipment("sports_pin"), "徽章槽应能装配校队纪念章")
	assert(MetaProgression.equip_equipment("family_photo"), "纪念品槽应能装配合影相框")

	var snapshot := MetaProgression.create_profile_snapshot()
	MetaProgression.reset_profile()
	assert(MetaProgression.restore_profile_snapshot(snapshot), "装备收藏与装配应随档案恢复")
	assert(MetaProgression.get_owned_equipment_ids().size() == 4, "购买的装备应永久保留")
	assert(MetaProgression.get_equipped_equipment().size() == 3, "三个不同装备槽应同时生效")

	var computer: MajorResource = Config.majors["computer"]
	var base_hp := 60 + int(computer.stats.get("体能", 5)) * 3
	var base_spirit := 100 + int(computer.stats.get("抗压", 5)) * 5
	GameState.start_run("computer", 718, 0)
	assert(GameState.run_max_hp == base_hp + 5, "校队纪念章应增加 5 点最大生命")
	assert(GameState.run_max_spirit == base_spirit + 8, "合影相框应增加 8 点最大精神")
	assert(GameState.get_effective_stat("学识") == int(computer.stats.get("学识", 5)) + 1, "图形计算器应增加 1 点学识")

	assert(MetaProgression.equip_equipment("debate_medal"), "同槽装备应可自由替换")
	assert(MetaProgression.get_equipped_equipment().get("badge") == "debate_medal", "替换后徽章槽应指向新装备")
	assert(GameState.run_max_hp == base_hp + 5, "中途替换装备不得改变已开始的一局")
	MetaProgression.reset_profile()


func _test_persistent_upgrade_tracks() -> void:
	MetaProgression.reset_profile()
	MetaProgression.grant_gold(1000)
	assert(MetaProgression.get_next_upgrade_cost("survival_training") == 25, "首级生存强化价格错误")
	for expected_level in [1, 2, 3]:
		assert(MetaProgression.purchase_upgrade("survival_training"), "生存强化应可升至 %d 级" % expected_level)
		assert(MetaProgression.get_upgrade_level("survival_training") == expected_level, "生存强化等级未保留")
	assert(not MetaProgression.purchase_upgrade("survival_training"), "永久强化达到 3 级后不得继续叠加")
	assert(MetaProgression.get_next_upgrade_cost("survival_training") == -1, "满级强化不应继续报价")
	assert(MetaProgression.purchase_upgrade("alumni_network"), "校友网络应可购买第一级")
	assert(MetaProgression.purchase_upgrade("alumni_network"), "校友网络应可购买第二级")

	var snapshot := MetaProgression.create_profile_snapshot()
	MetaProgression.reset_profile()
	assert(MetaProgression.restore_profile_snapshot(snapshot), "永久强化等级应随局外档案恢复")
	assert(MetaProgression.get_upgrade_level("survival_training") == 3, "恢复后应保持满级生存强化")

	var computer: MajorResource = Config.majors["computer"]
	var base_hp := 60 + int(computer.stats.get("体能", 5)) * 3
	GameState.start_run("computer", 719, 1)
	GameState.run_started_at = 20002
	assert(GameState.run_max_hp == base_hp + 9, "三级生存强化应增加 9 点最大生命")
	assert(GameState.get_meta_effect("gold_bonus_percent") == 16, "两级校友网络应提供 16% 金币加成")
	GameState.run_battles_won = 2
	GameState.run_events_resolved = 1
	var settlement := MetaProgression.settle_current_run(false)
	var expected_gold := MetaProgression.calculate_run_gold(2, 1, 1, false, 16)
	assert(int(settlement.get("earned", -1)) == expected_gold, "永久金币增益应按本局锁定强化结算")
	MetaProgression.reset_profile()


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
	assert(routed_ids.size() == 10, "校园路线应覆盖全部 10 名校园敌人")
	var unique_ids := {}
	for enemy_id in routed_ids:
		assert(Config.enemies.has(enemy_id), "校园路线引用了不存在的敌人: %s" % enemy_id)
		assert(not unique_ids.has(enemy_id), "同一敌人不应重复占用多个路线节点: %s" % enemy_id)
		unique_ids[enemy_id] = true

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
		"res://assets/sprites/chars/player_feilan.png",
		"res://assets/sprites/chars/player_xunji.png",
		"res://assets/sprites/chars/player_mimo.png",
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
		"res://assets/sprites/chars/enemy_voice_aggregate.png",
		"res://assets/sprites/chars/enemy_zero_maintenance.png",
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
	assert(ResourceLoader.exists("res://assets/sprites/bg/version_loop_tide_plaza.png"), "第二幕应具备舆潮广场背景")
	assert(ResourceLoader.exists("res://assets/sprites/bg/version_loop_graveyard.png"), "第三幕应具备版本坟场背景")

	var card_packed := load("res://src/ui/widgets/card_view.tscn") as PackedScene
	var card_view := card_packed.instantiate() as PanelContainer
	card_view.setup(Config.cards["trial_delay"], 0)
	add_child(card_view)
	assert(card_view.focus_mode == Control.FOCUS_ALL, "卡牌应可通过键盘或手柄焦点选中")
	var icon_texture: TextureRect = card_view.get_node("Margin/VBox/IconTex")
	assert(icon_texture.texture.resource_path == "res://assets/sprites/cards/trial_delay.png", "卡牌应优先加载与自身 ID 对应的独立插画")
	card_view.set_recommended(true)
	var type_label: Label = card_view.get_node("Margin/VBox/TypeLabel")
	assert(type_label.text.begins_with("★ 优先"), "推荐应对牌应给出醒目的优先标识")
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


func _test_card_archetype_coverage() -> void:
	var expected := {
		"computer": ["Bug 爆破", "防火墙", "高速循环"],
		"law": ["举证审判", "庭审控场", "辩护反击"],
		"medicine": ["急救续航", "外科爆发", "防疫抗压"],
		"finance": ["对冲护盾", "做空压制", "杠杆轮转"],
		"arts": ["锐评控场", "灵感连锁", "舞台爆发"],
	}
	for major_id in expected:
		var archetype_counts := {}
		for card in Config.cards.values():
			if str(card.major_id) != major_id:
				continue
			var archetype := str(card.archetype)
			archetype_counts[archetype] = int(archetype_counts.get(archetype, 0)) + 1
		assert(archetype_counts.keys().size() == 3, "%s 应有且仅有三条构筑流派" % major_id)
		for archetype in expected[major_id]:
			assert(int(archetype_counts.get(archetype, 0)) >= 3, "%s 的 %s 流派至少需要 3 张支持牌" % [major_id, archetype])
		var options := RewardGenerator._spread_card_candidates(RewardGenerator._get_card_pool(major_id), 3)
		var option_archetypes := {}
		for card in options:
			option_archetypes[str(card.archetype)] = true
		assert(option_archetypes.keys().size() == 3, "%s 的卡牌奖励应同时展示三条流派方向" % major_id)


func _test_specialization_rules() -> void:
	GameState.start_run("computer")
	var exhaust_player := GameState.create_battle_player()
	var exhaust_battle := Battle.new(exhaust_player, Config.enemies["employment_pressure"])
	exhaust_player.hand = [Config.cards["quick_script"]]
	exhaust_player.draw_pile = [Config.cards["strike"]]
	exhaust_player.discard_pile.clear()
	exhaust_player.exhaust_pile.clear()
	exhaust_battle.energy = 3
	assert(Config.cards["quick_script"].exhausts, "0 费循环牌应具备消耗关键词")
	assert(exhaust_battle.play_card(0), "0 费循环牌应可打出")
	assert(Config.cards["quick_script"] in exhaust_player.exhaust_pile, "消耗牌不应返回弃牌堆形成无限循环")
	assert(Config.cards["quick_script"] not in exhaust_player.discard_pile, "消耗牌不得进入弃牌堆")

	GameState.start_run("medicine")
	var adrenaline_player := GameState.create_battle_player()
	var adrenaline_battle := Battle.new(adrenaline_player, Config.enemies["employment_pressure"])
	adrenaline_player.hand = [Config.cards["adrenaline"], Config.cards["bug_generate"], Config.cards["scalpel"]]
	adrenaline_battle.energy = 3
	assert(adrenaline_battle.play_card(0), "医学肾上腺素应可打出")
	assert(adrenaline_player.get_status_stacks("adrenaline") == 3, "肾上腺素应施加给玩家")
	assert(not adrenaline_battle.enemy.has_status("adrenaline"), "肾上腺素不得错误施加给敌人")
	var hp_before_skill := adrenaline_battle.enemy.hp
	assert(adrenaline_battle.play_card(0), "带伤害的技能牌应可打出")
	assert(hp_before_skill - adrenaline_battle.enemy.hp == 6, "肾上腺素只应强化攻击牌，不应强化技能伤害")
	# 单独验证肾上腺素固定增益，避免医学 30% 弱点被动让断言随机波动。
	adrenaline_player.major_id = "test_without_random_passive"
	var hp_before_attack := adrenaline_battle.enemy.hp
	assert(adrenaline_battle.play_card(0), "医学攻击牌应可打出")
	assert(hp_before_attack - adrenaline_battle.enemy.hp == 12, "医学攻击牌应获得 3 点肾上腺素伤害")
	adrenaline_battle._enemy_intent = {"id": "shield", "value": 1}
	adrenaline_battle.end_player_turn()
	assert(not adrenaline_player.has_status("adrenaline"), "肾上腺素应在玩家回合结束时清除")

	GameState.start_run("arts")
	var pressure_player := GameState.create_battle_player()
	var pressure_battle := Battle.new(pressure_player, Config.enemies["employment_pressure"])
	pressure_battle.enemy.add_status("pressure", 2)
	pressure_player.add_status("pressure", 2)
	pressure_battle._enemy_intent = {"id": "attack", "value": 10}
	pressure_battle._intent_response_met = true
	var hp_before_pressure := pressure_player.hp
	pressure_battle.end_player_turn()
	assert(hp_before_pressure - pressure_player.hp == 10, "敌方减伤与玩家压力加伤应同时结算")
	assert(pressure_battle.enemy.get_status_stacks("pressure") == 1, "敌人压力应在每个敌方回合后衰减 1 层")

	GameState.start_run("computer")
	var charged_player := GameState.create_battle_player()
	var charged_battle := Battle.new(charged_player, Config.enemies["gpa_anxiety"])
	charged_battle.enemy.add_status("charged", 1)
	charged_battle._enemy_intent = {"id": "heavy_attack", "value": 10}
	charged_battle._intent_response_met = true
	var charged_hp_before := charged_player.hp
	charged_battle.end_player_turn()
	assert(charged_hp_before - charged_player.hp == 20, "蓄力应让下一次重击翻倍并消耗蓄力")
	assert(not charged_battle.enemy.has_status("charged"), "重击结算后必须移除蓄力状态")

	GameState.start_run("computer")
	var spirit_player := GameState.create_battle_player()
	var spirit_battle := Battle.new(spirit_player, Config.enemies["ai_interviewer"])
	spirit_player.spirit = 10
	spirit_battle._enemy_intent = {"id": "resume_challenge"}
	spirit_battle.end_player_turn()
	assert(spirit_player.spirit == 0 and spirit_battle.state == Battle.BattleState.PLAYER_LOST, "精神归零应结束战斗")

	GameState.start_run("computer")
	var response_player := GameState.create_battle_player()
	var response_battle := Battle.new(response_player, Config.enemies["gpa_anxiety"])
	response_battle.set_enemy_intent({"id": "attack", "value": 10})
	response_player.hand = [Config.cards["defend"], Config.cards["strike"]]
	response_battle.energy = 2
	assert(response_battle.get_intent_response_type() == "defense", "攻击意图应明确要求防御应对")
	assert(response_battle.is_card_recommended(response_player.hand[0]), "防御牌应被标为当前推荐")
	assert(not response_battle.is_card_recommended(response_player.hand[1]), "未应对攻击意图时不应推荐攻击牌")
	var response_hp_before := response_player.hp
	response_battle.end_player_turn()
	assert(response_hp_before - response_player.hp == 50, "忽略攻击意图应承受五倍伤害")

	GameState.start_run("computer")
	response_player = GameState.create_battle_player()
	response_battle = Battle.new(response_player, Config.enemies["gpa_anxiety"])
	response_battle.set_enemy_intent({"id": "attack", "value": 10})
	response_player.hand = [Config.cards["defend"]]
	response_battle.energy = 1
	assert(response_battle.play_card(0), "防御牌应能完成攻击意图应对")
	assert(response_battle.is_intent_response_met(), "打出对应类型后应记录本回合应对")
	response_hp_before = response_player.hp
	response_battle.end_player_turn()
	assert(response_hp_before - response_player.hp == 5, "完成应对后只承受原始伤害并由护盾抵消")

	GameState.start_run("computer")
	response_player = GameState.create_battle_player()
	response_battle = Battle.new(response_player, Config.enemies["gpa_anxiety"])
	response_battle.set_enemy_intent({"id": "shield", "value": 10})
	response_player.hand = [Config.cards["strike"]]
	response_battle.energy = 1
	assert(response_battle.play_card(0), "攻击牌应能完成敌方回复意图应对")
	response_battle.end_player_turn()
	assert(response_battle.enemy.shield == 5, "攻击应对应将敌方本次护盾减半")

	GameState.start_run("computer")
	var bug_battle := Battle.new(GameState.create_battle_player(), Config.enemies["employment_pressure"])
	bug_battle.enemy.add_status("bug", 4)
	assert(is_equal_approx(bug_battle.get_bug_failure_chance(), 0.6), "4 层 Bug 应提供 60% 行动失败率")
	bug_battle.enemy.add_status("bug", 10)
	assert(is_equal_approx(bug_battle.get_bug_failure_chance(), 0.75), "Bug 行动失败率应封顶 75%")

	_test_scaled_finishers()


func _test_world_rule_set_hooks() -> void:
	var active_expectations := {
		"computer": "code_injection",
		"law": "objection",
		"medicine": "emergency_suture",
		"finance": "leverage",
		"arts": "inspiration",
	}
	for major_id in active_expectations:
		GameState.start_run(major_id)
		var player := GameState.create_battle_player()
		var battle := Battle.new(player, Config.enemies["gpa_anxiety"])
		assert(battle.get_rule_set_id() == "campus", "校园战斗应加载校园规则集")
		if major_id == "law":
			battle.set_enemy_intent({"id": "attack", "value": 8})
		if major_id == "medicine":
			player.hp = maxi(1, player.max_hp - 20)
			player.add_status("bleed", 1)
			player.add_status("pressure", 1)
		if major_id == "arts":
			player.add_status("pressure", 2)
		var energy_before := battle.energy
		assert(battle.use_active_skill(), "%s 主动技能应由校园规则集执行" % major_id)
		assert(not battle.use_active_skill(), "每场战斗主动技能仍应只能使用一次")
		match major_id:
			"computer":
				assert(battle.enemy.get_status_stacks("bug") == 2, "代码注入应添加 2 层 Bug")
			"law":
				assert(battle.get_enemy_intent_id() == "stunned" and player.shield == 6, "异议应打断意图并提供护盾")
			"medicine":
				assert(not player.has_status("bleed") and not player.has_status("pressure"), "紧急缝合应清除校园身体负面")
				assert(player.has_status("resistance"), "紧急缝合应提供抗压")
			"finance":
				assert(battle.energy == energy_before + 1 and player.has_status("adrenaline"), "杠杆加仓应提供能量与肾上腺素")
			"arts":
				assert(player.get_status_stacks("pressure") == 1 and player.shield == 4, "灵感爆发应只减一层压力并提供护盾")

	GameState.start_run("law")
	var law_player := GameState.create_battle_player()
	var law_battle := Battle.new(law_player, Config.enemies["gpa_anxiety"])
	law_player.hp = 1
	law_battle._apply_damage_to_player(99)
	assert(law_player.hp == 1 and law_player.shield == 10, "法学濒死保护应由校园规则集执行")
	_test_version_loop_rule_foundation()


func _test_version_loop_rule_foundation() -> void:
	GameState.start_run("computer", 8080)
	var version_loop: Resource = Config.get_world("version_loop")
	GameState.current_world_id = "version_loop"
	GameState.world_run_state = version_loop.create_initial_run_state()
	var player := GameState.create_battle_player()
	var lightweight_battle := Battle.new(player, Config.enemies["gpa_anxiety"])
	assert(lightweight_battle.get_rule_set_id() == "version_loop", "版本回环应加载独立战斗规则集")
	assert(player.hand.size() == Battle.BASE_DRAW - 1, "轻量化更新应减少起手抽牌")
	player.hand = [Config.cards["strike"], Config.cards["defend"]]
	lightweight_battle.energy = 0
	assert(lightweight_battle.can_play_card(0), "轻量化更新应让每回合第一张 1 费牌免费")
	assert(lightweight_battle.play_card(0), "免费首张牌应能正常结算")
	assert(not lightweight_battle.can_play_card(0), "同回合第二张 1 费牌不应继续免费")

	assert(VersionLoopWorldState.select_patch_notice("numeric_inflation"), "版本公告应通过世界状态接口选择")
	var inflated_player := GameState.create_battle_player()
	var inflated_battle := Battle.new(inflated_player, Config.enemies["gpa_anxiety"])
	assert(inflated_battle.enemy.max_hp == 34, "数值膨胀应提高普通敌人最大生命")
	inflated_player.hand = [Config.cards["bsod_warning"]]
	inflated_battle.energy = 2
	var hp_before := inflated_battle.enemy.hp
	assert(inflated_battle.play_card(0), "高费卡应能在数值膨胀公告下正常结算")
	assert(hp_before - inflated_battle.enemy.hp == 14, "数值膨胀应为高费伤害牌提供 4 点额外伤害")

	GameState.set_world_run_state_value("patch_notice_id", "known_issue_fix")
	var fixed_player := GameState.create_battle_player()
	var fixed_battle := Battle.new(fixed_player, Config.enemies["gpa_anxiety"])
	assert(fixed_player.has_status("resistance"), "修复已知问题应抵消第一项自身负面")
	GameState.set_world_run_state_value("maintenance_clock", 3)
	GameState.set_world_run_state_value("maintenance_due", false)
	fixed_battle.enemy.hp = 1
	fixed_player.hand = [Config.cards["strike"]]
	fixed_battle.energy = 1
	assert(fixed_battle.play_card(0), "击败敌人应推进版本回环维护时钟")
	assert(GameState.get_world_run_state_value("maintenance_clock") == 4, "每场胜利应推进维护时钟")
	assert(bool(GameState.get_world_run_state_value("maintenance_due")), "维护时钟满格后应标记强制维护")
	var maintenance_reward: Dictionary = VersionLoopWorldState.resolve_forced_maintenance()
	assert(maintenance_reward.get("compensation_tickets") == 1, "强制维护应发放一张补偿券")
	assert(GameState.get_world_run_state_value("maintenance_clock") == 0, "强制维护应复位维护时钟")
	assert(not VersionLoopWorldState.is_maintenance_due(), "强制维护结算后不应继续占用路线")
	assert(VersionLoopWorldState.spend_compensation_ticket(), "补偿券应能被后续奖励和商店逻辑消费")
	assert(not VersionLoopWorldState.spend_compensation_ticket(), "补偿券不足时不得透支消费")
	GameState.start_run("computer")


func _test_version_loop_act_one_content() -> void:
	var qixu_cards := 0
	var feilan_cards := 0
	var xunji_cards := 0
	var mimo_cards := 0
	var shared_cards := 0
	for card in Config.cards.values():
		if str(card.major_id) == "qixu":
			qixu_cards += 1
		elif str(card.major_id) == "feilan":
			feilan_cards += 1
		elif str(card.major_id) == "xunji":
			xunji_cards += 1
		elif str(card.major_id) == "mimo":
			mimo_cards += 1
		elif str(card.world_id) == "version_loop":
			shared_cards += 1
	assert(qixu_cards == 54, "祈序成熟卡池应接入 54 张专属牌")
	assert(feilan_cards == 54, "绯澜成熟卡池应接入 54 张专属牌")
	assert(xunji_cards == 54, "循迹成熟卡池应接入 54 张专属牌")
	assert(mimo_cards == 54, "弥默成熟卡池应接入 54 张专属牌")
	assert(shared_cards == 18, "版本回环成熟共享池应包含 18 张可见世界共享牌")
	for enemy_id in [
		"vl_newbie_echo", "vl_stamina_leech", "vl_signin_beast", "vl_resource_sweeper",
		"vl_notice_copy", "vl_compat_glitch", "vl_pipeline_overload", "vl_probability_calibrator",
	]:
		assert(Config.enemies.has(enemy_id), "第一幕缺少敌人：%s" % enemy_id)
	for enemy_id in [
		"vl_outdated_guide", "vl_axis_inspector", "vl_pathing_failure", "vl_rhythm_carrier",
		"vl_rank_aggregate_beast", "vl_context_stripper", "vl_black_red_symbiote", "vl_voice_aggregate",
	]:
		assert(Config.enemies.has(enemy_id), "第二幕缺少敌人：%s" % enemy_id)

	GameState.start_run("qixu", 9090, 0, "version_loop")
	assert(GameState.current_world_id == "version_loop" and GameState.player_character_id == "qixu", "祈序应能在版本回环开始一局")
	assert(GameState.current_screen == GameState.Screen.VERSION_LOOP_EXPLORE, "版本回环开局应进入第一幕地图")
	assert(GameState.get_character_run_state_value("pity") == 0, "祈序开局保底应清零")
	assert(GameState.has_relic("blank_lottery_tube"), "祈序应携带空白签筒初始遗物")

	GameState.player_stats["current_enemy_id"] = "vl_newbie_echo"
	var player := GameState.create_battle_player()
	var battle := Battle.new(player, Config.enemies["vl_newbie_echo"])
	GameState.set_character_run_state_value("pity", 6)
	player.hand = [Config.cards["qixu_single_draw"]]
	battle.energy = 1
	var hp_before := battle.enemy.hp
	assert(battle.play_card(0), "祈序单抽应能结算")
	assert(GameState.get_character_run_state_value("last_random_outcome") == "hit", "满保底后的随机判定必须出货")
	assert(GameState.get_character_run_state_value("pity") == 0, "满保底出货后应清零")
	assert(hp_before - battle.enemy.hp >= 14, "单抽出货应造成高额伤害并计入学识修正")

	var active_player := GameState.create_battle_player()
	var active_battle := Battle.new(active_player, Config.enemies["vl_newbie_echo"])
	GameState.set_character_run_state_value("pity", 2)
	assert(active_battle.use_active_skill(), "祈序拥有至少 2 保底时应能主动校准")
	assert(GameState.get_character_run_state_value("forced_random_outcome") == "hit", "主动校准应锁定下一次出货")
	assert(GameState.get_character_run_state_value("pity") == 0, "主动校准应消耗 2 保底")

	GameState.set_character_run_state_value("pity", 4)
	var snapshot := GameState.create_run_save_snapshot(GameState.Screen.VERSION_LOOP_EXPLORE)
	assert(GameState.restore_run_save_snapshot(snapshot), "版本回环的角色资源应可随一局存档恢复")
	assert(GameState.get_character_run_state_value("pity") == 4, "恢复后不得丢失祈序保底")

	MetaProgression.reset_profile()
	GameState.start_run("qixu", 9091, 0, "version_loop")
	GameState.player_stats["current_enemy_id"] = "vl_probability_calibrator"
	var unlock_player := GameState.create_battle_player()
	var unlock_battle := Battle.new(unlock_player, Config.enemies["vl_probability_calibrator"])
	unlock_battle.enemy.hp = 1
	unlock_player.hand = [Config.cards["qixu_single_draw"]]
	unlock_battle.energy = 1
	assert(unlock_battle.play_card(0), "击败第一幕 Boss 应触发绯澜档案发现")
	assert(MetaProgression.is_character_unlocked("feilan"), "概率校准器击败后应永久发现绯澜")
	var discovered_profile := MetaProgression.create_profile_snapshot()
	MetaProgression.reset_profile()
	assert(MetaProgression.restore_profile_snapshot(discovered_profile), "角色发现状态应随局外档案恢复")
	assert(MetaProgression.is_character_unlocked("feilan"), "恢复档案后不得丢失绯澜发现状态")

	GameState.start_run("feilan", 9092, 0, "version_loop")
	assert(GameState.get_character_run_state_value("heat") == 0, "绯澜开局热度应清零")
	assert(GameState.has_relic("unextinguished_indicator"), "绯澜应携带未熄指示灯初始遗物")
	GameState.player_stats["current_enemy_id"] = "vl_outdated_guide"
	var feilan_player := GameState.create_battle_player()
	var feilan_battle := Battle.new(feilan_player, Config.enemies["vl_outdated_guide"])
	feilan_player.hand = [Config.cards["feilan_forward"], Config.cards["feilan_forward"], Config.cards["feilan_forward"], Config.cards["feilan_break_defense"]]
	feilan_battle.energy = 3
	assert(feilan_battle.play_card(0) and feilan_battle.play_card(0) and feilan_battle.play_card(0), "绯澜应能通过转发累积热度")
	assert(GameState.get_character_run_state_value("heat") >= 5, "三次转发应使绯澜登上热榜")
	var feilan_hp_before := feilan_battle.enemy.hp
	assert(feilan_battle.play_card(0), "热榜状态下破防应能结算")
	assert(feilan_hp_before - feilan_battle.enemy.hp >= 15, "热榜破防应使用高额伤害")
	feilan_player.hand = [Config.cards["feilan_short_comment"]]
	feilan_battle.energy = 1
	assert(feilan_battle.play_card(0) and feilan_battle.has_world_choice_pending(), "短评应要求玩家选择伤害或护盾")
	var shield_before := feilan_player.shield
	assert(feilan_battle.resolve_world_choice("shield"), "短评护航选项应可结算")
	assert(feilan_player.shield >= shield_before + 3, "短评护航应提供护盾")
	assert(feilan_battle.use_active_skill(), "热度足够时绯澜应能引爆话题")
	GameState.start_run("computer")


func _test_version_loop_act_three_content() -> void:
	for enemy_id in [
		"vl_meta_executor", "vl_rollback_wreck", "vl_test_server_leak", "vl_archive_shade",
		"vl_compat_grave", "vl_deprecated_echo", "vl_version_eater", "vl_zero_maintenance",
	]:
		assert(Config.enemies.has(enemy_id), "第三幕缺少敌人：%s" % enemy_id)

	MetaProgression.reset_profile()
	GameState.start_run("qixu", 9093, 0, "version_loop")
	GameState.player_stats["current_enemy_id"] = "vl_zero_maintenance"
	var unlock_player := GameState.create_battle_player()
	var unlock_battle := Battle.new(unlock_player, Config.enemies["vl_zero_maintenance"])
	unlock_battle.enemy.hp = 1
	unlock_player.hand = [Config.cards["qixu_single_draw"]]
	unlock_battle.energy = 1
	assert(unlock_battle.play_card(0), "击败第三幕 Boss 应触发循迹档案发现")
	assert(MetaProgression.is_character_unlocked("xunji"), "零号维护击败后应永久发现循迹")

	GameState.start_run("xunji", 9094, 0, "version_loop")
	assert(GameState.get_character_run_state_value("script_label") == "空脚本", "循迹开局应没有已录制脚本")
	assert(GameState.has_relic("unsaved_macro"), "循迹应携带未保存的宏初始遗物")
	GameState.player_stats["current_enemy_id"] = "vl_meta_executor"
	var xunji_player := GameState.create_battle_player()
	var xunji_battle := Battle.new(xunji_player, Config.enemies["vl_meta_executor"])
	xunji_player.hand = [Config.cards["xunji_record"], Config.cards["xunji_axis_stall"], Config.cards["xunji_copybook"]]
	xunji_battle.energy = 1
	var hp_before := xunji_battle.enemy.hp
	assert(xunji_battle.play_card(0), "循迹应能打出录制")
	assert(xunji_battle.play_card(0), "循迹应能录制可复演的直接伤害")
	assert(GameState.get_character_run_state_value("script_label") == "卡轴", "录制后应显示脚本来源")
	assert(hp_before - xunji_battle.enemy.hp >= 20, "未保存的宏应在首次录制后立刻复演")
	assert(xunji_battle.play_card(0), "抄本应能复演已录制脚本")
	var replay_hp_before := xunji_battle.enemy.hp
	assert(xunji_battle.use_active_skill(), "脚本槽非空时循迹主动技能应可用")
	assert(xunji_battle.enemy.hp < replay_hp_before, "执行脚本应对录制的伤害产生影响")

	GameState.start_run("qixu", 9193, 0, "version_loop")
	GameState.run_enemies_defeated.append({"id": "vl_probability_calibrator", "name": "概率校准器·门神", "type": "boss"})
	GameState.run_enemies_defeated.append({"id": "vl_voice_aggregate", "name": "众声聚合体", "type": "boss"})
	var packed := load("res://src/ui/screens/version_loop_explore.tscn") as PackedScene
	var explore := packed.instantiate() as Control
	add_child(explore)
	await get_tree().process_frame
	assert(int(GameState.get_world_run_state_value("act_index")) == 3, "第二幕 Boss 击败后应推进到第三幕")
	assert(explore._next_encounter_id() == "vl_meta_executor", "第三幕应从退环境执行官开始")
	assert(explore._node_list.get_child_count() == 8, "第三幕应展示 6 普通、1 精英与 1 Boss 节点")
	explore.queue_free()
	await get_tree().process_frame
	GameState.start_run("computer")


func _test_version_loop_endings_and_mimo() -> void:
	var mimo_cards := 0
	for card in Config.cards.values():
		if str(card.major_id) == "mimo":
			mimo_cards += 1
	assert(mimo_cards == 54, "弥默隐藏角色应接入 54 张成熟专属牌")

	MetaProgression.reset_profile()
	for major_id in ["qixu", "feilan", "xunji"]:
		GameState.start_run(major_id, 9300 + ["qixu", "feilan", "xunji"].find(major_id), 0, "version_loop")
		MetaProgression.record_world_clear("version_loop")
	assert(MetaProgression.get_world_character_clear_ids("version_loop") == ["qixu", "feilan", "xunji"], "三名标准角色通关应进入世界名册")
	assert(MetaProgression.is_character_unlocked("mimo"), "三名标准角色各通关一次后应永久解锁弥默")
	var profile_snapshot := MetaProgression.create_profile_snapshot()
	MetaProgression.reset_profile()
	assert(MetaProgression.restore_profile_snapshot(profile_snapshot), "角色通关名册应随局外档案恢复")
	assert(MetaProgression.has_character_cleared_world("version_loop", "xunji"), "恢复后不得丢失角色通关记录")
	assert(MetaProgression.set_world_ending_protocol("version_loop", "permanent_archive"), "版本回环应接受永久归档协议")
	assert(MetaProgression.get_world_ending_protocol("version_loop") == "permanent_archive", "终局协议应永久记录")

	GameState.start_run("mimo", 9310, 0, "version_loop")
	assert(GameState.get_character_run_state_value("meme_shards") == 0, "弥默开局模因片应归零")
	assert(GameState.has_relic("discarded_index"), "弥默应携带废弃索引初始遗物")
	GameState.player_stats["current_enemy_id"] = "vl_meta_executor"
	var mimo_player := GameState.create_battle_player()
	var mimo_battle := Battle.new(mimo_player, Config.enemies["vl_meta_executor"])
	mimo_player.hand = [Config.cards["mimo_clip"], Config.cards["mimo_clip"]]
	mimo_battle.energy = 1
	assert(mimo_battle.play_card(0) and mimo_battle.play_card(0), "弥默应能用回收攻击积累模因片")
	assert(GameState.get_character_run_state_value("meme_shards") >= 3, "废弃索引与两次剪辑应凑齐主动技能资源")
	assert(GameState.get_character_run_state_value("meme_tag") == "攻击", "剪辑片段应将标签更新为攻击")
	var hp_before_active := mimo_battle.enemy.hp
	assert(mimo_battle.use_active_skill(), "攻击标签且模因片足够时应能执行协议拼接")
	assert(mimo_battle.enemy.hp < hp_before_active, "攻击协议拼接应造成伤害")

	GameState.start_run("qixu", 9320, 0, "version_loop")
	GameState.player_stats["last_battle_victory"] = true
	GameState.player_stats["current_enemy_id"] = "vl_zero_maintenance"
	var result_packed := load("res://src/ui/screens/result.tscn") as PackedScene
	var result_screen := result_packed.instantiate() as Control
	add_child(result_screen)
	await get_tree().process_frame
	assert(result_screen._protocol_buttons.size() == 3, "零号维护胜利后应展示三项终局协议")
	result_screen._select_version_loop_protocol("open_protocol")
	assert(MetaProgression.get_world_ending_protocol("version_loop") == "open_protocol", "终局选择应覆盖为当前可读取协议")
	assert(result_screen.continue_button.visible, "选择协议后应允许进入通关总结")
	result_screen.queue_free()
	await get_tree().process_frame
	GameState.start_run("computer")


func _test_version_loop_scene_flow() -> void:
	GameState.start_run("qixu", 9191, 0, "version_loop")
	var packed := load("res://src/ui/screens/version_loop_explore.tscn") as PackedScene
	assert(packed != null, "版本回环第一幕场景应可加载")
	var explore := packed.instantiate() as Control
	add_child(explore)
	await get_tree().process_frame
	assert(explore._next_encounter_id() == "vl_newbie_echo", "第一幕应从新手引导残影开始")
	assert(explore._node_list.get_child_count() == 8, "第一幕应展示 6 普通、1 精英与 1 Boss 节点")
	var events_before := GameState.run_events_resolved
	explore._open_world_event()
	assert(explore._current_event != null and explore._event_shade.visible, "版本路线应能打开本幕异闻选择")
	explore._resolve_world_event(0)
	assert(GameState.run_events_resolved == events_before + 1, "版本异闻结算应计入本局事件次数")
	assert(GameState.has_event_flag("version_loop_event_act_1"), "版本异闻应按幕写入完成标识")
	explore._close_world_event()
	assert(explore._world_event_button.disabled, "同一幕异闻结算后入口应锁定")
	explore.queue_free()
	await get_tree().process_frame
	GameState.run_enemies_defeated.append({"id": "vl_probability_calibrator", "name": "概率校准器·门神", "type": "boss"})
	var act_two_explore := packed.instantiate() as Control
	add_child(act_two_explore)
	await get_tree().process_frame
	assert(int(GameState.get_world_run_state_value("act_index")) == 2, "第一幕 Boss 击败后应推进到第二幕")
	assert(act_two_explore._next_encounter_id() == "vl_outdated_guide", "第二幕应从过期攻略幽灵开始")
	assert(act_two_explore._node_list.get_child_count() == 8, "第二幕应展示 6 普通、1 精英与 1 Boss 节点")
	act_two_explore.queue_free()
	await get_tree().process_frame
	GameState.start_run("computer")


func _test_scaled_finishers() -> void:
	GameState.start_run("computer")
	var computer_player := GameState.create_battle_player()
	var computer_battle := Battle.new(computer_player, Config.enemies["employment_pressure"])
	computer_player.hand = [
		Config.cards["kernel_panic"],
		Config.cards["strike"],
		Config.cards["defend"],
		Config.cards["quick_script"],
		Config.cards["refactor"],
	]
	computer_battle.energy = 3
	var hp_before_kernel := computer_battle.enemy.hp
	assert(computer_battle.play_card(0), "内核恐慌应可打出")
	assert(hp_before_kernel - computer_battle.enemy.hp == 20, "内核恐慌应按其他手牌数量放大")

	GameState.start_run("law")
	var law_player := GameState.create_battle_player()
	var law_battle := Battle.new(law_player, Config.enemies["employment_pressure"])
	law_player.hand = [Config.cards["closing"]]
	law_battle.energy = 3
	law_battle.delay_enemy(2)
	var hp_before_closing := law_battle.enemy.hp
	assert(law_battle.play_card(0), "结案陈词应可打出")
	assert(hp_before_closing - law_battle.enemy.hp == 22, "结案陈词应按拖延回合放大")
	assert(law_battle.get_enemy_delay() == 0, "结案陈词应消耗全部拖延")

	GameState.start_run("medicine")
	var medicine_player := GameState.create_battle_player()
	var medicine_battle := Battle.new(medicine_player, Config.enemies["employment_pressure"])
	medicine_player.hand = [Config.cards["crisis_or"]]
	medicine_battle.energy = 3
	medicine_battle.enemy.add_status("bleed", 2)
	var hp_before_surgery := medicine_battle.enemy.hp
	assert(medicine_battle.play_card(0), "急诊开刀应可打出")
	assert(hp_before_surgery - medicine_battle.enemy.hp == 24, "急诊开刀应按流血层数放大")
	assert(not medicine_battle.enemy.has_status("bleed"), "急诊开刀应消耗全部流血")

	GameState.start_run("finance")
	var finance_player := GameState.create_battle_player()
	var finance_battle := Battle.new(finance_player, Config.enemies["employment_pressure"])
	finance_player.hand = [Config.cards["ipo"]]
	finance_player.gain_shield(10)
	finance_battle.energy = 3
	var hp_before_ipo := finance_battle.enemy.hp
	assert(finance_battle.play_card(0), "上市敲钟应可打出")
	assert(hp_before_ipo - finance_battle.enemy.hp == 20, "上市敲钟应把当前护盾转化为伤害")
	assert(finance_player.shield == 0, "上市敲钟应消耗全部护盾")

	GameState.start_run("arts")
	var arts_player := GameState.create_battle_player()
	var arts_battle := Battle.new(arts_player, Config.enemies["employment_pressure"])
	arts_player.hand = [Config.cards["masterpiece"]]
	arts_battle._turn_card_types = ["skill", "control", "attack"]
	arts_battle.energy = 3
	var hp_before_masterpiece := arts_battle.enemy.hp
	assert(arts_battle.play_card(0), "代表作应可打出")
	assert(hp_before_masterpiece - arts_battle.enemy.hp == 18, "代表作应按本回合出牌数放大")


func _test_event_chains_and_relic_synergies() -> void:
	assert(Config.events.size() == 19, "事件池应包含 14 个校园事件与 5 个版本回环异闻")
	GameState.start_run("computer")
	var handler := EventHandler.new(GameState.player_stats)
	handler.apply_event(Config.events["pop_quiz"], 0)
	assert(GameState.has_event_flag("study_group"), "认真整理错题应开启学习小组事件链")
	assert(GameState.has_event_flag("event:pop_quiz"), "已完成事件应写入本局去重标识")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var library_followup := EventHandler.pick_random_event("library", rng)
	assert(library_followup != null and library_followup.id == "group_research", "学习小组线索应优先触发图书馆后续")
	handler.apply_event(library_followup, 0)
	assert(GameState.has_event_flag("published_outline"), "主导联合研究应开启公开展示终章")
	var showcase := EventHandler.pick_random_event("playground", rng)
	assert(showcase != null and showcase.id == "research_showcase", "研究提纲应优先触发操场终章")
	handler.apply_event(showcase)
	assert(GameState.has_relic("mentor_letter"), "公开展示终章应发放导师推荐信")

	GameState.start_run("medicine")
	handler = EventHandler.new(GameState.player_stats)
	handler.apply_event(Config.events["stay_up"], 0)
	assert(GameState.has_event_flag("roommate_helped"), "帮助室友应开启互助事件链")
	var meal_followup := EventHandler.pick_random_event("cafeteria", rng)
	assert(meal_followup != null and meal_followup.id == "meal_return", "室友互助应优先触发食堂回礼")
	handler.apply_event(meal_followup)
	assert(GameState.has_event_flag("mutual_aid"), "食堂回礼应开启互助接力终章")
	var relay := EventHandler.pick_random_event("playground", rng)
	assert(relay != null and relay.id == "relay_support", "互助线索应优先触发操场接力终章")
	handler.apply_event(relay)
	assert(GameState.has_relic("noise_cancelling"), "互助接力终章应发放降噪耳机")

	GameState.start_run("qixu", 9401, 0, "version_loop")
	handler = EventHandler.new(GameState.player_stats)
	handler.apply_event(Config.events["vl_rerun_vote"], 0)
	assert(GameState.has_event_flag("vl_rerun_vote_support"), "复刻投票的公共卡池选择应开启共享蓝图")
	var version_rng := GameState.make_run_rng("version_loop_event_test", 1)
	var blueprint := EventHandler.pick_random_event("version_loop", version_rng)
	assert(blueprint != null and blueprint.id == "vl_shared_blueprint", "共享蓝图应在投票支持后优先出现")
	handler.apply_event(blueprint, 0)
	assert(GameState.has_event_flag("event:vl_shared_blueprint"), "版本异闻应复用统一事件去重标识")
	assert(not GameState.pending_buffs.is_empty(), "共享蓝图应能为下场战斗写入待生效增益")

	_test_major_relic_effects()


func _test_major_relic_effects() -> void:
	assert(RelicCatalog.all_ids().size() == 19, "遗物池应包含校园遗物与版本回环四名角色初始遗物")
	var major_relics := {
		"computer": "rubber_duck",
		"law": "red_pen",
		"medicine": "field_kit",
		"finance": "risk_terminal",
		"arts": "backstage_pass",
	}
	for major_id in major_relics:
		var relic_id := str(major_relics[major_id])
		assert(str(RelicCatalog.get_info(relic_id).get("major_id", "")) == major_id, "专业遗物归属应与专业一致")
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(major_id)
		for _i in 40:
			var candidate := RelicCatalog.random_relic(rng, true, [], major_id)
			var required_major := str(RelicCatalog.get_info(candidate).get("major_id", ""))
			assert(required_major.is_empty() or required_major == major_id, "奖励不得向 %s 发放其他专业遗物" % major_id)

	GameState.start_run("computer")
	GameState.run_relic_ids = ["rubber_duck"]
	var computer_player := GameState.create_battle_player()
	var computer_battle := Battle.new(computer_player, Config.enemies["gpa_anxiety"])
	computer_player.hand = [Config.cards["quick_script"]]
	computer_player.draw_pile = [Config.cards["strike"], Config.cards["defend"]]
	computer_battle.energy = 3
	computer_battle.play_card(0)
	assert(computer_player.hand.size() == 2, "橡皮鸭应让每回合第一张技能牌额外抽 1 张")

	GameState.start_run("law")
	GameState.run_relic_ids = ["red_pen"]
	var law_player := GameState.create_battle_player()
	var law_battle := Battle.new(law_player, Config.enemies["gpa_anxiety"])
	law_player.hand = [Config.cards["burden_of_proof"]]
	law_battle.energy = 3
	law_battle.play_card(0)
	assert(law_player.shield == 3, "红笔批注应在控制牌后提供 3 点护盾")

	GameState.start_run("medicine")
	GameState.run_relic_ids = ["field_kit"]
	var medicine_player := GameState.create_battle_player()
	var medicine_battle := Battle.new(medicine_player, Config.enemies["gpa_anxiety"])
	medicine_player.hp = medicine_player.max_hp - 1
	medicine_player.hand = [Config.cards["first_aid"]]
	medicine_battle.energy = 3
	medicine_battle.play_card(0)
	assert(medicine_player.hp == medicine_player.max_hp and medicine_player.shield == 8, "诊疗箱应提高治疗并把 8 点溢出转为护盾")

	GameState.start_run("finance")
	GameState.run_relic_ids = ["risk_terminal"]
	var finance_player := GameState.create_battle_player()
	var finance_battle := Battle.new(finance_player, Config.enemies["gpa_anxiety"])
	finance_player.gain_shield(10)
	finance_player.hand = [Config.cards["bull_run"]]
	finance_battle.energy = 3
	var hp_before_risk := finance_battle.enemy.hp
	finance_battle.play_card(0)
	assert(hp_before_risk - finance_battle.enemy.hp == 12, "风险终端应在 10 护盾时为攻击追加 4 点伤害")

	GameState.start_run("arts")
	GameState.run_relic_ids = ["backstage_pass"]
	var arts_player := GameState.create_battle_player()
	var arts_battle := Battle.new(arts_player, Config.enemies["gpa_anxiety"])
	arts_player.hand = [Config.cards["critique"]]
	arts_battle.energy = 3
	arts_battle.play_card(0)
	assert(arts_battle.energy == 3, "后台通行证应为每回合第一张控制牌返还 1 点能量")


func _test_elite_affix_variety() -> void:
	GameState.start_run("computer")
	var seen_affixes := {}
	for battle_index in 64:
		GameState.run_battles_won = battle_index
		var elite_battle := Battle.new(GameState.create_battle_player(), Config.enemies["all_nighter_king"])
		var affix_id := elite_battle.get_elite_affix_id()
		assert(Battle.ELITE_AFFIXES.has(affix_id), "精英遭遇应从受控词缀表选择")
		assert(not elite_battle.get_elite_affix_text().is_empty(), "精英词缀应提供可读名称与说明")
		seen_affixes[affix_id] = true
		match affix_id:
			"iron_wall":
				assert(elite_battle.enemy.shield == 14, "铁壁开题应提供 14 点开场护盾")
			"rapid_fire":
				assert(elite_battle._elite_damage_bonus == 3, "连环追问应提供 3 点直接伤害加成")
			"high_pressure":
				assert(elite_battle.player.get_status_stacks("pressure") == 2, "高压入场应施加 2 层玩家压力")
			"counter_review":
				assert(elite_battle.enemy.get_status_stacks("counter") == 2, "反制评审应提供 2 层反击")
	assert(seen_affixes.keys().size() == 4, "不同局次应覆盖四种精英词缀")

	GameState.run_battles_won = 5
	var deterministic_a := Battle.new(GameState.create_battle_player(), Config.enemies["sports_ace"])
	var deterministic_b := Battle.new(GameState.create_battle_player(), Config.enemies["sports_ace"])
	assert(deterministic_a.get_elite_affix_id() == deterministic_b.get_elite_affix_id(), "同一局次与敌人的词缀应可确定复现")


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
	assert(revision_player.hand.size() == 1, "忽略要求大修时应把下一回合抽牌压至 1 张")

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


func _test_seeded_run_reproducibility() -> void:
	var snapshot_a := _seeded_run_snapshot(20260718)
	var snapshot_b := _seeded_run_snapshot(20260718)
	var snapshot_c := _seeded_run_snapshot(20260719)
	assert(snapshot_a == snapshot_b, "相同局种子应复现牌序、事件、奖励、词缀与敌人意图")
	assert(snapshot_a != snapshot_c, "不同局种子应至少改变一项可观察的随机结果")
	assert(GameState.seed_from_text("") == 0, "空种子输入应请求随机开局")
	assert(GameState.seed_from_text("314159") == 314159, "数字种子应可直接分享复现")
	assert(GameState.seed_from_text("seed") == -1, "非数字种子应被输入校验拒绝")


func _seeded_run_snapshot(seed: int) -> Dictionary:
	GameState.start_run("computer", seed, 0)
	GameState.player_stats["current_enemy_id"] = "all_nighter_king"
	var player := GameState.create_battle_player()
	var deck_order: Array[String] = []
	for card in player.draw_pile:
		deck_order.append(str(card.id))
	var battle := Battle.new(player, Config.enemies["all_nighter_king"])
	var event_rng := GameState.make_run_rng("campus_event:dorm", 100)
	var event := EventHandler.pick_random_event("dorm", event_rng)
	var reward_rng := GameState.make_run_rng("reward:computer", 0)
	var rewards := RewardGenerator.generate_rewards("computer", reward_rng, false)
	var reward_signature: Array[String] = []
	for reward in rewards:
		var card_ids: Array[String] = []
		for card in reward.get("options", []):
			card_ids.append(str(card.id))
		reward_signature.append("%s|%s|%s|%s|%s|%s|%s" % [
			reward.get("type", -1),
			",".join(card_ids),
			reward.get("stat", ""),
			reward.get("status_id", ""),
			reward.get("relic_id", ""),
			reward.get("value", 0),
			reward.get("credits", 0),
		])
	return {
		"deck_order": deck_order,
		"intent": battle.get_enemy_intent_id(),
		"elite_affix": battle.get_elite_affix_id(),
		"event": event.id if event != null else "",
		"rewards": reward_signature,
	}


func _test_difficulty_ladder_rules() -> void:
	GameState.start_run("computer", 77, 0)
	GameState.player_stats["current_enemy_id"] = "gpa_anxiety"
	var standard_player := GameState.create_battle_player()
	var standard_battle := Battle.new(standard_player, Config.enemies["gpa_anxiety"])
	standard_battle._enemy_intent = {"id": "attack", "value": 5}
	var standard_window := standard_battle.begin_defense_window()
	assert(standard_battle.enemy.max_hp == Config.enemies["gpa_anxiety"].hp, "标准生存不应缩放敌人生命")
	assert(not standard_player.has_status("pressure"), "标准生存不应附加开场压力")

	GameState.start_run("computer", 77, 3)
	GameState.player_stats["current_enemy_id"] = "gpa_anxiety"
	var hard_player := GameState.create_battle_player()
	var hard_battle := Battle.new(hard_player, Config.enemies["gpa_anxiety"])
	hard_battle._enemy_intent = {"id": "attack", "value": 5}
	var hard_window := hard_battle.begin_defense_window()
	assert(
		hard_battle.enemy.max_hp == int(round(float(Config.enemies["gpa_anxiety"].hp) * 2.0)),
		"唯一席位应把敌人生命提高 100%"
	)
	assert(hard_player.get_status_stacks("pressure") == 3, "唯一席位应从 3 层压力开战")
	assert(
		float(hard_window.get("duration", 0.0)) < float(standard_window.get("duration", 0.0)),
		"高阶挑战应压缩答辩反应时间"
	)
	assert(
		float(hard_window.get("perfect_width", 0.0)) < float(standard_window.get("perfect_width", 0.0)),
		"高阶挑战应缩小精准反驳区间"
	)

	GameState.start_run("computer", 77, 3)
	GameState.player_stats["current_enemy_id"] = "gpa_anxiety"
	var damage_player := GameState.create_battle_player()
	var damage_battle := Battle.new(damage_player, Config.enemies["gpa_anxiety"])
	damage_player.shield = 0
	damage_player.hp = 200
	damage_battle._enemy_intent = {"id": "attack", "value": 5}
	var hp_before := damage_player.hp
	damage_battle.end_player_turn()
	assert(hp_before - damage_player.hp == 85, "唯一席位中忽略攻击意图会叠加压力与五倍惩罚")

	GameState.start_run("computer", 77, 0)
	var standard_credits := GameState.credits
	GameState.record_enemy_defeat("gpa_anxiety", "绩点焦虑者", "normal")
	standard_credits = GameState.credits - standard_credits
	GameState.start_run("computer", 77, 3)
	var challenge_credits := GameState.credits
	GameState.record_enemy_defeat("gpa_anxiety", "绩点焦虑者", "normal")
	challenge_credits = GameState.credits - challenge_credits
	assert(challenge_credits == int(round(float(standard_credits) * 1.5)), "最高挑战的战斗资源收益应提高 50%")
	GameState.run_hp = GameState.run_max_hp - 20
	assert(GameState.heal_run(10) == 5, "最高挑战的校内恢复应降低 50%")

	var previous_highest := Achievements.highest_cleared_difficulty
	Achievements.highest_cleared_difficulty = -1
	assert(Achievements.get_max_unlocked_difficulty() == 0, "新档只应开放标准生存")
	Achievements.highest_cleared_difficulty = 0
	assert(Achievements.get_max_unlocked_difficulty() == 1, "通关标准生存后应开放高压答辩")
	Achievements.highest_cleared_difficulty = 3
	assert(Achievements.get_max_unlocked_difficulty() == 3, "挑战阶梯不得越过最高档")
	Achievements.highest_cleared_difficulty = previous_highest


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
	assert(menu.get_node("MenuSidebar/Margin/VBox/ProgressionButton") is Button, "主菜单应提供局外成长入口")
	assert("校园世界" in menu.get_node("MajorCallout/Margin/VBox/Stats").text, "中枢档案应展示唯一初始世界")
	assert("未发现其他世界" in menu.get_node("MajorCallout/Margin/VBox/Survivors").text, "首次进入不得展示空世界入口")
	menu.queue_free()
	await get_tree().process_frame

	MetaProgression.reset_profile()
	MetaProgression.grant_gold(500)
	var progression := (load("res://src/ui/screens/meta_progression.tscn") as PackedScene).instantiate()
	add_child(progression)
	await get_tree().process_frame
	assert(progression.talent_list.get_child_count() == MetaProgression.TALENTS.size(), "成长界面应展示全部永久天赋")
	assert(progression.equipment_list.get_child_count() == MetaProgression.EQUIPMENT.size() + MetaProgression.EQUIPMENT_SLOTS.size(), "成长界面应按三槽展示全部装备")
	assert(progression.upgrade_list.get_child_count() == MetaProgression.UPGRADES.size(), "成长界面应展示四条永久强化")
	assert("500" in progression.gold_label.text, "成长界面应展示当前永久金币")
	progression._on_talent_action("healthy_routine")
	assert(MetaProgression.is_talent_equipped("healthy_routine"), "成长界面应能购买并自动装配天赋")
	progression._on_equipment_action("graphing_calculator")
	assert(MetaProgression.get_equipped_equipment().get("tool") == "graphing_calculator", "成长界面应能购买并装配装备")
	progression._on_upgrade_action("survival_training")
	assert(MetaProgression.get_upgrade_level("survival_training") == 1, "成长界面应能购买永久强化")
	progression.queue_free()
	await get_tree().process_frame
	MetaProgression.reset_profile()

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
	GameState.start_run("finance", 424242, 2)
	assert(GameState.current_world_id == "campus", "未显式指定时应进入校园世界")
	assert(GameState.player_character_id == "finance", "通用角色身份应兼容现有专业身份")
	GameState.run_hp -= 11
	GameState.run_progress = 4
	GameState.day_count = 3
	GameState.permanent_stats["资源"] = 2
	GameState.pending_buffs.clear()
	GameState.pending_buffs.append({"status_id": "shield", "stacks": 6})
	GameState.run_relic_ids.clear()
	GameState.run_relic_ids.append("mentor_letter")
	GameState.run_event_flags.clear()
	GameState.run_event_flags.append_array(["study_group", "event:pop_quiz"])
	GameState.campus_player_position = Vector2(734, 488)
	GameState.campus_visited_locations.clear()
	GameState.campus_visited_locations.append_array(["teaching", "library"])
	GameState.player_stats["current_enemy_id"] = "ai_interviewer"
	GameState.player_stats["battle_player"] = Character.new("temporary", "不可序列化对象", 10)
	var expected_hp := GameState.run_hp
	var expected_deck := GameState.deck_card_ids.duplicate()
	var snapshot := GameState.create_run_save_snapshot(GameState.Screen.BATTLE)
	assert(GameState.is_run_save_snapshot_valid(snapshot), "完整的一局快照应通过版本与内容校验")
	assert(snapshot.world_id == "campus" and snapshot.player_character_id == "finance", "存档应记录世界与通用角色身份")
	assert(snapshot.world_run_state == {}, "存档应为当前世界预留受约束的局内状态")
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
	var broken_world_snapshot := snapshot.duplicate(true)
	broken_world_snapshot["world_id"] = "missing_world"
	assert(not GameState.is_run_save_snapshot_valid(broken_world_snapshot), "存档引用未知世界时应安全拒绝")

	GameState.start_run("computer")
	assert(GameState.restore_run_save_snapshot(snapshot), "版本化一局快照应可恢复")
	assert(GameState.current_world_id == "campus" and GameState.player_character_id == "finance", "恢复后世界与角色身份应保持")
	assert(GameState.player_major_id == "finance", "恢复后专业应与存档一致")
	assert(GameState.current_screen == GameState.Screen.BATTLE, "战斗前检查点应恢复为一场全新战斗")
	assert(GameState.run_hp == expected_hp and GameState.deck_card_ids == expected_deck, "恢复后生命与牌组应保持一致")
	assert(GameState.permanent_stats.get("资源", 0) == 2, "永久属性应进入存档")
	assert(GameState.pending_buffs == [{"status_id": "shield", "stacks": 6}], "待生效状态应进入存档")
	assert(GameState.campus_player_position == Vector2(734, 488), "校园位置应进入存档")
	assert(GameState.run_event_flags == ["study_group", "event:pop_quiz"], "事件链线索与完成标识应进入存档")
	assert(GameState.run_seed == 424242 and GameState.run_difficulty == 2, "固定种子与挑战难度应进入安全存档")
	assert(not GameState.run_instance_id.is_empty(), "一局唯一标识应进入安全存档")

	var legacy_snapshot := snapshot.duplicate(true)
	legacy_snapshot.erase("run_meta_effects")
	legacy_snapshot.erase("run_meta_talent_ids")
	legacy_snapshot.erase("run_meta_equipment")
	legacy_snapshot.erase("run_instance_id")
	GameState.start_run("computer")
	assert(GameState.restore_run_save_snapshot(legacy_snapshot), "旧一局存档缺少局外成长字段时应安全恢复")
	assert(GameState.run_meta_effects.is_empty(), "旧一局存档应回落为空的局外加成")
	assert(GameState.run_meta_talent_ids.is_empty() and GameState.run_meta_equipment.is_empty(), "旧一局存档应回落为空配置")
	assert(GameState.run_instance_id.begins_with("legacy-"), "旧一局存档应生成稳定的兼容结算标识")

	var version_one_snapshot := snapshot.duplicate(true)
	version_one_snapshot["version"] = 1
	version_one_snapshot.erase("world_id")
	version_one_snapshot.erase("player_character_id")
	version_one_snapshot.erase("world_run_state")
	GameState.start_run("computer")
	assert(GameState.restore_run_save_snapshot(version_one_snapshot), "V1校园存档应迁移到首个世界包")
	assert(GameState.current_world_id == "campus" and GameState.player_character_id == "finance", "V1存档迁移不得丢失专业身份")


func _test_run_config_ui() -> void:
	var previous_highest := Achievements.highest_cleared_difficulty
	Achievements.highest_cleared_difficulty = -1
	var packed := load("res://src/ui/screens/major_select.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var difficulty: OptionButton = screen.get_node(
		"SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/RunConfigCol/DifficultyOption"
	)
	var seed: LineEdit = screen.get_node(
		"SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/RunConfigCol/SeedEdit"
	)
	assert(difficulty.item_count == GameState.DIFFICULTY_CATALOG.size(), "开局页应展示四档挑战规则")
	assert(not difficulty.is_item_disabled(0), "标准生存应默认开放")
	assert(difficulty.is_item_disabled(1), "未通关标准生存前不得选择下一阶挑战")
	seed.text = "8080"
	assert(screen._get_run_seed() == 8080, "开局页应接受可分享的数字种子")
	seed.text = "错误种子"
	assert(screen._get_run_seed() == -1, "开局页应拒绝非数字种子")
	screen.queue_free()
	await get_tree().process_frame
	Achievements.highest_cleared_difficulty = previous_highest


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
