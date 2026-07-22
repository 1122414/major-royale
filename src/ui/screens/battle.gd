extends Control
## 战斗场景。

const CARD_VIEW_SCENE := preload("res://src/ui/widgets/card_view.tscn")
const STATUS_ICON_SCENE := preload("res://src/ui/widgets/status_icon.tscn")
const BattleHandLayout := preload("res://src/ui/widgets/battle_hand_layout.gd")
const RelicCatalog := preload("res://src/logic/relic.gd")

@onready var enemy_name_label: Label = $EnemyPanel/VBoxContainer/EnemyNameLabel
@onready var enemy_hp_label: Label = $EnemyPanel/VBoxContainer/EnemyHPLabel
@onready var enemy_intent_label: Label = $EnemyPanel/VBoxContainer/EnemyIntentLabel
@onready var enemy_status_container: HBoxContainer = $EnemyPanel/VBoxContainer/EnemyStatusContainer
@onready var player_hp_label: Label = $PlayerPanel/VBoxContainer/PlayerHPLabel
@onready var player_spirit_label: Label = $PlayerPanel/VBoxContainer/PlayerSpiritLabel
@onready var energy_label: Label = $PlayerPanel/VBoxContainer/EnergyLabel
@onready var character_resource_label: Label = $PlayerPanel/VBoxContainer/CharacterResourceLabel
@onready var player_status_container: VBoxContainer = $BuffPanel/BuffCol/PlayerStatusContainer
@onready var hand_container: HBoxContainer = $HandContainer
@onready var end_turn_button: Button = $ActionPanel/VBox/EndTurnButton
@onready var skill_button: Button = $ActionPanel/VBox/SkillButton
@onready var message_label: Label = $MessageLabel
@onready var turn_label: Label = $TopBar/Margin/TopRow/TurnLabel
@onready var battle_title: Label = $TopBar/Margin/TopRow/BattleTitle
@onready var player_title: Label = $TopBar/Margin/TopRow/PlayerTitle
@onready var pressure_label: Label = $TopBar/Margin/TopRow/PressureLabel
@onready var settings_button: Button = $TopBar/Margin/TopRow/SettingsButton
@onready var draw_pile_label: Label = $DeckPanel/VBox/DrawPileLabel
@onready var discard_pile_label: Label = $DeckPanel/VBox/DiscardPileLabel
@onready var deck_total_label: Label = $DeckPanel/VBox/DeckTotalLabel
@onready var relic_label: Label = $DeckPanel/VBox/RelicLabel
@onready var battle_stage: BattleStage = $Arena
@onready var ai_banner: PanelContainer = $AIBanner
@onready var ai_profile_panel: PanelContainer = $AIProfilePanel
@onready var ai_profile_body: Label = $AIProfilePanel/ProfileVBox/ProfileBody
@onready var ai_loot_preview: Label = $AIProfilePanel/ProfileVBox/LootPreview
@onready var ai_actions_panel: PanelContainer = $AIActionsPanel
@onready var ai_actions_list: VBoxContainer = $AIActionsPanel/ActionsVBox/ActionsList
@onready var ai_chat_bubble: PanelContainer = $AIChatBubble
@onready var ai_state_label: Label = $AIChatBubble/BubbleVBox/AIStateLabel
@onready var ai_bubble_text: Label = $AIChatBubble/BubbleVBox/BubbleText
@onready var ai_profile_title: Label = $AIProfilePanel/ProfileVBox/ProfileTitle
@onready var ai_profile_portrait: TextureRect = $AIProfilePanel/ProfileVBox/ProfilePortrait
@onready var ai_threat_label: Label = $AIProfilePanel/ProfileVBox/ThreatLabel
@onready var ai_adapt_label: Label = $AIProfilePanel/ProfileVBox/AdaptLabel
@onready var buff_panel: PanelContainer = $BuffPanel
@onready var defense_window: PanelContainer = $DefenseWindow
@onready var defense_title: Label = $DefenseWindow/Margin/VBox/Title
@onready var defense_countdown: Label = $DefenseWindow/Margin/VBox/CountdownLabel
@onready var defense_timing_bar: ProgressBar = $DefenseWindow/Margin/VBox/TimingBar
@onready var defense_left_button: Button = $DefenseWindow/Margin/VBox/LaneRow/LeftLaneButton
@onready var defense_center_button: Button = $DefenseWindow/Margin/VBox/LaneRow/CenterLaneButton
@onready var defense_right_button: Button = $DefenseWindow/Margin/VBox/LaneRow/RightLaneButton
@onready var defense_confirm_button: Button = $DefenseWindow/Margin/VBox/LaneRow/ConfirmButton

var _battle: Battle
var _is_ai_battle: bool = false
var _enemy_res: EnemyResource = null
var _defense_active := false
var _defense_context: Dictionary = {}
var _defense_elapsed := 0.0
var _defense_lane := 1
var _ui_update_queued := false
var _last_ai_actions_selected := "__uninitialized__"
var _world_choice_panel: PanelContainer = null


