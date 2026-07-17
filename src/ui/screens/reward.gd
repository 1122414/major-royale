extends Control
## 奖励选择场景。

const CARD_VIEW_SCENE := preload("res://src/ui/widgets/card_view.tscn")
const StatLex := preload("res://src/logic/stat_lexicon.gd")

@onready var title_label: Label = $Header/Margin/Row/TitleLabel
@onready var run_summary: Label = $Header/Margin/Row/RunSummary
@onready var settings_button: Button = $Header/Margin/Row/SettingsButton
@onready var rewards_container: HBoxContainer = $RewardsPanel/Margin/RewardsContainer
@onready var info_label: Label = $InfoLabel
@onready var continue_button: Button = $ContinueButton

var _rewards: Array[Dictionary] = []
var _chosen: bool = false


func _ready() -> void:
	continue_button.visible = false
	continue_button.pressed.connect(_return_to_map)
	settings_button.pressed.connect(_on_settings)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameState.player_major_id) + GameState.run_progress + GameState.day_count
	var is_elite: bool = GameState.last_reward_is_elite
	_rewards = RewardGenerator.generate_rewards(GameState.player_major_id, rng, is_elite)
	if is_elite:
		title_label.text = "精英奖励"
		info_label.text = "击败精英！可选遗物与更强补给。"
	else:
		info_label.text = "选择一项奖励，继续构筑你的校园生存路线。"
	_render_rewards()
	_refresh_run_summary()


func _render_rewards() -> void:
	for child in rewards_container.get_children():
		child.queue_free()
	for i in _rewards.size():
		var reward := _rewards[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(186, 350)
		btn.text = _format_reward(reward)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 15)
		_style_reward_button(btn, int(reward.type))
		btn.pressed.connect(_on_reward_selected.bind(i))
		rewards_container.add_child(btn)


func _format_reward(reward: Dictionary) -> String:
	match reward.type:
		RewardGenerator.RewardType.CARD:
			var options: Array = reward.options
			var names: Array[String] = []
			for card in options:
				names.append(card.name)
			return "▤\n%s\n\n包含 %d 张候选\n%s\n\n点击查看卡面" % [reward.get("label", "获得新卡"), names.size(), " / ".join(names)]
		RewardGenerator.RewardType.STAT_UP:
			return "↑\n提升属性\n\n%s +%d\n\n%s" % [reward.stat, reward.value, reward.get("hint", StatLex.stat_text(str(reward.stat)))]
		RewardGenerator.RewardType.BUFF:
			var info := Status.get_status_info(reward.status_id)
			return "◆\n临时强化\n\n%s ×%d\n%s\n\n下场战斗生效" % [
				info.get("name", reward.status_id), reward.stacks, info.get("description", "")
			]
		RewardGenerator.RewardType.HEAL:
			return "♥\n补给恢复\n\n生命 +%d" % int(reward.value)
		RewardGenerator.RewardType.CREDITS:
			return "▣\n资源补给\n\n学分 +%d\n信用点 +%d" % [int(reward.credits), int(reward.credit_points)]
		RewardGenerator.RewardType.REMOVE_PRESSURE:
			return "◌\n减压\n\n压力圈 -%d" % int(reward.value)
		RewardGenerator.RewardType.RELIC:
			var RelicCat = preload("res://src/logic/relic.gd")
			var info: Dictionary = RelicCat.get_info(str(reward.relic_id))
			return "✦\n%s\n\n【%s】\n%s" % [reward.get("label", "遗物"), info.get("name", reward.relic_id), info.get("desc", "")]
	return "未知奖励"


func _style_reward_button(button: Button, reward_type: int) -> void:
	var colors := {
		RewardGenerator.RewardType.CARD: UIColors.BORDER_CYAN,
		RewardGenerator.RewardType.STAT_UP: UIColors.SUCCESS_GREEN,
		RewardGenerator.RewardType.BUFF: UIColors.AI_PURPLE,
		RewardGenerator.RewardType.HEAL: UIColors.SUCCESS_GREEN,
		RewardGenerator.RewardType.CREDITS: UIColors.ACCENT_GOLD,
		RewardGenerator.RewardType.REMOVE_PRESSURE: UIColors.SPIRIT_BLUE,
		RewardGenerator.RewardType.RELIC: UIColors.ACCENT_GOLD_BRIGHT,
	}
	var accent: Color = colors.get(reward_type, UIColors.BORDER_CYAN)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.075, 0.09, 0.97)
	normal.set_border_width_all(3)
	normal.border_color = accent
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 16
	normal.content_margin_bottom = 16
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.07, 0.15, 0.18, 1.0)
	hover.border_color = accent.lightened(0.18)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", accent)


