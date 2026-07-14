extends Control
## 专业选择：三列专业卡 + 底栏描述（无自定义专业主路径）。

const MAJOR_CARD_SCENE := preload("res://src/ui/widgets/major_card.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

@onready var title_label: Label = $Header/TitleLabel
@onready var cards_container: HBoxContainer = $CardsContainer
@onready var back_button: Button = $Header/BackButton
@onready var footer_name: Label = $Footer/FooterPanel/HBox/InfoCol/NameLabel
@onready var footer_desc: Label = $Footer/FooterPanel/HBox/InfoCol/DescLabel
@onready var footer_skill: Label = $Footer/FooterPanel/HBox/InfoCol/SkillLabel

var _cards: Dictionary = {}
var _selected_id: String = ""


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

	# 固定顺序：计算机 / 法学 / 医学
	for major_id in ["computer", "law", "medicine"]:
		if not Config.majors.has(major_id):
			continue
		var major: MajorResource = Config.majors[major_id]
		var card: Control = MAJOR_CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.setup(major)
		card.selected.connect(_on_major_selected.bind(major_id))
		card.hovered.connect(_on_major_hovered.bind(major_id))
		_cards[major_id] = card

	if Config.majors.has("computer"):
		_preview_major("computer")

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1180, 20)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)


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


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MENU)


func _on_settings() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)
