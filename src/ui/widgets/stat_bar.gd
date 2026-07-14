extends Control
class_name StatBar
## HP / 精神等双色进度条，带图标与数值文字。

enum BarKind { HP, SPIRIT, ENERGY, CUSTOM }

@export var kind: BarKind = BarKind.HP
@export var icon_text: String = "♥"
@export var label_prefix: String = ""
@export var bar_color: Color = Color("#E04545")
@export var max_value: float = 100.0 :
	set(v):
		max_value = maxf(v, 1.0)
		_refresh()
@export var value: float = 100.0 :
	set(v):
		value = clampf(v, 0.0, max_value)
		_refresh()

var _icon: Label
var _bar: ProgressBar
var _text: Label


func _ready() -> void:
	custom_minimum_size = Vector2(180, 28)
	_build()
	_apply_kind_defaults()
	_refresh()


func _build() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_icon = Label.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_icon)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 2)
	row.add_child(stack)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.max_value = 100
	_bar.show_percentage = false
	_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	stack.add_child(_bar)

	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 12)
	_text.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	stack.add_child(_text)


func _apply_kind_defaults() -> void:
	match kind:
		BarKind.HP:
			icon_text = "♥"
			bar_color = UIColors.DANGER_RED
			label_prefix = ""
		BarKind.SPIRIT:
			icon_text = "◆"
			bar_color = UIColors.SPIRIT_BLUE
			label_prefix = "精神 "
		BarKind.ENERGY:
			icon_text = "⚡"
			bar_color = UIColors.ACCENT_GOLD
			label_prefix = "能量 "
		_:
			pass


func set_values(current: float, maximum: float) -> void:
	max_value = maximum
	value = current


func _refresh() -> void:
	if _icon == null:
		return
	_icon.text = icon_text
	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_color
	_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.08, 1)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = UIColors.BORDER_CYAN_DIM
	_bar.add_theme_stylebox_override("background", bg)
	_bar.max_value = max_value
	_bar.value = value
	_text.text = "%s%d/%d" % [label_prefix, int(value), int(max_value)]
