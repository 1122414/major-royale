extends Node
## 局外成长档案：保存永久金币，并负责一局结束后的幂等奖励结算。

signal profile_changed

const PROFILE_SAVE_VERSION := 1
const PROFILE_SAVE_PATH := "user://meta_progression.json"
const PROFILE_SAVE_BACKUP_PATH := "user://meta_progression.backup.json"
const PROFILE_SAVE_TEMP_PATH := "user://meta_progression.tmp.json"
const MAX_SETTLED_RUNS := 40
const TALENT_SLOT_LIMIT := 2
const TALENTS := {
	"healthy_routine": {
		"name": "规律作息",
		"desc": "每局最大生命 +6。",
		"cost": 30,
		"effects": {"max_hp": 6},
	},
	"calm_mind": {
		"name": "稳定心态",
		"desc": "每局最大精神 +10。",
		"cost": 30,
		"effects": {"max_spirit": 10},
	},
	"organized_notes": {
		"name": "笔记归档",
		"desc": "每场战斗开局额外抽 1 张牌。",
		"cost": 45,
		"effects": {"opening_draw": 1},
	},
	"pressure_drill": {
		"name": "抗压演练",
		"desc": "每场战斗开局获得 1 层抗压。",
		"cost": 40,
		"effects": {"opening_resistance": 1},
	},
	"resource_network": {
		"name": "资源人脉",
		"desc": "每局初始学分 +20。",
		"cost": 35,
		"effects": {"starting_credits": 20},
	},
	"emergency_review": {
		"name": "临场复盘",
		"desc": "每场战斗开局获得 4 点护盾。",
		"cost": 35,
		"effects": {"opening_shield": 4},
	},
}
const EQUIPMENT_SLOTS := {
	"tool": "工具",
	"badge": "徽章",
	"keepsake": "纪念品",
}
const EQUIPMENT := {
	"secondhand_laptop": {
		"name": "二手笔记本",
		"desc": "每局初始信用点 +30。",
		"slot": "tool",
		"cost": 25,
		"effects": {"starting_credit_points": 30},
	},
	"graphing_calculator": {
		"name": "图形计算器",
		"desc": "学识永久 +1。",
		"slot": "tool",
		"cost": 45,
		"effects": {"stat_学识": 1},
	},
	"portable_charger": {
		"name": "随身充电宝",
		"desc": "每场战斗开局获得 3 点护盾。",
		"slot": "tool",
		"cost": 35,
		"effects": {"opening_shield": 3},
	},
	"debate_medal": {
		"name": "辩论赛奖牌",
		"desc": "表达永久 +1。",
		"slot": "badge",
		"cost": 45,
		"effects": {"stat_表达": 1},
	},
	"sports_pin": {
		"name": "校队纪念章",
		"desc": "每局最大生命 +5。",
		"slot": "badge",
		"cost": 35,
		"effects": {"max_hp": 5},
	},
	"volunteer_badge": {
		"name": "志愿者徽章",
		"desc": "社交永久 +1。",
		"slot": "badge",
		"cost": 45,
		"effects": {"stat_社交": 1},
	},
	"family_photo": {
		"name": "合影相框",
		"desc": "每局最大精神 +8。",
		"slot": "keepsake",
		"cost": 35,
		"effects": {"max_spirit": 8},
	},
	"lucky_pen": {
		"name": "幸运签字笔",
		"desc": "资源永久 +1。",
		"slot": "keepsake",
		"cost": 45,
		"effects": {"stat_资源": 1},
	},
	"campus_map": {
		"name": "折叠校园图",
		"desc": "每局初始学分 +15。",
		"slot": "keepsake",
		"cost": 30,
		"effects": {"starting_credits": 15},
	},
}
const UPGRADES := {
	"survival_training": {
		"name": "生存训练",
		"desc": "每级使每局最大生命 +3。",
		"max_level": 3,
		"base_cost": 25,
		"cost_step": 20,
		"effects_per_level": {"max_hp": 3},
	},
	"mindset_training": {
		"name": "心态建设",
		"desc": "每级使每局最大精神 +5。",
		"max_level": 3,
		"base_cost": 25,
		"cost_step": 20,
		"effects_per_level": {"max_spirit": 5},
	},
	"resource_planning": {
		"name": "资源规划",
		"desc": "每级使每局初始学分 +10。",
		"max_level": 3,
		"base_cost": 30,
		"cost_step": 20,
		"effects_per_level": {"starting_credits": 10},
	},
	"alumni_network": {
		"name": "校友网络",
		"desc": "每级使局末永久金币收益 +8%。",
		"max_level": 3,
		"base_cost": 35,
		"cost_step": 25,
		"effects_per_level": {"gold_bonus_percent": 8},
	},
}

