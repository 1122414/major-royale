class_name ObjectiveTracker
extends RefCounted
## 探索目标派生器：根据已访问热点生成当前主目标与可选目标。

var main_objective: Dictionary = {}
var optional_objectives: Array[Dictionary] = []


func refresh(visited_locations: Array[String]) -> void:
	if "teaching" not in visited_locations:
		main_objective = {
			"id": "first_classroom",
			"title": "前往教学楼",
			"description": "进入教学楼，完成首次课堂挑战。",
			"target": "teaching",
		}
	elif "library" not in visited_locations:
		main_objective = {
			"id": "find_library_clue",
			"title": "前往图书馆",
			"description": "到达图书馆，寻找下一阶段线索。",
			"target": "library",
		}
	else:
		main_objective = {
			"id": "prepare_finale",
			"title": "准备终局挑战",
			"description": "继续探索校园热点，提升生存准备。",
			"target": "sports",
		}

	optional_objectives = [
		_make_optional("visit_cafeteria", "在食堂探索一次", "cafeteria", visited_locations),
		_make_optional("visit_dorm", "在宿舍探索一次", "dorm", visited_locations),
		_make_optional("visit_sports", "到操场踩点一次", "sports", visited_locations),
	]


func _make_optional(id: String, title: String, target: String, visited_locations: Array[String]) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"target": target,
		"completed": target in visited_locations,
	}
