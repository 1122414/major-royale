extends Node
## 全局游戏状态：当前运行、玩家数据、场景栈。

enum Screen {
	MENU,
	MAJOR_SELECT,
	CAMPUS_EXPLORE,
	BATTLE,
	REWARD,
	SETTINGS,
	RESULT,
	ACHIEVEMENTS,
	RUN_SUMMARY,
	META_PROGRESSION,
}

const RUN_SAVE_VERSION := 1
const RUN_SAVE_PATH := "user://run_save.json"
const RUN_SAVE_BACKUP_PATH := "user://run_save.backup.json"
const RUN_SAVE_TEMP_PATH := "user://run_save.tmp.json"
const SAVED_PLAYER_STAT_KEYS := [
	"current_enemy_id",
	"last_campus_hotspot",
	"last_battle_victory",
	"last_enemy_was_ai",
	"last_ending_flag",
]
const STAT_NAMES := ["学识", "体能", "专注", "表达", "创造", "社交", "抗压", "资源"]
const SAVED_META_EFFECT_KEYS := [
	"max_hp",
	"max_spirit",
	"starting_credits",
	"starting_credit_points",
	"opening_draw",
	"opening_shield",
	"opening_resistance",
	"stat_学识",
	"stat_体能",
	"stat_专注",
	"stat_表达",
	"stat_创造",
	"stat_社交",
	"stat_抗压",
	"stat_资源",
	"gold_bonus_percent",
]
const RUN_SEED_MODULUS := 2147483647
const DIFFICULTY_CATALOG := [
	{
		"id": "standard",
		"name": "标准生存",
		"description": "完整规则体验，适合首次上手。",
		"enemy_hp_multiplier": 1.0,
		"enemy_damage_bonus": 0,
		"starting_pressure": 0,
		"action_window_multiplier": 1.0,
		"reward_multiplier": 1.0,
		"campus_healing_multiplier": 1.0,
	},
	{
		"id": "high_pressure",
		"name": "高压答辩",
		"description": "敌人生命 +25%，直接伤害 +2，窗口缩短，校内恢复 -15%，收益 +10%。",
		"enemy_hp_multiplier": 1.25,
		"enemy_damage_bonus": 2,
		"starting_pressure": 0,
		"action_window_multiplier": 0.9,
		"reward_multiplier": 1.1,
		"campus_healing_multiplier": 0.85,
	},
	{
		"id": "closing_circle",
		"name": "红圈收缩",
		"description": "敌人生命 +55%，直接伤害 +5，每战 2 层压力，校内恢复 -35%，收益 +20%。",
		"enemy_hp_multiplier": 1.55,
		"enemy_damage_bonus": 5,
		"starting_pressure": 2,
		"action_window_multiplier": 0.78,
		"reward_multiplier": 1.2,
		"campus_healing_multiplier": 0.65,
	},
	{
		"id": "last_seat",
		"name": "唯一席位",
		"description": "敌人生命 +100%，直接伤害 +8，每战 3 层压力，校内恢复 -50%，收益 +50%。",
		"enemy_hp_multiplier": 2.0,
		"enemy_damage_bonus": 8,
		"starting_pressure": 3,
		"action_window_multiplier": 0.65,
		"reward_multiplier": 1.5,
		"campus_healing_multiplier": 0.5,
	},
]

var current_screen: Screen = Screen.MENU
var settings_return_screen: Screen = Screen.MENU
var player_major_id: String = ""
var player_stats: Dictionary = {}
var run_progress: int = 0

## 一局持久化状态
var run_hp: int = 60
var run_max_hp: int = 60
var run_spirit: int = 100
var run_max_spirit: int = 100
var deck_card_ids: Array[String] = []
var permanent_stats: Dictionary = {}
var pending_buffs: Array[Dictionary] = []  ## [{status_id, stacks}, ...]
var run_relic_ids: Array[String] = []
var run_event_flags: Array[String] = []
var run_meta_effects: Dictionary = {}
var run_meta_talent_ids: Array[String] = []
var run_meta_equipment: Dictionary = {}
var credits: int = 120
var credit_points: int = 560
var day_count: int = 1
var last_reward_is_elite: bool = false
var campus_player_position := Vector2(640, 620)
var campus_visited_locations: Array[String] = []

