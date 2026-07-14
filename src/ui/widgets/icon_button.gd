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
	icon_label.text = icon_text
	_apply_style()


func _apply_style() -> void:
	var normal := _make_style(UIColors.PANEL, UIColors.BORDER_CYAN)
	var hover := _make_style(UIColors.HOVER_FILL, UIColors.BORDER_CYAN)
	var pressed := _make_style(UIColors.PRESSED_FILL, UIColors.ACCENT_GOLD)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", pressed)
	icon_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	icon_label.add_theme_font_size_override("font_size", 22)


func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	return style
