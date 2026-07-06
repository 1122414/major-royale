extends Control
## 奖励选择场景。

const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

@onready var title_label: Label = $TitleLabel
@onready var rewards_container: HBoxContainer = $RewardsContainer
@onready var info_label: Label = $InfoLabel

var _rewards: Array[Dictionary] = []


func _ready() -> void:
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
		btn.custom_minimum_size = Vector2(240, 200)
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
			return "获得新卡\n" + "\n".join(names)
		RewardGenerator.RewardType.STAT_UP:
			return "提升属性\n%s +%d" % [reward.stat, reward.value]
		RewardGenerator.RewardType.BUFF:
			var info := Status.get_status_info(reward.status_id)
			return "临时强化\n%s x%d" % [info.get("name", reward.status_id), reward.stacks]
	return "未知奖励"


func _on_reward_selected(index: int) -> void:
	var reward := _rewards[index]
	_apply_reward(reward)
	info_label.text = "已选择奖励，按 ESC 返回地图"


func _apply_reward(reward: Dictionary) -> void:
	match reward.type:
		RewardGenerator.RewardType.CARD:
			# 简单选择第一张候选卡
			var options: Array = reward.options
			if not options.is_empty():
				var selected_card = options[0]
				GameState.player_stats["deck_additions"] = GameState.player_stats.get("deck_additions", []) + [selected_card.id]
		RewardGenerator.RewardType.STAT_UP:
			var stats: Dictionary = GameState.player_stats.get("permanent_stats", {})
			stats[reward.stat] = stats.get(reward.stat, 0) + reward.value
			GameState.player_stats["permanent_stats"] = stats
		RewardGenerator.RewardType.BUFF:
			var player = GameState.player_stats.get("battle_player") as Character
			if player != null:
				player.add_status(reward.status_id, reward.stacks)


func _on_settings() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameState.change_screen(GameState.Screen.MAP_EXPLORE)
