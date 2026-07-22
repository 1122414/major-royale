extends Control
## 参考图式专业选择：左侧菜单、五专业卡、明确确认开局。

const MAJOR_CARD_SCENE := preload("res://src/ui/widgets/major_card.tscn")
const StatLex := preload("res://src/logic/stat_lexicon.gd")

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
@onready var difficulty_option: OptionButton = $SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/RunConfigCol/DifficultyOption
@onready var seed_edit: LineEdit = $SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/RunConfigCol/SeedEdit
@onready var start_selected_button: Button = $SelectorPanel/Margin/VBox/SelectedInfoPanel/Margin/HBox/StartSelectedButton
@onready var custom_shade: ColorRect = $CustomShade
@onready var custom_panel: PanelContainer = $CustomPanel

var _cards: Dictionary = {}
var _selected_id := ""
var _custom_stats: Dictionary = {}
var _character_order: Array[String] = []


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	settings_button.pressed.connect(_on_settings)
	sidebar_start_button.pressed.connect(_start_selected_major)
	start_selected_button.pressed.connect(_start_selected_major)
	custom_button.pressed.connect(_on_custom_pressed)
	_init_run_config()

	var world: Resource = Config.get_world(GameState.current_world_id)
	if world != null:
		for character_id in world.character_ids:
			if MetaProgression.is_character_unlocked(character_id):
				_character_order.append(character_id)
	for major_id in _character_order:
		if not Config.majors.has(major_id):
			continue
		var major: MajorResource = Config.majors[major_id]
		var card: Control = MAJOR_CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(170, 430)
		cards_container.add_child(card)
		card.setup(major)
		card.selected.connect(_preview_major.bind(major_id))
		_cards[major_id] = card

	if not _character_order.is_empty():
		_preview_major(_character_order[0])

	_init_custom_panel()
	custom_button.visible = GameState.current_world_id == GameState.DEFAULT_WORLD_ID
	_set_custom_visible(false)
	sidebar_start_button.grab_focus()


func _init_run_config() -> void:
	difficulty_option.clear()
	var max_unlocked := Achievements.get_max_unlocked_difficulty()
	for i in GameState.DIFFICULTY_CATALOG.size():
		var info: Dictionary = GameState.get_difficulty_info(i)
		var locked := i > max_unlocked
		var label := "%d · %s%s" % [i + 1, info.get("name", "挑战"), "（未解锁）" if locked else ""]
		difficulty_option.add_item(label, i)
		difficulty_option.set_item_disabled(i, locked)
	difficulty_option.select(0)
	difficulty_option.item_selected.connect(_on_difficulty_selected)
	seed_edit.text_changed.connect(_on_seed_text_changed)
	_on_difficulty_selected(0)


func _on_difficulty_selected(index: int) -> void:
	var difficulty_id := difficulty_option.get_item_id(index)
	var info := GameState.get_difficulty_info(difficulty_id)
	difficulty_option.tooltip_text = str(info.get("description", ""))


func _on_seed_text_changed(_value: String) -> void:
	seed_edit.remove_theme_color_override("font_color")


func _get_run_seed() -> int:
	var seed := GameState.seed_from_text(seed_edit.text)
	if seed >= 0:
		return seed
	seed_edit.add_theme_color_override("font_color", UIColors.DANGER_RED)
	seed_edit.tooltip_text = "种子只能填写数字，或留空使用随机种子。"
	seed_edit.grab_focus()
	return -1


func _get_selected_difficulty() -> int:
	var selected := difficulty_option.get_selected_id()
	return clampi(selected, 0, Achievements.get_max_unlocked_difficulty())


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
	counter_label.text = "%d / %d" % [_character_order.find(major_id) + 1, _character_order.size()]
	footer_desc.tooltip_text = StatLex.all_stats_block()


func _select_relative(delta: int) -> void:
	var index := _character_order.find(_selected_id)
	if index < 0:
		index = 0
	if _character_order.is_empty():
		return
	index = wrapi(index + delta, 0, _character_order.size())
	_preview_major(_character_order[index])
	AudioManager.play_sfx("click")


func _start_selected_major() -> void:
	if _selected_id.is_empty() or not Config.majors.has(_selected_id):
		return
	var seed := _get_run_seed()
	if seed < 0:
		return
	AudioManager.play_sfx("click")
	GameState.start_run(_selected_id, seed, _get_selected_difficulty(), GameState.current_world_id)
	GameState.change_screen(GameState.get_world_exploration_screen())


func _on_custom_pressed() -> void:
	if GameState.current_world_id != GameState.DEFAULT_WORLD_ID:
		return
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
	var seed := _get_run_seed()
	if seed < 0:
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
	GameState.start_run(custom_major.id, seed, _get_selected_difficulty(), GameState.current_world_id)
	GameState.change_screen(GameState.get_world_exploration_screen())


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MENU)


func _on_settings() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)


func _input(event: InputEvent) -> void:
	if custom_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_custom_cancel()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		_on_settings()
		return
	if event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_select_relative(-1)
		return
	if event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_select_relative(1)
		return
	if event is not InputEventKey or not event.pressed or event.echo:
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
