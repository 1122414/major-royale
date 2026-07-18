extends Control
## 成就一览：按难度分组，解锁后可查看。

@onready var title_label: Label = $TitleLabel
@onready var tabs: HBoxContainer = $Tabs
@onready var list: VBoxContainer = $Scroll/List
@onready var detail: Label = $DetailPanel/DetailLabel
@onready var back_button: Button = $BackButton

var _current_diff: String = "easy"
const DIFFS := [
	{"id": "easy", "name": "简单"},
	{"id": "normal", "name": "普通"},
	{"id": "hard", "name": "困难"},
	{"id": "legendary", "name": "传说"},
]


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	for d in DIFFS:
		var btn := Button.new()
		btn.text = d.name
		btn.custom_minimum_size = Vector2(120, 40)
		btn.pressed.connect(_select_diff.bind(d.id))
		tabs.add_child(btn)
	_select_diff("easy")
	if tabs.get_child_count() > 0:
		(tabs.get_child(0) as Button).grab_focus()
	AudioManager.play_bgm_for_phase("menu")


func _select_diff(diff: String) -> void:
	_current_diff = diff
	for child in list.get_children():
		child.queue_free()
	detail.text = "点击成就查看详情"
	for a in Achievements.get_by_difficulty(diff):
		var unlocked: bool = Achievements.is_unlocked(a.id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.text = ("%s  ✓" if unlocked else "%s  锁定") % a.name
		btn.disabled = false
		btn.modulate = Color(1, 1, 1) if unlocked else Color(0.55, 0.55, 0.6)
		btn.pressed.connect(_show_detail.bind(a, unlocked))
		list.add_child(btn)


func _show_detail(a: Dictionary, unlocked: bool) -> void:
	AudioManager.play_sfx("click")
	if unlocked:
		detail.text = "【%s】%s\n难度：%s\n状态：已解锁" % [a.name, a.desc, _diff_name(a.difficulty)]
	else:
		detail.text = "【%s】%s\n难度：%s\n状态：未解锁（达成条件后自动点亮）" % [
			a.name, a.desc, _diff_name(a.difficulty)
		]


func _diff_name(diff: String) -> String:
	for d in DIFFS:
		if d.id == diff:
			return d.name
	return diff


func _on_back() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
