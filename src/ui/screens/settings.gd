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

	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)

	save_button.pressed.connect(_on_save)
	back_button.pressed.connect(_on_back)
	message_label.text = "拖动滑条可实时预听；点「保存设置」写入本地。"


func _on_master_changed(v: float) -> void:
	AudioManager.set_master_volume(v)
	message_label.text = "主音量 %.0f%%（未保存）" % (v * 100.0)


func _on_sfx_changed(v: float) -> void:
	AudioManager.set_sfx_volume(v)
	AudioManager.play_sfx("click")
	message_label.text = "音效音量 %.0f%%（未保存）" % (v * 100.0)


func _on_music_changed(v: float) -> void:
	AudioManager.set_music_volume(v)
	message_label.text = "音乐音量 %.0f%%（未保存）" % (v * 100.0)


func _on_save() -> void:
	Settings.ai_enabled = ai_enabled_check.button_pressed
	Settings.ai_server_url = ai_server_edit.text
	Settings.master_volume = master_slider.value
	Settings.sfx_volume = sfx_slider.value
	Settings.music_volume = music_slider.value
	Settings.fullscreen = fullscreen_check.button_pressed
	Settings.save_settings()

	AudioManager.set_master_volume(Settings.master_volume)
	AudioManager.set_sfx_volume(Settings.sfx_volume)
	AudioManager.set_music_volume(Settings.music_volume)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

	message_label.text = "设置已保存"


func _on_back() -> void:
	# 未保存则恢复已保存音量，避免预览残留
	AudioManager.set_master_volume(Settings.master_volume)
	AudioManager.set_sfx_volume(Settings.sfx_volume)
	AudioManager.set_music_volume(Settings.music_volume)
	GameState.return_from_settings()
