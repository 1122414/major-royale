extends Node
## 校园事件面板人工验收入口。


func _ready() -> void:
	var screenshot_path := ""
	var show_event := true
	var event_id := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			screenshot_path = argument.trim_prefix("--screenshot=")
		elif argument.begins_with("--event="):
			event_id = argument.trim_prefix("--event=")
		elif argument == "--no-event":
			show_event = false
	GameState.start_run("computer")
	var campus = (load("res://src/ui/screens/campus_explore.tscn") as PackedScene).instantiate()
	add_child(campus)
	await get_tree().process_frame
	if show_event:
		var dorm: CampusHotspot = campus.get_node("World/Hotspots/Dorm")
		if not event_id.is_empty() and Config.events.has(event_id):
			campus._current_event = Config.events[event_id]
			campus._pending_hotspot = dorm
			campus.hud.show_event(dorm.display_name, campus._current_event)
		else:
			campus._on_hotspot_activated(dorm)
	if screenshot_path.is_empty():
		return
	for _frame in 3:
		await get_tree().process_frame
	var absolute_path := ProjectSettings.globalize_path(screenshot_path)
	var error := get_viewport().get_texture().get_image().save_jpg(absolute_path, 0.94)
	assert(error == OK, "视觉验收截图保存失败: %s" % absolute_path)
	print("VISUAL: 截图已保存到 %s" % absolute_path)
	campus.queue_free()
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
