extends Control
## 战斗/游戏结算场景。

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton


func _ready() -> void:
	var victory: bool = GameState.player_stats.get("last_battle_victory", false)
	if victory:
		title_label.text = "胜利"
		desc_label.text = "你击败了敌人，获得了奖励。"
	else:
		title_label.text = "失败"
		desc_label.text = "你倒下了，但还能重新开始。"

	continue_button.pressed.connect(_on_continue)


func _on_continue() -> void:
	var victory: bool = GameState.player_stats.get("last_battle_victory", false)
	if victory:
		GameState.change_screen(GameState.Screen.REWARD)
	else:
		GameState.change_screen(GameState.Screen.MENU)
