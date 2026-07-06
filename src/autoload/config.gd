extends Node
## 全局配置加载器：读取 JSON 数据并解析为自定义 Resource。

const GAME_CFG_PATH := "res://config/game.cfg"
const DATA_DIR := "res://data"

const MajorResourceScript := preload("res://src/resources/major_resource.gd")
const CardResourceScript := preload("res://src/resources/card_resource.gd")
const CardEffectScript := preload("res://src/resources/card_effect.gd")
const EnemyResourceScript := preload("res://src/resources/enemy_resource.gd")
const EventResourceScript := preload("res://src/resources/event_resource.gd")

var _game_cfg: ConfigFile

## 专业 ID -> MajorResource
var majors: Dictionary = {}
## 卡牌 ID -> CardResource
var cards: Dictionary = {}
## 敌人 ID -> EnemyResource
var enemies: Dictionary = {}
## 事件 ID -> EventResource
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
	majors = _load_major_folder("%s/majors" % DATA_DIR)
	cards = _load_card_folder("%s/cards" % DATA_DIR)
	enemies = _load_enemy_folder("%s/enemies" % DATA_DIR)
	events = _load_event_folder("%s/events" % DATA_DIR)


func _load_major_folder(folder_path: String) -> Dictionary:
	var result := {}
	for file_name in _list_json_files(folder_path):
		var data := _load_json_file("%s/%s" % [folder_path, file_name])
		if data.is_empty():
			continue
		var major = MajorResourceScript.from_dict(data)
		if major.id != "":
			result[major.id] = major
	return result


func _load_card_folder(folder_path: String) -> Dictionary:
	var result := {}
	for file_name in _list_json_files(folder_path):
		var data := _load_json_file("%s/%s" % [folder_path, file_name])
		if data.is_empty():
			continue

		var card_list: Array = []
		if data.has("cards"):
			card_list = data["cards"]
		else:
			card_list.append(data)

		for card_dict in card_list:
			if card_dict is Dictionary:
				var card = CardResourceScript.from_dict(card_dict)
				if card.id != "":
					result[card.id] = card
	return result


func _load_enemy_folder(folder_path: String) -> Dictionary:
	var result := {}
	for file_name in _list_json_files(folder_path):
		var data := _load_json_file("%s/%s" % [folder_path, file_name])
		if data.is_empty():
			continue

		var enemy_list: Array = []
		if data.has("enemies"):
			enemy_list = data["enemies"]
		else:
			enemy_list.append(data)

		for enemy_dict in enemy_list:
			if enemy_dict is Dictionary:
				var enemy = EnemyResourceScript.from_dict(enemy_dict)
				if enemy.id != "":
					result[enemy.id] = enemy
	return result


func _load_event_folder(folder_path: String) -> Dictionary:
	var result := {}
	for file_name in _list_json_files(folder_path):
		var data := _load_json_file("%s/%s" % [folder_path, file_name])
		if data.is_empty():
			continue

		var event_list: Array = []
		if data.has("events"):
			event_list = data["events"]
		else:
			event_list.append(data)

		for event_dict in event_list:
			if event_dict is Dictionary:
				var event = EventResourceScript.from_dict(event_dict)
				if event.id != "":
					result[event.id] = event
	return result


func _list_json_files(folder_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("无法打开数据目录: %s" % folder_path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			result.append(file_name)
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
