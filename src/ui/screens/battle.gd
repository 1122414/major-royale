extends Control
## 战斗场景。

const CARD_VIEW_SCENE := preload("res://src/ui/widgets/card_view.tscn")
const STATUS_ICON_SCENE := preload("res://src/ui/widgets/status_icon.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

@onready var enemy_name_label: Label = $EnemyPanel/VBoxContainer/EnemyNameLabel
@onready var enemy_hp_label: Label = $EnemyPanel/VBoxContainer/EnemyHPLabel
@onready var enemy_intent_label: Label = $EnemyPanel/VBoxContainer/EnemyIntentLabel
@onready var enemy_status_container: HBoxContainer = $EnemyPanel/VBoxContainer/EnemyStatusContainer
@onready var player_hp_label: Label = $PlayerPanel/VBoxContainer/PlayerHPLabel
@onready var player_spirit_label: Label = $PlayerPanel/VBoxContainer/PlayerSpiritLabel
@onready var energy_label: Label = $PlayerPanel/VBoxContainer/EnergyLabel
@onready var player_status_container: VBoxContainer = $BuffPanel/BuffCol/PlayerStatusContainer
@onready var hand_container: HBoxContainer = $HandContainer
@onready var end_turn_button: Button = $EndTurnButton
@onready var skill_button: Button = $SkillButton
@onready var message_label: Label = $MessageLabel
@onready var turn_label: Label = $TopBar/TopRow/TurnLabel
@onready var battle_title: Label = $TopBar/TopRow/BattleTitle
@onready var player_title: Label = $TopBar/TopRow/PlayerTitle
@onready var draw_pile_label: Label = $DrawDiscard/DrawPileLabel
@onready var discard_pile_label: Label = $DrawDiscard/DiscardPileLabel
@onready var enemy_fig_label: Label = $Arena/EnemyFigure/EnemyFigLabel
@onready var ai_banner: PanelContainer = $AIBanner
@onready var ai_profile_panel: PanelContainer = $AIProfilePanel
@onready var ai_profile_body: Label = $AIProfilePanel/ProfileVBox/ProfileBody
@onready var ai_loot_preview: Label = $AIProfilePanel/ProfileVBox/LootPreview
@onready var ai_actions_panel: PanelContainer = $AIActionsPanel
@onready var ai_actions_list: VBoxContainer = $AIActionsPanel/ActionsVBox/ActionsList
@onready var buff_panel: PanelContainer = $BuffPanel

var _battle: Battle
var _is_ai_battle: bool = false
var _enemy_res: EnemyResource = null


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
	_battle.hand_updated.connect(_update_ui)
	_battle.energy_updated.connect(_update_ui)
	_battle.turn_changed.connect(_on_turn_changed)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.skill_used.connect(_on_skill_used)
	_battle.ai_decision_requested.connect(_on_ai_decision_requested)
	_battle.boss_phase_changed.connect(_on_boss_phase_changed)

	AIClient.decision_received.connect(_on_ai_decision_received)
	AIClient.decision_failed.connect(_on_ai_decision_failed)

	end_turn_button.pressed.connect(_on_end_turn)
	skill_button.pressed.connect(_on_skill)
	_style_end_turn_button()

	var major: MajorResource = Config.majors[GameState.player_major_id]
	skill_button.text = major.active_skill.get("name", "技能")
	player_title.text = "%s新生" % major.name
	battle_title.text = "战斗"
	_setup_ai_native_ui(enemy_id, enemy_res)
	_setup_battle_art(enemy_id)
	enemy_fig_label.text = "AI" if _is_ai_battle else "敌"

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1210, 20)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)

	_update_ui()
	AudioManager.play_sfx("click")


func _setup_ai_native_ui(enemy_id: String, enemy_res: EnemyResource) -> void:
	ai_banner.visible = _is_ai_battle
	ai_profile_panel.visible = _is_ai_battle
	ai_actions_panel.visible = _is_ai_battle
	buff_panel.visible = not _is_ai_battle
	if not _is_ai_battle:
		return
	battle_title.text = "精英遭遇"
	battle_title.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	var banner: Label = ai_banner.get_node("BannerLabel")
	banner.text = "精英遭遇: %s" % enemy_res.name
	var traits := "行为学习 / 多维评估 / 心理施压" if enemy_id == "ai_interviewer" else "拒稿逻辑 / 方法质疑 / 修订压迫"
	ai_profile_body.text = "%s\n危险等级：精英\n特质：%s\nHP %d" % [enemy_res.name, traits, enemy_res.hp]
	ai_loot_preview.text = "掉落预览：稀有卡 / 事件称号 / ending_flag 分支"
	_refresh_ai_actions("")