func _ready() -> void:
	var enemy_id: String = GameState.player_stats.get("current_enemy_id", "gpa_anxiety")
	var enemy_res = Config.enemies.get(enemy_id)
	if enemy_res == null:
		enemy_res = Config.enemies["gpa_anxiety"]
	_enemy_res = enemy_res
	_is_ai_battle = bool(enemy_res.is_ai_native)

	var player := _create_player()
	_battle = Battle.new(player, enemy_res)
	GameState.player_stats["battle_player"] = player
	_battle.hand_updated.connect(_request_ui_update)
	_battle.energy_updated.connect(_request_ui_update)
	_battle.turn_changed.connect(_on_turn_changed)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.skill_used.connect(_on_skill_used)
	_battle.ai_decision_requested.connect(_on_ai_decision_requested)
	_battle.boss_phase_changed.connect(_on_boss_phase_changed)
	_battle.character_resource_updated.connect(_request_ui_update)
	_battle.world_rule_feedback.connect(_on_world_rule_feedback)
	_battle.world_choice_requested.connect(_on_world_choice_requested)

	AIClient.decision_received.connect(_on_ai_decision_received)
	AIClient.decision_failed.connect(_on_ai_decision_failed)

	end_turn_button.pressed.connect(_on_end_turn)
	skill_button.pressed.connect(_on_skill)
	settings_button.pressed.connect(_on_settings)
	defense_left_button.pressed.connect(_set_defense_lane.bind(0))
	defense_center_button.pressed.connect(_set_defense_lane.bind(1))
	defense_right_button.pressed.connect(_set_defense_lane.bind(2))
	defense_confirm_button.pressed.connect(_resolve_defense_window.bind(true))

	var major: MajorResource = Config.majors[GameState.player_major_id]
	skill_button.text = major.active_skill.get("name", "技能")
	skill_button.tooltip_text = str(major.active_skill.get("description", ""))
	player_title.text = "%s新生" % major.name
	battle_title.text = "战斗"
	_setup_ai_native_ui(enemy_id, enemy_res)
	_setup_battle_art(enemy_id)
	_battle.request_current_ai_decision()

	_update_ui()
	if _battle.state == Battle.BattleState.PLAYER_LOST:
		call_deferred("_on_battle_ended", false)
	AudioManager.play_sfx("click")
	if _enemy_res != null and (str(_enemy_res.enemy_type) == "boss" or str(_enemy_res.id) == "employment_pressure"):
		AudioManager.play_bgm_for_phase("boss")
	else:
		AudioManager.play_bgm_for_phase("battle")


func _process(delta: float) -> void:
	if not _defense_active:
		return
	var duration := maxf(0.01, float(_defense_context.get("duration", 1.5)))
	_defense_elapsed = minf(_defense_elapsed + delta, duration)
	var normalized := _defense_elapsed / duration
	defense_timing_bar.value = normalized * 100.0
	var remaining := maxf(0.0, duration - _defense_elapsed)
	var perfect_center := float(_defense_context.get("perfect_center", 0.72))
	var perfect_width := float(_defense_context.get("perfect_width", 0.1))
	var in_perfect_window := absf(normalized - perfect_center) <= perfect_width
	if _defense_lane == int(_defense_context.get("danger_lane", 1)) and in_perfect_window:
		defense_countdown.text = "金色刻度！现在反驳　%.1fs" % remaining
		defense_countdown.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
		defense_timing_bar.modulate = UIColors.ACCENT_GOLD
	else:
		defense_countdown.text = "避开红色落点，或留在危险位等待金色刻度　%.1fs" % remaining
		defense_countdown.add_theme_color_override("font_color", UIColors.BORDER_CYAN_BRIGHT)
		defense_timing_bar.modulate = Color.WHITE
	if _defense_elapsed >= duration:
		_resolve_defense_window(false)


func _exit_tree() -> void:
	if AIClient.decision_received.is_connected(_on_ai_decision_received):
		AIClient.decision_received.disconnect(_on_ai_decision_received)
	if AIClient.decision_failed.is_connected(_on_ai_decision_failed):
		AIClient.decision_failed.disconnect(_on_ai_decision_failed)
	if _battle != null:
		_disconnect_battle_signals()
		_battle = null
	_enemy_res = null
	GameState.player_stats.erase("battle_player")


func _disconnect_battle_signals() -> void:
	var connections := [
		[_battle.hand_updated, _request_ui_update],
		[_battle.energy_updated, _request_ui_update],
		[_battle.turn_changed, _on_turn_changed],
		[_battle.battle_ended, _on_battle_ended],
		[_battle.skill_used, _on_skill_used],
		[_battle.ai_decision_requested, _on_ai_decision_requested],
		[_battle.boss_phase_changed, _on_boss_phase_changed],
		[_battle.character_resource_updated, _request_ui_update],
		[_battle.world_rule_feedback, _on_world_rule_feedback],
		[_battle.world_choice_requested, _on_world_choice_requested],
	]
	for connection in connections:
		if connection[0].is_connected(connection[1]):
			connection[0].disconnect(connection[1])


