class_name GameMap
extends RefCounted

## 地图节点类型。
enum NodeType {
	BATTLE,
	EVENT,
	REST,
	REWARD,
	ELITE,
	BOSS,
}

## 区域定义。
const AREAS := [
	{"id": "dorm", "name": "宿舍", "color": Color.SKY_BLUE},
	{"id": "classroom", "name": "教学楼", "color": Color.LIGHT_CORAL},
	{"id": "library", "name": "图书馆", "color": Color.WHEAT},
	{"id": "cafeteria", "name": "食堂", "color": Color.LIGHT_GREEN},
	{"id": "playground", "name": "操场", "color": Color.ORANGE},
]

## 每区域固定节点数（线性路线，玩家逐步前进）。
const NODES_PER_AREA := 3

class MapNode:
	var id: String
	var area_index: int
	var node_index: int
	var type: NodeType
	var position: Vector2
	var connections: Array[String] = []
	var visited: bool = false
	var available: bool = false
	var data_id: String = ""
	var path_index: int = 0  ## 在线性路线中的序号

	func _init(p_id: String, p_area: int, p_index: int, p_type: NodeType, p_pos: Vector2) -> void:
		id = p_id
		area_index = p_area
		node_index = p_index
		type = p_type
		position = p_pos


var nodes: Dictionary = {}  ## id -> MapNode
var path_order: Array[String] = []  ## 线性前进顺序
var current_node_id: String = ""


func generate(seed_value: int = 0) -> void:
	nodes.clear()
	path_order.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()

	var x_start := 48.0
	var x_step := 78.0
	var y_center := 110.0
	var path_i := 0

	for area_idx in AREAS.size():
		var area = AREAS[area_idx]
		for node_idx in NODES_PER_AREA:
			var node_id := "area_%d_node_%d" % [area_idx, node_idx]
			var pos := Vector2(x_start + path_i * x_step, y_center + sin(path_i * 0.7) * 36.0)
			var node_type := _pick_node_type(area_idx, node_idx, NODES_PER_AREA, rng)
			var node := MapNode.new(node_id, area_idx, node_idx, node_type, pos)
			node.path_index = path_i
			node.data_id = _assign_data_id(node_type, area.id, rng)
			nodes[node_id] = node
			path_order.append(node_id)

			if path_i > 0:
				var prev_id: String = path_order[path_i - 1]
				nodes[prev_id].connections.append(node_id)
			path_i += 1

	# 起点：已到达；仅解锁下一站
	current_node_id = path_order[0]
	nodes[current_node_id].visited = true
	nodes[current_node_id].available = false
	_unlock_next_only()
	ensure_ai_native_encounter()


func _unlock_next_only() -> void:
	for node_id in path_order:
		var n: MapNode = nodes[node_id]
		if n.visited:
			n.available = false
		else:
			n.available = false
	var next_id := get_next_node_id()
	if next_id != "":
		nodes[next_id].available = true


func get_next_node_id() -> String:
	var cur: MapNode = get_current_node()
	if cur == null:
		return ""
	var next_idx := cur.path_index + 1
	if next_idx >= path_order.size():
		return ""
	return path_order[next_idx]


func get_next_node() -> MapNode:
	var nid := get_next_node_id()
	if nid == "":
		return null
	return nodes[nid] as MapNode


## 沿固定路线前进一格。成功返回新节点，否则 null。
func advance() -> MapNode:
	var next_id := get_next_node_id()
	if next_id == "":
		return null
	return move_to(next_id)


func _pick_node_type(area_idx: int, node_idx: int, node_count: int, rng: RandomNumberGenerator) -> NodeType:
	if area_idx == AREAS.size() - 1 and node_idx == node_count - 1:
		return NodeType.BOSS
	# 每区域首站偏事件/补给，中站偏战斗，末站偏奖励/精英
	if node_idx == 0:
		return NodeType.REST if area_idx == 0 else NodeType.EVENT
	if node_idx == node_count - 1 and area_idx < AREAS.size() - 1:
		var roll_end := rng.randf()
		if roll_end < 0.4:
			return NodeType.REWARD
		elif roll_end < 0.7:
			return NodeType.ELITE
		return NodeType.EVENT
	var roll := rng.randf()
	if roll < 0.55:
		return NodeType.BATTLE
	elif roll < 0.75:
		return NodeType.EVENT
	elif roll < 0.88:
		return NodeType.REST
	else:
		return NodeType.ELITE


