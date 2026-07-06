extends PanelContainer
## 专业选择卡片。

signal selected

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var select_button: Button = $VBoxContainer/SelectButton


func setup(major: MajorResource) -> void:
	name_label.text = major.name
	desc_label.text = major.description

	var stats_text := ""
	for stat_name in major.stats:
		stats_text += "%s: %d\n" % [stat_name, major.stats[stat_name]]
	stats_label.text = stats_text.strip_edges()

	select_button.pressed.connect(_on_select)


func _on_select() -> void:
	selected.emit()
