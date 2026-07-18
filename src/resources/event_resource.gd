class_name EventResource
extends Resource

## 事件资源定义。

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var area: String = ""  ## dorm, classroom, library, cafeteria, playground
@export var effects: Array[Dictionary] = []
@export var choices: Array[Dictionary] = []
@export var requires_flags: Array[String] = []
@export var priority_flags: Array[String] = []


static func from_dict(data: Dictionary) -> Resource:
	var event := EventResource.new()
	event.id = data.get("id", "")
	event.name = data.get("name", "")
	event.description = data.get("description", "")
	event.area = data.get("area", "")
	event.effects = _to_dict_array(data.get("effects", []))
	event.choices = _to_dict_array(data.get("choices", []))
	for flag in data.get("requires_flags", []):
		event.requires_flags.append(str(flag))
	for flag in data.get("priority_flags", []):
		event.priority_flags.append(str(flag))
	return event


static func _to_dict_array(arr: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in arr:
		if item is Dictionary:
			result.append(item)
	return result
