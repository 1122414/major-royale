extends PanelContainer
## 卡牌视图：费用圆标 + 类型色带 + icon + 描述。

signal card_clicked(card_index: int)
signal card_rejected(card_index: int)

var card_index: int = -1
var _card: Resource = null

@onready var cost_label: Label = $Margin/VBox/TopRow/CostBadge/CostLabel
@onready var name_label: Label = $Margin/VBox/TopRow/NameLabel
@onready var icon_label: Label = $Margin/VBox/IconLabel
@onready var type_label: Label = $Margin/VBox/TypeLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var major_label: Label = $Margin/VBox/MetaRow/MajorLabel
@onready var rarity_label: Label = $Margin/VBox/MetaRow/RarityLabel

var _affordable := true
var _play_cost := -1
var _hover_tween: Tween

var _type_colors := {
	"attack": UIColors.CARD_ATTACK,
	"defense": UIColors.CARD_DEFENSE,
	"skill": UIColors.CARD_SKILL,
	"control": UIColors.CARD_CONTROL,
	"heal": UIColors.CARD_HEAL,
	"finisher": UIColors.CARD_FINISHER,
}

const TYPE_ICONS := {
	"attack": "⚔",
	"defense": "🛡",
	"skill": "✦",
	"control": "◎",
	"heal": "+",
	"finisher": "◆",
}

const MAJOR_NAMES := {
	"computer": "计算机",
	"law": "法学",
	"medicine": "医学",
	"finance": "金融",
	"arts": "艺术",
}

const MAJOR_COLORS := {
	"computer": Color("#6DF7FF"),
	"law": Color("#75B9FF"),
	"medicine": Color("#72E39B"),
	"finance": Color("#FFD36A"),
	"arts": Color("#C78BFF"),
}

const RARITY_NAMES := {
	"common": "普通",
	"uncommon": "进阶",
	"rare": "稀有",
}

const RARITY_COLORS := {
	"common": Color("#8A9AA8"),
	"uncommon": Color("#E8A838"),
	"rare": Color("#B67CFF"),
}

const MAJOR_FALLBACK_ART := {
	"computer": "bug_generate",
	"law": "law_search",
	"medicine": "triage",
	"finance": "compound",
	"arts": "muse",
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
	_animate_draw()


func set_affordable(value: bool) -> void:
	_affordable = value
	if is_node_ready():
		_apply_affordability()


func set_play_cost(value: int) -> void:
	_play_cost = value
	if is_node_ready() and _card != null:
		cost_label.text = str(_play_cost)


func _refresh() -> void:
	if _card == null:
		return
	name_label.text = _card.name
	cost_label.text = str(_play_cost if _play_cost >= 0 else _card.cost)
	type_label.text = "— %s —" % _type_name(_card.type)
	desc_label.text = _effective_description(_card)
	var major_id := str(_card.major_id)
	major_label.text = MAJOR_NAMES.get(major_id, "通用")
	major_label.add_theme_color_override("font_color", MAJOR_COLORS.get(major_id, UIColors.TEXT_MUTED))
	var rarity := str(_card.rarity)
	rarity_label.text = RARITY_NAMES.get(rarity, rarity)
	rarity_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, UIColors.TEXT_MUTED))
	icon_label.text = ""
	_apply_frame(_frame_color(str(_card.type), rarity))
	_apply_card_icon(str(_card.id), str(_card.type), major_id)
	_apply_affordability()


func _apply_card_icon(card_id: String, card_type: String, major_id: String) -> void:
	var path := "res://assets/sprites/cards/%s.png" % card_id
	if not ResourceLoader.exists(path) and MAJOR_FALLBACK_ART.has(major_id):
		path = "res://assets/sprites/cards/%s.png" % MAJOR_FALLBACK_ART[major_id]
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/cards/%s.png" % card_type
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
	var cost_style := StyleBoxFlat.new()
	cost_style.bg_color = Color(0.02, 0.06, 0.08, 0.96)
	cost_style.set_border_width_all(2)
	cost_style.border_color = accent
	cost_style.set_corner_radius_all(3)
	$Margin/VBox/TopRow/CostBadge.add_theme_stylebox_override("panel", cost_style)


func _frame_color(card_type: String, rarity: String) -> Color:
	if rarity == "rare":
		return RARITY_COLORS.rare
	if rarity == "uncommon":
		return RARITY_COLORS.uncommon
	return _type_colors.get(card_type, UIColors.BORDER_CYAN)


func _effective_description(card: Resource) -> String:
	var description := str(card.description)
	var total_base_damage := 0
	for effect in card.effects:
		if str(effect.type) == "damage":
			total_base_damage += int(effect.value)
	if total_base_damage <= 0 or GameState.player_major_id.is_empty():
		return description
	var knowledge_bonus := int(GameState.get_effective_stat("学识") / 3)
	var hit_count := 0
	for effect in card.effects:
		if str(effect.type) == "damage":
			hit_count += 1
	var expected := total_base_damage + knowledge_bonus * hit_count
	return "%s\n本局预估：%d 伤害" % [description, expected]


func _apply_affordability() -> void:
	if _affordable:
		modulate = Color.WHITE
		cost_label.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
		tooltip_text = "点击打出"
	else:
		modulate = Color(0.52, 0.55, 0.58, 0.88)
		cost_label.add_theme_color_override("font_color", UIColors.DANGER_RED)
		tooltip_text = "能量不足"


func _animate_draw() -> void:
	modulate.a = 0.0
	pivot_offset = size * 0.5
	scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_hover() -> void:
	pivot_offset = size * 0.5
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.08).set_trans(Tween.TRANS_BACK)
	z_index = 12


func _on_unhover() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	z_index = 0


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
		if _affordable:
			card_clicked.emit(card_index)
		else:
			_play_rejected_feedback()
			card_rejected.emit(card_index)


func _play_rejected_feedback() -> void:
	var base := position
	var tween := create_tween()
	tween.tween_property(self, "position", base + Vector2(-5, 0), 0.035)
	tween.tween_property(self, "position", base + Vector2(5, 0), 0.035)
	tween.tween_property(self, "position", base, 0.05)
