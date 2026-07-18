extends Node
## 设置与可访问性页面人工验收入口。


func _ready() -> void:
	var screenshot_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			screenshot_path = argument.trim_prefix("--screenshot=")
	var settings_screen := (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()
	add_child(settings_screen)
	if screenshot_path.is_empty():
		return
	for _frame in 4:
		await get_tree().process_frame
	var absolute_path := ProjectSettings.globalize_path(screenshot_path)
	var error := get_viewport().get_texture().get_image().save_jpg(absolute_path, 0.94)
	assert(error == OK, "视觉验收截图保存失败: %s" % absolute_path)
	print("VISUAL: 截图已保存到 %s" % absolute_path)
	settings_screen.queue_free()
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
