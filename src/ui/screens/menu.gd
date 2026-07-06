extends Control
## 主菜单场景。

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	GameState.change_screen(GameState.Screen.MAJOR_SELECT)


func _on_settings_pressed() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)


func _on_quit_pressed() -> void:
	get_tree().quit()