func _assign_data_id(node_type: NodeType, area_id: String, rng: RandomNumberGenerator) -> String:
	match node_type:
		NodeType.BATTLE:
			if area_id == "classroom" and rng.randf() < 0.45:
				return "ai_interviewer"
			if area_id == "library" and rng.randf() < 0.45:
				return "paper_reviewer"
			var normal_ids := ["gpa_anxiety", "seat_grabber", "all_nighter", "sports_student", "client_phantom"]
			return normal_ids[rng.randi() % normal_ids.size()]
		NodeType.ELITE:
			if area_id == "classroom" and rng.randf() < 0.55:
				return "ai_interviewer"
			if area_id == "library" and rng.randf() < 0.55:
				return "paper_reviewer"
			var elite_ids := ["all_nighter_king", "sports_ace"]
			return elite_ids[rng.randi() % elite_ids.size()]
		NodeType.BOSS:
			return "employment_pressure"
		_:
			return ""


func unlock_boss_if_pressure_ready(threshold: int = 8) -> void:
	# 线性路线下终局是最后一站，压力只影响强度，不跳关
	pass


func ensure_ai_native_encounter() -> void:
	var has_ai := false
	for node_id in nodes:
		var n: MapNode = nodes[node_id]
		if n.data_id in ["ai_interviewer", "paper_reviewer"]:
			has_ai = true
			break
	if has_ai:
		return
	for node_id in path_order:
		var n: MapNode = nodes[node_id]
		var area_id: String = AREAS[n.area_index].id
		if area_id == "classroom" and n.type in [NodeType.BATTLE, NodeType.ELITE]:
			n.data_id = "ai_interviewer"
			return
		if area_id == "library" and n.type in [NodeType.BATTLE, NodeType.ELITE]:
			n.data_id = "paper_reviewer"
			return


func get_area_name(area_index: int) -> String:
	if area_index < 0 or area_index >= AREAS.size():
		return "未知"
	return AREAS[area_index].name


func get_area_color(area_index: int) -> Color:
	if area_index < 0 or area_index >= AREAS.size():
		return Color.WHITE
	return AREAS[area_index].color


func move_to(node_id: String) -> MapNode:
	if not nodes.has(node_id):
		return null
	var target: MapNode = nodes[node_id]
	# 线性：只能进下一站
	var expected := get_next_node_id()
	if expected != node_id:
		return null

	current_node_id = node_id
	target.visited = true
	_unlock_next_only()
	GameState.map_path_index = target.path_index
	return target


func restore_progress(path_index: int) -> void:
	## 按已保存进度恢复线性路线状态。
	path_index = clampi(path_index, 0, maxi(path_order.size() - 1, 0))
	for node_id in path_order:
		var n: MapNode = nodes[node_id]
		n.visited = n.path_index <= path_index
		n.available = false
	current_node_id = path_order[path_index]
	_unlock_next_only()
	GameState.map_path_index = path_index


func get_current_node() -> MapNode:
	return nodes.get(current_node_id) as MapNode


func get_progress_text() -> String:
	var cur := get_current_node()
	if cur == null:
		return "0/%d" % path_order.size()
	return "%d/%d" % [cur.path_index + 1, path_order.size()]


static func node_type_name(node_type: NodeType) -> String:
	match node_type:
		NodeType.BATTLE: return "战斗"
		NodeType.EVENT: return "事件"
		NodeType.REST: return "补给"
		NodeType.REWARD: return "奖励"
		NodeType.ELITE: return "精英"
		NodeType.BOSS: return "终局"
	return "未知"