func _on_reward_selected(index: int) -> void:
	if _chosen:
		return
	AudioManager.play_sfx("click")
	var reward := _rewards[index]
	if reward.type == RewardGenerator.RewardType.CARD:
		_show_card_picker(reward)
		return
	_apply_reward(reward)
	if reward.type == RewardGenerator.RewardType.RELIC:
		var RelicCat = preload("res://src/logic/relic.gd")
		var info: Dictionary = RelicCat.get_info(str(reward.relic_id))
		_finish_choice("已获得遗物：%s" % info.get("name", reward.relic_id))
	else:
		_finish_choice()


func _show_card_picker(reward: Dictionary) -> void:
	_clear_rewards()
	info_label.text = "选择一张卡加入牌组"
	var options: Array = reward.options
	for i in options.size():
		var card = options[i]
		var view: Control = CARD_VIEW_SCENE.instantiate()
		view.custom_minimum_size = Vector2(190, 350)
		view.setup(card, i)
		view.set_play_cost(int(card.cost))
		view.set_affordable(true)
		view.card_clicked.connect(_on_card_view_picked.bind(str(card.id)))
		rewards_container.add_child(view)


func _on_card_view_picked(_index: int, card_id: String) -> void:
	_on_card_picked(card_id)


func _on_card_picked(card_id: String) -> void:
	if _chosen:
		return
	AudioManager.play_sfx("click")
	GameState.add_card_to_deck(card_id)
	_finish_choice("已将卡牌加入牌组（牌库 %d）" % GameState.deck_card_ids.size())


func _apply_reward(reward: Dictionary) -> void:
	match reward.type:
		RewardGenerator.RewardType.STAT_UP:
			var stats: Dictionary = GameState.permanent_stats
			stats[reward.stat] = int(stats.get(reward.stat, 0)) + int(reward.value)
			GameState.permanent_stats = stats
			if reward.stat == "体能":
				GameState.run_max_hp += 3 * int(reward.value)
				GameState.run_hp += 3 * int(reward.value)
			elif reward.stat == "抗压":
				GameState.run_max_spirit += 5 * int(reward.value)
				GameState.run_spirit += 5 * int(reward.value)
		RewardGenerator.RewardType.BUFF:
			GameState.add_pending_buff(str(reward.status_id), int(reward.stacks))
		RewardGenerator.RewardType.HEAL:
			GameState.heal_run(int(reward.value))
		RewardGenerator.RewardType.CREDITS:
			GameState.credits += int(reward.credits)
			GameState.credit_points += int(reward.credit_points)
		RewardGenerator.RewardType.REMOVE_PRESSURE:
			GameState.run_progress = maxi(0, GameState.run_progress - int(reward.value))
		RewardGenerator.RewardType.RELIC:
			GameState.add_relic(str(reward.relic_id))
			var RelicCat = preload("res://src/logic/relic.gd")
			var info: Dictionary = RelicCat.get_info(str(reward.relic_id))
			# 消息在 _finish_choice 统一展示；此处仅写入
			pass


func _finish_choice(msg: String = "已选择奖励") -> void:
	_chosen = true
	info_label.text = "%s\n点击下方按钮返回地图" % msg
	for child in rewards_container.get_children():
		if child is Button:
			child.disabled = true
	continue_button.visible = true
	continue_button.disabled = false
	continue_button.text = "返回校园 ▶"
	continue_button.grab_focus()
	_refresh_run_summary()


func _return_to_map() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)


func _on_settings() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)


func _refresh_run_summary() -> void:
	run_summary.text = "牌库 %d　遗物 %d　生命 %d/%d　精神 %d/%d　压力 %d" % [
		GameState.deck_card_ids.size(),
		GameState.run_relic_ids.size(),
		GameState.run_hp,
		GameState.run_max_hp,
		GameState.run_spirit,
		GameState.run_max_spirit,
		GameState.run_progress,
	]


func _clear_rewards() -> void:
	for child in rewards_container.get_children():
		rewards_container.remove_child(child)
		child.queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_map()
