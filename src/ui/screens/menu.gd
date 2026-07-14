extends Control
## 主菜单：左栏按钮 + 标题 + 校园氛围背景。

const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

@onready var title_label: Label = $TopBar/TitleLabel
@onready var start_button: Button = $LeftPanel/ButtonColumn/StartButton
@onready var major_button: Button = $LeftPanel/ButtonColumn/MajorButton
@onready var settings_button: Button = $LeftPanel/ButtonColumn/SettingsButton
@onready var quit_button: Button = $LeftPanel/ButtonColumn/QuitButton
@onready var bgm_button: Button = $LeftPanel/ButtonColumn/BgmButton
@onready var achievements_button: Button = $LeftPanel/ButtonColumn/AchievementsButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	major_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	bgm_button.pressed.connect(_on_bgm_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	_style_primary_button(start_button)
	_style_secondary_button(major_button)
	_style_secondary_button(settings_button)
	_style_secondary_button(quit_button)
	_style_secondary_button(bgm_button)
	_style_secondary_button(achievements_button)
	_refresh_bgm_button()
	AudioManager.play_bgm_for_phase("menu")

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.custom_minimum_size = Vector2(40, 40)
	settings_btn.position = Vector2(1228, 12)
	settings_btn.pressed.connect(_on_settings_pressed)
	add_child(settings_btn)


func _style_primary_button(btn: Button) -> void:
	var normal := _btn_style(UIColors.PANEL_SOLID, UIColors.ACCENT_GOLD, 3)
	var hover := _btn_style(UIColors.HOVER_FILL, UIColors.ACCENT_GOLD, 3)
	var pressed := _btn_style(UIColors.PRESSED_FILL, Color("#FFD070"), 3)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 24)


func _style_secondary_button(btn: Button) -> void:
	var normal := _btn_style(UIColors.PANEL, UIColors.BORDER_CYAN, 2)
	var hover := _btn_style(UIColors.HOVER_FILL, UIColors.BORDER_CYAN, 2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)


func _btn_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(width)
	style.border_color = border
	style.set_corner_radius_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _on_start_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MAJOR_SELECT)


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_bgm_pressed() -> void:
	AudioManager.play_sfx("click")
	var name_str: String = AudioManager.cycle_menu_bgm()
	_refresh_bgm_button(name_str)


func _on_achievements_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.ACHIEVEMENTS)


func _refresh_bgm_button(name_str: String = "") -> void:
	if name_str == "":
		name_str = AudioManager.get_current_bgm_name()
	bgm_button.text = "♪  BGM：%s" % name_str
