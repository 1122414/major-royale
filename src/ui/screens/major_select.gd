extends Control
## 专业选择：预设专业 + 自定义专业。

const MAJOR_CARD_SCENE := preload("res://src/ui/widgets/major_card.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

const PRESET_ORDER := ["computer", "law", "medicine", "finance", "arts"]
const STAT_NAMES := ["学识", "体能", "专注", "表达", "创造", "社交", "抗压", "资源"]
const TOTAL_POINTS := 48

@onready var title_label: Label = $Header/TitleLabel
@onready var cards_container: HBoxContainer = $Scroll/CardsContainer
@onready var back_button: Button = $Header/BackButton
@onready var custom_button: Button = $Footer/FooterPanel/HBox/CustomButton
@onready var footer_name: Label = $Footer/FooterPanel/HBox/InfoCol/NameLabel
@onready var footer_desc: Label = $Footer/FooterPanel/HBox/InfoCol/DescLabel
@onready var footer_skill: Label = $Footer/FooterPanel/HBox/InfoCol/SkillLabel
@onready var custom_panel: PanelContainer = $CustomPanel

var _cards: Dictionary = {}
var _selected_id: String = ""
var _custom_stats: Dictionary = {}


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	custom_button.pressed.connect(_on_custom_pressed)

	for major_id in PRESET_ORDER:
		if not Config.majors.has(major_id):
			continue
		var major: MajorResource = Config.majors[major_id]
		var card: Control = MAJOR_CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(220, 420)
		cards_container.add_child(card)
		card.setup(major)
		card.selected.connect(_on_major_selected.bind(major_id))
		card.hovered.connect(_on_major_hovered.bind(major_id))
		_cards[major_id] = card

	if Config.majors.has("computer"):
		_preview_major("computer")

	_init_custom_panel()
	custom_panel.visible = false

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1180, 20)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)


func _init_custom_panel() -> void:
	var confirm_btn: Button = custom_panel.get_node("VBox/ConfirmButton")
	var cancel_btn: Button = custom_panel.get_node("VBox/CancelButton")
	confirm_btn.pressed.connect(_on_custom_confirm)
	cancel_btn.pressed.connect(_on_custom_cancel)

	var stats_container: GridContainer = custom_panel.get_node("VBox/StatsContainer")
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
	for v in _custom_stats.values():
		used += int(v)
	var label: Label = custom_panel.get_node("VBox/PointsLabel")
	label.text = "剩余点数：%d / %d" % [TOTAL_POINTS - used, TOTAL_POINTS]
	label.add_theme_color_override("font_color", UIColors.DANGER_RED if used > TOTAL_POINTS else UIColors.TEXT_PRIMARY)


func _preview_major(major_id: String) -> void:
	_selected_id = major_id
	for id in _cards:
		_cards[id].set_selected(id == major_id)
	var major: MajorResource = Config.majors[major_id]
	footer_name.text = major.name
	footer_desc.text = major.description
	footer_skill.text = "主动：%s　被动：%s" % [
		str(major.active_skill.get("name", "")),
		str(major.passive_skill.get("name", "")),
	]


func _on_major_hovered(major_id: String) -> void:
	_preview_major(major_id)


func _on_major_selected(major_id: String) -> void:
	AudioManager.play_sfx("click")
	_preview_major(major_id)
	GameState.start_run(major_id)
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)


func _on_custom_pressed() -> void:
	AudioManager.play_sfx("click")
	custom_panel.visible = true


func _on_custom_cancel() -> void:
	AudioManager.play_sfx("click")
	custom_panel.visible = false


func _on_custom_confirm() -> void:
	AudioManager.play_sfx("click")
	var used := 0
	for v in _custom_stats.values():
		used += int(v)
	if used > TOTAL_POINTS:
		return

	var name_edit: LineEdit = custom_panel.get_node("VBox/NameEdit")
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
	custom_major.starter_deck = ["strike", "defend", "draw_card", "strike", "defend"]

	Config.majors[custom_major.id] = custom_major
	GameState.start_run(custom_major.id)
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MENU)


func _on_settings() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)
