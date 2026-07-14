extends PanelContainer
## 卡牌视图：费用圆标 + 类型色带 + icon + 描述。

signal card_clicked(card_index: int)

var card_index: int = -1
var _card: Resource = null

@onready var cost_label: Label = $Margin/VBox/TopRow/CostBadge/CostLabel
@onready var name_label: Label = $Margin/VBox/TopRow/NameLabel
@onready var icon_label: Label = $Margin/VBox/IconLabel
@onready var type_label: Label = $Margin/VBox/TypeLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel

const TYPE_COLORS := {
	"attack": Color("#C94A4A"),
	"defense": Color("#2E8B8B"),
	"skill": Color("#3A7CC9"),
	"control": Color("#8B5FBF"),
	"heal": Color("#3A9B5C"),
	"finisher": Color("#E8A838"),
}

const TYPE_ICONS := {
	"attack": "⚔",
	"defense": "🛡",
	"skill": "✦",
	"control": "◎",
	"heal": "+",
	"finisher": "◆",
}


func setup(card: Resource, index: int) -> void:
	card_index = index
	_card = card
	if is_node_ready():
		_refresh()
	else:
		ready.connect(_refresh, CONNECT_ONE_SHOT)


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	if _card != null:
		_refresh()


func _refresh() -> void:
	if _card == null:
		return
	name_label.text = _card.name
	cost_label.text = str(_card.cost)
	type_label.text = _type_name(_card.type)
	desc_label.text = _card.description
	icon_label.text = ""
	_apply_frame(TYPE_COLORS.get(_card.type, UIColors.BORDER_CYAN))
	_apply_card_icon(str(_card.type))


func _apply_card_icon(card_type: String) -> void:
	var path := "res://assets/sprites/cards/%s.png" % card_type
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/cards/skill.png"
	if ResourceLoader.exists(path):
		# Replace label with texture if possible
		var parent := icon_label.get_parent()
		var existing := parent.get_node_or_null("IconTex")
		if existing == null:
			existing = TextureRect.new()
			existing.name = "IconTex"
			existing.custom_minimum_size = Vector2(64, 64)
			existing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			existing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			existing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			parent.add_child(existing)
			parent.move_child(existing, icon_label.get_index())
		existing.texture = load(path)
		icon_label.visible = false
	else:
		icon_label.text = TYPE_ICONS.get(card_type, "●")
		icon_label.visible = true


func _apply_frame(accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.PANEL
	style.set_border_width_all(2)
	style.border_color = accent
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	type_label.add_theme_color_override("font_color", accent)
	icon_label.add_theme_color_override("font_color", accent)


func _on_hover() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(1.06, 1.06)


func _on_unhover() -> void:
	scale = Vector2.ONE


func _type_name(card_type: String) -> String:
	match card_type:
		"attack": return "攻击"
		"defense": return "防御"
		"skill": return "技能"
		"control": return "控制"
		"heal": return "治疗"
		"finisher": return "终结"
	return card_type


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card_index)
