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
}

var current_screen: Screen = Screen.MENU
var player_major_id: String = ""
var player_stats: Dictionary = {}
var player_deck: Array[Dictionary] = []
var run_progress: int = 0


func start_run(major_id: String) -> void:
	player_major_id = major_id
	player_stats = {}
	player_deck = []
	run_progress = 0
	current_screen = Screen.MAP_EXPLORE


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
	return "res://src/ui/screens/menu.tscn"
