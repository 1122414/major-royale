extends Node
## 验证桌面关闭请求会先释放音频流，再退出 SceneTree。


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for _frame in 3:
		await get_tree().process_frame
	print("QUIT: 开始执行统一退出清理")
	AudioManager.request_application_quit()