func _setup_ai_native_ui(enemy_id: String, enemy_res: EnemyResource) -> void:
	ai_banner.visible = _is_ai_battle
	ai_profile_panel.visible = _is_ai_battle
	ai_actions_panel.visible = _is_ai_battle
	ai_chat_bubble.visible = _is_ai_battle
	buff_panel.visible = not _is_ai_battle
	battle_stage.set_ai_mode(_is_ai_battle)
	# 精英战隐藏右侧标准敌人面板，避免与「可选行动」重叠
	$EnemyPanel.visible = not _is_ai_battle
	if not _is_ai_battle:
		return
	battle_title.text = "AI 精英遭遇"
	battle_title.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	var banner: Label = ai_banner.get_node("BannerLabel")
	banner.text = "⚠ 精英遭遇：%s　生命 %d/%d" % [enemy_res.name, enemy_res.hp, enemy_res.hp]
	var trait_str := " / ".join(PackedStringArray(enemy_res.traits)) if enemy_res.traits.size() > 0 else "AI Native"
	ai_profile_title.text = enemy_res.name
	ai_profile_body.text = "%s\n弱点：%s" % [
		trait_str,
		enemy_res.weakness if enemy_res.weakness != "" else "未知",
	]
	var threat_blocks := clampi(int(ceil(float(enemy_res.hp) / 18.0)), 1, 5)
	ai_threat_label.text = "强度　%s%s" % ["■".repeat(threat_blocks), "□".repeat(5 - threat_blocks)]
	var adapt_blocks := clampi(enemy_res.actions.size(), 1, 5)
	ai_adapt_label.text = "适应性　%s%s" % ["■".repeat(adapt_blocks), "□".repeat(5 - adapt_blocks)]
	if enemy_id == "paper_reviewer":
		ai_loot_preview.text = "掉落预览\n稀有卡 / 审稿意见遗物"
	else:
		ai_loot_preview.text = "掉落预览\n稀有卡 / 算法幸存者称号"
	if Settings.ai_enabled:
		_set_ai_strategy_ui("本地策略已装载", enemy_res.specialty, UIColors.AI_PURPLE)
	else:
		_set_ai_strategy_ui("离线策略已就绪", _battle.get_enemy_intent_text(), UIColors.AI_PURPLE)
	_refresh_ai_actions("")
	# 左档案窄栏，右行动贴顶不挡立绘
	ai_profile_panel.offset_left = 12.0
	ai_profile_panel.offset_top = 100.0
	ai_profile_panel.offset_right = 226.0
	ai_profile_panel.offset_bottom = 326.0
	ai_actions_panel.offset_left = 1032.0
	ai_actions_panel.offset_top = 100.0
	ai_actions_panel.offset_right = 1268.0
	ai_actions_panel.offset_bottom = 364.0
	# 把敌人状态/意图写到横幅下方短提示
	enemy_name_label.text = enemy_res.name
	enemy_hp_label.text = "HP: %d/%d" % [enemy_res.hp, enemy_res.hp]

func _refresh_ai_actions(selected_id: String) -> void:
	if not _is_ai_battle or _enemy_res == null:
		return
	if selected_id == _last_ai_actions_selected and ai_actions_list.get_child_count() == _enemy_res.actions.size():
		return
	_last_ai_actions_selected = selected_id
	for child in ai_actions_list.get_children():
		ai_actions_list.remove_child(child)
		child.queue_free()
	for action in _enemy_res.actions:
		var aid: String = str(action.get("id", ""))
		var row := PanelContainer.new()
		var label := Label.new()
		var name_map := {
			"ask_algorithm": "算法追问",
			"ask_ethics": "职业伦理",
			"resume_challenge": "简历质疑",
			"praise_then_pressure": "先夸后压",
			"silent_observe": "沉默观察",
			"reject_core_card": "拒绝核心卡",
			"demand_revision": "要求大修",
			"question_method": "质疑方法",
			"accept_minor": "小修接收",
			"desk_reject": "直接拒稿",
		}
		label.text = "%s %s\n%s" % ["▶" if aid == selected_id else "•", name_map.get(aid, aid), action.get("description", "")]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 10)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.12, 0.15, 0.94)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		if aid == selected_id:
			label.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
			style.border_color = UIColors.ACCENT_GOLD
		else:
			label.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
			style.border_color = UIColors.BORDER_CYAN_DIM
		row.add_theme_stylebox_override("panel", style)
		row.add_child(label)
		ai_actions_list.add_child(row)

