extends Control
## 专业选择界面。

const MAJOR_CARD_SCENE := preload("res://src/ui/widgets/major_card.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

@onready var title_label: Label = $TitleLabel
@onready var cards_container: HBoxContainer = $CardsContainer
@onready var back_button: Button = $BackButton
@onready var custom_button: Button = $CustomButton
@onready var custom_panel: PanelContainer = $CustomPanel

const STAT_NAMES := ["学识", "体能", "专注", "表达", "创造", "社交", "抗压", "资源"]
const TOTAL_POINTS := 48

var _custom_stats: Dictionary = {}


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	custom_button.pressed.connect(_on_custom_pressed)

	for major_id in Config.majors:
		var major: MajorResource = Config.majors[major_id]
		var card: Control = MAJOR_CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.setup(major)
		card.selected.connect(_on_major_selected.bind(major_id))

	custom_panel.visible = false
	_init_custom_panel()

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1180, 20)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)


func _init_custom_panel() -> void:
	var confirm_btn: Button = custom_panel.get_node("VBoxContainer/ConfirmButton")
	var cancel_btn: Button = custom_panel.get_node("VBoxContainer/CancelButton")
	confirm_btn.pressed.connect(_on_custom_confirm)
	cancel_btn.pressed.connect(_on_custom_cancel)

	var stats_container: GridContainer = custom_panel.get_node("VBoxContainer/StatsContainer")
	for stat_name in STAT_NAMES:
		_custom_stats[stat_name] = 5
		var label := Label.new()
		label.text = stat_name
		stats_container.add_child(label)

		var slider := HSlider.new()
		slider.name = "%sSlider" % stat_name
		slider.min_value = 1
		slider.max_value = 10
		slider.value = 5
		slider.step = 1
		slider.value_changed.connect(_on_custom_stat_changed.bind(stat_name))
		stats_container.add_child(slider)

	_update_points_label()


func _on_custom_stat_changed(value: float, stat_name: String) -> void:
	_custom_stats[stat_name] = int(value)
	_update_points_label()


func _update_points_label() -> void:
	var used := 0
	for v in _custom_stats.values():
		used += v
	var label: Label = custom_panel.get_node("VBoxContainer/PointsLabel")
	label.text = "剩余点数：%d / %d" % [TOTAL_POINTS - used, TOTAL_POINTS]


func _on_major_selected(major_id: String) -> void:
	AudioManager.play_sfx("click")
	GameState.start_run(major_id)
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MENU)


func _on_settings() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)


func _on_custom_pressed() -> void:
	AudioManager.play_sfx("click")
	custom_panel.visible = true


func _on_custom_cancel() -> void:
	AudioManager.play_sfx("click")
	custom_panel.visible = false


func _on_custom_confirm() -> void:
	AudioManager.play_sfx("click")
	var name_edit: LineEdit = custom_panel.get_node("VBoxContainer/NameEdit")
	var major_name := name_edit.text.strip_edges()
	if major_name.is_empty():
		major_name = "自定义专业"

	var used := 0
	for v in _custom_stats.values():
		used += v
	if used > TOTAL_POINTS:
		return

	var custom_major := MajorResource.new()
	custom_major.id = "custom_%d" % Time.get_unix_time_from_system()
	custom_major.name = major_name
	custom_major.description = "玩家自定义专业"
	custom_major.stats = _custom_stats.duplicate()
	custom_major.active_skill = {"id": "emergency_suture", "name": "紧急缝合", "description": "恢复生命并移除身体负面状态。"}
	custom_major.passive_skill = {"id": "anatomy_familiarity", "name": "人体结构熟悉", "description": "攻击有概率命中弱点。"}
	custom_major.starter_deck = ["strike", "defend", "draw_card", "first_aid", "anatomy_weakness"]

	Config.majors[custom_major.id] = custom_major
	GameState.start_run(custom_major.id)
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)
