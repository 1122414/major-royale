class_name CampusPlayer
extends CharacterBody2D
## 校园世界玩家：八方向移动、碰撞、朝向与轻量像素步行动效。

@export var move_speed := 190.0
@export var world_bounds := Rect2(28, 88, 1224, 604)

@onready var sprite: Sprite2D = $Sprite

var controls_enabled := true
var _walk_time := 0.0


func _ready() -> void:
	add_to_group("campus_player")


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if controls_enabled:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction.normalized() * move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, world_bounds.position.x, world_bounds.end.x)
	global_position.y = clampf(global_position.y, world_bounds.position.y, world_bounds.end.y)

	if absf(direction.x) > 0.05:
		sprite.flip_h = direction.x < 0.0
	if direction.length_squared() > 0.01:
		_walk_time += delta * 12.0
		sprite.position.y = -44.0 + sin(_walk_time) * 1.5
	else:
		sprite.position.y = move_toward(sprite.position.y, -44.0, delta * 12.0)
