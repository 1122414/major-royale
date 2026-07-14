extends Control
## 地图探索：固定路线逐步前进 + 玩法说明 HUD。

const MAP_NODE_SCENE := preload("res://src/ui/widgets/map_node.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")
const STAT_BAR_SCENE := preload("res://src/ui/widgets/stat_bar.tscn")
const MINIMAP_SCENE := preload("res://src/ui/widgets/pressure_minimap.tscn")

@onready var area_label: Label = $TopHud/LeftStats/AreaLabel
@onready var day_label: Label = $TopHud/DayBadge/DayLabel
@onready var resource_label: Label = $TopHud/RightStats/ResourceLabel
@onready var howto_label: Label = $HowToPanel/HowToBody
@onready var objective_label: Label = $ObjectivePanel/VBox/ObjectiveBody
@onready var info_label: Label = $BottomBar/InfoLabel
@onready var nodes_container: Control = $PathPanel/NodesContainer
@onready var advance_button: Button = $AdvanceButton
@onready var next_preview: Label = $NextPreview
@onready var event_popup: PanelContainer = $EventPopup
@onready var event_title: Label = $EventPopup/VBoxContainer/EventTitle
@onready var event_desc: Label = $EventPopup/VBoxContainer/EventDesc
@onready var event_buttons: VBoxContainer = $EventPopup/VBoxContainer/EventButtons
@onready var minimap_slot: Control = $TopHud/LeftStats/MinimapSlot

var _game_map: GameMap
var _rng := RandomNumberGenerator.new()
var _current_event: EventResource = null
var _hp_bar: StatBar
var _spirit_bar: StatBar
var _minimap: PressureMinimap
var _node_buttons: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
	_game_map = GameMap.new()
	if GameState.map_seed == 0:
		GameState.map_seed = hash(GameState.player_major_id) + Time.get_unix_time_from_system()
	_rng.seed = GameState.map_seed
	_game_map.generate(GameState.map_seed)
	_game_map.restore_progress(GameState.map_path_index)

	_hp_bar = STAT_BAR_SCENE.instantiate()
	_hp_bar.kind = StatBar.BarKind.HP
	$TopHud/LeftStats/Bars.add_child(_hp_bar)

	_spirit_bar = STAT_BAR_SCENE.instantiate()
	_spirit_bar.kind = StatBar.BarKind.SPIRIT
	$TopHud/LeftStats/Bars.add_child(_spirit_bar)

	_minimap = MINIMAP_SCENE.instantiate()
	_minimap.custom_minimum_size = Vector2(100, 100)
	minimap_slot.add_child(_minimap)

	advance_button.pressed.connect(_on_advance_pressed)
	_style_advance_button()

	_render_map()
	_update_ui()

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1210, 16)
	settings_btn.pressed.connect(_on_settings_pressed)
	add_child(settings_btn)

	event_popup.visible = false


func _style_advance_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.12, 0.04, 0.95)
	style.set_border_width_all(3)
	style.border_color = UIColors.ACCENT_GOLD
	style.set_corner_radius_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	advance_button.add_theme_stylebox_override("normal", style)
	advance_button.add_theme_stylebox_override("hover", style)
	advance_button.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	advance_button.add_theme_font_size_override("font_size", 22)


func _render_map() -> void:
	for child in nodes_container.get_children():
		child.queue_free()
	_node_buttons.clear()

	for i in _game_map.path_order.size():
		var node_id: String = _game_map.path_order[i]
		var node: GameMap.MapNode = _game_map.nodes[node_id]
		if i + 1 < _game_map.path_order.size():
			var next: GameMap.MapNode = _game_map.nodes[_game_map.path_order[i + 1]]
			_draw_connection(node.position, next.position)

	for node_id in _game_map.path_order:
		var node: GameMap.MapNode = _game_map.nodes[node_id]
		var btn: Button = MAP_NODE_SCENE.instantiate()
		nodes_container.add_child(btn)
		var is_current := node_id == _game_map.current_node_id
		btn.setup(node_id, node.type, _game_map.get_area_color(node.area_index), node.visited, node.available)
		if is_current:
			btn.modulate = UIColors.ACCENT_GOLD
		btn.position = node.position - Vector2(28, 28)
		btn.node_selected.connect(_on_node_selected)
		_node_buttons[node_id] = btn


func _refresh_node_buttons() -> void:
	for node_id in _node_buttons:
		var node: GameMap.MapNode = _game_map.nodes[node_id]
		var btn: Button = _node_buttons[node_id]
		btn.setup(node_id, node.type, _game_map.get_area_color(node.area_index), node.visited, node.available)
		if node_id == _game_map.current_node_id:
			btn.modulate = UIColors.ACCENT_GOLD


