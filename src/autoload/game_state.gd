extends Node
## 全局游戏状态：当前运行、玩家数据、场景栈。

enum Screen {
	MENU,
	MAJOR_SELECT,
	MAP_EXPLORE,
	BATTLE,
	REWARD,
	SETTINGS,
	RESULT,
	ACHIEVEMENTS,
	RUN_SUMMARY,
}

var current_screen: Screen = Screen.MENU
var player_major_id: String = ""
var player_stats: Dictionary = {}
var player_deck: Array[Dictionary] = []
var run_progress: int = 0

## 一局持久化状态
var run_hp: int = 60
var run_max_hp: int = 60
var run_spirit: int = 100
var run_max_spirit: int = 100
var deck_card_ids: Array[String] = []
var permanent_stats: Dictionary = {}
var pending_buffs: Array[Dictionary] = []  ## [{status_id, stacks}, ...]
var run_relic_ids: Array[String] = []
var credits: int = 120
var credit_points: int = 560
var day_count: int = 1
var map_seed: int = 0
var map_path_index: int = 0  ## 当前所在线性节点序号
var last_reward_is_elite: bool = false

## 通关总结统计
var run_enemies_defeated: Array[Dictionary] = []  ## [{id, name, type}]
var run_battles_won: int = 0
var run_damage_dealt: int = 0
var run_cards_played: int = 0
var run_events_resolved: int = 0
var run_started_at: int = 0


func start_run(major_id: String) -> void:
	player_major_id = major_id
	player_stats = {}
	player_deck = []
	run_progress = 0
	permanent_stats = {}
	pending_buffs = []
	run_relic_ids.clear()
	last_reward_is_elite = false
	credits = 120
	credit_points = 560
	day_count = 1
	map_seed = 0
	map_path_index = 0
	run_enemies_defeated.clear()
	run_battles_won = 0
	run_damage_dealt = 0
	run_cards_played = 0
	run_events_resolved = 0
	run_started_at = int(Time.get_unix_time_from_system())
	_init_run_from_major(major_id)
	current_screen = Screen.MAP_EXPLORE


func add_relic(relic_id: String) -> void:
	if relic_id.is_empty() or relic_id in run_relic_ids:
		return
	run_relic_ids.append(relic_id)
	# 即时生效类
	if relic_id == "gym_bracelet":
		run_max_hp += 8
		heal_run(8)


func has_relic(relic_id: String) -> bool:
	return relic_id in run_relic_ids


func record_enemy_defeat(enemy_id: String, enemy_name: String, enemy_type: String) -> void:
	run_battles_won += 1
	run_enemies_defeated.append({
		"id": enemy_id,
		"name": enemy_name,
		"type": enemy_type,
	})
	last_reward_is_elite = enemy_type in ["elite", "ai_native", "boss"]
	# 资源收益
	var resource_bonus := get_effective_stat("资源")
	var social_bonus := get_effective_stat("社交")
	var credit_gain := 8 + resource_bonus
	var point_gain := 12 + social_bonus
	if last_reward_is_elite:
		credit_gain *= 2
		point_gain *= 2
	if has_relic("mentor_letter"):
		credit_gain = int(credit_gain * 1.5)
		point_gain = int(point_gain * 1.5)
	credits += credit_gain
	credit_points += point_gain
	var was_elite := last_reward_is_elite
	Achievements.try_after_battle_win(enemy_id, was_elite)


func _init_run_from_major(major_id: String) -> void:
	var major: MajorResource = Config.majors[major_id]
	var base_hp := 60 + int(major.stats.get("体能", 5)) * 3
	var base_spirit := 100 + int(major.stats.get("抗压", 5)) * 5
	run_max_hp = base_hp
	run_hp = base_hp
	run_max_spirit = base_spirit
	run_spirit = base_spirit
	deck_card_ids.clear()
	for card_id in major.starter_deck:
		deck_card_ids.append(str(card_id))


func get_effective_stat(stat_name: String) -> int:
	var major: MajorResource = Config.majors[player_major_id]
	var base: int = int(major.stats.get(stat_name, 5))
	return base + int(permanent_stats.get(stat_name, 0))


func heal_run(amount: int) -> int:
	var before := run_hp
	run_hp = mini(run_hp + amount, run_max_hp)
	return run_hp - before


func damage_run(amount: int) -> int:
	var before := run_hp
	run_hp = maxi(run_hp - amount, 0)
	return before - run_hp


func lose_spirit_run(amount: int) -> void:
	run_spirit = clampi(run_spirit - amount, 0, run_max_spirit)


func gain_spirit_run(amount: int) -> void:
	run_spirit = clampi(run_spirit + amount, 0, run_max_spirit)


func add_card_to_deck(card_id: String) -> void:
	if card_id.is_empty():
		return
	deck_card_ids.append(card_id)


func add_pending_buff(status_id: String, stacks: int) -> void:
	pending_buffs.append({"status_id": status_id, "stacks": stacks})


func sync_from_battle_character(player: Character) -> void:
	if player == null:
		return
	run_hp = player.hp
	run_max_hp = player.max_hp
	run_spirit = player.spirit
	run_max_spirit = player.max_spirit


func change_screen(screen: Screen) -> void:
	current_screen = screen
	var scene_path := _screen_to_path(screen)
	get_tree().change_scene_to_file(scene_path)


func _screen_to_path(screen: Screen) -> String:
	match screen:
		Screen.MENU: return "res://src/ui/screens/menu.tscn"
		Screen.MAJOR_SELECT: return "res://src/ui/screens/major_select.tscn"
		Screen.MAP_EXPLORE: return "res://src/ui/screens/map_explore.tscn"
		Screen.BATTLE: return "res://src/ui/screens/battle.tscn"
		Screen.REWARD: return "res://src/ui/screens/reward.tscn"
		Screen.SETTINGS: return "res://src/ui/screens/settings.tscn"
		Screen.RESULT: return "res://src/ui/screens/result.tscn"
		Screen.ACHIEVEMENTS: return "res://src/ui/screens/achievements.tscn"
		Screen.RUN_SUMMARY: return "res://src/ui/screens/run_summary.tscn"
	return "res://src/ui/screens/menu.tscn"
