extends PanelContainer
## 专业选择卡片。

signal selected

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var icon_label: Label = $VBoxContainer/IconLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var stats_container: GridContainer = $VBoxContainer/StatsContainer
@onready var skill_label: Label = $VBoxContainer/SkillLabel
@onready var select_button: Button = $VBoxContainer/SelectButton

var _major: MajorResource

const STAT_ICONS := {
	"学识": "🧠", "体能": "💪", "专注": "🎯", "表达": "🗣",
	"创造": "💡", "社交": "🤝", "抗压": "🛡", "资源": "💰"
}
const MAJOR_ICONS := {
	"computer": "💻", "law": "⚖", "medicine": "🏥"
}


func setup(major: MajorResource) -> void:
	_major = major
	if is_node_ready():
		_update_ui()


func _ready() -> void:
	select_button.pressed.connect(_on_select)
	if _major != null:
		_update_ui()


func _update_ui() -> void:
	name_label.text = _major.name
	icon_label.text = MAJOR_ICONS.get(_major.id, "🎓")
	desc_label.text = _major.description
	skill_label.text = "技能：%s / %s" % [_major.active_skill.get("name", ""), _major.passive_skill.get("name", "")]

	for child in stats_container.get_children():
		child.queue_free()

	for stat_name in _major.stats:
		var hbox := HBoxContainer.new()
		var icon := Label.new()
		icon.text = STAT_ICONS.get(stat_name, "•")
		var label := Label.new()
		label.text = "%s %d" % [stat_name, _major.stats[stat_name]]
		hbox.add_child(icon)
		hbox.add_child(label)
		stats_container.add_child(hbox)


func _on_select() -> void:
	selected.emit()
