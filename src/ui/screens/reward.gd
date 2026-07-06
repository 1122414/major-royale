extends Control
## 奖励选择场景（占位，阶段 6 完善）。

@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	info_label.text = "战斗胜利！\n奖励选择（占位）\n按 ESC 返回地图"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameState.change_screen(GameState.Screen.MAP_EXPLORE)
