extends Control
class_name PressureMinimap
## 压力圈小地图：随 run_progress 收缩的危险环。

func _ready() -> void:
	custom_minimum_size = Vector2(140, 140)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := mini(size.x, size.y) * 0.42
	# 外圈校园
	draw_arc(center, radius, 0, TAU, 48, UIColors.BORDER_CYAN_DIM, 2.0, true)
	# 区域点
	var area_colors := [
		Color.SKY_BLUE, Color.LIGHT_CORAL, Color.WHEAT, Color.LIGHT_GREEN, Color.ORANGE
	]
	for i in 5:
		var ang := -PI / 2.0 + i * TAU / 5.0
		var p := center + Vector2(cos(ang), sin(ang)) * (radius * 0.55)
		draw_circle(p, 5.0, area_colors[i])
	# 压力圈（进度越高半径越小）
	var progress := clampf(float(GameState.run_progress) / 12.0, 0.0, 0.85)
	var danger_r := radius * (1.0 - progress * 0.7)
	draw_arc(center, danger_r, 0, TAU, 48, UIColors.DANGER_RED, 3.0, true)
	draw_circle(center, 4.0, UIColors.SPIRIT_BLUE)
