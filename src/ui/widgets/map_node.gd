extends Button
## 地图节点控件。

signal node_selected(node_id: String)

var node_id: String = ""
var node_type: int = 0
var area_color: Color = Color.WHITE
var is_visited: bool = false
var is_available: bool = false

@onready var icon_label: Label = $IconLabel


func setup(p_node_id: String, p_type: int, p_color: Color, p_visited: bool, p_available: bool) -> void:
	node_id = p_node_id
	node_type = p_type
	area_color = p_color
	is_visited = p_visited
	is_available = p_available
	if is_node_ready():
		_update_appearance()


func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_appearance()


func _update_appearance() -> void:
	match node_type:
		GameMap.NodeType.BATTLE: icon_label.text = "⚔"
		GameMap.NodeType.EVENT: icon_label.text = "?"
		GameMap.NodeType.REST: icon_label.text = "♥"
		GameMap.NodeType.REWARD: icon_label.text = "★"
		GameMap.NodeType.ELITE: icon_label.text = "👹"
		GameMap.NodeType.BOSS: icon_label.text = "👑"

	modulate = area_color
	disabled = not is_available

	if is_visited:
		modulate = modulate.darkened(0.3)


func _on_pressed() -> void:
	if is_available and not is_visited:
		node_selected.emit(node_id)