func _setup_battle_art(enemy_id: String) -> void:
	var bg: TextureRect = $PixelBackground
	if bg and bg.has_method("_ready"):
		if GameState.current_world_id == "version_loop":
			var act_index := int(GameState.get_world_run_state_value("act_index", 1))
			if act_index == 3:
				bg.texture_path = "res://assets/sprites/bg/version_loop_graveyard.png"
			elif act_index == 2:
				bg.texture_path = "res://assets/sprites/bg/version_loop_tide_plaza.png"
			else:
				bg.texture_path = "res://assets/sprites/bg/version_loop_warmup.png"
			if ResourceLoader.exists(bg.texture_path):
				bg.texture = load(bg.texture_path)
		elif enemy_id == "employment_pressure":
			bg.texture_path = "res://assets/sprites/bg/battle_finale.png"
			if ResourceLoader.exists(bg.texture_path):
				bg.texture = load(bg.texture_path)
		elif _is_ai_battle:
			bg.texture_path = "res://assets/sprites/bg/battle_interview.png"
			if ResourceLoader.exists(bg.texture_path):
				bg.texture = load(bg.texture_path)
		else:
			bg.texture_path = "res://assets/sprites/bg/battle_classroom.png"
			if ResourceLoader.exists(bg.texture_path):
				bg.texture = load(bg.texture_path)

	var player_path := "res://assets/sprites/chars/player_cs.png"
	match GameState.player_major_id:
		"law": player_path = "res://assets/sprites/chars/player_law.png"
		"medicine": player_path = "res://assets/sprites/chars/player_med.png"
		"finance": player_path = "res://assets/sprites/chars/player_finance.png"
		"arts": player_path = "res://assets/sprites/chars/player_arts.png"
		"qixu": player_path = "res://assets/sprites/chars/player_qixu.png"
		"feilan": player_path = "res://assets/sprites/chars/player_feilan.png"
		"xunji": player_path = "res://assets/sprites/chars/player_xunji.png"
		"mimo": player_path = "res://assets/sprites/chars/player_mimo.png"
	var enemy_paths := {
		"gpa_anxiety": "res://assets/sprites/chars/enemy_anxiety.png",
		"seat_grabber": "res://assets/sprites/chars/enemy_seat_grabber.png",
		"all_nighter": "res://assets/sprites/chars/enemy_all_nighter.png",
		"sports_student": "res://assets/sprites/chars/enemy_sports_student.png",
		"client_phantom": "res://assets/sprites/chars/enemy_client_phantom.png",
		"all_nighter_king": "res://assets/sprites/chars/enemy_all_nighter_elite.png",
		"sports_ace": "res://assets/sprites/chars/enemy_sports_ace.png",
		"ai_interviewer": "res://assets/sprites/chars/enemy_ai.png",
		"paper_reviewer": "res://assets/sprites/chars/enemy_reviewer.png",
		"employment_pressure": "res://assets/sprites/chars/enemy_boss.png",
		"vl_probability_calibrator": "res://assets/sprites/chars/enemy_probability_calibrator.png",
		"vl_voice_aggregate": "res://assets/sprites/chars/enemy_voice_aggregate.png",
		"vl_zero_maintenance": "res://assets/sprites/chars/enemy_zero_maintenance.png",
	}
	var enemy_path: String = enemy_paths.get(enemy_id, "res://assets/sprites/chars/enemy_ai.png" if GameState.current_world_id == "version_loop" else "res://assets/sprites/chars/enemy_anxiety.png")
	battle_stage.setup_art(player_path, enemy_path)
	if _is_ai_battle and ResourceLoader.exists(enemy_path):
		ai_profile_portrait.texture = load(enemy_path)

func _create_player() -> Character:
	return GameState.create_battle_player()


func _request_ui_update() -> void:
	if _ui_update_queued:
		return
	_ui_update_queued = true
	call_deferred("_flush_ui_update")


func _flush_ui_update() -> void:
	_ui_update_queued = false
	if not is_inside_tree() or _battle == null:
		return
	_update_ui()


