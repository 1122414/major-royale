class_name CampusRoute
extends RefCounted

## 校园路线图：五个地点各自拥有递进对手，清空全部区域后解锁终局。

const BOSS_ID := "employment_pressure"
const LOCATION_ORDER: Array[String] = ["teaching", "library", "dorm", "cafeteria", "sports"]
const LOCATION_NAMES := {
	"teaching": "教学楼",
	"library": "图书馆",
	"dorm": "宿舍",
	"cafeteria": "食堂",
	"sports": "操场",
}
const LOCATION_ROUTES := {
	"teaching": ["gpa_anxiety", "ai_interviewer"],
	"library": ["seat_grabber", "paper_reviewer"],
	"dorm": ["all_nighter", "all_nighter_king"],
	"cafeteria": ["client_phantom"],
	"sports": ["sports_student", "sports_ace"],
}


static func next_enemy_id(location_id: String, defeated_enemies: Array) -> String:
	var defeated_ids := _defeated_ids(defeated_enemies)
	for enemy_id in LOCATION_ROUTES.get(location_id, []):
		if str(enemy_id) not in defeated_ids:
			return str(enemy_id)
	if location_id == "sports" and is_finale_ready(defeated_enemies) and BOSS_ID not in defeated_ids:
		return BOSS_ID
	return ""


static func is_finale_ready(defeated_enemies: Array) -> bool:
	var defeated_ids := _defeated_ids(defeated_enemies)
	for enemy_id in all_route_enemy_ids():
		if enemy_id not in defeated_ids:
			return false
	return true


static func all_route_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for location_id in LOCATION_ORDER:
		for enemy_id in LOCATION_ROUTES.get(location_id, []):
			result.append(str(enemy_id))
	return result


static func remaining_enemy_ids(defeated_enemies: Array) -> Array[String]:
	var defeated_ids := _defeated_ids(defeated_enemies)
	var result: Array[String] = []
	for enemy_id in all_route_enemy_ids():
		if enemy_id not in defeated_ids:
			result.append(enemy_id)
	return result


static func location_progress(location_id: String, defeated_enemies: Array) -> Dictionary:
	var route: Array = LOCATION_ROUTES.get(location_id, [])
	var defeated_ids := _defeated_ids(defeated_enemies)
	var cleared := 0
	for enemy_id in route:
		if str(enemy_id) in defeated_ids:
			cleared += 1
	return {
		"cleared": cleared,
		"total": route.size(),
		"completed": cleared >= route.size(),
		"next_enemy_id": next_enemy_id(location_id, defeated_enemies),
	}


static func _defeated_ids(defeated_enemies: Array) -> Dictionary:
	var result := {}
	for enemy in defeated_enemies:
		if enemy is Dictionary:
			result[str(enemy.get("id", ""))] = true
		else:
			result[str(enemy)] = true
	return result
