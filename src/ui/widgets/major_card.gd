extends PanelContainer
## 专业选择卡：代表物、八维、双技能与选中态。

signal selected
signal hovered

@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var representative_frame: PanelContainer = $Margin/VBox/RepresentativeFrame
@onready var icon_label: Label = $Margin/VBox/RepresentativeFrame/IconLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var stats_container: VBoxContainer = $Margin/VBox/StatsContainer
@onready var skill_label: Label = $Margin/VBox/SkillLabel
@onready var select_button: Button = $Margin/VBox/SelectButton

var _major: MajorResource
var _selected := false

const MAJOR_ICONS := {
	"computer": "⌨",
	"law": "⚖",
	"medicine": "✚",
	"finance": "¥",
	"arts": "✦",
}

const MAJOR_COLORS := {
	"computer": Color("#79D66B"),
	"law": Color("#65AFFF"),
	"medicine": Color("#72DB91"),
	"finance": Color("#E8A838"),
	"arts": Color("#C985FF"),
}

const STAT_ORDER := ["学识", "体能", "专注", "表达", "创造", "社交", "抗压", "资源"]


func setup(major: MajorResource) -> void:
	_major = major
	if is_node_ready():
		_update_ui()


func set_selected(is_selected: bool) -> void:
	_selected = is_selected
	if is_instance_valid(select_button):
		select_button.text = "已选择" if _selected else "选择"
	_apply_border()


func _ready() -> void:
	select_button.pressed.connect(_on_select)
	mouse_entered.connect(func(): hovered.emit())
	gui_input.connect(_on_gui_input)
	if _major != null:
		_update_ui()
	_apply_border()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_select()


func _update_ui() -> void:
	name_label.text = _major.name
	icon_label.text = MAJOR_ICONS.get(_major.id, "●")
	icon_label.add_theme_color_override("font_color", MAJOR_COLORS.get(_major.id, UIColors.BORDER_CYAN))
	desc_label.text = _major.description
	var active_name: String = str(_major.active_skill.get("name", ""))
	var passive_name: String = str(_major.passive_skill.get("name", ""))
	skill_label.text = "主动·%s\n被动·%s" % [active_name, passive_name]

	for child in stats_container.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "八维属性"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", UIColors.BORDER_CYAN)
	stats_container.add_child(title)

	for stat_name in STAT_ORDER:
		stats_container.add_child(_make_stat_row(stat_name, int(_major.stats.get(stat_name, 5))))


func _make_stat_row(stat_name: String, value: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var name_l := Label.new()
	name_l.text = stat_name
	name_l.custom_minimum_size = Vector2(30, 0)
	name_l.add_theme_font_size_override("font_size", 11)
	row.add_child(name_l)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(48, 8)
	bar.max_value = 10
	bar.value = value
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = MAJOR_COLORS.get(_major.id, UIColors.SPIRIT_BLUE) if value >= 6 else UIColors.BORDER_CYAN_DIM
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.08, 1)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)

	var val := Label.new()
	val.text = str(value)
	val.custom_minimum_size = Vector2(12, 0)
	val.add_theme_font_size_override("font_size", 11)
	val.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	row.add_child(val)
	return row


func _apply_border() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.PANEL_SOLID if _selected else UIColors.PANEL
	style.set_border_width_all(3 if _selected else 2)
	style.border_color = UIColors.ACCENT_GOLD if _selected else UIColors.BORDER_CYAN
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	if not is_instance_valid(representative_frame):
		return
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.025, 0.07, 0.09, 0.92)
	icon_style.set_border_width_all(1)
	icon_style.border_color = MAJOR_COLORS.get(_major.id if _major != null else "", UIColors.BORDER_CYAN)
	icon_style.set_corner_radius_all(2)
	representative_frame.add_theme_stylebox_override("panel", icon_style)


func _on_select() -> void:
	selected.emit()