func _update_ui() -> void:
	if not _is_ai_battle:
		enemy_name_label.text = _battle.enemy.display_name
		var specialty := ""
		if _enemy_res != null:
			specialty = str(_enemy_res.specialty)
		var affix_text := _battle.get_elite_affix_text()
		if not affix_text.is_empty():
			specialty = "%s\n词缀：%s" % [specialty, affix_text] if not specialty.is_empty() else "词缀：%s" % affix_text
		enemy_hp_label.text = "HP: %d/%d 护盾: %d" % [_battle.enemy.hp, _battle.enemy.max_hp, _battle.enemy.shield]
		if specialty != "":
			enemy_intent_label.text = "特长：%s\n意图: %s" % [specialty, _battle.get_enemy_intent_text()]
		else:
			enemy_intent_label.text = "意图: %s" % _battle.get_enemy_intent_text()
		if _enemy_res != null and _enemy_res.weakness != "":
			enemy_intent_label.tooltip_text = "弱点：%s" % _enemy_res.weakness
	else:
		var banner: Label = ai_banner.get_node("BannerLabel")
		banner.text = "⚠ 精英遭遇：%s　生命 %d/%d　护盾 %d" % [
			_battle.enemy.display_name,
			_battle.enemy.hp,
			_battle.enemy.max_hp,
			_battle.enemy.shield,
		]
		_refresh_ai_actions(_battle.get_enemy_intent_id())

	player_hp_label.text = "♥ 生命 %d/%d　护盾 %d" % [_battle.player.hp, _battle.player.max_hp, _battle.player.shield]
	player_spirit_label.text = "◆ 精神 %d/%d" % [_battle.player.spirit, _battle.player.max_spirit]
	energy_label.text = "⚡ 能量 %d/%d" % [_battle.energy, _battle.max_energy]
	if GameState.current_world_id == "version_loop":
		var act_index := int(GameState.get_world_run_state_value("act_index", 1))
		var act_name := "版本坟场" if act_index == 3 else ("活动高峰" if act_index == 2 else "新服预热")
		battle_title.text = "版本回环 · %s" % act_name
		var title := "模因回收员" if GameState.player_character_id == "mimo" else ("流程代行员" if GameState.player_character_id == "xunji" else ("舆潮主播" if GameState.player_character_id == "feilan" else "概率校准师"))
		player_title.text = "%s · %s" % [Config.characters[GameState.player_character_id].name, title]
		turn_label.text = "第%d幕　第 %d 回合" % [act_index, _battle.turn_count]
		var maintenance := int(GameState.get_world_run_state_value("maintenance_clock", 0))
		pressure_label.text = "维护 %s" % ("●".repeat(maintenance) + "○".repeat(4 - maintenance))
		character_resource_label.visible = true
		if GameState.player_character_id == "feilan":
			var heat := int(GameState.get_character_run_state_value("heat", 0))
			var comments := int(GameState.get_character_run_state_value("short_comments_played", 0))
			character_resource_label.text = "◉ 热度 %d/10　%s　短评 %d" % [heat, "热榜" if heat >= 5 else "蓄势", comments]
			character_resource_label.add_theme_color_override("font_color", UIColors.DANGER_RED if heat >= 5 else UIColors.AI_PURPLE)
		elif GameState.player_character_id == "xunji":
			var script_label := str(GameState.get_character_run_state_value("script_label", "空脚本"))
			var sequence := str(GameState.get_character_run_state_value("recent_sequence", ""))
			character_resource_label.text = "◉ 脚本：%s　牌序：%s" % [script_label, sequence if not sequence.is_empty() else "—"]
			character_resource_label.add_theme_color_override("font_color", UIColors.BORDER_CYAN_BRIGHT)
		elif GameState.player_character_id == "mimo":
			var shards := int(GameState.get_character_run_state_value("meme_shards", 0))
			var meme_tag := str(GameState.get_character_run_state_value("meme_tag", "空白"))
			character_resource_label.text = "◉ 模因片 %d/12　标签：%s" % [shards, meme_tag]
			character_resource_label.add_theme_color_override("font_color", UIColors.AI_PURPLE)
		else:
			var pity := int(GameState.get_character_run_state_value("pity", 0))
			var last_result := str(GameState.get_character_run_state_value("last_random_outcome", ""))
			var result_text: String = str({"miss": "歪", "hit": "出货"}.get(last_result, "未结算"))
			character_resource_label.text = "◉ 保底 %d/6　最近：%s" % [pity, result_text]
			character_resource_label.add_theme_color_override("font_color", UIColors.ACCENT_GOLD if pity >= 6 else UIColors.BORDER_CYAN_BRIGHT)
	else:
		turn_label.text = "第%d天 第%d回合" % [GameState.day_count, _battle.turn_count]
		pressure_label.text = "压力等级 %d" % maxi(1, GameState.run_progress + 1)
		character_resource_label.visible = false
	var deck_total := _battle.player.deck.size()
	draw_pile_label.text = "抽牌堆 %d" % _battle.player.draw_pile.size()
	deck_total_label.text = "牌库 %d" % deck_total
	draw_pile_label.tooltip_text = "开局会先抽到手牌；抽完后从弃牌堆洗回。"
	discard_pile_label.text = "弃牌堆 %d" % _battle.player.discard_pile.size()
	relic_label.text = RelicCatalog.format_list(GameState.run_relic_ids)
	relic_label.tooltip_text = relic_label.text
	for rid in GameState.run_relic_ids:
		var info: Dictionary = RelicCatalog.get_info(str(rid))
		relic_label.tooltip_text += "\n【%s】%s" % [info.get("name", rid), info.get("desc", "")]

	_update_status_icons(enemy_status_container, _battle.enemy.statuses)
	_update_status_icons(player_status_container, _battle.player.statuses)

	_rebuild_hand()

	end_turn_button.disabled = _battle.state != Battle.BattleState.PLAYER_TURN or _defense_active or _battle.has_world_choice_pending()
	skill_button.disabled = _battle.state != Battle.BattleState.PLAYER_TURN or _defense_active or _battle.has_world_choice_pending()


func _rebuild_hand() -> void:
	## 手牌始终相对底部居中；牌多时自动缩宽，避免挤向右侧。
	while hand_container.get_child_count() > 0:
		var child: Node = hand_container.get_child(0)
		hand_container.remove_child(child)
		child.queue_free()

	var n: int = _battle.player.hand.size()
	var layout := BattleHandLayout.calculate(n)
	var card_w: float = layout.card_width
	var total_w: float = layout.total_width
	var start_x: float = layout.start_x
	var sep: float = layout.separation

	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.offset_left = start_x
	hand_container.offset_top = 492.0
	hand_container.offset_right = start_x + maxf(total_w, 1.0)
	hand_container.offset_bottom = 708.0

	hand_container.add_theme_constant_override("separation", int(sep))
	var first_card_view: Control = null
	for i in n:
		var card_view: Control = CARD_VIEW_SCENE.instantiate()
		if first_card_view == null:
			first_card_view = card_view
		card_view.custom_minimum_size = Vector2(card_w, 200)
		card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_view.setup(_battle.player.hand[i], i)
		card_view.set_play_cost(_battle.get_card_cost(i))
		card_view.set_affordable(_battle.can_play_card(i))
		card_view.card_clicked.connect(_on_card_clicked)
		card_view.card_rejected.connect(_on_card_rejected)
		hand_container.add_child(card_view)
	if first_card_view != null and not Input.get_connected_joypads().is_empty():
		first_card_view.call_deferred("grab_focus")


