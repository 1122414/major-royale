class_name WorldResource
extends Resource

## 世界包定义：声明一个世界的角色、共享内容、入口场景与局内状态边界。

@export var id: String = ""
@export var name: String = ""
@export var chapter_title: String = ""
@export var description: String = ""
@export var theme_id: String = ""
@export var rule_set_id: String = ""
@export var fragment_id: String = ""
@export var fragment_name: String = ""
@export var availability: String = "available"
@export var selection_scene_path: String = ""
@export var exploration_scene_path: String = ""
@export var character_ids: Array[String] = []
@export var shared_card_ids: Array[String] = []
@export var run_state_schema: Dictionary = {}
@export var rule_catalog: Dictionary = {}


func load_from_dict(data: Dictionary) -> void:
	id = str(data.get("id", "")).strip_edges()
	name = str(data.get("name", "")).strip_edges()
	chapter_title = str(data.get("chapter_title", "")).strip_edges()
	description = str(data.get("description", "")).strip_edges()
	theme_id = str(data.get("theme_id", id)).strip_edges()
	rule_set_id = str(data.get("rule_set_id", id)).strip_edges()
	fragment_id = str(data.get("fragment_id", "")).strip_edges()
	fragment_name = str(data.get("fragment_name", "")).strip_edges()
	availability = str(data.get("availability", "available")).strip_edges()
	if availability not in ["available", "foundation"]:
		availability = "foundation"
	selection_scene_path = str(data.get("selection_scene_path", "")).strip_edges()
	exploration_scene_path = str(data.get("exploration_scene_path", "")).strip_edges()
	character_ids = _to_unique_string_array(data.get("character_ids", []))
	shared_card_ids = _to_unique_string_array(data.get("shared_card_ids", []))
	var schema = data.get("run_state_schema", {})
	run_state_schema = schema.duplicate(true) if schema is Dictionary else {}
	var catalog = data.get("rule_catalog", {})
	rule_catalog = catalog.duplicate(true) if catalog is Dictionary else {}


func has_character(character_id: String) -> bool:
	return character_id in character_ids


func is_playable() -> bool:
	return availability == "available" and not character_ids.is_empty() and not selection_scene_path.is_empty() and not exploration_scene_path.is_empty()


func get_rule_catalog_entries(catalog_key: String) -> Array[Dictionary]:
	var source = rule_catalog.get(catalog_key, [])
	var output: Array[Dictionary] = []
	if source is not Array:
		return output
	for entry in source:
		if entry is Dictionary:
			output.append((entry as Dictionary).duplicate(true))
	return output


func create_initial_run_state() -> Dictionary:
	return sanitize_run_state({})


func sanitize_run_state(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var output := {}
	for state_key in run_state_schema:
		var rule = run_state_schema[state_key]
		if rule is not Dictionary:
			continue
		var key := str(state_key)
		var default_value = rule.get("default")
		var raw_value = source.get(key, default_value)
		match str(rule.get("type", "")):
			"int":
				var min_value := int(rule.get("min", -2147483648))
				var max_value := int(rule.get("max", 2147483647))
				output[key] = clampi(int(raw_value), min_value, max_value)
			"float":
				var min_value := float(rule.get("min", -1.0e20))
				var max_value := float(rule.get("max", 1.0e20))
				output[key] = clampf(float(raw_value), min_value, max_value)
			"bool":
				output[key] = bool(raw_value)
			"string":
				var normalized := str(raw_value).strip_edges().left(int(rule.get("max_length", 96)))
				var allowed_values = rule.get("allowed_values", [])
				if allowed_values is Array and not allowed_values.is_empty():
					var allowed := _to_unique_string_array(allowed_values)
					var default_normalized := str(default_value).strip_edges().left(int(rule.get("max_length", 96)))
					output[key] = normalized if normalized in allowed else default_normalized
				else:
					output[key] = normalized
	return output


static func _to_unique_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is not Array:
		return output
	for item in value:
		var normalized := str(item).strip_edges()
		if not normalized.is_empty() and normalized not in output:
			output.append(normalized)
	return output
