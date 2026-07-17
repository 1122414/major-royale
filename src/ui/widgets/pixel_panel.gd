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
	theme_type_variation = &"PanelGold" if use_gold_border else &""
