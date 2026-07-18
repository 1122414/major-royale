extends Control
## 设置界面。

@onready var ai_enabled_check: CheckBox = $VBoxContainer/AIEnabledCheck
@onready var ai_server_edit: LineEdit = $VBoxContainer/AIServerEdit
@onready var master_slider: HSlider = $VBoxContainer/MasterSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicSlider
@onready var fullscreen_check: CheckBox = $VBoxContainer/FullscreenCheck
@onready var action_window_option: OptionButton = $VBoxContainer/ActionWindowOption
@onready var reduced_motion_check: CheckBox = $VBoxContainer/ReducedMotionCheck
@onready var vibration_check: CheckBox = $VBoxContainer/VibrationCheck
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
	_setup_action_window_options()
	reduced_motion_check.button_pressed = Settings.reduced_motion
	vibration_check.button_pressed = Settings.controller_vibration
	_refresh_ai_server_edit(Settings.ai_enabled)

	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	ai_enabled_check.toggled.connect(_refresh_ai_server_edit)

	save_button.pressed.connect(_on_save)
	back_button.pressed.connect(_on_back)
	message_label.text = "拖动滑条可实时预听；点「保存设置」写入本地。"
	ai_enabled_check.grab_focus()


func _setup_action_window_options() -> void:
	var options := [
		{"label": "快速（0.75×）", "value": 0.75},
		{"label": "标准（1.0×）", "value": 1.0},
		{"label": "宽松（1.5×）", "value": 1.5},
		{"label": "辅助（2.0×）", "value": 2.0},
	]
	action_window_option.clear()
	var selected_index := 1
	for i in options.size():
		action_window_option.add_item(str(options[i].label))
		action_window_option.set_item_metadata(i, float(options[i].value))
		if is_equal_approx(float(options[i].value), Settings.action_window_scale):
			selected_index = i
	action_window_option.select(selected_index)


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
	var server_url := Settings.normalize_ai_server_url(ai_server_edit.text)
	if ai_enabled_check.button_pressed and server_url.is_empty():
		message_label.text = "AI 服务地址必须以 http:// 或 https:// 开头"
		ai_server_edit.grab_focus()
		return
	Settings.ai_enabled = ai_enabled_check.button_pressed
	if not server_url.is_empty():
		Settings.ai_server_url = server_url
	Settings.master_volume = master_slider.value
	Settings.sfx_volume = sfx_slider.value
	Settings.music_volume = music_slider.value
	Settings.fullscreen = fullscreen_check.button_pressed
	Settings.action_window_scale = float(action_window_option.get_selected_metadata())
	Settings.reduced_motion = reduced_motion_check.button_pressed
	Settings.controller_vibration = vibration_check.button_pressed
	Settings.save_settings()

	AudioManager.set_master_volume(Settings.master_volume)
	AudioManager.set_sfx_volume(Settings.sfx_volume)
	AudioManager.set_music_volume(Settings.music_volume)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

	message_label.text = "设置已保存"


func _refresh_ai_server_edit(enabled: bool) -> void:
	ai_server_edit.editable = enabled
	ai_server_edit.tooltip_text = "在线服务仅用于扩展敌人台词与策略；关闭时完整使用本地白名单策略。"


func _on_back() -> void:
	# 未保存则恢复已保存音量，避免预览残留
	AudioManager.set_master_volume(Settings.master_volume)
	AudioManager.set_sfx_volume(Settings.sfx_volume)
	AudioManager.set_music_volume(Settings.music_volume)
	GameState.return_from_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
