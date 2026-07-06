extends PanelContainer
## 卡牌视图控件。

signal card_clicked(card_index: int)

var card_index: int = -1

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var cost_label: Label = $VBoxContainer/CostLabel
@onready var type_label: Label = $VBoxContainer/TypeLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel


func setup(card: Resource, index: int) -> void:
	card_index = index
	name_label.text = card.name
	cost_label.text = "费用: %d" % card.cost
	type_label.text = _type_name(card.type)
	desc_label.text = card.description
	_update_color(card.type)

	gui_input.connect(_on_gui_input)


func _update_color(card_type: String) -> void:
	match card_type:
		"attack": modulate = Color(0.9, 0.5, 0.5)
		"defense": modulate = Color(0.5, 0.7, 0.9)
		"skill": modulate = Color(0.9, 0.9, 0.5)
		"control": modulate = Color(0.7, 0.5, 0.9)
		"heal": modulate = Color(0.5, 0.9, 0.5)
		"finisher": modulate = Color(0.9, 0.7, 0.3)
		_: modulate = Color.WHITE


func _type_name(card_type: String) -> String:
	match card_type:
		"attack": return "攻击"
		"defense": return "防御"
		"skill": return "技能"
		"control": return "控制"
		"heal": return "治疗"
		"finisher": return "终结"
	return card_type


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card_index)
