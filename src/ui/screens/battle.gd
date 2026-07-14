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

var _battle: Battle


func _ready() -> void:
	var enemy_id: String = GameState.player_stats.get("current_enemy_id", "gpa_anxiety")
	var enemy_res = Config.enemies.get(enemy_id)
	if enemy_res == null:
		enemy_res = Config.enemies["gpa_anxiety"]

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
	if enemy_id in ["ai_interviewer", "paper_reviewer"]:
		battle_title.text = "精英遭遇"
		battle_title.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	enemy_fig_label.text = "AI" if enemy_id.begins_with("ai_") or enemy_id == "paper_reviewer" else "敌"

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1210, 20)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)

	_update_ui()
	AudioManager.play_sfx("click")


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

	# 更新手牌
	for child in hand_container.get_children():
		child.queue_free()
	for i in _battle.player.hand.size():
		var card_view: Control = CARD_VIEW_SCENE.instantiate()
		card_view.setup(_battle.player.hand[i], i)
		card_view.card_clicked.connect(_on_card_clicked)
		hand_container.add_child(card_view)

	end_turn_button.disabled = _battle.state != Battle.BattleState.PLAYER_TURN
	skill_button.disabled = _battle.state != Battle.BattleState.PLAYER_TURN


func _update_status_icons(container: Control, statuses: Dictionary) -> void:
	for child in container.get_children():
		child.queue_free()
	for status_id in statuses:
		var icon: Control = STATUS_ICON_SCENE.instantiate()
		icon.setup(status_id, statuses[status_id])
		container.add_child(icon)


func _on_card_clicked(index: int) -> void:
	var card: Resource = _battle.player.hand[index]
	if _battle.play_card(index):
		AudioManager.play_sfx("card_play")
		match card.type:
			"attack": AudioManager.play_sfx("attack")
			"defense": AudioManager.play_sfx("shield")
			"heal": AudioManager.play_sfx("heal")
		message_label.text = ""
	else:
		message_label.text = "能量不足或无法出牌"


func _on_end_turn() -> void:
	AudioManager.play_sfx("click")
	_battle.end_player_turn()


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
	_update_ui()


func _on_ai_decision_failed() -> void:
	message_label.text = "AI 服务未响应，使用规则兜底"


func _on_boss_phase_changed(phase_name: String) -> void:
	message_label.text = "Boss 进入阶段：%s" % phase_name


func _on_battle_ended(victory: bool) -> void:
	GameState.player_stats["last_battle_victory"] = victory
	if _battle != null and _battle.player != null:
		GameState.sync_from_battle_character(_battle.player)
	AudioManager.play_sfx("win" if victory else "lose")
	GameState.change_screen(GameState.Screen.RESULT)


func _on_settings() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)