## 通关总结统计
var run_enemies_defeated: Array[Dictionary] = []  ## [{id, name, type}]
var run_battles_won: int = 0
var run_damage_dealt: int = 0
var run_cards_played: int = 0
var run_events_resolved: int = 0
var run_perfect_rebuttals: int = 0
var run_successful_dodges: int = 0
var run_started_at: int = 0
var run_instance_id: String = ""
var run_seed: int = 1
var run_difficulty: int = 0

var _settings_overlay: Control = null
var _settings_previous_pause_state := false
var run_save_enabled := true


func has_run_save() -> bool:
	if not _is_run_save_allowed():
		return false
	return not _read_valid_run_save().is_empty()


func resume_saved_run() -> bool:
	if not _is_run_save_allowed():
		return false
	var data := _read_valid_run_save()
	if data.is_empty() or not restore_run_save_snapshot(data):
		return false
	var error := get_tree().change_scene_to_file(_screen_to_path(current_screen))
	return error == OK


func save_run_checkpoint(target_screen: Screen) -> bool:
	if not _is_run_save_allowed() or player_major_id.is_empty():
		return false
	var snapshot := create_run_save_snapshot(target_screen)
	if not is_run_save_snapshot_valid(snapshot):
		push_warning("跳过无效的一局存档快照")
		return false
	return _write_run_save_atomically(snapshot)


