extends PanelContainer
## 状态图标控件。

@onready var label: Label = $Label


func setup(status_id: String, stacks: int) -> void:
	var info := Status.get_status_info(status_id)
	var display_name: String = info.get("name", status_id)
	if stacks > 1:
		label.text = "%s x%d" % [display_name, stacks]
	else:
		label.text = display_name

	if info.get("is_debuff", false):
		modulate = Color(1.0, 0.6, 0.6)
	else:
		modulate = Color(0.6, 1.0, 0.6)
