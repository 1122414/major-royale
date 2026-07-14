extends Control
## 地图探索：顶栏 HUD、压力圈小地图、目标面板、底栏提示。

const MAP_NODE_SCENE := preload("res://src/ui/widgets/map_node.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")
const STAT_BAR_SCENE := preload("res://src/ui/widgets/stat_bar.tscn")
const MINIMAP_SCENE := preload("res://src/ui/widgets/pressure_minimap.tscn")

@onready var area_label: Label = $TopHud/LeftStats/AreaLabel
@onready var day_label: Label = $TopHud/CenterDay/DayLabel
@onready var resource_label: Label = $TopHud/RightStats/ResourceLabel
@onready var objective_label: Label = $ObjectivePanel/VBox/ObjectiveBody
@onready var info_label: Label = $BottomBar/InfoLabel
@onready var nodes_container: Control = $NodesContainer
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


func _ready() -> void:
	_game_map = GameMap.new()
	_rng.seed = hash(GameState.player_major_id) + Time.get_unix_time_from_system()
	_game_map.generate(_rng.seed)

	_hp_bar = STAT_BAR_SCENE.instantiate()
	_hp_bar.kind = StatBar.BarKind.HP
	$TopHud/LeftStats/Bars.add_child(_hp_bar)

	_spirit_bar = STAT_BAR_SCENE.instantiate()
	_spirit_bar.kind = StatBar.BarKind.SPIRIT
	$TopHud/LeftStats/Bars.add_child(_spirit_bar)

	_minimap = MINIMAP_SCENE.instantiate()
	minimap_slot.add_child(_minimap)

	_render_map()
	_update_ui()

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1180, 20)
	settings_btn.pressed.connect(_on_settings_pressed)
	add_child(settings_btn)

	event_popup.visible = false


func _render_map() -> void:
	for child in nodes_container.get_children():
		child.queue_free()
	_node_buttons.clear()

	for node_id in _game_map.nodes:
		var node: GameMap.MapNode = _game_map.nodes[node_id]
		for next_id in node.connections:
			if _game_map.nodes.has(next_id):
				_draw_connection(node.position, _game_map.nodes[next_id].position)

	for node_id in _game_map.nodes:
		var node: GameMap.MapNode = _game_map.nodes[node_id]
		var btn: Button = MAP_NODE_SCENE.instantiate()
		nodes_container.add_child(btn)
		btn.setup(node_id, node.type, _game_map.get_area_color(node.area_index), node.visited, node.available)
		btn.position = node.position - Vector2(28, 28)
		btn.node_selected.connect(_on_node_selected)
		_node_buttons[node_id] = btn


func _refresh_node_buttons() -> void:
	for node_id in _node_buttons:
		var node: GameMap.MapNode = _game_map.nodes[node_id]
		var btn: Button = _node_buttons[node_id]
		btn.setup(node_id, node.type, _game_map.get_area_color(node.area_index), node.visited, node.available)


func _draw_connection(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 3
	line.default_color = Color(UIColors.BORDER_CYAN_DIM.r, UIColors.BORDER_CYAN_DIM.g, UIColors.BORDER_CYAN_DIM.b, 0.7)
	nodes_container.add_child(line)


func _on_node_selected(node_id: String) -> void:
	AudioManager.play_sfx("click")
	_game_map.move_to(node_id)
	var node: GameMap.MapNode = _game_map.get_current_node()
	_refresh_node_buttons()
	_update_ui()

	match node.type:
		GameMap.NodeType.BATTLE, GameMap.NodeType.ELITE, GameMap.NodeType.BOSS:
			GameState.player_stats["current_enemy_id"] = node.data_id
			GameState.run_progress += 1
			GameState.day_count = maxi(GameState.day_count, 1 + GameState.run_progress / 2)
			GameState.change_screen(GameState.Screen.BATTLE)
		GameMap.NodeType.EVENT:
			_trigger_event(node.area_index)
		GameMap.NodeType.REST:
			_trigger_rest()
		GameMap.NodeType.REWARD:
			GameState.change_screen(GameState.Screen.REWARD)


func _trigger_event(area_index: int) -> void:
	var area_id: String = GameMap.AREAS[area_index].id
	_current_event = EventHandler.pick_random_event(area_id, _rng)
	if _current_event == null:
		info_label.text = "这里什么都没有。"
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
	info_label.text = message
	event_popup.visible = false
	_current_event = null
	_update_ui()


func _trigger_rest() -> void:
	AudioManager.play_sfx("heal")
	var handler := EventHandler.new(GameState.player_stats)
	info_label.text = handler.apply_rest()
	_update_ui()


func _update_ui() -> void:
	var node: GameMap.MapNode = _game_map.get_current_node()
	if node == null:
		return
	_game_map.unlock_boss_if_pressure_ready(8)
	_refresh_node_buttons()
	area_label.text = "当前区域：%s" % _game_map.get_area_name(node.area_index)
	day_label.text = "第 %d 天" % GameState.day_count
	resource_label.text = "学分 %d　信用点 %d　压力 %d" % [
		GameState.credits, GameState.credit_points, GameState.run_progress
	]
	info_label.text = "节点：%s | %s　[点击可用节点移动]  SHIFT冲刺占位  E交互占位  ESC系统" % [
		node.id, GameMap.node_type_name(node.type)
	]
	if _hp_bar:
		_hp_bar.set_values(GameState.run_hp, GameState.run_max_hp)
	if _spirit_bar:
		_spirit_bar.set_values(GameState.run_spirit, GameState.run_max_spirit)
	if _minimap:
		_minimap.refresh()

	var next_goal := "继续探索校园节点"
	if node.area_index >= 3:
		next_goal = "前往操场，准备终极答辩"
	elif node.area_index == 2:
		next_goal = "在图书馆强化构筑，留意 AI 审稿人"
	objective_label.text = "主目标：%s\n可选：食堂补给 / 操场遭遇\n压力圈进度：%d（≥8 强化终局压迫）" % [
		next_goal, GameState.run_progress
	]


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)
