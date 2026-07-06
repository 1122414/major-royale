extends Control
## 专业选择界面。

const MAJOR_CARD_SCENE := preload("res://src/ui/widgets/major_card.tscn")

@onready var title_label: Label = $TitleLabel
@onready var cards_container: HBoxContainer = $CardsContainer
@onready var back_button: Button = $BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_populate_major_cards()


func _populate_major_cards() -> void:
	for major_id in Config.majors:
		var major: MajorResource = Config.majors[major_id]
		var card: Control = MAJOR_CARD_SCENE.instantiate()
		card.setup(major)
		card.selected.connect(_on_major_selected.bind(major_id))
		cards_container.add_child(card)


func _on_major_selected(major_id: String) -> void:
	GameState.start_run(major_id)
	GameState.change_screen(GameState.Screen.MAP_EXPLORE)


func _on_back_pressed() -> void:
	GameState.change_screen(GameState.Screen.MENU)
