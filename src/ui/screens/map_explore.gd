extends Control
## 地图探索场景（占位，阶段 3 完善）。

@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	var major: MajorResource = Config.majors.get(GameState.player_major_id)
	if major:
		info_label.text = "你选择了 %s\n按 ESC 返回主菜单" % major.name


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameState.change_screen(GameState.Screen.MENU)