func _draw_connection(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 4
	line.default_color = Color(UIColors.BORDER_CYAN.r, UIColors.BORDER_CYAN.g, UIColors.BORDER_CYAN.b, 0.55)
	nodes_container.add_child(line)


func _on_advance_pressed() -> void:
	if _busy:
		return
	AudioManager.play_sfx("click")
	_advance_and_resolve()


func _on_node_selected(node_id: String) -> void:
	if _busy:
		return
	# 仅允许点击「下一站」
	if node_id != _game_map.get_next_node_id():
		info_label.text = "这是固定路线：请点击金色「前进」或高亮的下一站。"
		return
	AudioManager.play_sfx("click")
	_advance_and_resolve()


func _advance_and_resolve() -> void:
	var node: GameMap.MapNode = _game_map.advance()
	if node == null:
		info_label.text = "已经到达路线尽头。"
		advance_button.disabled = true
		return

	_busy = true
	_refresh_node_buttons()
	_update_ui()

	match node.type:
		GameMap.NodeType.BATTLE, GameMap.NodeType.ELITE, GameMap.NodeType.BOSS:
			GameState.player_stats["current_enemy_id"] = node.data_id
			GameState.run_progress += 1
			GameState.day_count = maxi(GameState.day_count, 1 + int(node.path_index / 3))
			GameState.change_screen(GameState.Screen.BATTLE)
		GameMap.NodeType.EVENT:
			_trigger_event(node.area_index)
			_busy = false
		GameMap.NodeType.REST:
			_trigger_rest()
			_busy = false
		GameMap.NodeType.REWARD:
			GameState.change_screen(GameState.Screen.REWARD)


func _trigger_event(area_index: int) -> void:
	var area_id: String = GameMap.AREAS[area_index].id
	_current_event = EventHandler.pick_random_event(area_id, _rng)
	if _current_event == null:
		info_label.text = "这里什么都没有，可继续前进。"
		return

	event_title.text = _current_event.name
	event_desc.text = _current_event.description

	for child in event_buttons.get_children():
		child.queue_free()

	if _current_event.choices.is_empty():
		var btn := Button.new()
		btn.text = "确定"
		btn.pressed.connect(_resolve_event.bind(-1))
		event_buttons.add_child(btn)
	else:
		for i in _current_event.choices.size():
			var choice := _current_event.choices[i]
			var btn := Button.new()
			btn.text = choice.get("text", "选择")
			btn.pressed.connect(_resolve_event.bind(i))
			event_buttons.add_child(btn)

	event_popup.visible = true


func _resolve_event(choice_index: int) -> void:
	AudioManager.play_sfx("click")
	if _current_event == null:
		return
	var handler := EventHandler.new(GameState.player_stats)
	var message := handler.apply_event(_current_event, choice_index)
	info_label.text = message + "　→ 可继续点「前进」。"
	event_popup.visible = false
	_current_event = null
	_update_ui()


func _trigger_rest() -> void:
	AudioManager.play_sfx("heal")
	var handler := EventHandler.new(GameState.player_stats)
	info_label.text = handler.apply_rest() + "　→ 可继续点「前进」。"
	_update_ui()


func _update_ui() -> void:
	var node: GameMap.MapNode = _game_map.get_current_node()
	if node == null:
		return
	_refresh_node_buttons()
	area_label.text = "当前区域：%s" % _game_map.get_area_name(node.area_index)
	day_label.text = "第%d天 · 进度 %s" % [GameState.day_count, _game_map.get_progress_text()]
	resource_label.text = "学分 %d　信用点 %d　压力 %d" % [
		GameState.credits, GameState.credit_points, GameState.run_progress
	]

	howto_label.text = "怎么玩：路线是固定的，从左到右一站接一站。\n1) 点金色「前进」进入下一站\n2) ⚔战斗 ※精英　?事件　♥补给　★奖励　♛终局\n3) 打赢拿卡构筑，压力越高敌人越狠\n4) 走到操场挑战「就业压力」通关"

	var next_n := _game_map.get_next_node()
	if next_n == null:
		advance_button.text = "路线已走完"
		advance_button.disabled = true
		next_preview.text = "下一站：无（已到终点）"
		info_label.text = "当前：%s | %s" % [GameMap.node_type_name(node.type), _game_map.get_area_name(node.area_index)]
	else:
		var next_name := GameMap.node_type_name(next_n.type)
		var next_area := _game_map.get_area_name(next_n.area_index)
		advance_button.text = "▶ 前进：%s（%s）" % [next_name, next_area]
		advance_button.disabled = false
		next_preview.text = "下一站预告：%s · %s" % [next_area, next_name]
		info_label.text = "当前站：%s | %s　|　点击「前进」继续" % [
			GameMap.node_type_name(node.type), _game_map.get_area_name(node.area_index)
		]

	if _hp_bar:
		_hp_bar.set_values(GameState.run_hp, GameState.run_max_hp)
	if _spirit_bar:
		_spirit_bar.set_values(GameState.run_spirit, GameState.run_max_spirit)
	if _minimap:
		_minimap.refresh()

	objective_label.text = "主线：沿路线推进到操场终局答辩\n当前：%s\n压力圈：%d（每点提升敌伤，上限+40%%）" % [
		_game_map.get_area_name(node.area_index), GameState.run_progress
	]


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)
