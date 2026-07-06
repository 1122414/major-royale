extends PanelContainer
## 卡牌视图控件。

signal card_clicked(card_index: int)

var card_index: int = -1

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var cost_label: Label = $VBoxContainer/CostLabel
@onready var type_label: Label = $VBoxContainer/TypeLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel

const TYPE_COLORS := {
	"attack": Color(0.95, 0.35, 0.35),
	"defense": Color(0.35, 0.65, 0.95),
	"skill": Color(0.95, 0.85, 0.35),
	"control": Color(0.75, 0.45, 0.95),
	"heal": Color(0.35, 0.95, 0.45),
	"finisher": Color(0.95, 0.65, 0.25),
}


func setup(card: Resource, index: int) -> void:
	card_index = index
	name_label.text = card.name
	cost_label.text = "%d" % card.cost
	type_label.text = _type_name(card.type)
	desc_label.text = card.description
	modulate = TYPE_COLORS.get(card.type, Color.WHITE)

	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)


func _on_hover() -> void:
	scale = Vector2(1.08, 1.08)


func _on_unhover() -> void:
	scale = Vector2(1, 1)


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
