extends Control
## 奖励选择场景。

const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

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
	rng.seed = hash(GameState.player_major_id) + GameState.run_progress
	_rewards = RewardGenerator.generate_rewards(GameState.player_major_id, rng)
	_render_rewards()

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1180, 20)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)


func _render_rewards() -> void:
	for i in _rewards.size():
		var reward := _rewards[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(260, 240)
		btn.text = _format_reward(reward)
		btn.pressed.connect(_on_reward_selected.bind(i))
		rewards_container.add_child(btn)


func _format_reward(reward: Dictionary) -> String:
	match reward.type:
		RewardGenerator.RewardType.CARD:
			var options: Array = reward.options
			var names: Array[String] = []
			for card in options:
				names.append(card.name)
			return "获得新卡（点进后选一张）\n" + "\n".join(names)
		RewardGenerator.RewardType.STAT_UP:
			return "提升属性\n%s +%d" % [reward.stat, reward.value]
		RewardGenerator.RewardType.BUFF:
			var info := Status.get_status_info(reward.status_id)
			return "临时强化\n%s x%d\n（下场战斗生效）" % [info.get("name", reward.status_id), reward.stacks]
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
	_finish_choice()


func _show_card_picker(reward: Dictionary) -> void:
	for child in rewards_container.get_children():
		child.queue_free()
	info_label.text = "选择一张卡加入牌组"
	var options: Array = reward.options
	for card in options:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 200)
		btn.text = "%s\n费用 %d\n%s" % [card.name, card.cost, card.description]
		btn.pressed.connect(_on_card_picked.bind(str(card.id)))
		rewards_container.add_child(btn)


func _on_card_picked(card_id: String) -> void:
	if _chosen:
		return
	AudioManager.play_sfx("click")
	GameState.add_card_to_deck(card_id)
	_finish_choice("已将卡牌加入牌组")


func _apply_reward(reward: Dictionary) -> void:
	match reward.type:
		RewardGenerator.RewardType.STAT_UP:
			var stats: Dictionary = GameState.permanent_stats
			stats[reward.stat] = int(stats.get(reward.stat, 0)) + int(reward.value)
			GameState.permanent_stats = stats
			# 体能/抗压即时抬高上限
			if reward.stat == "体能":
				GameState.run_max_hp += 3 * int(reward.value)
			elif reward.stat == "抗压":
				GameState.run_max_spirit += 5 * int(reward.value)
		RewardGenerator.RewardType.BUFF:
			GameState.add_pending_buff(str(reward.status_id), int(reward.stacks))


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
