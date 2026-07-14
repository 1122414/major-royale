extends Control
## 奖励选择场景。

const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")
const StatLex := preload("res://src/logic/stat_lexicon.gd")

@onready var title_label: Label = $TitleLabel
@onready var rewards_container: HBoxContainer = $RewardsContainer
@onready var info_label: Label = $InfoLabel
@onready var continue_button: Button = $ContinueButton

var _rewards: Array[Dictionary] = []
var _chosen: bool = false


func _ready() -> void:
	continue_button.visible = false
	continue_button.pressed.connect(_return_to_map)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameState.player_major_id) + GameState.run_progress + GameState.day_count
	var is_elite: bool = GameState.last_reward_is_elite
	_rewards = RewardGenerator.generate_rewards(GameState.player_major_id, rng, is_elite)
	if is_elite:
		title_label.text = "精英奖励"
		info_label.text = "击败精英！可选遗物与更强补给。"
	_render_rewards()

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.custom_minimum_size = Vector2(40, 40)
	settings_btn.position = Vector2(1228, 12)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)


func _render_rewards() -> void:
	for child in rewards_container.get_children():
		child.queue_free()
	for i in _rewards.size():
		var reward := _rewards[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 220)
		btn.text = _format_reward(reward)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_reward_selected.bind(i))
		rewards_container.add_child(btn)


func _format_reward(reward: Dictionary) -> String:
	match reward.type:
		RewardGenerator.RewardType.CARD:
			var options: Array = reward.options
			var names: Array[String] = []
			for card in options:
				names.append(card.name)
			return "%s\n（点选一张）\n%s" % [reward.get("label", "获得新卡"), "\n".join(names)]
		RewardGenerator.RewardType.STAT_UP:
			return "提升属性\n%s +%d\n%s" % [reward.stat, reward.value, reward.get("hint", StatLex.stat_text(str(reward.stat)))]
		RewardGenerator.RewardType.BUFF:
			var info := Status.get_status_info(reward.status_id)
			return "临时强化\n%s ×%d\n%s\n（下场战斗）" % [
				info.get("name", reward.status_id), reward.stacks, info.get("description", "")
			]
		RewardGenerator.RewardType.HEAL:
			return "补给恢复\n生命 +%d" % int(reward.value)
		RewardGenerator.RewardType.CREDITS:
			return "资源补给\n学分 +%d\n信用点 +%d" % [int(reward.credits), int(reward.credit_points)]
		RewardGenerator.RewardType.REMOVE_PRESSURE:
			return "减压\n压力圈 -%d" % int(reward.value)
		RewardGenerator.RewardType.RELIC:
			var RelicCat = preload("res://src/logic/relic.gd")
			var info: Dictionary = RelicCat.get_info(str(reward.relic_id))
			return "%s\n【%s】\n%s" % [reward.get("label", "遗物"), info.get("name", reward.relic_id), info.get("desc", "")]
	return "未知奖励"


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
	for child in rewards_container.get_children():
		child.queue_free()
	info_label.text = "选择一张卡加入牌组"
	var options: Array = reward.options
	for card in options:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 200)
		btn.text = "%s\n费用 %d\n%s" % [card.name, card.cost, card.description]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_card_picked.bind(str(card.id)))
		rewards_container.add_child(btn)


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
	continue_button.text = "返回地图 ▶"
	continue_button.grab_focus()


func _return_to_map() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)


func _on_settings() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_map()
