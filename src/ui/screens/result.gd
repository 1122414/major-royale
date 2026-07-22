extends Control
## 战斗/游戏结算场景。

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var content_box: VBoxContainer = $VBoxContainer

var _protocol_buttons: Array[Button] = []


func _ready() -> void:
	var victory: bool = GameState.player_stats.get("last_battle_victory", false)
	var was_ai: bool = GameState.player_stats.get("last_enemy_was_ai", false)
	var ending_flag: String = str(GameState.player_stats.get("last_ending_flag", ""))
	var enemy_id: String = str(GameState.player_stats.get("current_enemy_id", ""))
	var is_version_loop_finale := victory and enemy_id == "vl_zero_maintenance" and GameState.current_world_id == "version_loop"
	var is_run_end: bool = (not victory) or (enemy_id == "employment_pressure" and GameState.current_world_id == "campus") or is_version_loop_finale

	if is_version_loop_finale:
		_show_version_loop_protocol_choices()
		AudioManager.play_sfx("win")
		AudioManager.play_bgm_for_phase("victory")
		return
	if victory:
		if enemy_id == "employment_pressure":
			title_label.text = "唯一上岸者"
			desc_label.text = "你通过了终极答辩，成为赛场中的唯一上岸者。"
			continue_button.text = "查看通关总结 ▶"
		elif was_ai:
			title_label.text = "AI 遭遇胜利"
			desc_label.text = "你击败了 AI Native 敌人。%s" % _ending_text(ending_flag)
			continue_button.text = "领取奖励 ▶"
		else:
			title_label.text = "胜利"
			desc_label.text = "你击败了敌人，可以领取奖励。"
			continue_button.text = "领取奖励 ▶"
		AudioManager.play_sfx("win")
		AudioManager.play_bgm_for_phase("victory")
	else:
		title_label.text = "失败"
		if was_ai and ending_flag != "":
			desc_label.text = "你倒下了。%s" % _ending_text(ending_flag)
		else:
			desc_label.text = "你倒下了，本局结束。"
		continue_button.text = "查看本局总结 ▶"
		AudioManager.play_sfx("lose")
		AudioManager.play_bgm_for_phase("menu")

	continue_button.pressed.connect(_on_continue.bind(is_run_end))
	continue_button.grab_focus()


func _show_version_loop_protocol_choices() -> void:
	title_label.text = "终局维护室"
	desc_label.text = "零号维护停止了循环。请决定版本回环的后续协议；该选择会永久写入中枢，并在后续破壁世界中作为可读取接口。"
	continue_button.visible = false
	for protocol_id in ["stable_operation", "permanent_archive", "open_protocol"]:
		var info := MetaProgression.WORLD_ENDING_PROTOCOLS["version_loop"].get(protocol_id, {}) as Dictionary
		var button := Button.new()
		button.custom_minimum_size = Vector2(380, 58)
		button.text = "%s\n%s" % [str(info.get("name", protocol_id)), str(info.get("description", ""))]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = "该协议可在未来世界与次元破壁中被读取。"
		button.pressed.connect(_select_version_loop_protocol.bind(protocol_id))
		content_box.add_child(button)
		_protocol_buttons.append(button)
	if not _protocol_buttons.is_empty():
		_protocol_buttons[0].grab_focus()


func _select_version_loop_protocol(protocol_id: String) -> void:
	if not MetaProgression.set_world_ending_protocol("version_loop", protocol_id):
		return
	AudioManager.play_sfx("click")
	for button in _protocol_buttons:
		button.queue_free()
	_protocol_buttons.clear()
	var info := MetaProgression.get_world_ending_info("version_loop")
	GameState.player_stats["version_loop_ending_protocol"] = protocol_id
	title_label.text = "协议已写入：%s" % str(info.get("name", protocol_id))
	desc_label.text = "%s\n版本回环首次通关将结算热更新权限，并计入当前角色的世界通关名册。" % str(info.get("description", ""))
	continue_button.visible = true
	continue_button.text = "查看通关总结 ▶"
	continue_button.pressed.connect(_on_continue.bind(true))
	continue_button.grab_focus()


func _ending_text(flag: String) -> String:
	match flag:
		"tech_pressure": return "结局标记：技术施压。"
		"elegant_rebuttal": return "结局标记：优雅 rebuttal。"
		"delay_shadow": return "结局标记：延毕阴影。"
		"": return ""
	return "结局标记：%s。" % flag


func _on_continue(is_run_end: bool) -> void:
	AudioManager.play_sfx("click")
	if is_run_end:
		GameState.change_screen(GameState.Screen.RUN_SUMMARY)
	else:
		GameState.change_screen(GameState.Screen.REWARD)