var gold: int = 0
var settled_runs: Dictionary = {}  ## run_token -> {earned, settled_at}
var unlocked_talent_ids: Array[String] = []
var equipped_talent_ids: Array[String] = []
var owned_equipment_ids: Array[String] = []
var equipped_equipment: Dictionary = {}  ## slot_id -> equipment_id
var upgrade_levels: Dictionary = {}  ## upgrade_id -> level
var save_enabled := true


func _ready() -> void:
	load_profile()


func get_gold() -> int:
	return gold


func grant_gold(amount: int) -> int:
	var granted := maxi(0, amount)
	if granted == 0:
		return 0
	gold += granted
	save_profile()
	profile_changed.emit()
	return granted


func can_afford(amount: int) -> bool:
	return amount >= 0 and gold >= amount


func spend_gold(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	if amount == 0:
		return true
	gold -= amount
	save_profile()
	profile_changed.emit()
	return true


func get_talent_info(talent_id: String) -> Dictionary:
	return (TALENTS.get(talent_id, {}) as Dictionary).duplicate(true)


func get_talent_ids() -> Array[String]:
	var output: Array[String] = []
	for talent_id in TALENTS:
		output.append(str(talent_id))
	return output


func is_talent_unlocked(talent_id: String) -> bool:
	return talent_id in unlocked_talent_ids


func is_talent_equipped(talent_id: String) -> bool:
	return talent_id in equipped_talent_ids


func purchase_talent(talent_id: String) -> bool:
	if not TALENTS.has(talent_id) or is_talent_unlocked(talent_id):
		return false
	var cost := maxi(0, int(TALENTS[talent_id].get("cost", 0)))
	if not can_afford(cost):
		return false
	gold -= cost
	unlocked_talent_ids.append(talent_id)
	save_profile()
	profile_changed.emit()
	return true


func equip_talent(talent_id: String) -> bool:
	if not is_talent_unlocked(talent_id):
		return false
	if is_talent_equipped(talent_id):
		return true
	if equipped_talent_ids.size() >= TALENT_SLOT_LIMIT:
		return false
	equipped_talent_ids.append(talent_id)
	save_profile()
	profile_changed.emit()
	return true


func unequip_talent(talent_id: String) -> bool:
	if not is_talent_equipped(talent_id):
		return false
	equipped_talent_ids.erase(talent_id)
	save_profile()
	profile_changed.emit()
	return true


func get_equipped_talent_ids() -> Array[String]:
	return equipped_talent_ids.duplicate()


func get_equipment_info(equipment_id: String) -> Dictionary:
	return (EQUIPMENT.get(equipment_id, {}) as Dictionary).duplicate(true)


func get_equipment_ids() -> Array[String]:
	var output: Array[String] = []
	for equipment_id in EQUIPMENT:
		output.append(str(equipment_id))
	return output


func is_equipment_owned(equipment_id: String) -> bool:
	return equipment_id in owned_equipment_ids


func purchase_equipment(equipment_id: String) -> bool:
	if not EQUIPMENT.has(equipment_id) or is_equipment_owned(equipment_id):
		return false
	var cost := maxi(0, int(EQUIPMENT[equipment_id].get("cost", 0)))
	if not can_afford(cost):
		return false
	gold -= cost
	owned_equipment_ids.append(equipment_id)
	save_profile()
	profile_changed.emit()
	return true


func equip_equipment(equipment_id: String) -> bool:
	if not is_equipment_owned(equipment_id):
		return false
	var slot_id := str(EQUIPMENT[equipment_id].get("slot", ""))
	if not EQUIPMENT_SLOTS.has(slot_id):
		return false
	equipped_equipment[slot_id] = equipment_id
	save_profile()
	profile_changed.emit()
	return true


func unequip_slot(slot_id: String) -> bool:
	if not equipped_equipment.has(slot_id):
		return false
	equipped_equipment.erase(slot_id)
	save_profile()
	profile_changed.emit()
	return true


func get_owned_equipment_ids() -> Array[String]:
	return owned_equipment_ids.duplicate()


func get_equipped_equipment() -> Dictionary:
	return equipped_equipment.duplicate()


func get_upgrade_info(upgrade_id: String) -> Dictionary:
	return (UPGRADES.get(upgrade_id, {}) as Dictionary).duplicate(true)


func get_upgrade_ids() -> Array[String]:
	var output: Array[String] = []
	for upgrade_id in UPGRADES:
		output.append(str(upgrade_id))
	return output


func get_upgrade_level(upgrade_id: String) -> int:
	if not UPGRADES.has(upgrade_id):
		return 0
	return clampi(
		int(upgrade_levels.get(upgrade_id, 0)),
		0,
		int(UPGRADES[upgrade_id].get("max_level", 0)),
	)


func get_next_upgrade_cost(upgrade_id: String) -> int:
	if not UPGRADES.has(upgrade_id):
		return -1
	var info: Dictionary = UPGRADES[upgrade_id]
	var level := get_upgrade_level(upgrade_id)
	if level >= int(info.get("max_level", 0)):
		return -1
	return int(info.get("base_cost", 0)) + level * int(info.get("cost_step", 0))


func purchase_upgrade(upgrade_id: String) -> bool:
	var cost := get_next_upgrade_cost(upgrade_id)
	if cost < 0 or not can_afford(cost):
		return false
	gold -= cost
	upgrade_levels[upgrade_id] = get_upgrade_level(upgrade_id) + 1
	save_profile()
	profile_changed.emit()
	return true


func get_combined_effects() -> Dictionary:
	var output := {}
	for talent_id in equipped_talent_ids:
		var effects: Dictionary = TALENTS[talent_id].get("effects", {})
		for effect_id in effects:
			output[effect_id] = int(output.get(effect_id, 0)) + int(effects[effect_id])
	for equipment_id in equipped_equipment.values():
		var effects: Dictionary = EQUIPMENT[equipment_id].get("effects", {})
		for effect_id in effects:
			output[effect_id] = int(output.get(effect_id, 0)) + int(effects[effect_id])
	for upgrade_id in UPGRADES:
		var level := get_upgrade_level(upgrade_id)
		var effects: Dictionary = UPGRADES[upgrade_id].get("effects_per_level", {})
		for effect_id in effects:
			output[effect_id] = int(output.get(effect_id, 0)) + int(effects[effect_id]) * level
	return output


func calculate_run_gold(
	battles_won: int,
	events_resolved: int,
	difficulty: int,
	is_clear: bool,
	gold_bonus_percent: int = 0,
) -> int:
	var reward := 4
	reward += maxi(0, battles_won) * 3
	reward += maxi(0, events_resolved)
	reward += maxi(0, difficulty) * 4
	if is_clear:
		reward += 20
	return int(round(float(reward) * (1.0 + float(maxi(0, gold_bonus_percent)) / 100.0)))


func settle_current_run(is_clear: bool) -> Dictionary:
	var run_token := GameState.run_instance_id
	if run_token.is_empty():
		run_token = _make_run_token(
			GameState.run_started_at,
			GameState.run_seed,
			GameState.player_major_id,
		)
	if settled_runs.has(run_token):
		var previous: Dictionary = settled_runs[run_token]
		return {
			"earned": int(previous.get("earned", 0)),
			"balance": gold,
			"already_settled": true,
			"run_token": run_token,
		}

	var earned := calculate_run_gold(
		GameState.run_battles_won,
		GameState.run_events_resolved,
		GameState.run_difficulty,
		is_clear,
		GameState.get_meta_effect("gold_bonus_percent"),
	)
	gold += earned
	settled_runs[run_token] = {
		"earned": earned,
		"settled_at": int(Time.get_unix_time_from_system()),
	}
	_trim_settled_runs()
	save_profile()
	profile_changed.emit()
	return {
		"earned": earned,
		"balance": gold,
		"already_settled": false,
		"run_token": run_token,
	}


func create_profile_snapshot() -> Dictionary:
	return {
		"version": PROFILE_SAVE_VERSION,
		"gold": gold,
		"settled_runs": settled_runs.duplicate(true),
		"unlocked_talent_ids": unlocked_talent_ids.duplicate(),
		"equipped_talent_ids": equipped_talent_ids.duplicate(),
		"owned_equipment_ids": owned_equipment_ids.duplicate(),
		"equipped_equipment": equipped_equipment.duplicate(),
		"upgrade_levels": upgrade_levels.duplicate(),
	}


func restore_profile_snapshot(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != PROFILE_SAVE_VERSION:
		return false
	var saved_runs = data.get("settled_runs", {})
	if saved_runs is not Dictionary:
		return false

	gold = clampi(int(data.get("gold", 0)), 0, 999999999)
	settled_runs.clear()
	for token in saved_runs:
		var normalized_token := str(token).strip_edges()
		var entry = saved_runs[token]
		if normalized_token.is_empty() or normalized_token.length() > 160 or entry is not Dictionary:
			continue
		settled_runs[normalized_token] = {
			"earned": clampi(int(entry.get("earned", 0)), 0, 999999),
			"settled_at": maxi(0, int(entry.get("settled_at", 0))),
		}
	unlocked_talent_ids = _sanitize_id_array(data.get("unlocked_talent_ids", []), TALENTS)
	equipped_talent_ids.clear()
	for talent_id in _sanitize_id_array(data.get("equipped_talent_ids", []), TALENTS):
		if talent_id in unlocked_talent_ids and equipped_talent_ids.size() < TALENT_SLOT_LIMIT:
			equipped_talent_ids.append(talent_id)
	owned_equipment_ids = _sanitize_id_array(data.get("owned_equipment_ids", []), EQUIPMENT)
	equipped_equipment.clear()
	var saved_equipment = data.get("equipped_equipment", {})
	if saved_equipment is Dictionary:
		for slot_id in EQUIPMENT_SLOTS:
			var equipment_id := str(saved_equipment.get(slot_id, ""))
			if equipment_id in owned_equipment_ids and str(EQUIPMENT[equipment_id].get("slot", "")) == slot_id:
				equipped_equipment[slot_id] = equipment_id
	upgrade_levels.clear()
	var saved_upgrade_levels = data.get("upgrade_levels", {})
	if saved_upgrade_levels is Dictionary:
		for upgrade_id in UPGRADES:
			upgrade_levels[upgrade_id] = clampi(
				int(saved_upgrade_levels.get(upgrade_id, 0)),
				0,
				int(UPGRADES[upgrade_id].get("max_level", 0)),
			)
	_trim_settled_runs()
	profile_changed.emit()
	return true


func reset_profile() -> void:
	gold = 0
	settled_runs.clear()
	unlocked_talent_ids.clear()
	equipped_talent_ids.clear()
	owned_equipment_ids.clear()
	equipped_equipment.clear()
	upgrade_levels.clear()
	profile_changed.emit()


func load_profile() -> bool:
	for path in [PROFILE_SAVE_PATH, PROFILE_SAVE_BACKUP_PATH]:
		var data := _read_profile_file(path)
		if not data.is_empty() and restore_profile_snapshot(data):
			return true
	return false


func save_profile() -> bool:
	if not save_enabled:
		return false
	return _write_profile_atomically(create_profile_snapshot())


func _make_run_token(started_at: int, seed: int, major_id: String) -> String:
	return "%d:%d:%s" % [maxi(0, started_at), maxi(1, seed), major_id.strip_edges()]


func _sanitize_id_array(value: Variant, catalog: Dictionary) -> Array[String]:
	var output: Array[String] = []
	if value is not Array:
		return output
	for raw_id in value:
		var item_id := str(raw_id)
		if catalog.has(item_id) and item_id not in output:
			output.append(item_id)
	return output


func _trim_settled_runs() -> void:
	if settled_runs.size() <= MAX_SETTLED_RUNS:
		return
	var ordered: Array = settled_runs.keys()
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(settled_runs[a].get("settled_at", 0)) < int(settled_runs[b].get("settled_at", 0))
	)
	while settled_runs.size() > MAX_SETTLED_RUNS and not ordered.is_empty():
		settled_runs.erase(ordered.pop_front())


func _write_profile_atomically(data: Dictionary) -> bool:
	var save_path := ProjectSettings.globalize_path(PROFILE_SAVE_PATH)
	var backup_path := ProjectSettings.globalize_path(PROFILE_SAVE_BACKUP_PATH)
	var temp_path := ProjectSettings.globalize_path(PROFILE_SAVE_TEMP_PATH)
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("无法创建局外成长临时存档：%s" % temp_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		var backup_error := DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			push_error("无法轮换局外成长存档备份：%s" % error_string(backup_error))
			return false
	var replace_error := DirAccess.rename_absolute(temp_path, save_path)
	if replace_error == OK:
		return true
	if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(backup_path, save_path)
	push_error("无法提交局外成长存档：%s" % error_string(replace_error))
	return false


func _read_profile_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}
