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
@onready var deck_total_label: Label = $DrawDiscard/DeckTotalLabel
@onready var relic_label: Label = $DrawDiscard/RelicLabel
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
	_battle.request_current_ai_decision()

	end_turn_button.pressed.connect(_on_end_turn)
	skill_button.pressed.connect(_on_skill)
	_style_end_turn_button()

	var major: MajorResource = Config.majors[GameState.player_major_id]
	skill_button.text = major.active_skill.get("name", "技能")
	skill_button.tooltip_text = str(major.active_skill.get("description", ""))
	player_title.text = "%s新生" % major.name
	battle_title.text = "战斗"
	_setup_ai_native_ui(enemy_id, enemy_res)
	_setup_battle_art(enemy_id)
	enemy_fig_label.text = "AI" if _is_ai_battle else "敌"

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.custom_minimum_size = Vector2(48, 48)
	settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	settings_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	$TopBar/TopRow.add_child(settings_btn)
	settings_btn.pressed.connect(_on_settings)

	_update_ui()
	AudioManager.play_sfx("click")
	if _enemy_res != null and (str(_enemy_res.enemy_type) == "boss" or str(_enemy_res.id) == "employment_pressure"):
		AudioManager.play_bgm_for_phase("boss")
	else:
		AudioManager.play_bgm_for_phase("battle")


func _setup_ai_native_ui(enemy_id: String, enemy_res: EnemyResource) -> void:
	ai_banner.visible = _is_ai_battle
	ai_profile_panel.visible = _is_ai_battle
	ai_actions_panel.visible = _is_ai_battle
	buff_panel.visible = not _is_ai_battle
	# 精英战隐藏右侧标准敌人面板，避免与「可选行动」重叠
	$EnemyPanel.visible = not _is_ai_battle
	if not _is_ai_battle:
		return
	battle_title.text = "精英遭遇"
	battle_title.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	var banner: Label = ai_banner.get_node("BannerLabel")
	banner.text = "精英：%s　HP %d　| %s" % [
		enemy_res.name,
		enemy_res.hp,
		enemy_res.specialty if enemy_res.specialty != "" else "AI Native",
	]
	var trait_str := " / ".join(PackedStringArray(enemy_res.traits)) if enemy_res.traits.size() > 0 else "AI Native"
	ai_profile_body.text = "%s\n%s\n弱点：%s" % [
		enemy_res.specialty if enemy_res.specialty != "" else "行为多变",
		trait_str,
		enemy_res.weakness if enemy_res.weakness != "" else "未知",
	]
	ai_loot_preview.text = "掉落：稀有卡 / 称号"
	_refresh_ai_actions("")
	# 左档案窄栏，右行动贴顶不挡立绘
	ai_profile_panel.offset_left = 16.0
	ai_profile_panel.offset_top = 100.0
	ai_profile_panel.offset_right = 200.0
	ai_profile_panel.offset_bottom = 250.0
	ai_actions_panel.offset_left = 1080.0
	ai_actions_panel.offset_top = 100.0
	ai_actions_panel.offset_right = 1264.0
	ai_actions_panel.offset_bottom = 320.0
	$Arena.offset_left = 240.0
	$Arena.offset_right = 1040.0
	# 把敌人状态/意图写到横幅下方短提示
	enemy_name_label.text = enemy_res.name
	enemy_hp_label.text = "HP: %d/%d" % [enemy_res.hp, enemy_res.hp]

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
	return GameState.create_battle_player()


