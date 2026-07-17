class_name ExploreHUD
extends CanvasLayer
## 校园探索 HUD：状态、资源、压力圈、目标、快捷键与基础功能面板。

signal settings_requested
signal fallback_requested

const STAT_BAR_SCENE := preload("res://src/ui/widgets/stat_bar.tscn")
const MINIMAP_SCENE := preload("res://src/ui/widgets/pressure_minimap.tscn")
const ObjectiveTrackerScript := preload("res://src/logic/objective_tracker.gd")
const StatLex := preload("res://src/logic/stat_lexicon.gd")

@onready var major_label: Label = $TopBar/Margin/Row/Identity/MajorLabel
@onready var area_label: Label = $TopBar/Margin/Row/Identity/AreaLabel
@onready var bars: VBoxContainer = $TopBar/Margin/Row/Bars
@onready var day_label: Label = $TopBar/Margin/Row/DayPanel/DayLabel
@onready var credits_label: Label = $TopBar/Margin/Row/CreditsLabel
@onready var points_label: Label = $TopBar/Margin/Row/PointsLabel
@onready var minimap_slot: Control = $PressurePanel/Margin/VBox/MinimapSlot
@onready var pressure_label: Label = $PressurePanel/Margin/VBox/PressureLabel
@onready var main_title: Label = $ObjectivePanel/Margin/VBox/MainTitle
@onready var main_description: Label = $ObjectivePanel/Margin/VBox/MainDescription
@onready var optional_list: VBoxContainer = $ObjectivePanel/Margin/VBox/OptionalList
@onready var message_label: Label = $LocationToast/Margin/MessageLabel
@onready var interaction_prompt: PanelContainer = $InteractionPrompt
@onready var interaction_label: Label = $InteractionPrompt/InteractionLabel
@onready var utility_shade: ColorRect = $UtilityShade
@onready var utility_panel: PanelContainer = $UtilityPanel
@onready var utility_title: Label = $UtilityPanel/Margin/VBox/Title
@onready var utility_body: Label = $UtilityPanel/Margin/VBox/Body
@onready var vignette: PressureVignette = $PressureVignette

var _hp_bar: StatBar
var _spirit_bar: StatBar
var _minimap: PressureMinimap
var _objectives := ObjectiveTrackerScript.new()


func _ready() -> void:
	_hp_bar = STAT_BAR_SCENE.instantiate()
	_hp_bar.kind = StatBar.BarKind.HP
	_hp_bar.custom_minimum_size = Vector2(196, 26)
	bars.add_child(_hp_bar)
	_spirit_bar = STAT_BAR_SCENE.instantiate()
	_spirit_bar.kind = StatBar.BarKind.SPIRIT
	_spirit_bar.custom_minimum_size = Vector2(196, 26)
	bars.add_child(_spirit_bar)

	_minimap = MINIMAP_SCENE.instantiate()
	_minimap.custom_minimum_size = Vector2(150, 150)
	minimap_slot.add_child(_minimap)

	$TopBar/Margin/Row/BagButton.pressed.connect(_open_bag)
	$TopBar/Margin/Row/MapButton.pressed.connect(_open_map)
	$TopBar/Margin/Row/SettingsButton.pressed.connect(func(): settings_requested.emit())
	$UtilityPanel/Margin/VBox/CloseButton.pressed.connect(_close_utility)
	$UtilityPanel/Margin/VBox/FallbackButton.pressed.connect(func(): fallback_requested.emit())
	utility_shade.gui_input.connect(_on_shade_input)
	interaction_prompt.visible = false
	_close_utility()
	refresh()


func refresh() -> void:
	var major_name := "未定专业"
	if Config.majors.has(GameState.player_major_id):
		major_name = str(Config.majors[GameState.player_major_id].name)
	major_label.text = "%s新生" % major_name
	day_label.text = "第 %d 天" % GameState.day_count
	credits_label.text = "▣ 学分  %d" % GameState.credits
	points_label.text = "● 信用点  %d" % GameState.credit_points
	_hp_bar.set_values(GameState.run_hp, GameState.run_max_hp)
	_spirit_bar.set_values(GameState.run_spirit, GameState.run_max_spirit)
	pressure_label.text = "压力 %d　危险区 %d%%" % [GameState.run_progress, _danger_percent()]
	pressure_label.add_theme_color_override("font_color", UIColors.DANGER_RED if GameState.run_progress >= 4 else UIColors.ACCENT_GOLD)
	_minimap.refresh()
	vignette.set_pressure(GameState.run_progress)

	_objectives.refresh(GameState.campus_visited_locations)
	main_title.text = str(_objectives.main_objective.get("title", "当前目标"))
	main_description.text = str(_objectives.main_objective.get("description", ""))
	for child in optional_list.get_children():
		child.queue_free()
	for objective in _objectives.optional_objectives:
		var label := Label.new()
		var completed := bool(objective.get("completed", false))
		label.text = "%s  %s" % ["✓" if completed else "□", str(objective.get("title", ""))]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", UIColors.SUCCESS_GREEN if completed else UIColors.TEXT_MUTED)
		optional_list.add_child(label)


func set_area(display_name: String) -> void:
	area_label.text = display_name


func set_interaction(hotspot: CampusHotspot) -> void:
	interaction_prompt.visible = hotspot != null
	if hotspot != null:
		interaction_label.text = "E  交互 · %s" % hotspot.display_name


func show_message(message: String) -> void:
	message_label.text = message


func _danger_percent() -> int:
	return clampi(int(round(float(GameState.run_progress) / 12.0 * 100.0)), 0, 100)


func _open_bag() -> void:
	_open_utility("背包与牌组", "牌库：%d 张\n遗物：%d 件\n学分：%d\n信用点：%d" % [
		GameState.deck_card_ids.size(),
		GameState.run_relic_ids.size(),
		GameState.credits,
		GameState.credit_points,
	])


func _open_status() -> void:
	var stat_text := StatLex.all_stats_block() if not GameState.player_major_id.is_empty() else "尚未选择专业"
	_open_utility("当前状态", "生命 %d/%d　精神 %d/%d\n压力 %d\n\n%s" % [
		GameState.run_hp,
		GameState.run_max_hp,
		GameState.run_spirit,
		GameState.run_max_spirit,
		GameState.run_progress,
		stat_text,
	])


func _open_map() -> void:
	var visited_names: Array[String] = []
	var name_map := {"teaching": "教学楼", "library": "图书馆", "dorm": "宿舍", "cafeteria": "食堂", "sports": "操场"}
	for location_id in GameState.campus_visited_locations:
		visited_names.append(str(name_map.get(location_id, location_id)))
	var visited_text := "、".join(visited_names) if not visited_names.is_empty() else "尚未探索"
	_open_utility("校园地图", "已到达：%s\n压力危险区：%d%%\n当前目标：%s" % [
		visited_text,
		_danger_percent(),
		str(_objectives.main_objective.get("title", "")),
	])


func _open_utility(title: String, body: String) -> void:
	utility_title.text = title
	utility_body.text = body
	utility_shade.visible = true
	utility_panel.visible = true


func _close_utility() -> void:
	utility_shade.visible = false
	utility_panel.visible = false


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_utility()


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if utility_panel.visible and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close_utility()
		return
	if event.keycode not in [KEY_I, KEY_C, KEY_M, KEY_ESCAPE]:
		return
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_I:
			_open_bag()
		KEY_C:
			_open_status()
		KEY_M:
			_open_map()
		KEY_ESCAPE:
			settings_requested.emit()