func _update_status_icons(container: Control, statuses: Dictionary) -> void:
	var status_ids := statuses.keys()
	status_ids.sort()
	var signature_parts: PackedStringArray = []
	for status_id in status_ids:
		signature_parts.append("%s:%s" % [status_id, statuses[status_id]])
	var signature := "|".join(signature_parts)
	if str(container.get_meta("status_signature", "__uninitialized__")) == signature:
		return
	container.set_meta("status_signature", signature)
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for status_id in status_ids:
		var icon: Control = STATUS_ICON_SCENE.instantiate()
		container.add_child(icon)
		icon.setup(status_id, statuses[status_id])


func _on_world_choice_requested(context: Dictionary) -> void:
	if _world_choice_panel != null and is_instance_valid(_world_choice_panel):
		_world_choice_panel.queue_free()
	_world_choice_panel = PanelContainer.new()
	_world_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_world_choice_panel.position = Vector2(360, 250)
	_world_choice_panel.size = Vector2(560, 190)
	_world_choice_panel.z_index = 20
	add_child(_world_choice_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	_world_choice_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = str(context.get("title", "选择效果"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	column.add_child(title)
	var description := Label.new()
	description.text = str(context.get("description", ""))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	for choice in context.get("choices", []):
		if choice is not Dictionary:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 42)
		button.text = str(choice.get("label", choice.get("id", "确认")))
		button.tooltip_text = str(choice.get("description", ""))
		button.pressed.connect(_resolve_world_choice.bind(str(choice.get("id", ""))))
		row.add_child(button)
	if row.get_child_count() > 0:
		(row.get_child(0) as Control).grab_focus()
	message_label.text = "等待选择：%s" % str(context.get("title", "效果"))
	_update_ui()


func _resolve_world_choice(choice_id: String) -> void:
	if choice_id.is_empty() or _battle == null or not _battle.resolve_world_choice(choice_id):
		return
	AudioManager.play_sfx("click")
	if _world_choice_panel != null and is_instance_valid(_world_choice_panel):
		_world_choice_panel.queue_free()
	_world_choice_panel = null
	message_label.text = ""
	_update_ui()


func _on_card_clicked(index: int) -> void:
	if _defense_active:
		return
	if index < 0 or index >= _battle.player.hand.size():
		return
	var card: Resource = _battle.player.hand[index]
	var card_type: String = str(card.type)
	var before := _combat_snapshot()
	if _battle.play_card(index):
		var after := _combat_snapshot()
		AudioManager.play_sfx("card_play")
		if card_type == "attack":
			_play_attack_animation(true)
			AudioManager.play_sfx("attack")
		elif card_type == "defense":
			AudioManager.play_sfx("shield")
		elif card_type == "heal":
			AudioManager.play_sfx("heal")
		else:
			_flash_intent()
		_show_card_feedback(before, after)
		if GameState.current_world_id != "version_loop":
			message_label.text = ""
	else:
		message_label.text = "能量不足或无法出牌"


func _on_card_rejected(_index: int) -> void:
	message_label.text = "能量不足：请选择费用不高于当前能量的卡牌"
	AudioManager.play_sfx("click")


func _combat_snapshot() -> Dictionary:
	return {
		"player_hp": _battle.player.hp,
		"player_shield": _battle.player.shield,
		"player_spirit": _battle.player.spirit,
		"player_statuses": _battle.player.statuses.duplicate(true),
		"enemy_hp": _battle.enemy.hp,
		"enemy_shield": _battle.enemy.shield,
		"enemy_statuses": _battle.enemy.statuses.duplicate(true),
	}


func _show_card_feedback(before: Dictionary, after: Dictionary) -> void:
	if not is_instance_valid(battle_stage):
		return
	var enemy_damage := int(before.enemy_hp) - int(after.enemy_hp)
	var shield_gain := int(after.player_shield) - int(before.player_shield)
	var heal_gain := int(after.player_hp) - int(before.player_hp)
	var spirit_loss := int(before.player_spirit) - int(after.player_spirit)
	if enemy_damage > 0:
		battle_stage.show_feedback("-%d" % enemy_damage, true, UIColors.DANGER_RED)
	if shield_gain > 0:
		battle_stage.show_feedback("+%d 护盾" % shield_gain, false, UIColors.BORDER_CYAN_BRIGHT)
		battle_stage.pulse_figure(false, Color(0.55, 1.25, 1.35))
	if heal_gain > 0:
		battle_stage.show_feedback("+%d 生命" % heal_gain, false, UIColors.SUCCESS_GREEN)
		battle_stage.pulse_figure(false, Color(0.65, 1.35, 0.75))
	if spirit_loss > 0:
		battle_stage.show_feedback("-%d 精神" % spirit_loss, false, UIColors.SPIRIT_BLUE)
	_show_status_delta(before.enemy_statuses, after.enemy_statuses, true)
	_show_status_delta(before.player_statuses, after.player_statuses, false)


func _show_status_delta(before: Dictionary, after: Dictionary, on_enemy: bool) -> void:
	for status_id in after:
		var added := int(after[status_id]) - int(before.get(status_id, 0))
		if added > 0:
			var info := Status.get_status_info(str(status_id))
			var color := UIColors.DANGER_RED if info.get("is_debuff", false) else UIColors.SUCCESS_GREEN
			battle_stage.show_feedback("%s +%d" % [info.get("name", status_id), added], on_enemy, color)


func _flash_intent() -> void:
	var tw := create_tween()
	tw.tween_property(enemy_intent_label, "modulate", UIColors.ACCENT_GOLD, 0.08)
	tw.tween_property(enemy_intent_label, "modulate", Color.WHITE, 0.18)


func _play_attack_animation(from_player: bool) -> void:
	battle_stage.play_attack(from_player)


func _on_end_turn() -> void:
	if _defense_active:
		return
	AudioManager.play_sfx("click")
	var context := _battle.begin_defense_window()
	if bool(context.get("enabled", false)):
		_start_defense_window(context)
		return
	_complete_enemy_turn_without_window()


func _complete_enemy_turn_without_window() -> void:
	var intent_id: String = _battle.get_enemy_intent_id()
	var before := _combat_snapshot()
	_battle.end_player_turn()
	var after := _combat_snapshot()
	_show_enemy_turn_feedback(intent_id, before, after, "")


func _start_defense_window(context: Dictionary) -> void:
	_defense_active = true
	_defense_context = context
	_defense_elapsed = 0.0
	# 窗口总从敌方落点开始，玩家必须主动换位或承担精准反驳风险。
	_defense_lane = int(context.get("danger_lane", 1))
	defense_window.visible = true
	message_label.visible = false
	end_turn_button.disabled = true
	skill_button.disabled = true
	end_turn_button.text = "答辩中…"
	defense_title.text = "答辩窗口 · %s" % _intent_short_name(str(context.get("intent_id", "")))
	defense_timing_bar.value = 0.0
	battle_stage.show_defense_lanes(int(context.get("danger_lane", 1)), _defense_lane)
	_refresh_defense_lane_buttons()
	defense_confirm_button.grab_focus()


func _set_defense_lane(lane: int) -> void:
	if not _defense_active:
		return
	_defense_lane = clampi(lane, 0, 2)
	battle_stage.show_defense_lanes(int(_defense_context.get("danger_lane", 1)), _defense_lane)
	_refresh_defense_lane_buttons()
	AudioManager.play_sfx("click")


func _refresh_defense_lane_buttons() -> void:
	var buttons := [defense_left_button, defense_center_button, defense_right_button]
	for i in buttons.size():
		var button := buttons[i] as Button
		button.modulate = UIColors.ACCENT_GOLD if i == _defense_lane else Color.WHITE
		button.text = ["A / ←  左位", "中位", "D / →  右位"][i]
		if i == int(_defense_context.get("danger_lane", 1)):
			button.text += "  ⚠"


func _resolve_defense_window(confirmed: bool) -> void:
	if not _defense_active:
		return
	var duration := maxf(0.01, float(_defense_context.get("duration", 1.5)))
	var normalized := clampf(_defense_elapsed / duration, 0.0, 1.0)
	var danger_lane := int(_defense_context.get("danger_lane", 1))
	var perfect_center := float(_defense_context.get("perfect_center", 0.72))
	var perfect_width := float(_defense_context.get("perfect_width", 0.1))
	var outcome := "miss"
	if _defense_lane != danger_lane:
		outcome = "dodge"
	elif confirmed and absf(normalized - perfect_center) <= perfect_width:
		outcome = "perfect"
	elif confirmed:
		outcome = "brace"

	var context := _defense_context.duplicate(true)
	var intent_id := _battle.get_enemy_intent_id()
	var before := _combat_snapshot()
	_defense_active = false
	_defense_context.clear()
	defense_window.visible = false
	message_label.visible = true
	end_turn_button.text = "结束回合"
	battle_stage.hide_defense_lanes(outcome)
	if not _battle.resolve_defense_window(outcome, context):
		return
	var after := _combat_snapshot()
	_show_enemy_turn_feedback(intent_id, before, after, outcome)


func _show_enemy_turn_feedback(intent_id: String, before: Dictionary, after: Dictionary, outcome: String) -> void:
	# 若本回合意图是攻击类，播敌人冲刺动画。
	if intent_id in ["attack", "multi_attack", "heavy_attack", "drain", "special_attack"]:
		_play_attack_animation(false)
	var damage_taken := int(before.player_hp) - int(after.player_hp)
	if damage_taken > 0 and is_instance_valid(battle_stage):
		battle_stage.show_feedback("-%d" % damage_taken, false, UIColors.DANGER_RED)
		_vibrate_controllers(0.25, 0.65, 0.18)
	var counter_damage := int(before.enemy_hp) - int(after.enemy_hp)
	if counter_damage > 0 and outcome == "perfect":
		battle_stage.show_feedback("反驳 -%d" % counter_damage, true, UIColors.ACCENT_GOLD)
	match outcome:
		"perfect":
			message_label.text = "精准反驳：打断行动并反击，下回合 +1 能量"
			AudioManager.play_sfx("perfect")
			_vibrate_controllers(0.45, 0.35, 0.16)
		"dodge":
			message_label.text = "换位成功：伤害减半并避开控制效果"
			AudioManager.play_sfx("dodge")
		"brace":
			message_label.text = "正面招架：获得护盾并降低 25% 伤害"
			AudioManager.play_sfx("brace")
		"miss":
			message_label.text = "答辩失误：承受完整行动"
			AudioManager.play_sfx("damage")

func _on_skill() -> void:
	if _defense_active:
		return
	if _battle.use_active_skill():
		AudioManager.play_sfx("heal")
		_update_ui()
	else:
		message_label.text = "本战斗已使用过技能"


func _on_turn_changed(is_player_turn: bool) -> void:
	if is_player_turn:
		message_label.text = "第 %d 回合" % _battle.turn_count
	else:
		message_label.text = "敌人回合"


func _on_skill_used(skill_name: String) -> void:
	message_label.text = "使用了 %s" % skill_name


func _on_world_rule_feedback(text: String) -> void:
	message_label.text = text
	_request_ui_update()


func _on_ai_decision_requested(context: Dictionary) -> void:
	_set_ai_strategy_ui("正在实时分析", "正在分析你的出牌、状态与资源，并调整应对策略……", UIColors.BORDER_CYAN_BRIGHT)
	AIClient.request_decision(context)


func _on_ai_decision_received(action_id: String, intent_text: String, ending_flag: String, source: String, request_token: int = -1) -> void:
	if request_token >= 0 and request_token != _battle.get_pending_ai_request_token():
		return
	var accepted := _battle.set_ai_decision(action_id, intent_text, ending_flag, request_token)
	GameState.player_stats["last_ending_flag"] = ending_flag
	var selected_id := _battle.get_enemy_intent_id()
	_refresh_ai_actions(selected_id)
	if not accepted:
		_set_ai_strategy_ui("安全策略已接管", _battle.get_enemy_intent_text(), UIColors.WARNING_ORANGE)
	elif source == "fallback":
		_set_ai_strategy_ui("安全策略已就绪", intent_text, UIColors.AI_PURPLE)
	else:
		_set_ai_strategy_ui("实时策略已更新", intent_text, UIColors.SUCCESS_GREEN)
	_update_ui()


func _on_ai_decision_failed(request_token: int = -1) -> void:
	if _is_ai_battle:
		if request_token >= 0 and not _battle.fail_ai_decision(request_token):
			return
		var selected_id := _battle.get_enemy_intent_id()
		_refresh_ai_actions(selected_id)
		_set_ai_strategy_ui("离线策略已就绪", _battle.get_enemy_intent_text(), UIColors.AI_PURPLE)
		message_label.text = "敌人已完成策略调整"


func _set_ai_strategy_ui(status: String, text: String, color: Color) -> void:
	if not _is_ai_battle:
		return
	ai_state_label.text = "策略状态：%s" % status
	ai_state_label.add_theme_color_override("font_color", color)
	ai_bubble_text.text = text if not text.is_empty() else "敌人正在观察你的行动。"


func _on_boss_phase_changed(phase_name: String) -> void:
	message_label.text = "Boss 进入阶段：%s" % phase_name
	AudioManager.play_bgm_for_phase("boss")


func _on_battle_ended(victory: bool) -> void:
	end_turn_button.disabled = true
	skill_button.disabled = true
	GameState.player_stats["last_battle_victory"] = victory
	GameState.player_stats["last_enemy_was_ai"] = _is_ai_battle
	if _battle != null and _battle.player != null:
		GameState.sync_from_battle_character(_battle.player)
	AudioManager.play_sfx("win" if victory else "lose")
	if victory:
		AudioManager.play_bgm_for_phase("victory")
		var etype := str(_enemy_res.enemy_type) if _enemy_res else "normal"
		var ename := str(_enemy_res.name) if _enemy_res else _battle.enemy.display_name
		var eid := str(_enemy_res.id) if _enemy_res else _battle.enemy.id
		GameState.record_enemy_defeat(eid, ename, etype)
	await get_tree().create_timer(0.35).timeout
	await battle_stage.play_outcome(victory)
	GameState.change_screen(GameState.Screen.RESULT)


func _on_settings() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_on_settings()
		get_viewport().set_input_as_handled()
		return
	if not _defense_active:
		return
	if event.is_action_pressed("move_left"):
		_set_defense_lane(_defense_lane - 1)
	elif event.is_action_pressed("move_right"):
		_set_defense_lane(_defense_lane + 1)
	elif event.is_action_pressed("ui_accept"):
		_resolve_defense_window(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _vibrate_controllers(weak: float, strong: float, duration: float) -> void:
	if not Settings.controller_vibration:
		return
	for device_id in Input.get_connected_joypads():
		Input.start_joy_vibration(device_id, weak, strong, duration)


func _intent_short_name(intent_id: String) -> String:
	var names := {
		"attack": "快速追问",
		"heavy_attack": "高压重问",
		"stack_pressure": "压力施加",
		"ask_algorithm": "算法追问",
		"ask_ethics": "职业伦理",
		"resume_challenge": "简历质疑",
		"praise_then_pressure": "先夸后压",
		"reject_core_card": "拒绝核心",
		"demand_revision": "要求大修",
		"question_method": "质疑方法",
		"desk_reject": "直接拒稿",
		"hand_limit": "限制表达",
		"bleed_attack": "灵魂拷问",
	}
	return str(names.get(intent_id, intent_id))
