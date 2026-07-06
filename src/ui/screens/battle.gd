extends Control
## 战斗场景。

const CARD_VIEW_SCENE := preload("res://src/ui/widgets/card_view.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

@onready var enemy_name_label: Label = $EnemyPanel/EnemyNameLabel
@onready var enemy_hp_label: Label = $EnemyPanel/EnemyHPLabel
@onready var enemy_intent_label: Label = $EnemyPanel/EnemyIntentLabel
@onready var player_hp_label: Label = $PlayerPanel/PlayerHPLabel
@onready var player_spirit_label: Label = $PlayerPanel/PlayerSpiritLabel
@onready var energy_label: Label = $PlayerPanel/EnergyLabel
@onready var hand_container: HBoxContainer = $HandContainer
@onready var end_turn_button: Button = $EndTurnButton
@onready var skill_button: Button = $SkillButton
@onready var message_label: Label = $MessageLabel

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

	var major: MajorResource = Config.majors[GameState.player_major_id]
	skill_button.text = major.active_skill.get("name", "技能")

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1180, 20)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)

	_update_ui()


func _create_player() -> Character:
	var major: MajorResource = Config.majors[GameState.player_major_id]
	var player := Character.new("player", "玩家", 60, true)
	player.major_id = GameState.player_major_id

	# 属性影响
	var stats := major.stats
	player.max_hp += stats.get("体能", 5) * 3
	player.hp = player.max_hp
	player.max_spirit += stats.get("抗压", 5) * 5
	player.spirit = player.max_spirit

	# 初始牌组
	for card_id in major.starter_deck:
		var card = Config.cards.get(card_id)
		if card != null:
			player.deck.append(card)

	player.draw_pile = player.deck.duplicate()
	player.shuffle_draw_pile()
	return player


func _update_ui() -> void:
	enemy_name_label.text = _battle.enemy.display_name
	enemy_hp_label.text = "HP: %d/%d 护盾: %d" % [_battle.enemy.hp, _battle.enemy.max_hp, _battle.enemy.shield]
	enemy_intent_label.text = "意图: %s" % _battle.get_enemy_intent_text()

	player_hp_label.text = "HP: %d/%d 护盾: %d" % [_battle.player.hp, _battle.player.max_hp, _battle.player.shield]
	player_spirit_label.text = "精神: %d/%d" % [_battle.player.spirit, _battle.player.max_spirit]
	energy_label.text = "能量: %d/%d" % [_battle.energy, _battle.max_energy]

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


func _on_card_clicked(index: int) -> void:
	if _battle.play_card(index):
		message_label.text = ""
	else:
		message_label.text = "能量不足或无法出牌"


func _on_end_turn() -> void:
	_battle.end_player_turn()


func _on_skill() -> void:
	if _battle.use_active_skill():
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
	GameState.change_screen(GameState.Screen.RESULT)


func _on_settings() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)
