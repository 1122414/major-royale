class_name EventResource
extends Resource

## 事件资源定义。

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var area: String = ""  ## dorm, classroom, library, cafeteria, playground
@export var effects: Array[Dictionary] = []
@export var choices: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> Resource:
	var event := EventResource.new()
	event.id = data.get("id", "")
	event.name = data.get("name", "")
	event.description = data.get("description", "")
	event.area = data.get("area", "")
	event.effects = _to_dict_array(data.get("effects", []))
	event.choices = _to_dict_array(data.get("choices", []))
	return event


static func _to_dict_array(arr: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in arr:
		if item is Dictionary:
			result.append(item)
	return result