func clear_run_save() -> void:
	for path in [RUN_SAVE_PATH, RUN_SAVE_BACKUP_PATH, RUN_SAVE_TEMP_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func create_run_save_snapshot(target_screen: Screen) -> Dictionary:
	var snapshot := {
		"version": RUN_SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"screen": _screen_to_save_name(target_screen),
		"player_major_id": player_major_id,
		"player_stats": _serializable_player_stats(),
		"run_progress": run_progress,
		"run_hp": run_hp,
		"run_max_hp": run_max_hp,
		"run_spirit": run_spirit,
		"run_max_spirit": run_max_spirit,
		"deck_card_ids": deck_card_ids.duplicate(),
		"permanent_stats": permanent_stats.duplicate(true),
		"pending_buffs": pending_buffs.duplicate(true),
		"run_relic_ids": run_relic_ids.duplicate(),
		"run_event_flags": run_event_flags.duplicate(),
		"run_meta_effects": run_meta_effects.duplicate(true),
		"run_meta_talent_ids": run_meta_talent_ids.duplicate(),
		"run_meta_equipment": run_meta_equipment.duplicate(),
		"credits": credits,
		"credit_points": credit_points,
		"day_count": day_count,
		"last_reward_is_elite": last_reward_is_elite,
		"campus_player_position": [campus_player_position.x, campus_player_position.y],
		"campus_visited_locations": campus_visited_locations.duplicate(),
		"run_enemies_defeated": run_enemies_defeated.duplicate(true),
		"run_battles_won": run_battles_won,
		"run_damage_dealt": run_damage_dealt,
		"run_cards_played": run_cards_played,
		"run_events_resolved": run_events_resolved,
		"run_perfect_rebuttals": run_perfect_rebuttals,
		"run_successful_dodges": run_successful_dodges,
		"run_started_at": run_started_at,
		"run_instance_id": run_instance_id,
		"run_seed": run_seed,
		"run_difficulty": run_difficulty,
	}
	if player_major_id.begins_with("custom_") and Config.majors.has(player_major_id):
		var major: MajorResource = Config.majors[player_major_id]
		snapshot["custom_major"] = {
			"id": major.id,
			"name": major.name,
			"description": major.description,
			"stats": major.stats.duplicate(true),
			"active_skill": major.active_skill.duplicate(true),
			"passive_skill": major.passive_skill.duplicate(true),
			"starter_deck": major.starter_deck.duplicate(),
		}
	return snapshot


func is_run_save_snapshot_valid(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != RUN_SAVE_VERSION:
		return false
	var screen_name := str(data.get("screen", ""))
	if _save_name_to_screen(screen_name) == Screen.MENU:
		return false
	var major_id := str(data.get("player_major_id", ""))
	if major_id.begins_with("custom_"):
		var custom_data = data.get("custom_major")
		if custom_data is not Dictionary or str(custom_data.get("id", "")) != major_id:
			return false
	elif not Config.majors.has(major_id):
		return false
	var saved_player_stats = data.get("player_stats", {})
	if saved_player_stats is not Dictionary:
		return false
	if screen_name in ["battle", "result"]:
		var enemy_id := str(saved_player_stats.get("current_enemy_id", ""))
		if not Config.enemies.has(enemy_id):
			return false
	var saved_deck = data.get("deck_card_ids")
	if saved_deck is not Array or saved_deck.is_empty():
		return false
	for card_id in saved_deck:
		if not Config.cards.has(str(card_id)):
			return false
	if int(data.get("run_max_hp", 0)) <= 0 or int(data.get("run_max_spirit", 0)) <= 0:
		return false
	return true


func restore_run_save_snapshot(data: Dictionary) -> bool:
	if not is_run_save_snapshot_valid(data):
		return false
	_restore_custom_major(data)
	player_major_id = str(data.get("player_major_id", ""))
	player_stats = (data.get("player_stats", {}) as Dictionary).duplicate(true)
	run_progress = maxi(0, int(data.get("run_progress", 0)))
	run_max_hp = maxi(1, int(data.get("run_max_hp", 60)))
	run_hp = clampi(int(data.get("run_hp", run_max_hp)), 0, run_max_hp)
	run_max_spirit = maxi(1, int(data.get("run_max_spirit", 100)))
	run_spirit = clampi(int(data.get("run_spirit", run_max_spirit)), 0, run_max_spirit)
	deck_card_ids.clear()
	for card_id in data.get("deck_card_ids", []):
		deck_card_ids.append(str(card_id))
	permanent_stats = _sanitize_permanent_stats(data.get("permanent_stats", {}))
	pending_buffs.clear()
	for saved_buff in data.get("pending_buffs", []):
		if saved_buff is not Dictionary:
			continue
		var status_id := str(saved_buff.get("status_id", ""))
		if not status_id.is_empty():
			pending_buffs.append({
				"status_id": status_id,
				"stacks": clampi(int(saved_buff.get("stacks", 1)), 1, 99),
			})
	run_relic_ids.clear()
	for relic_id in data.get("run_relic_ids", []):
		var normalized_relic_id := str(relic_id)
		if not normalized_relic_id.is_empty() and normalized_relic_id not in run_relic_ids:
			run_relic_ids.append(normalized_relic_id)
	run_event_flags.clear()
	for event_flag in data.get("run_event_flags", []):
		var normalized_flag := str(event_flag).strip_edges()
		if not normalized_flag.is_empty() and normalized_flag.length() <= 64 and normalized_flag not in run_event_flags:
			run_event_flags.append(normalized_flag)
	run_meta_effects = _sanitize_meta_effects(data.get("run_meta_effects", {}))
	run_meta_talent_ids.clear()
	var saved_talent_ids = data.get("run_meta_talent_ids", [])
	if saved_talent_ids is Array:
		for talent_id in saved_talent_ids:
			var normalized_talent_id := str(talent_id)
			if MetaProgression.TALENTS.has(normalized_talent_id) and normalized_talent_id not in run_meta_talent_ids:
				run_meta_talent_ids.append(normalized_talent_id)
	run_meta_equipment.clear()
	var saved_equipment = data.get("run_meta_equipment", {})
	if saved_equipment is Dictionary:
		for slot_id in MetaProgression.EQUIPMENT_SLOTS:
			var equipment_id := str(saved_equipment.get(slot_id, ""))
			if MetaProgression.EQUIPMENT.has(equipment_id):
				var equipment_slot := str(MetaProgression.EQUIPMENT[equipment_id].get("slot", ""))
				if equipment_slot == slot_id:
					run_meta_equipment[slot_id] = equipment_id
	credits = maxi(0, int(data.get("credits", 0)))
	credit_points = maxi(0, int(data.get("credit_points", 0)))
	day_count = maxi(1, int(data.get("day_count", 1)))
	last_reward_is_elite = bool(data.get("last_reward_is_elite", false))
	var saved_position = data.get("campus_player_position", [])
	if saved_position is Array and saved_position.size() == 2:
		campus_player_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	else:
		campus_player_position = Vector2(640, 620)
	campus_visited_locations.clear()
	for location_id in data.get("campus_visited_locations", []):
		var normalized_location_id := str(location_id)
		if not normalized_location_id.is_empty() and normalized_location_id not in campus_visited_locations:
			campus_visited_locations.append(normalized_location_id)
	_restore_defeated_enemies(data.get("run_enemies_defeated", []))
	run_battles_won = maxi(run_enemies_defeated.size(), int(data.get("run_battles_won", 0)))
	run_damage_dealt = maxi(0, int(data.get("run_damage_dealt", 0)))
	run_cards_played = maxi(0, int(data.get("run_cards_played", 0)))
	run_events_resolved = maxi(0, int(data.get("run_events_resolved", 0)))
	run_perfect_rebuttals = maxi(0, int(data.get("run_perfect_rebuttals", 0)))
	run_successful_dodges = maxi(0, int(data.get("run_successful_dodges", 0)))
	run_started_at = maxi(0, int(data.get("run_started_at", 0)))
	run_seed = maxi(1, int(data.get("run_seed", 1)) % RUN_SEED_MODULUS)
	run_difficulty = clampi(int(data.get("run_difficulty", 0)), 0, DIFFICULTY_CATALOG.size() - 1)
	run_instance_id = str(data.get("run_instance_id", "")).strip_edges().left(96)
	if run_instance_id.is_empty():
		run_instance_id = "legacy-%d-%d-%s" % [run_started_at, run_seed, player_major_id]
	current_screen = _save_name_to_screen(str(data.get("screen", "")))
	return current_screen != Screen.MENU


func _serializable_player_stats() -> Dictionary:
	var output := {}
	for key in SAVED_PLAYER_STAT_KEYS:
		if player_stats.has(key):
			output[key] = player_stats[key]
	return output


func _sanitize_permanent_stats(value: Variant) -> Dictionary:
	var output := {}
	if value is not Dictionary:
		return output
	for stat_name in STAT_NAMES:
		if value.has(stat_name):
			output[stat_name] = clampi(int(value[stat_name]), -20, 100)
	return output


func _sanitize_meta_effects(value: Variant) -> Dictionary:
	var output := {}
	if value is not Dictionary:
		return output
	for effect_id in SAVED_META_EFFECT_KEYS:
		if value.has(effect_id):
			output[effect_id] = clampi(int(value[effect_id]), 0, 1000)
	return output


func _restore_defeated_enemies(value: Variant) -> void:
	run_enemies_defeated.clear()
	if value is not Array:
		return
	var seen := {}
	for saved_enemy in value:
		if saved_enemy is not Dictionary:
			continue
		var enemy_id := str(saved_enemy.get("id", ""))
		if seen.has(enemy_id) or not Config.enemies.has(enemy_id):
			continue
		var enemy: EnemyResource = Config.enemies[enemy_id]
		run_enemies_defeated.append({
			"id": enemy.id,
			"name": enemy.name,
			"type": enemy.enemy_type,
		})
		seen[enemy_id] = true


func _restore_custom_major(data: Dictionary) -> void:
	var custom_data = data.get("custom_major")
	if custom_data is not Dictionary:
		return
	var major_id := str(data.get("player_major_id", ""))
	if not major_id.begins_with("custom_") or str(custom_data.get("id", "")) != major_id:
		return
	var restored := MajorResource.from_dict(custom_data) as MajorResource
	if restored != null:
		Config.majors[major_id] = restored


func _write_run_save_atomically(data: Dictionary) -> bool:
	var save_path := ProjectSettings.globalize_path(RUN_SAVE_PATH)
	var backup_path := ProjectSettings.globalize_path(RUN_SAVE_BACKUP_PATH)
	var temp_path := ProjectSettings.globalize_path(RUN_SAVE_TEMP_PATH)
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("无法创建一局临时存档：%s" % temp_path)
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
			push_error("无法轮换一局存档备份：%s" % error_string(backup_error))
			return false
	var replace_error := DirAccess.rename_absolute(temp_path, save_path)
	if replace_error == OK:
		return true
	if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(backup_path, save_path)
	push_error("无法提交一局存档：%s" % error_string(replace_error))
	return false


func _read_valid_run_save() -> Dictionary:
	for path in [RUN_SAVE_PATH, RUN_SAVE_BACKUP_PATH]:
		var data := _read_run_save_file(path)
		if not data.is_empty() and is_run_save_snapshot_valid(data):
			return data
	return {}


func _read_run_save_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed as Dictionary if parsed is Dictionary else {}


func _is_run_save_allowed() -> bool:
	if not run_save_enabled:
		return false
	var scene := get_tree().current_scene
	return scene == null or not scene.scene_file_path.begins_with("res://tests/")


func _screen_to_save_name(screen: Screen) -> String:
	match screen:
		Screen.CAMPUS_EXPLORE: return "campus_explore"
		Screen.BATTLE: return "battle"
		Screen.REWARD: return "reward"
		Screen.RESULT: return "result"
		Screen.RUN_SUMMARY: return "run_summary"
	return ""


func _save_name_to_screen(screen_name: String) -> Screen:
	match screen_name:
		"campus_explore": return Screen.CAMPUS_EXPLORE
		"battle": return Screen.BATTLE
		"reward": return Screen.REWARD
		"result": return Screen.RESULT
		"run_summary": return Screen.RUN_SUMMARY
	return Screen.MENU


func start_run(major_id: String, seed_override: int = 0, difficulty: int = 0) -> void:
	player_major_id = major_id
	player_stats = {}
	run_progress = 0
	permanent_stats = {}
	pending_buffs = []
	run_relic_ids.clear()
	run_event_flags.clear()
	run_meta_effects = MetaProgression.get_combined_effects()
	run_meta_talent_ids = MetaProgression.get_equipped_talent_ids()
	run_meta_equipment = MetaProgression.get_equipped_equipment()
	last_reward_is_elite = false
	credits = 120 + get_meta_effect("starting_credits")
	credit_points = 560 + get_meta_effect("starting_credit_points")
	day_count = 1
	campus_player_position = Vector2(640, 620)
	campus_visited_locations.clear()
	run_enemies_defeated.clear()
	run_battles_won = 0
	run_damage_dealt = 0
	run_cards_played = 0
	run_events_resolved = 0
	run_perfect_rebuttals = 0
	run_successful_dodges = 0
	run_started_at = int(Time.get_unix_time_from_system())
	run_instance_id = "%d-%d" % [run_started_at, Time.get_ticks_usec()]
	run_seed = _normalize_run_seed(seed_override)
	run_difficulty = clampi(difficulty, 0, DIFFICULTY_CATALOG.size() - 1)
	_init_run_from_major(major_id)
	current_screen = Screen.CAMPUS_EXPLORE
	save_run_checkpoint(Screen.CAMPUS_EXPLORE)


func _normalize_run_seed(seed_override: int) -> int:
	if seed_override != 0:
		return maxi(1, absi(seed_override) % RUN_SEED_MODULUS)
	var generated := int(Time.get_unix_time_from_system()) + Time.get_ticks_usec()
	return maxi(1, generated % RUN_SEED_MODULUS)


func seed_from_text(text: String) -> int:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return 0
	if not normalized.is_valid_int():
		return -1
	return maxi(1, absi(int(normalized)) % RUN_SEED_MODULUS)


func make_run_rng(stream: String, index: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var value := (run_seed + absi(index) * 1103515245) % RUN_SEED_MODULUS
	for byte in stream.to_utf8_buffer():
		value = (value * 48271 + int(byte) + 1) % RUN_SEED_MODULUS
	rng.seed = maxi(1, value)
	return rng


func get_difficulty_info(difficulty: int = -1) -> Dictionary:
	var index := run_difficulty if difficulty < 0 else difficulty
	index = clampi(index, 0, DIFFICULTY_CATALOG.size() - 1)
	return (DIFFICULTY_CATALOG[index] as Dictionary).duplicate(true)


func get_difficulty_name(difficulty: int = -1) -> String:
	return str(get_difficulty_info(difficulty).get("name", "标准生存"))


func add_relic(relic_id: String) -> void:
	if relic_id.is_empty() or relic_id in run_relic_ids:
		return
	run_relic_ids.append(relic_id)
	# 即时生效类
	if relic_id == "gym_bracelet":
		run_max_hp += 8
		heal_run(8)


func has_relic(relic_id: String) -> bool:
	return relic_id in run_relic_ids


func add_event_flag(flag_id: String) -> void:
	var normalized := flag_id.strip_edges()
	if normalized.is_empty() or normalized.length() > 64 or normalized in run_event_flags:
		return
	run_event_flags.append(normalized)


func has_event_flag(flag_id: String) -> bool:
	return flag_id in run_event_flags


func record_enemy_defeat(enemy_id: String, enemy_name: String, enemy_type: String) -> void:
	run_battles_won += 1
	run_enemies_defeated.append({
		"id": enemy_id,
		"name": enemy_name,
		"type": enemy_type,
	})
	last_reward_is_elite = enemy_type in ["elite", "ai_native", "boss"]
	# 资源收益
	var resource_bonus := get_effective_stat("资源")
	var social_bonus := get_effective_stat("社交")
	var credit_gain := 8 + resource_bonus
	var point_gain := 12 + social_bonus
	if last_reward_is_elite:
		credit_gain *= 2
		point_gain *= 2
	if has_relic("mentor_letter"):
		credit_gain = int(credit_gain * 1.5)
		point_gain = int(point_gain * 1.5)
	var reward_multiplier := float(get_difficulty_info().get("reward_multiplier", 1.0))
	credit_gain = int(round(float(credit_gain) * reward_multiplier))
	point_gain = int(round(float(point_gain) * reward_multiplier))
	credits += credit_gain
	credit_points += point_gain
	var was_elite := last_reward_is_elite
	Achievements.try_after_battle_win(enemy_id, was_elite)


func _init_run_from_major(major_id: String) -> void:
	var major: MajorResource = Config.majors[major_id]
	var base_hp := 60 + int(major.stats.get("体能", 5)) * 3
	var base_spirit := 100 + int(major.stats.get("抗压", 5)) * 5
	base_hp += get_meta_effect("max_hp")
	base_spirit += get_meta_effect("max_spirit")
	run_max_hp = base_hp
	run_hp = base_hp
	run_max_spirit = base_spirit
	run_spirit = base_spirit
	deck_card_ids.clear()
	for card_id in major.starter_deck:
		deck_card_ids.append(str(card_id))


func get_effective_stat(stat_name: String) -> int:
	var major: MajorResource = Config.majors[player_major_id]
	var base: int = int(major.stats.get(stat_name, 5))
	return base + int(permanent_stats.get(stat_name, 0)) + get_meta_effect("stat_%s" % stat_name)


func get_meta_effect(effect_id: String) -> int:
	return maxi(0, int(run_meta_effects.get(effect_id, 0)))


func create_battle_player() -> Character:
	if not Config.majors.has(player_major_id):
		push_error("无法创建战斗角色，未知专业: %s" % player_major_id)
		return null

	var major: MajorResource = Config.majors[player_major_id]
	var player := Character.new("player", "玩家", run_max_hp, true)
	player.major_id = player_major_id
	player.max_hp = run_max_hp
	player.hp = clampi(run_hp, 0, run_max_hp)
	player.max_spirit = run_max_spirit
	player.spirit = clampi(run_spirit, 0, run_max_spirit)
	player.gain_shield(get_meta_effect("opening_shield"))
	if get_meta_effect("opening_resistance") > 0:
		player.add_status("resistance", get_meta_effect("opening_resistance"))

	var card_ids: Array = deck_card_ids
	if card_ids.is_empty():
		card_ids = major.starter_deck
	for card_id in card_ids:
		var card = Config.cards.get(str(card_id))
		if card != null:
			player.deck.append(card)

	for buff in pending_buffs:
		var status_id := str(buff.get("status_id", ""))
		var stacks := int(buff.get("stacks", 1))
		if status_id == "shield":
			player.gain_shield(stacks)
		else:
			player.add_status(status_id, stacks)
	pending_buffs.clear()

	var enemy_id := str(player_stats.get("current_enemy_id", "unassigned"))
	player.set_rng(make_run_rng("deck:%s" % enemy_id, run_battles_won))
	player.draw_pile = player.deck.duplicate()
	player.shuffle_draw_pile()
	return player


func heal_run(amount: int) -> int:
	var healing_multiplier := float(get_difficulty_info().get("campus_healing_multiplier", 1.0))
	amount = maxi(0, int(round(float(amount) * healing_multiplier)))
	var before := run_hp
	run_hp = mini(run_hp + amount, run_max_hp)
	return run_hp - before


func damage_run(amount: int) -> int:
	var before := run_hp
	run_hp = maxi(run_hp - amount, 0)
	return before - run_hp


func lose_spirit_run(amount: int) -> void:
	run_spirit = clampi(run_spirit - amount, 0, run_max_spirit)


func gain_spirit_run(amount: int) -> void:
	run_spirit = clampi(run_spirit + amount, 0, run_max_spirit)


func add_card_to_deck(card_id: String) -> void:
	if card_id.is_empty():
		return
	deck_card_ids.append(card_id)


func add_pending_buff(status_id: String, stacks: int) -> void:
	pending_buffs.append({"status_id": status_id, "stacks": stacks})


func sync_from_battle_character(player: Character) -> void:
	if player == null:
		return
	run_hp = player.hp
	run_max_hp = player.max_hp
	run_spirit = player.spirit
	run_max_spirit = player.max_spirit


func change_screen(screen: Screen) -> void:
	if screen == Screen.SETTINGS:
		_open_settings_overlay()
		return
	_dismiss_settings_overlay()
	if screen == Screen.MENU and current_screen == Screen.RUN_SUMMARY:
		clear_run_save()
	current_screen = screen
	if _screen_to_save_name(screen) != "":
		save_run_checkpoint(screen)
	var scene_path := _screen_to_path(screen)
	get_tree().change_scene_to_file(scene_path)


func return_from_settings() -> void:
	if is_instance_valid(_settings_overlay):
		var target := settings_return_screen
		_dismiss_settings_overlay()
		current_screen = Screen.MENU if target == Screen.SETTINGS else target
		return
	var target := settings_return_screen
	if target == Screen.SETTINGS:
		target = Screen.MENU
	change_screen(target)


func _open_settings_overlay() -> void:
	if is_instance_valid(_settings_overlay):
		return
	settings_return_screen = current_screen
	var current_scene := get_tree().current_scene
	if current_scene == null:
		current_screen = Screen.SETTINGS
		get_tree().change_scene_to_file(_screen_to_path(Screen.SETTINGS))
		return
	var packed := load("res://src/ui/screens/settings.tscn") as PackedScene
	_settings_overlay = packed.instantiate() as Control
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_settings_overlay.z_index = 1000
	current_scene.add_child(_settings_overlay)
	_settings_previous_pause_state = get_tree().paused
	get_tree().paused = true
	current_screen = Screen.SETTINGS


func _dismiss_settings_overlay() -> void:
	if not is_instance_valid(_settings_overlay):
		_settings_overlay = null
		return
	get_tree().paused = _settings_previous_pause_state
	_settings_overlay.queue_free()
	_settings_overlay = null


func _screen_to_path(screen: Screen) -> String:
	match screen:
		Screen.MENU: return "res://src/ui/screens/menu.tscn"
		Screen.MAJOR_SELECT: return "res://src/ui/screens/major_select.tscn"
		Screen.CAMPUS_EXPLORE: return "res://src/ui/screens/campus_explore.tscn"
		Screen.BATTLE: return "res://src/ui/screens/battle.tscn"
		Screen.REWARD: return "res://src/ui/screens/reward.tscn"
		Screen.SETTINGS: return "res://src/ui/screens/settings.tscn"
		Screen.RESULT: return "res://src/ui/screens/result.tscn"
		Screen.ACHIEVEMENTS: return "res://src/ui/screens/achievements.tscn"
		Screen.RUN_SUMMARY: return "res://src/ui/screens/run_summary.tscn"
		Screen.META_PROGRESSION: return "res://src/ui/screens/meta_progression.tscn"
	return "res://src/ui/screens/menu.tscn"