func _refresh_ai_actions(selected_id: String) -> void:
	if not _is_ai_battle or _enemy_res == null:
		return
	for child in ai_actions_list.get_children():
		child.queue_free()
	for action in _enemy_res.actions:
		var aid: String = str(action.get("id", ""))
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
		label.text = "• %s" % name_map.get(aid, aid)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		if aid == selected_id:
			label.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
		else:
			label.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
		ai_actions_list.add_child(label)

func _setup_battle_art(enemy_id: String) -> void:
	var bg: TextureRect = $PixelBackground
	if bg and bg.has_method("_ready"):
		if _is_ai_battle:
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
	_set_figure_texture($Arena/PlayerFigure, player_path)

	var enemy_path := "res://assets/sprites/chars/enemy_anxiety.png"
	if enemy_id == "ai_interviewer":
		enemy_path = "res://assets/sprites/chars/enemy_ai.png"
	elif enemy_id == "paper_reviewer":
		enemy_path = "res://assets/sprites/chars/enemy_reviewer.png"
	elif enemy_id == "employment_pressure":
		enemy_path = "res://assets/sprites/chars/enemy_boss.png"
	_set_figure_texture($Arena/EnemyFigure, enemy_path)


func _set_figure_texture(panel: PanelContainer, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var label := panel.get_child(0) as Label
	if label:
		label.visible = false
	var tex := panel.get_node_or_null("Sprite") as TextureRect
	if tex == null:
		tex = TextureRect.new()
		tex.name = "Sprite"
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_child(tex)
	tex.texture = load(path)


func _style_end_turn_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.14, 0.04, 0.95)
	style.set_border_width_all(3)
	style.border_color = UIColors.ACCENT_GOLD
	style.set_corner_radius_all(2)
	end_turn_button.add_theme_stylebox_override("normal", style)
	end_turn_button.add_theme_stylebox_override("hover", style)
	end_turn_button.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)

func _create_player() -> Character:
	var major: MajorResource = Config.majors[GameState.player_major_id]
	# 体能永久加成可抬高上限
	var stamina_bonus := GameState.get_effective_stat("体能") - int(major.stats.get("体能", 5))
	var max_hp := GameState.run_max_hp + stamina_bonus * 3
	if max_hp < GameState.run_hp:
		max_hp = GameState.run_hp

	var player := Character.new("player", "玩家", max_hp, true)
	player.major_id = GameState.player_major_id
	player.max_hp = max_hp
	player.hp = clampi(GameState.run_hp, 1, max_hp)

	var resist_bonus := GameState.get_effective_stat("抗压") - int(major.stats.get("抗压", 5))
	player.max_spirit = GameState.run_max_spirit + resist_bonus * 5
	player.spirit = clampi(GameState.run_spirit, 0, player.max_spirit)

	# 持久牌组（含奖励卡）
	var card_ids: Array = GameState.deck_card_ids
	if card_ids.is_empty():
		card_ids = major.starter_deck
	for card_id in card_ids:
		var card = Config.cards.get(str(card_id))
		if card != null:
			player.deck.append(card)

	# 开战前挂上待生效 Buff
	for buff in GameState.pending_buffs:
		player.add_status(str(buff.get("status_id", "")), int(buff.get("stacks", 1)))
	GameState.pending_buffs.clear()

	player.draw_pile = player.deck.duplicate()
	player.shuffle_draw_pile()
	return player


func _update_ui() -> void:
	enemy_name_label.text = _battle.enemy.display_name
	enemy_hp_label.text = "HP: %d/%d 护盾: %d" % [_battle.enemy.hp, _battle.enemy.max_hp, _battle.enemy.shield]
	enemy_intent_label.text = "意图: %s" % _battle.get_enemy_intent_text()

	player_hp_label.text = "HP: %d/%d 护盾: %d" % [_battle.player.hp, _battle.player.max_hp, _battle.player.shield]
	player_spirit_label.text = "精神: %d/%d" % [_battle.player.spirit, _battle.player.max_spirit]
	energy_label.text = "能量 %d/%d" % [_battle.energy, _battle.max_energy]
	turn_label.text = "第%d天 第%d回合" % [GameState.day_count, _battle.turn_count]
	draw_pile_label.text = "抽牌堆 %d" % _battle.player.draw_pile.size()
	discard_pile_label.text = "弃牌堆 %d" % _battle.player.discard_pile.size()

	_update_status_icons(enemy_status_container, _battle.enemy.statuses)
	_update_status_icons(player_status_container, _battle.player.statuses)

	_rebuild_hand()

	end_turn_button.disabled = _battle.state != Battle.BattleState.PLAYER_TURN
	skill_button.disabled = _battle.state != Battle.BattleState.PLAYER_TURN


