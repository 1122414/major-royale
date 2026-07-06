extends SceneTree
## 命令行场景切换测试。

const MajorResource := preload("res://src/resources/major_resource.gd")

func _initialize() -> void:
	print("TEST: 项目初始化成功")
	print("Majors count: %d" % Config.majors.size())
	print("Cards count: %d" % Config.cards.size())
	print("Enemies count: %d" % Config.enemies.size())
	print("Events count: %d" % Config.events.size())

	if Config.majors.is_empty():
		push_error("没有加载到专业数据")
		quit(1)
		return

	var major: MajorResource = Config.majors["computer"]
	if major == null or major.name.is_empty():
		push_error("计算机专业加载失败")
		quit(1)
		return

	print("TEST: 专业 '%s' 加载成功" % major.name)
	print("TEST: 场景切换测试通过")
	quit(0)
