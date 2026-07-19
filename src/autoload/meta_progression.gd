extends Node
## 局外成长档案：保存永久金币，并负责一局结束后的幂等奖励结算。

signal profile_changed

const PROFILE_SAVE_VERSION := 1
const PROFILE_SAVE_PATH := "user://meta_progression.json"
const PROFILE_SAVE_BACKUP_PATH := "user://meta_progression.backup.json"
const PROFILE_SAVE_TEMP_PATH := "user://meta_progression.tmp.json"
const MAX_SETTLED_RUNS := 40

var gold: int = 0
var settled_runs: Dictionary = {}  ## run_token -> {earned, settled_at}
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


func calculate_run_gold(
	battles_won: int,
	events_resolved: int,
	difficulty: int,
	is_clear: bool,
) -> int:
	var reward := 4
	reward += maxi(0, battles_won) * 3
	reward += maxi(0, events_resolved)
	reward += maxi(0, difficulty) * 4
	if is_clear:
		reward += 20
	return reward


func settle_current_run(is_clear: bool) -> Dictionary:
	var run_token := _make_run_token(
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
	_trim_settled_runs()
	profile_changed.emit()
	return true


func reset_profile() -> void:
	gold = 0
	settled_runs.clear()
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
