extends Button
## 赛博边框图标按钮（设置 / 地图 / 背包等）。

@export var icon_text: String = "⚙" :
	set(value):
		icon_text = value
		if is_node_ready() and icon_label:
			icon_label.text = icon_text

@onready var icon_label: Label = $IconLabel


func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_label.text = icon_text
	icon_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	icon_label.add_theme_font_size_override("font_size", 22)
