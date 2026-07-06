extends ColorRect
## 像素风格背景：深色底 + 网格线。

func _ready() -> void:
	color = Color(0.06, 0.08, 0.1, 1)
	mouse_filter = MOUSE_FILTER_IGNORE
	_queue_redraw()


func _queue_redraw() -> void:
	queue_redraw()


func _draw() -> void:
	var grid_color := Color(0.1, 0.15, 0.2, 1)
	var grid_size := 40
	for x in range(0, int(size.x), grid_size):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(0, int(size.y), grid_size):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
