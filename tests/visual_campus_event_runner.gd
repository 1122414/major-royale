extends Node
## 校园事件面板人工验收入口。


func _ready() -> void:
	GameState.start_run("computer")
	var campus = (load("res://src/ui/screens/campus_explore.tscn") as PackedScene).instantiate()
	add_child(campus)
	await get_tree().process_frame
	var dorm: CampusHotspot = campus.get_node("World/Hotspots/Dorm")
	campus._on_hotspot_activated(dorm)
