extends Control
## 战斗场景（占位，阶段 4 完善）。

@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	var enemy_id: String = GameState.player_stats.get("current_enemy_id", "")
	info_label.text = "战斗场景（占位）\n敌人: %s\n按 ESC 返回地图" % enemy_id


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameState.change_screen(GameState.Screen.MAP_EXPLORE)
