extends Control
## 地图探索场景。

const MAP_NODE_SCENE := preload("res://src/ui/widgets/map_node.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

@onready var area_label: Label = $TopBar/AreaLabel
@onready var progress_label: Label = $TopBar/ProgressLabel
@onready var info_label: Label = $BottomBar/InfoLabel
@onready var nodes_container: Control = $NodesContainer
@onready var event_popup: PanelContainer = $EventPopup
@onready var event_title: Label = $EventPopup/VBoxContainer/EventTitle
@onready var event_desc: Label = $EventPopup/VBoxContainer/EventDesc
@onready var event_buttons: VBoxContainer = $EventPopup/VBoxContainer/EventButtons

var _game_map: GameMap
var _rng := RandomNumberGenerator.new()
var _current_event: EventResource = null


func _ready() -> void:
	_game_map = GameMap.new()
	_rng.seed = hash(GameState.player_major_id) + Time.get_unix_time_from_system()
	_game_map.generate(_rng.seed)
	_render_map()
	_update_ui()

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1180, 20)
	settings_btn.pressed.connect(_on_settings_pressed)
	add_child(settings_btn)

	event_popup.visible = false


func _render_map() -> void:
	# 绘制连线
	for node_id in _game_map.nodes:
		var node: GameMap.MapNode = _game_map.nodes[node_id]
		for next_id in node.connections:
			if _game_map.nodes.has(next_id):
				_draw_connection(node.position, _game_map.nodes[next_id].position)

	# 绘制节点
	for node_id in _game_map.nodes:
		var node: GameMap.MapNode = _game_map.nodes[node_id]
		var btn: Button = MAP_NODE_SCENE.instantiate()
		nodes_container.add_child(btn)
		btn.setup(node_id, node.type, _game_map.get_area_color(node.area_index), node.visited, node.available)
		btn.position = node.position - Vector2(28, 28)
		btn.node_selected.connect(_on_node_selected)


func _draw_connection(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 3
	line.default_color = Color(0.25, 0.35, 0.4, 0.8)
	nodes_container.add_child(line)


func _on_node_selected(node_id: String) -> void:
	AudioManager.play_sfx("click")
	_game_map.move_to(node_id)
	var node: GameMap.MapNode = _game_map.get_current_node()
	_update_ui()

	match node.type:
		GameMap.NodeType.BATTLE, GameMap.NodeType.ELITE, GameMap.NodeType.BOSS:
			GameState.player_stats["current_enemy_id"] = node.data_id
			GameState.run_progress += 1
			GameState.change_screen(GameState.Screen.BATTLE)
		GameMap.NodeType.EVENT:
			_trigger_event(node.area_index)
		GameMap.NodeType.REST:
			_trigger_rest()


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


func _trigger_rest() -> void:
	AudioManager.play_sfx("heal")
	var handler := EventHandler.new(GameState.player_stats)
	info_label.text = handler.apply_rest()


func _update_ui() -> void:
	var node: GameMap.MapNode = _game_map.get_current_node()
	if node == null:
		return
	area_label.text = "当前区域：%s" % _game_map.get_area_name(node.area_index)
	info_label.text = "节点：%s | %s" % [node.id, GameMap.node_type_name(node.type)]
	progress_label.text = "压力圈：%d" % GameState.run_progress


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)
