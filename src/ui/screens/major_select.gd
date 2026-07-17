extends Control
## 参考图式专业选择：左侧菜单、五专业卡、明确确认开局。

const MAJOR_CARD_SCENE := preload("res://src/ui/widgets/major_card.tscn")
const StatLex := preload("res://src/logic/stat_lexicon.gd")

const PRESET_ORDER := ["computer", "law", "medicine", "finance", "arts"]
const STAT_NAMES := ["学识", "体能", "专注", "表达", "创造", "社交", "抗压", "资源"]
const TOTAL_POINTS := 48

@onready var cards_container: HBoxContainer = $SelectorPanel/Margin/VBox/CardsContainer
@onready var counter_label: Label = $SelectorPanel/Margin/VBox/Header/CounterLabel
@onready var back_button: Button = $MenuSidebar/Margin/VBox/BackButton
@onready var settings_button: Button = $MenuSidebar/Margin/VBox/SettingsButton
@onready var sidebar_start_button: Button = $MenuSidebar/Margin/VBox/StartButton
@onready var custom_button: Button = $MenuSidebar/Margin/VBox/CustomButton
@onready var current_major_name: Label = $MenuSidebar/Margin/VBox/CurrentMajorName
@onready var footer_name: Label = $SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/InfoCol/NameLabel
@onready var footer_desc: Label = $SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/InfoCol/DescLabel
@onready var footer_skill: Label = $SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/InfoCol/SkillLabel
@onready var start_selected_button: Button = $SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/StartSelectedButton
@onready var custom_shade: ColorRect = $CustomShade
@onready var custom_panel: PanelContainer = $CustomPanel

var _cards: Dictionary = {}
var _selected_id := ""
var _custom_stats: Dictionary = {}


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	settings_button.pressed.connect(_on_settings)
	sidebar_start_button.pressed.connect(_start_selected_major)
	start_selected_button.pressed.connect(_start_selected_major)
	custom_button.pressed.connect(_on_custom_pressed)

	for major_id in PRESET_ORDER:
		if not Config.majors.has(major_id):
			continue
		var major: MajorResource = Config.majors[major_id]
		var card: Control = MAJOR_CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(170, 430)
		cards_container.add_child(card)
		card.setup(major)
		card.selected.connect(_preview_major.bind(major_id))
		_cards[major_id] = card

	if Config.majors.has("computer"):
		_preview_major("computer")

	_init_custom_panel()
	_set_custom_visible(false)
	sidebar_start_button.grab_focus()


func _init_custom_panel() -> void:
	var confirm_btn: Button = custom_panel.get_node("Margin/VBox/ConfirmButton")
	var cancel_btn: Button = custom_panel.get_node("Margin/VBox/CancelButton")
	confirm_btn.pressed.connect(_on_custom_confirm)
	cancel_btn.pressed.connect(_on_custom_cancel)

	var stats_container: GridContainer = custom_panel.get_node("Margin/VBox/StatsContainer")
	for child in stats_container.get_children():
		child.queue_free()
	for stat_name in STAT_NAMES:
		_custom_stats[stat_name] = 6
		var label := Label.new()
		label.text = stat_name
		stats_container.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 1
		slider.max_value = 10
		slider.value = 6
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_custom_stat_changed.bind(stat_name))
		stats_container.add_child(slider)
	_update_points_label()


func _on_custom_stat_changed(value: float, stat_name: String) -> void:
	_custom_stats[stat_name] = int(value)
	_update_points_label()


func _update_points_label() -> void:
	var used := 0
	for value in _custom_stats.values():
		used += int(value)
	var label: Label = custom_panel.get_node("Margin/VBox/PointsLabel")
	label.text = "剩余点数：%d / %d" % [TOTAL_POINTS - used, TOTAL_POINTS]
	label.add_theme_color_override("font_color", UIColors.DANGER_RED if used > TOTAL_POINTS else UIColors.TEXT_PRIMARY)


func _preview_major(major_id: String) -> void:
	if not Config.majors.has(major_id):
		return
	_selected_id = major_id
	for id in _cards:
		_cards[id].set_selected(id == major_id)
	var major: MajorResource = Config.majors[major_id]
	current_major_name.text = major.name
	footer_name.text = major.name
	footer_desc.text = major.description
	footer_skill.text = "主动：%s　｜　被动：%s" % [
		str(major.active_skill.get("name", "")),
		str(major.passive_skill.get("name", "")),
	]
	footer_skill.tooltip_text = "%s\n\n%s" % [
		str(major.active_skill.get("description", "")),
		str(major.passive_skill.get("description", "")),
	]
	counter_label.text = "%d / %d" % [PRESET_ORDER.find(major_id) + 1, PRESET_ORDER.size()]
	footer_desc.tooltip_text = StatLex.all_stats_block()


func _select_relative(delta: int) -> void:
	var index := PRESET_ORDER.find(_selected_id)
	if index < 0:
		index = 0
	index = wrapi(index + delta, 0, PRESET_ORDER.size())
	_preview_major(PRESET_ORDER[index])
	AudioManager.play_sfx("click")


func _start_selected_major() -> void:
	if _selected_id.is_empty() or not Config.majors.has(_selected_id):
		return
	AudioManager.play_sfx("click")
	GameState.start_run(_selected_id)
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)


func _on_custom_pressed() -> void:
	AudioManager.play_sfx("click")
	_set_custom_visible(true)
	var name_edit: LineEdit = custom_panel.get_node("Margin/VBox/NameEdit")
	name_edit.grab_focus()
	name_edit.select_all()


func _on_custom_cancel() -> void:
	AudioManager.play_sfx("click")
	_set_custom_visible(false)
	sidebar_start_button.grab_focus()


func _set_custom_visible(value: bool) -> void:
	custom_shade.visible = value
	custom_panel.visible = value


func _on_custom_confirm() -> void:
	AudioManager.play_sfx("click")
	var used := 0
	for value in _custom_stats.values():
		used += int(value)
	if used > TOTAL_POINTS:
		return

	var name_edit: LineEdit = custom_panel.get_node("Margin/VBox/NameEdit")
	var major_name := name_edit.text.strip_edges()
	if major_name.is_empty():
		major_name = "自定义专业"

	var custom_major := MajorResource.new()
	custom_major.id = "custom_%d" % Time.get_unix_time_from_system()
	custom_major.name = major_name
	custom_major.description = "玩家自定义专业（点买八维）。"
	custom_major.stats = _custom_stats.duplicate()
	custom_major.active_skill = {"id": "inspiration", "name": "灵感爆发", "description": "抽 2 张牌，并减少压力。"}
	custom_major.passive_skill = {"id": "custom_grit", "name": "自学成才", "description": "开局精神略高。"}
	custom_major.starter_deck = [
		"strike", "defend", "draw_card", "deep_breath", "coffee_boost",
		"stretch", "group_project", "strike", "defend", "all_nighter_study",
		"deep_breath", "draw_card",
	]

	Config.majors[custom_major.id] = custom_major
	GameState.start_run(custom_major.id)
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MENU)


func _on_settings() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if custom_panel.visible:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_custom_cancel()
		return
	if event.keycode not in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_ENTER, KEY_KP_ENTER, KEY_S, KEY_ESCAPE]:
		return
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_LEFT, KEY_A:
			_select_relative(-1)
		KEY_RIGHT, KEY_D:
			_select_relative(1)
		KEY_ENTER, KEY_KP_ENTER:
			_start_selected_major()
		KEY_S:
			_on_settings()
		KEY_ESCAPE:
			_on_back_pressed()
