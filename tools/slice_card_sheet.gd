extends SceneTree
## 将 imagegen 等距卡牌表按网格切成运行时使用的 256×256 PNG。


func _initialize() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var sheet_path := str(options.get("sheet", ""))
	var output_path := str(options.get("output", "res://assets/sprites/cards"))
	var ids := str(options.get("ids", "")).split(",", false)
	var columns := int(options.get("columns", 4))
	var rows := int(options.get("rows", 4))
	if sheet_path.is_empty() or ids.size() != columns * rows:
		push_error("用法：--sheet=路径 --columns=4 --rows=4 --ids=id1,id2,... [--output=res://目录]")
		quit(1)
		return

	var sheet := Image.new()
	var load_error := sheet.load(sheet_path)
	if load_error != OK:
		push_error("无法读取卡牌表：%s（%s）" % [sheet_path, error_string(load_error)])
		quit(1)
		return

	var absolute_output := ProjectSettings.globalize_path(output_path)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if mkdir_error != OK:
		push_error("无法创建输出目录：%s（%s）" % [absolute_output, error_string(mkdir_error)])
		quit(1)
		return

	for index in ids.size():
		var column := index % columns
		var row := index / columns
		var left := roundi(float(column) * float(sheet.get_width()) / float(columns))
		var right := roundi(float(column + 1) * float(sheet.get_width()) / float(columns))
		var top := roundi(float(row) * float(sheet.get_height()) / float(rows))
		var bottom := roundi(float(row + 1) * float(sheet.get_height()) / float(rows))
		var card_image := sheet.get_region(Rect2i(left, top, right - left, bottom - top))
		card_image.resize(256, 256, Image.INTERPOLATE_NEAREST)
		var save_path := absolute_output.path_join("%s.png" % ids[index])
		var save_error := card_image.save_png(save_path)
		if save_error != OK:
			push_error("无法保存卡牌插画：%s（%s）" % [save_path, error_string(save_error)])
			quit(1)
			return
	print("CARD_SHEET: 已输出 %d 张卡牌插画到 %s" % [ids.size(), absolute_output])
	quit()


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var options := {}
	for argument in arguments:
		if not argument.begins_with("--") or "=" not in argument:
			continue
		var separator := argument.find("=")
		options[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return options
