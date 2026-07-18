extends Node
## 成就系统：分难度解锁，持久化到 user://achievements.cfg。

signal achievement_unlocked(id: String)

const SAVE_PATH := "user://achievements.cfg"
const CampusRouteScript := preload("res://src/logic/campus_route.gd")

## difficulty: easy / normal / hard / legendary
const CATALOG := [
	{"id": "first_blood", "name": "初战告捷", "desc": "赢得一场战斗。", "difficulty": "easy"},
	{"id": "deck_builder", "name": "开始构筑", "desc": "牌组达到 10 张。", "difficulty": "easy"},
	{"id": "pressure_3", "name": "压力初现", "desc": "压力圈进度达到 3。", "difficulty": "easy"},
	{"id": "elite_slayer", "name": "精英猎手", "desc": "击败一名精英或 AI Native 敌人。", "difficulty": "normal"},
	{"id": "full_heal", "name": "满血状态", "desc": "在补给点将生命回满。", "difficulty": "normal"},
	{"id": "card_hoarder", "name": "卡牌收藏家", "desc": "牌组达到 15 张。", "difficulty": "normal"},
	{"id": "no_spirit_break", "name": "精神不倒", "desc": "通关时精神仍高于 50%。", "difficulty": "hard"},
	{"id": "speed_runner", "name": "急行军", "desc": "在第 10 天内通关。", "difficulty": "hard"},
	{"id": "ai_conqueror", "name": "AI 征服者", "desc": "击败全部 AI Native 敌人类型。", "difficulty": "hard"},
	{"id": "campus_sweep", "name": "五区制霸", "desc": "在同一局击败五区全部 9 名竞争者。", "difficulty": "hard"},
	{"id": "sole_survivor", "name": "唯一上岸者", "desc": "通关终极答辩。", "difficulty": "legendary"},
	{"id": "perfectionist", "name": "完美答辩", "desc": "通关时生命高于 80%。", "difficulty": "legendary"},
	{"id": "all_majors", "name": "全专业通关", "desc": "用 5 个不同专业通关（累计）。", "difficulty": "legendary"},
]

var unlocked: Dictionary = {}  # id -> unix time
var cleared_majors: Array[String] = []
var defeated_ai_ids: Array[String] = []


func _ready() -> void:
	load_achievements()


func load_achievements() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked.clear()
	for key in cfg.get_section_keys("unlocked"):
		unlocked[key] = int(cfg.get_value("unlocked", key, 0))
	cleared_majors.clear()
	for m in cfg.get_value("meta", "cleared_majors", []):
		cleared_majors.append(str(m))
	defeated_ai_ids.clear()
	for a in cfg.get_value("meta", "defeated_ai", []):
		defeated_ai_ids.append(str(a))


func save_achievements() -> void:
	var cfg := ConfigFile.new()
	for id in unlocked:
		cfg.set_value("unlocked", id, unlocked[id])
	cfg.set_value("meta", "cleared_majors", cleared_majors)
	cfg.set_value("meta", "defeated_ai", defeated_ai_ids)
	cfg.save(SAVE_PATH)


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = int(Time.get_unix_time_from_system())
	save_achievements()
	achievement_unlocked.emit(id)


func try_after_battle_win(enemy_id: String, was_elite_or_ai: bool) -> void:
	unlock("first_blood")
	if GameState.deck_card_ids.size() >= 10:
		unlock("deck_builder")
	if GameState.deck_card_ids.size() >= 15:
		unlock("card_hoarder")
	if GameState.run_progress >= 3:
		unlock("pressure_3")
	if was_elite_or_ai:
		unlock("elite_slayer")
	if enemy_id in ["ai_interviewer", "paper_reviewer"]:
		if enemy_id not in defeated_ai_ids:
			defeated_ai_ids.append(enemy_id)
			save_achievements()
		if "ai_interviewer" in defeated_ai_ids and "paper_reviewer" in defeated_ai_ids:
			unlock("ai_conqueror")
	if CampusRouteScript.remaining_enemy_ids(GameState.run_enemies_defeated).is_empty():
		unlock("campus_sweep")


func try_after_rest(healed_to_full: bool) -> void:
	if healed_to_full:
		unlock("full_heal")


func try_after_clear() -> void:
	unlock("sole_survivor")
	if GameState.run_spirit >= int(GameState.run_max_spirit * 0.5):
		unlock("no_spirit_break")
	if GameState.day_count <= 10:
		unlock("speed_runner")
	if GameState.run_hp >= int(GameState.run_max_hp * 0.8):
		unlock("perfectionist")
	var mid := GameState.player_major_id
	if mid != "" and mid not in cleared_majors:
		cleared_majors.append(mid)
		save_achievements()
	if cleared_majors.size() >= 5:
		unlock("all_majors")


func get_by_difficulty(diff: String) -> Array:
	var out := []
	for a in CATALOG:
		if a.difficulty == diff:
			out.append(a)
	return out
