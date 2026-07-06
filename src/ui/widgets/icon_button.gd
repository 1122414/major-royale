extends Button
## 图标按钮（如设置图标）。

@export var icon_text: String = "⚙" :
	set(value):
		icon_text = value
		if is_node_ready() and icon_label:
			icon_label.text = icon_text

@onready var icon_label: Label = $IconLabel


func _ready() -> void:
	icon_label.text = icon_text
