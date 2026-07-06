extends Control
## 地图探索场景。

const MAP_NODE_SCENE := preload("res://src/ui/widgets/map_node.tscn")
const ICON_BUTTON_SCENE := preload("res://src/ui/widgets/icon_button.tscn")

@onready var area_label: Label = $AreaLabel
@onready var info_label: Label = $InfoLabel

var _game_map: GameMap


func _ready() -> void:
	_game_map = GameMap.new()
	_game_map.generate(hash(GameState.player_major_id))
	_render_map()
	_update_ui()

	var settings_btn: Button = ICON_BUTTON_SCENE.instantiate()
	settings_btn.icon_text = "⚙"
	settings_btn.position = Vector2(1180, 20)
	settings_btn.pressed.connect(_on_settings_pressed)
	add_child(settings_btn)


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
		btn.setup(node_id, node.type, _game_map.get_area_color(node.area_index), node.visited, node.available)
		btn.position = node.position - Vector2(24, 24)
		btn.node_selected.connect(_on_node_selected)
		add_child(btn)


func _draw_connection(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 3
	line.default_color = Color(0.4, 0.4, 0.4, 0.6)
	add_child(line)


func _on_node_selected(node_id: String) -> void:
	_game_map.move_to(node_id)
	var node: GameMap.MapNode = _game_map.get_current_node()
	_update_ui()

	match node.type:
		GameMap.NodeType.BATTLE, GameMap.NodeType.ELITE, GameMap.NodeType.BOSS:
			GameState.player_stats["current_enemy_id"] = node.data_id
			GameState.change_screen(GameState.Screen.BATTLE)
		GameMap.NodeType.EVENT:
			EventBus.event_triggered.emit(node.data_id)
		GameMap.NodeType.REST:
			EventBus.event_triggered.emit("rest_site")


func _update_ui() -> void:
	var node: GameMap.MapNode = _game_map.get_current_node()
	if node == null:
		return
	area_label.text = "当前区域：%s" % _game_map.get_area_name(node.area_index)
	info_label.text = "节点：%s | %s" % [node.id, GameMap.node_type_name(node.type)]


func _on_settings_pressed() -> void:
	GameState.change_screen(GameState.Screen.SETTINGS)
