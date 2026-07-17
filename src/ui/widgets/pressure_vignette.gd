class_name PressureVignette
extends Control
## 屏幕边缘压力警示；强度由局内压力进度驱动。

var pressure := 0


func set_pressure(value: int) -> void:
	pressure = maxi(0, value)
	queue_redraw()


func _draw() -> void:
	var intensity := clampf(float(pressure) / 12.0, 0.0, 1.0)
	if intensity <= 0.0:
		return
	for index in 8:
		var inset := float(index * 9)
		var alpha := intensity * 0.12 * (1.0 - float(index) / 8.0)
		var rect := Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0)
		draw_rect(rect, Color(UIColors.DANGER_RED, alpha), false, 10.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(UIColors.DANGER_RED, intensity * 0.035), true)
