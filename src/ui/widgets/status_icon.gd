extends PanelContainer
## 状态图标：显示效果摘要，悬停展示完整解析。

@onready var label: Label = $Label

var _status_id: String = ""
var _stacks: int = 0
var _tooltip_panel: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_label()


func setup(status_id: String, stacks: int) -> void:
	_status_id = status_id
	_stacks = stacks
	_apply_label()


func _apply_label() -> void:
	if label == null:
		return
	var info := Status.get_status_info(_status_id)
	var display_name: String = str(info.get("name", _status_id))
	var effect_short: String = _short_effect(info)
	if _stacks > 1:
		label.text = "%s×%d\n%s" % [display_name, _stacks, effect_short]
	else:
		label.text = "%s\n%s" % [display_name, effect_short]

	if info.get("is_debuff", false):
		modulate = Color(1.0, 0.72, 0.72)
	else:
		modulate = Color(0.72, 1.0, 0.78)
	tooltip_text = _full_tooltip(info)


func _short_effect(info: Dictionary) -> String:
	var desc: String = str(info.get("description", "")).strip_edges()
	if desc == "":
		return "效果未知"
	# 首句摘要，避免按钮过长
	var cut := desc
	if "。" in desc:
		cut = desc.split("。")[0]
	if cut.length() > 14:
		cut = cut.substr(0, 14) + "…"
	return cut


func _full_tooltip(info: Dictionary) -> String:
	var display_name: String = str(info.get("name", _status_id))
	var desc: String = str(info.get("description", "暂无说明"))
	var kind: String = "减益" if info.get("is_debuff", false) else "增益"
	var stack_line := "层数：%d" % _stacks if _stacks > 1 else ""
	return ("%s（%s）\n%s\n%s" % [display_name, kind, desc, stack_line]).strip_edges()


func _on_mouse_entered() -> void:
	_show_floating_tip()


func _on_mouse_exited() -> void:
	_hide_floating_tip()


func _show_floating_tip() -> void:
	_hide_floating_tip()
	var info := Status.get_status_info(_status_id)
	var tip := Label.new()
	tip.text = _full_tooltip(info)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(220, 0)
	tip.add_theme_font_size_override("font_size", 13)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.z_index = 64
	_tooltip_panel.add_child(tip)
	# 挂到场景根，避免被父容器裁剪
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(_tooltip_panel)
	var global_pos := get_global_rect().position
	_tooltip_panel.global_position = global_pos + Vector2(0, size.y + 4)


func _hide_floating_tip() -> void:
	if _tooltip_panel != null and is_instance_valid(_tooltip_panel):
		_tooltip_panel.queue_free()
	_tooltip_panel = null


func _exit_tree() -> void:
	_hide_floating_tip()
