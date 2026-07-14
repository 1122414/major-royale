extends PanelContainer
class_name PixelPanel
## 半透明深青面板，青色霓虹边框。

@export var use_gold_border: bool = false :
	set(value):
		use_gold_border = value
		_apply_style()


func _ready() -> void:
	_apply_style()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.PANEL
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = UIColors.ACCENT_GOLD if use_gold_border else UIColors.BORDER_CYAN
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