func _rebuild_hand() -> void:
	## 始终重建并保持手牌区几何居中，避免出牌/抽牌后偏移。
	hand_container.position = Vector2(160, 500)
	hand_container.size = Vector2(960, 200)
	hand_container.offset_left = 160.0
	hand_container.offset_top = 500.0
	hand_container.offset_right = 1120.0
	hand_container.offset_bottom = 700.0
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	while hand_container.get_child_count() > 0:
		var child: Node = hand_container.get_child(0)
		hand_container.remove_child(child)
		child.free()
	for i in _battle.player.hand.size():
		var card_view: Control = CARD_VIEW_SCENE.instantiate()
		card_view.setup(_battle.player.hand[i], i)
		card_view.card_clicked.connect(_on_card_clicked)
		hand_container.add_child(card_view)


func _update_status_icons(container: Control, statuses: Dictionary) -> void:
	for child in container.get_children():
		child.queue_free()
	for status_id in statuses:
		var icon: Control = STATUS_ICON_SCENE.instantiate()
		container.add_child(icon)
		icon.setup(status_id, statuses[status_id])


func _on_card_clicked(index: int) -> void:
	if index < 0 or index >= _battle.player.hand.size():
		return
	var card: Resource = _battle.player.hand[index]
	var card_type: String = str(card.type)
	if _battle.play_card(index):
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
		message_label.text = ""
	else:
		message_label.text = "能量不足或无法出牌"


func _flash_intent() -> void:
	var tw := create_tween()
	tw.tween_property(enemy_intent_label, "modulate", UIColors.ACCENT_GOLD, 0.08)
	tw.tween_property(enemy_intent_label, "modulate", Color.WHITE, 0.18)


func _play_attack_animation(from_player: bool) -> void:
	var attacker: Control = $Arena/PlayerFigure if from_player else $Arena/EnemyFigure
	var defender: Control = $Arena/EnemyFigure if from_player else $Arena/PlayerFigure
	var base := attacker.position
	var toward := defender.position - attacker.position
	toward = toward.normalized() * 36.0
	var tw := create_tween()
	tw.tween_property(attacker, "position", base + toward, 0.08)
	tw.tween_property(attacker, "position", base, 0.12)
	var flash := create_tween()
	flash.tween_property(defender, "modulate", Color(1.4, 0.6, 0.6), 0.06)
	flash.tween_property(defender, "modulate", Color.WHITE, 0.14)


func _on_end_turn() -> void:
	AudioManager.play_sfx("click")
	var intent_id: String = _battle.get_enemy_intent_id()
	_battle.end_player_turn()
	# 若本回合意图是攻击类，播敌人冲刺动画
	if intent_id in ["attack", "multi_attack", "heavy_attack", "drain", "special_attack"]:
		_play_attack_animation(false)

func _on_skill() -> void:
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


func _on_ai_decision_requested(context: Dictionary) -> void:
	AIClient.request_decision(context)


func _on_ai_decision_received(action_id: String, intent_text: String, ending_flag: String) -> void:
	_battle.set_ai_decision(action_id, intent_text, ending_flag)
	GameState.player_stats["last_ending_flag"] = ending_flag
	_refresh_ai_actions(action_id)
	_update_ui()


func _on_ai_decision_failed() -> void:
	message_label.text = "AI 服务未响应，使用规则兜底"
	if _is_ai_battle:
		_refresh_ai_actions(str(_battle.get_enemy_intent_text()))


func _on_boss_phase_changed(phase_name: String) -> void:
	message_label.text = "Boss 进入阶段：%s" % phase_name


func _on_battle_ended(victory: bool) -> void:
	GameState.player_stats["last_battle_victory"] = victory
	GameState.player_stats["last_enemy_was_ai"] = _is_ai_battle
	if _battle != null and _battle.player != null:
		GameState.sync_from_battle_character(_battle.player)
	AudioManager.play_sfx("win" if victory else "lose")
	GameState.change_screen(GameState.Screen.RESULT)


func _on_settings() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)
