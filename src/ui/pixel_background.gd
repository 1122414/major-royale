extends ColorRect
## 像素风格背景：深色底 + 细网格。

func _ready() -> void:
	color = UIColors.BG_DEEP
	mouse_filter = MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var grid_color := Color(UIColors.BORDER_CYAN_DIM.r, UIColors.BORDER_CYAN_DIM.g, UIColors.BORDER_CYAN_DIM.b, 0.25)
	var grid_size := 40
	for x in range(0, int(size.x) + 1, grid_size):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(0, int(size.y) + 1, grid_size):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
