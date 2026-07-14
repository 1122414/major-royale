extends TextureRect
class_name SceneBackground
## 场景底图：像素纹理 + 深色叠层，保证 UI 可读。

@export var texture_path: String = "res://assets/sprites/bg/menu_campus.png"
@export var dim: float = 0.35


func _ready() -> void:
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_SCALE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# dim overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, dim)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)
