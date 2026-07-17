extends PanelContainer
## 状态图标：显示效果摘要，悬停展示完整解析。

@onready var label: Label = $Label

var _status_id: String = ""
var _stacks: int = 0
var _tooltip_panel: PanelContainer

const STATUS_SYMBOLS := {
	"bug": "◇",
	"举证失败": "×",
	"vulnerable": "!",
	"bleed": "♥",
	"pressure": "●",
	"shield": "◆",
	"resistance": "▣",
	"adrenaline": "↑",
	"counter": "↶",
	"charged": "⚡",
}


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
	var symbol: String = STATUS_SYMBOLS.get(_status_id, "•")
	if _stacks > 1:
		label.text = "%s %s×%d\n%s" % [symbol, display_name, _stacks, effect_short]
	else:
		label.text = "%s %s\n%s" % [symbol, display_name, effect_short]

	var accent := UIColors.DANGER_RED if info.get("is_debuff", false) else UIColors.SUCCESS_GREEN
	label.add_theme_color_override("font_color", accent)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.067, 0.94)
	style.set_border_width_all(1)
	style.border_color = accent
	style.set_corner_radius_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
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
	var desired := global_pos + Vector2(0, size.y + 4)
	var viewport_size := get_viewport_rect().size
	desired.x = clampf(desired.x, 8.0, maxf(8.0, viewport_size.x - 230.0))
	desired.y = minf(desired.y, viewport_size.y - 100.0)
	_tooltip_panel.global_position = desired


func _hide_floating_tip() -> void:
	if _tooltip_panel != null and is_instance_valid(_tooltip_panel):
		_tooltip_panel.queue_free()
	_tooltip_panel = null


func _exit_tree() -> void:
	_hide_floating_tip()
