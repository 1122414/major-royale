extends Node
## 全局配置加载器：读取 JSON 数据与游戏常量。

const GAME_CFG_PATH := "res://config/game.cfg"
const DATA_DIR := "res://data"

var _game_cfg: ConfigFile
var majors: Dictionary = {}
var cards: Dictionary = {}
var enemies: Dictionary = {}
var events: Dictionary = {}


func _ready() -> void:
	_load_game_cfg()
	_load_all_json_data()
	print("Config loaded. Majors: %d, Cards: %d, Enemies: %d, Events: %d" % [
		majors.size(), cards.size(), enemies.size(), events.size()
	])


func _load_game_cfg() -> void:
	_game_cfg = ConfigFile.new()
	var err := _game_cfg.load(GAME_CFG_PATH)
	if err != OK:
		push_error("无法加载游戏配置文件: %s" % GAME_CFG_PATH)


func get_game_value(section: String, key: String, default_value: Variant = null) -> Variant:
	return _game_cfg.get_value(section, key, default_value)


func _load_all_json_data() -> void:
	majors = _load_json_folder("%s/majors" % DATA_DIR)
	cards = _load_json_folder("%s/cards" % DATA_DIR)
	enemies = _load_json_folder("%s/enemies" % DATA_DIR)
	events = _load_json_folder("%s/events" % DATA_DIR)


func _load_json_folder(folder_path: String) -> Dictionary:
	var result := {}
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("无法打开数据目录: %s" % folder_path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := "%s/%s" % [folder_path, file_name]
			var data := _load_json_file(full_path)
			if data.has("id"):
				result[data.id] = data
			else:
				push_warning("JSON 缺少 id 字段: %s" % full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取 JSON 文件: %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON 解析失败 %s: %s" % [path, json.get_error_message()])
		return {}
	return json.data as Dictionary
