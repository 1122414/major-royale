class_name MajorResource
extends Resource

## 专业资源定义。

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var stats: Dictionary = {}  ## 八维属性
@export var active_skill: Dictionary = {}
@export var passive_skill: Dictionary = {}
@export var starter_deck: Array[String] = []
@export var starter_relic_id: String = ""
@export var run_state_schema: Dictionary = {}
@export var portrait_path: String = ""


static func from_dict(data: Dictionary) -> Resource:
	var major := MajorResource.new()
	major.id = data.get("id", "")
	major.name = data.get("name", "")
	major.description = data.get("description", "")
	major.stats = data.get("stats", {})
	major.active_skill = data.get("active_skill", {})
	major.passive_skill = data.get("passive_skill", {})
	major.starter_relic_id = str(data.get("starter_relic_id", "")).strip_edges()
	var schema = data.get("run_state_schema", {})
	major.run_state_schema = schema.duplicate(true) if schema is Dictionary else {}
	major.portrait_path = str(data.get("portrait_path", "")).strip_edges()

	var deck: Array = data.get("starter_deck", [])
	for card_id in deck:
		major.starter_deck.append(str(card_id))
	return major


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
				output[key] = clampi(int(raw_value), int(rule.get("min", -2147483648)), int(rule.get("max", 2147483647)))
			"bool":
				output[key] = bool(raw_value)
			"string":
				var normalized := str(raw_value).strip_edges().left(int(rule.get("max_length", 96)))
				var allowed_values = rule.get("allowed_values", [])
				if allowed_values is Array and not allowed_values.is_empty() and normalized not in allowed_values:
					normalized = str(default_value).strip_edges().left(int(rule.get("max_length", 96)))
				output[key] = normalized
	return output
