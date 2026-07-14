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

class MapNode:
	var id: String
	var area_index: int
	var node_index: int
	var type: NodeType
	var position: Vector2
	var connections: Array[String] = []
	var visited: bool = false
	var available: bool = false
	var data_id: String = ""  ## 关联的敌人/事件 ID

	func _init(p_id: String, p_area: int, p_index: int, p_type: NodeType, p_pos: Vector2) -> void:
		id = p_id
		area_index = p_area
		node_index = p_index
		type = p_type
		position = p_pos


var nodes: Dictionary = {}  ## id -> MapNode
var current_node_id: String = ""


func generate(seed_value: int = 0) -> void:
	nodes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()

	var x_start := 120.0
	var x_step := 200.0
	var y_center := 360.0
	var y_spread := 140.0

	for area_idx in AREAS.size():
		var area = AREAS[area_idx]
		var node_count := rng.randi_range(2, 4)
		var previous_ids: Array[String] = []

		if area_idx > 0:
			for prev in nodes.values():
				if prev.area_index == area_idx - 1:
					previous_ids.append(prev.id)

		for node_idx in node_count:
			var node_id := "area_%d_node_%d" % [area_idx, node_idx]
			var pos := Vector2(
				x_start + area_idx * x_step + node_idx * (x_step / node_count),
				y_center + rng.randf_range(-y_spread, y_spread)
			)
			var node_type := _pick_node_type(area_idx, node_idx, node_count, rng)
			var node := MapNode.new(node_id, area_idx, node_idx, node_type, pos)
			node.data_id = _assign_data_id(node_type, area.id, rng)
			nodes[node_id] = node

			# 连接上一区域节点（第一个节点连接所有上一区域节点）
			if not previous_ids.is_empty():
				if node_idx == 0:
					for prev_id in previous_ids:
						nodes[prev_id].connections.append(node_id)
				else:
					var prev_in_area := "area_%d_node_%d" % [area_idx, node_idx - 1]
					if nodes.has(prev_in_area):
						nodes[prev_in_area].connections.append(node_id)

	# 设置起点
	current_node_id = "area_0_node_0"
	nodes[current_node_id].available = true
	nodes[current_node_id].visited = true
	ensure_ai_native_encounter()


func _pick_node_type(area_idx: int, node_idx: int, node_count: int, rng: RandomNumberGenerator) -> NodeType:
	# 最后一区域最后一个节点固定为 Boss
	if area_idx == AREAS.size() - 1 and node_idx == node_count - 1:
		return NodeType.BOSS

	# 每个区域最后一个节点固定为过渡到下一区域的节点
	if node_idx == node_count - 1:
		return NodeType.EVENT

	var roll := rng.randf()
	if roll < 0.40:
		return NodeType.BATTLE
	elif roll < 0.62:
		return NodeType.EVENT
	elif roll < 0.74:
		return NodeType.REST
	elif roll < 0.82:
		return NodeType.REWARD
	else:
		return NodeType.ELITE


func _assign_data_id(node_type: NodeType, area_id: String, rng: RandomNumberGenerator) -> String:
	match node_type:
		NodeType.BATTLE:
			# 教学楼 / 图书馆：一定概率刷 AI Native
			if area_id == "classroom" and rng.randf() < 0.45:
				return "ai_interviewer"
			if area_id == "library" and rng.randf() < 0.45:
				return "paper_reviewer"
			var normal_ids := ["gpa_anxiety", "seat_grabber", "all_nighter", "sports_student", "client_phantom"]
			return normal_ids[rng.randi() % normal_ids.size()]
		NodeType.ELITE:
			# 精英也可替换为 AI Native（保证每局更易遇见）
			if area_id == "classroom" and rng.randf() < 0.55:
				return "ai_interviewer"
			if area_id == "library" and rng.randf() < 0.55:
				return "paper_reviewer"
			var elite_ids := ["all_nighter_king", "sports_ace"]
			return elite_ids[rng.randi() % elite_ids.size()]
		NodeType.BOSS:
			return "employment_pressure"
		NodeType.EVENT:
			return ""
		NodeType.REST:
			return ""
		NodeType.REWARD:
			return ""
	return ""


## 压力 ≥8 时强制解锁操场终局 Boss 节点。
func unlock_boss_if_pressure_ready(threshold: int = 8) -> void:
	if GameState.run_progress < threshold:
		return
	for node_id in nodes:
		var node: MapNode = nodes[node_id]
		if node.type == NodeType.BOSS:
			node.available = true




## 若生成后仍无 AI Native，则把教学楼/图书馆一个战斗节点强制替换。
func ensure_ai_native_encounter() -> void:
	var has_ai := false
	for node_id in nodes:
		var n: MapNode = nodes[node_id]
		if n.data_id in ["ai_interviewer", "paper_reviewer"]:
			has_ai = true
			break
	if has_ai:
		return
	for node_id in nodes:
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


func move_to(node_id: String) -> void:
	if not nodes.has(node_id):
		return
	var target: MapNode = nodes[node_id]
	if not target.available:
		return

	current_node_id = node_id
	target.visited = true

	# 解锁后续节点
	for next_id in target.connections:
		if nodes.has(next_id):
			nodes[next_id].available = true


func get_current_node() -> MapNode:
	return nodes.get(current_node_id) as MapNode


static func node_type_name(node_type: NodeType) -> String:
	match node_type:
		NodeType.BATTLE: return "战斗"
		NodeType.EVENT: return "事件"
		NodeType.REST: return "补给"
		NodeType.REWARD: return "奖励"
		NodeType.ELITE: return "精英"
		NodeType.BOSS: return "终局"
	return "未知"
