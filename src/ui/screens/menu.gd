extends Control
## 夜景校园主菜单：左侧操作、右侧生存情报与压力提示。

@onready var start_button: Button = $MenuSidebar/Margin/VBox/StartButton
@onready var major_button: Button = $MenuSidebar/Margin/VBox/MajorButton
@onready var settings_button: Button = $MenuSidebar/Margin/VBox/SettingsButton
@onready var quit_button: Button = $MenuSidebar/Margin/VBox/QuitButton
@onready var bgm_button: Button = $MenuSidebar/Margin/VBox/BgmButton
@onready var achievements_button: Button = $MenuSidebar/Margin/VBox/AchievementsButton
@onready var progression_button: Button = $MenuSidebar/Margin/VBox/ProgressionButton
@onready var settings_shortcut: Button = $SettingsShortcut
@onready var footer_tip: Label = $MenuSidebar/Margin/VBox/FooterTip
@onready var meta_gold_label: Label = $MenuSidebar/Margin/VBox/MetaGoldLabel
@onready var world_title: Label = $MajorCallout/Margin/VBox/Title
@onready var world_status: Label = $MajorCallout/Margin/VBox/Stats
@onready var world_portal: Label = $MajorCallout/Margin/VBox/Survivors
@onready var world_portal_state: Label = $MajorCallout/Margin/VBox/Countdown
@onready var world_hint: Label = $MajorCallout/Margin/VBox/SelectHint


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	major_button.pressed.connect(_on_new_run_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_shortcut.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	bgm_button.pressed.connect(_on_bgm_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	progression_button.pressed.connect(_on_progression_pressed)
	_refresh_run_buttons()
	_refresh_bgm_button()
	_refresh_meta_progress()
	MetaProgression.profile_changed.connect(_refresh_meta_progress)
	AudioManager.play_bgm_for_phase("menu")
	start_button.grab_focus()


func _on_start_pressed() -> void:
	AudioManager.play_sfx("click")
	if GameState.has_run_save() and GameState.resume_saved_run():
		return
	GameState.change_screen(GameState.Screen.MAJOR_SELECT)


func _on_new_run_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MAJOR_SELECT)


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)


func _on_quit_pressed() -> void:
	AudioManager.request_application_quit()


func _on_bgm_pressed() -> void:
	AudioManager.play_sfx("click")
	var name_str: String = AudioManager.cycle_menu_bgm()
	_refresh_bgm_button(name_str)


func _on_achievements_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.ACHIEVEMENTS)


func _on_progression_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.META_PROGRESSION)


func _refresh_bgm_button(name_str: String = "") -> void:
	if name_str == "":
		name_str = AudioManager.get_current_bgm_name()
	bgm_button.text = "♪  BGM：%s" % name_str


func _refresh_run_buttons() -> void:
	var has_save := GameState.has_run_save()
	start_button.text = "▶  继续校园生存" if has_save else "▶  开始游戏"
	major_button.text = "🎓  新开一局 / 选择专业" if has_save else "🎓  选择专业"
	major_button.tooltip_text = "选择专业后会覆盖当前一局进度" if has_save else "选择本局战斗专业"
	footer_tip.text = (
		"Enter 继续　M 新开一局　S 设置\n进度会在安全节点自动保存"
		if has_save
		else "Enter 开始　M 专业　S 设置\n压力圈将在开局后持续收缩"
	)


func _refresh_meta_gold() -> void:
	meta_gold_label.text = "◆  永久金币：%d" % MetaProgression.get_gold()


func _refresh_meta_progress() -> void:
	_refresh_meta_gold()
	world_title.text = "中枢档案"
	world_status.text = "当前入口：校园世界\n通关记录：%d　·　规则碎片：%d / 4" % [
		MetaProgression.get_world_clear_count("campus"),
		MetaProgression.get_collected_fragment_ids().size(),
	]
	if MetaProgression.is_world_unlocked("version_loop"):
		world_portal.text = "异常下载：版本回环"
		world_portal_state.text = "正在稳定"
		world_hint.text = "已取得「筛选许可」。入口正在载入新的世界规则，当前不可进入。"
	else:
		world_portal.text = "未发现其他世界"
		world_portal_state.text = "校园入口稳定"
		world_hint.text = "通过终极答辩后，中枢将记录你的第一枚世界规则碎片。"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_M, KEY_S]:
		return
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_on_start_pressed()
		KEY_M:
			_on_new_run_pressed()
		KEY_S:
			_on_settings_pressed()
