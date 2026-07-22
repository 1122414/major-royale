extends Control
## 中枢世界选择：只展示已发现且已具备完整入口的世界，不提前暴露空内容。

const WORLD_ORDER := ["campus", "version_loop"]


func _ready() -> void:
	_build_background()
	_build_selector()


func _build_background() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://assets/sprites/bg/version_loop_warmup.png" if MetaProgression.is_world_unlocked("version_loop") else "res://assets/sprites/bg/menu_campus.png"
	if ResourceLoader.exists(path):
		background.texture = load(path)
	background.modulate = Color(0.62, 0.68, 0.76, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.045, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_selector() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(150, 70)
	panel.size = Vector2(980, 580)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := Label.new()
	title.text = "中枢 · 选择世界"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UIColors.BORDER_CYAN_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var hint := Label.new()
	hint.text = "世界不是背景：每条入口都携带独立规则、资源与角色档案。"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	var entries := HBoxContainer.new()
	entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 20)
	entries.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(entries)
	for world_id in WORLD_ORDER:
		if not MetaProgression.is_world_unlocked(world_id):
			continue
		var world: Resource = Config.get_world(world_id)
		if world == null or not world.is_playable():
			continue
		entries.add_child(_make_world_card(world))
	if entries.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "中枢正在同步世界档案。"
		entries.add_child(empty)
	var back := Button.new()
	back.text = "返回中枢"
	back.custom_minimum_size = Vector2(190, 46)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): GameState.change_screen(GameState.Screen.MENU))
	column.add_child(back)


func _make_world_card(world: Resource) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(390, 350)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.11, 0.94)
	style.set_border_width_all(3 if world.id == GameState.current_world_id else 2)
	style.border_color = UIColors.ACCENT_GOLD if world.id == GameState.current_world_id else UIColors.BORDER_CYAN
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var name_label := Label.new()
	name_label.text = world.name
	name_label.add_theme_font_size_override("font_size", 27)
	name_label.add_theme_color_override("font_color", UIColors.ACCENT_GOLD if world.id == "version_loop" else UIColors.BORDER_CYAN_BRIGHT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var chapter := Label.new()
	chapter.text = world.chapter_title
	chapter.add_theme_font_size_override("font_size", 14)
	chapter.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(chapter)
	var description := Label.new()
	description.text = world.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 15)
	column.add_child(description)
	var fragment := Label.new()
	fragment.text = "规则碎片：%s" % (world.fragment_name if MetaProgression.has_fragment(world.fragment_id) else "未取得")
	fragment.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	column.add_child(fragment)
	var enter := Button.new()
	enter.text = "进入 %s ▶" % world.name
	enter.custom_minimum_size = Vector2(0, 48)
	enter.pressed.connect(_enter_world.bind(world.id))
	column.add_child(enter)
	return card


func _enter_world(world_id: String) -> void:
	AudioManager.play_sfx("click")
	GameState.current_world_id = world_id
	GameState.change_screen(GameState.Screen.MAJOR_SELECT)