func _update_ui() -> void:
	if not _is_ai_battle:
		enemy_name_label.text = _battle.enemy.display_name
		var specialty := ""
		if _enemy_res != null:
			specialty = str(_enemy_res.specialty)
		enemy_hp_label.text = "HP: %d/%d 护盾: %d" % [_battle.enemy.hp, _battle.enemy.max_hp, _battle.enemy.shield]
		if specialty != "":
			enemy_intent_label.text = "特长：%s\n意图: %s" % [specialty, _battle.get_enemy_intent_text()]
		else:
			enemy_intent_label.text = "意图: %s" % _battle.get_enemy_intent_text()
		if _enemy_res != null and _enemy_res.weakness != "":
			enemy_intent_label.tooltip_text = "弱点：%s" % _enemy_res.weakness
	else:
		var banner: Label = ai_banner.get_node("BannerLabel")
		banner.text = "精英：%s　HP %d/%d 护盾 %d　| %s" % [
			_battle.enemy.display_name,
			_battle.enemy.hp,
			_battle.enemy.max_hp,
			_battle.enemy.shield,
			_battle.get_enemy_intent_text(),
		]
		_refresh_ai_actions(_battle.get_enemy_intent_id())

	player_hp_label.text = "HP: %d/%d 护盾: %d" % [_battle.player.hp, _battle.player.max_hp, _battle.player.shield]
	player_spirit_label.text = "精神: %d/%d" % [_battle.player.spirit, _battle.player.max_spirit]
	energy_label.text = "能量 %d/%d" % [_battle.energy, _battle.max_energy]
	turn_label.text = "第%d天 第%d回合" % [GameState.day_count, _battle.turn_count]
	var deck_total := _battle.player.deck.size()
	draw_pile_label.text = "抽牌堆 %d" % _battle.player.draw_pile.size()
	deck_total_label.text = "牌库 %d" % deck_total
	draw_pile_label.tooltip_text = "开局会先抽到手牌；抽完后从弃牌堆洗回。"
	discard_pile_label.text = "弃牌堆 %d" % _battle.player.discard_pile.size()
	var RelicCat = preload("res://src/logic/relic.gd")
	relic_label.text = RelicCat.format_list(GameState.run_relic_ids)
	relic_label.tooltip_text = relic_label.text
	for rid in GameState.run_relic_ids:
		var info: Dictionary = RelicCat.get_info(str(rid))
		relic_label.tooltip_text += "\n【%s】%s" % [info.get("name", rid), info.get("desc", "")]

	_update_status_icons(enemy_status_container, _battle.enemy.statuses)
	_update_status_icons(player_status_container, _battle.player.statuses)

	_rebuild_hand()

	end_turn_button.disabled = _battle.state != Battle.BattleState.PLAYER_TURN
	skill_button.disabled = _battle.state != Battle.BattleState.PLAYER_TURN


func _rebuild_hand() -> void:
	## 手牌始终相对底部居中；牌多时自动缩宽，避免挤向右侧。
	while hand_container.get_child_count() > 0:
		var child: Node = hand_container.get_child(0)
		hand_container.remove_child(child)
		child.free()

	var n: int = _battle.player.hand.size()
	var area_left := 168.0
	var area_right := 1120.0
	var area_w := area_right - area_left
	var sep := 8.0
	var base_w := 148.0
	var card_w := base_w
	if n > 1:
		card_w = mini(base_w, (area_w - sep * float(n - 1)) / float(n))
	var total_w := float(n) * card_w + float(maxi(0, n - 1)) * sep
	var start_x := area_left + (area_w - total_w) * 0.5

	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.offset_left = start_x
	hand_container.offset_top = 500.0
	hand_container.offset_right = start_x + maxf(total_w, 1.0)
	hand_container.offset_bottom = 700.0

	hand_container.add_theme_constant_override("separation", int(sep))
	for i in n:
		var card_view: Control = CARD_VIEW_SCENE.instantiate()
		card_view.custom_minimum_size = Vector2(card_w, 200)
		card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	attacker.pivot_offset = attacker.size * 0.5
	defender.pivot_offset = defender.size * 0.5
	var base := attacker.position
	var def_base := defender.position
	var toward := (defender.position - attacker.position)
	if toward.length() < 1.0:
		toward = Vector2(40, 0) if from_player else Vector2(-40, 0)
	else:
		toward = toward.normalized() * 48.0

	# 冲刺 → 受击抖动 → 回位
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(attacker, "position", base + toward, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(attacker, "scale", Vector2(1.08, 0.92), 0.05)
	tw.tween_callback(_spawn_slash_fx.bind(attacker, defender, from_player))
	tw.tween_property(attacker, "scale", Vector2.ONE, 0.08)
	tw.tween_property(attacker, "position", base, 0.14).set_trans(Tween.TRANS_SINE)

	var hit := create_tween()
	hit.tween_property(defender, "modulate", Color(1.5, 0.45, 0.45), 0.05)
	hit.tween_property(defender, "position", def_base + Vector2(10 if from_player else -10, -4), 0.05)
	hit.tween_property(defender, "position", def_base + Vector2(-6 if from_player else 6, 2), 0.05)
	hit.tween_property(defender, "position", def_base, 0.08)
	hit.tween_property(defender, "modulate", Color.WHITE, 0.12)


func _spawn_slash_fx(attacker: Control, defender: Control, from_player: bool) -> void:
	var slash := ColorRect.new()
	slash.color = Color(1.0, 0.92, 0.55, 0.85) if from_player else Color(1.0, 0.4, 0.4, 0.85)
	slash.size = Vector2(56, 8)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.z_index = 20
	var mid := (attacker.global_position + defender.global_position) * 0.5 + Vector2(40, 60)
	$Arena.add_child(slash)
	slash.global_position = mid
	slash.rotation = 0.6 if from_player else -0.6
	var tw := create_tween()
	tw.tween_property(slash, "modulate:a", 0.0, 0.18)
	tw.tween_callback(slash.queue_free)


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
	AudioManager.play_bgm_for_phase("boss")


func _on_battle_ended(victory: bool) -> void:
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
	GameState.change_screen(GameState.Screen.RESULT)


func _on_settings() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)
