extends Control
## 设置界面。

@onready var ai_enabled_check: CheckBox = $VBoxContainer/AIEnabledCheck
@onready var ai_server_edit: LineEdit = $VBoxContainer/AIServerEdit
@onready var master_slider: HSlider = $VBoxContainer/MasterSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicSlider
@onready var fullscreen_check: CheckBox = $VBoxContainer/FullscreenCheck
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var message_label: Label = $VBoxContainer/MessageLabel


func _ready() -> void:
	ai_enabled_check.button_pressed = Settings.ai_enabled
	ai_server_edit.text = Settings.ai_server_url
	master_slider.value = Settings.master_volume
	sfx_slider.value = Settings.sfx_volume
	music_slider.value = Settings.music_volume
	fullscreen_check.button_pressed = Settings.fullscreen

	save_button.pressed.connect(_on_save)
	back_button.pressed.connect(_on_back)


func _on_save() -> void:
	Settings.ai_enabled = ai_enabled_check.button_pressed
	Settings.ai_server_url = ai_server_edit.text
	Settings.master_volume = master_slider.value
	Settings.sfx_volume = sfx_slider.value
	Settings.music_volume = music_slider.value
	Settings.fullscreen = fullscreen_check.button_pressed
	Settings.save_settings()

	AudioManager.set_master_volume(Settings.master_volume)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

	message_label.text = "设置已保存"


func _on_back() -> void:
	GameState.change_screen(GameState.Screen.MENU)
