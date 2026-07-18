class_name ObjectiveTracker
extends RefCounted
## 探索目标派生器：根据五区挑战进度生成当前主目标与区域清单。

const CampusRouteScript := preload("res://src/logic/campus_route.gd")

var main_objective: Dictionary = {}
var optional_objectives: Array[Dictionary] = []


func refresh(visited_locations: Array[String], defeated_enemies: Array = []) -> void:
	var all_route_enemies := CampusRouteScript.all_route_enemy_ids()
	var remaining := CampusRouteScript.remaining_enemy_ids(defeated_enemies)
	var cleared_count := all_route_enemies.size() - remaining.size()
	var boss_defeated := _was_defeated(CampusRouteScript.BOSS_ID, defeated_enemies)

	if boss_defeated:
		main_objective = {
			"id": "campus_cleared",
			"title": "校园挑战已完成",
			"description": "你已经通过终极答辩。",
			"target": "sports",
		}
	elif remaining.is_empty():
		main_objective = {
			"id": "finale",
			"title": "前往操场 · 终极答辩",
			"description": "五区资格战已全部完成，就业压力正在操场等待。",
			"target": "sports",
		}
	else:
		var target := _recommended_location(visited_locations, defeated_enemies)
		var enemy_id := CampusRouteScript.next_enemy_id(target, defeated_enemies)
		main_objective = {
			"id": "route_%s" % target,
			"title": "前往%s" % CampusRouteScript.LOCATION_NAMES.get(target, target),
			"description": "校园竞争者 %d/%d · 下一战：%s" % [
				cleared_count,
				all_route_enemies.size(),
				_enemy_name(enemy_id),
			],
			"target": target,
		}

	optional_objectives.clear()
	for location_id in CampusRouteScript.LOCATION_ORDER:
		var progress := CampusRouteScript.location_progress(location_id, defeated_enemies)
		var next_enemy_id := str(progress.get("next_enemy_id", ""))
		var title := "%s %d/%d" % [
			CampusRouteScript.LOCATION_NAMES.get(location_id, location_id),
			progress.get("cleared", 0),
			progress.get("total", 0),
		]
		if not next_enemy_id.is_empty() and next_enemy_id != CampusRouteScript.BOSS_ID:
			title += " · %s" % _enemy_name(next_enemy_id)
		optional_objectives.append({
			"id": "route_%s" % location_id,
			"title": title,
			"target": location_id,
			"completed": bool(progress.get("completed", false)),
		})


func _recommended_location(visited_locations: Array[String], defeated_enemies: Array) -> String:
	for location_id in CampusRouteScript.LOCATION_ORDER:
		if location_id not in visited_locations and not CampusRouteScript.next_enemy_id(location_id, defeated_enemies).is_empty():
			return location_id
	for location_id in CampusRouteScript.LOCATION_ORDER:
		var next_id := CampusRouteScript.next_enemy_id(location_id, defeated_enemies)
		if not next_id.is_empty() and next_id != CampusRouteScript.BOSS_ID:
			return location_id
	return "sports"


func _enemy_name(enemy_id: String) -> String:
	var enemy = Config.enemies.get(enemy_id)
	return str(enemy.name) if enemy != null else enemy_id


func _was_defeated(enemy_id: String, defeated_enemies: Array) -> bool:
	for enemy in defeated_enemies:
		if enemy is Dictionary and str(enemy.get("id", "")) == enemy_id:
			return true
		if str(enemy) == enemy_id:
			return true
	return false
