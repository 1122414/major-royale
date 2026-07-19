extends Node
## 局外成长页面人工验收入口，可生成稳定截图。


func _ready() -> void:
	var screenshot_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			screenshot_path = argument.trim_prefix("--screenshot=")

	MetaProgression.save_enabled = false
	MetaProgression.reset_profile()
	MetaProgression.grant_gold(680)
	for talent_id in ["healthy_routine", "organized_notes", "pressure_drill"]:
		MetaProgression.purchase_talent(talent_id)
	MetaProgression.equip_talent("healthy_routine")
	MetaProgression.equip_talent("organized_notes")
	for equipment_id in ["graphing_calculator", "sports_pin", "family_photo"]:
		MetaProgression.purchase_equipment(equipment_id)
		MetaProgression.equip_equipment(equipment_id)
	MetaProgression.purchase_upgrade("survival_training")
	MetaProgression.purchase_upgrade("survival_training")
	MetaProgression.purchase_upgrade("alumni_network")

	var screen := (load("res://src/ui/screens/meta_progression.tscn") as PackedScene).instantiate()
	add_child(screen)
	if screenshot_path.is_empty():
		return
	for _frame in 5:
		await get_tree().process_frame
	var absolute_path := ProjectSettings.globalize_path(screenshot_path)
	var error := get_viewport().get_texture().get_image().save_jpg(absolute_path, 0.94)
	assert(error == OK, "视觉验收截图保存失败: %s" % absolute_path)
	print("VISUAL: 截图已保存到 %s" % absolute_path)
	screen.queue_free()
	MetaProgression.reset_profile()
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
