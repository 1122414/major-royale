class_name CampusHotspot
extends Area2D
## 建筑入口热点：独立图标、碰撞范围、近距离提示与激活信号。

signal proximity_changed(hotspot: CampusHotspot, is_near: bool)
signal activated(hotspot: CampusHotspot)

@export var location_id := ""
@export var display_name := "地点"
@export var description := ""
@export var icon_path := ""
@export var action_id := "inspect"

@onready var icon: Sprite2D = $Icon
@onready var name_label: Label = $NamePlate/NameLabel

var _player_near := false
var _pulse_time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	name_label.text = display_name
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)


func _process(delta: float) -> void:
	_pulse_time += delta
	var pulse := 0.68 + sin(_pulse_time * 2.4) * 0.025
	icon.scale = Vector2.ONE * pulse


func is_player_near() -> bool:
	return _player_near


func activate() -> void:
	if _player_near:
		activated.emit(self)


func set_visited(is_visited: bool) -> void:
	name_label.add_theme_color_override("font_color", UIColors.ACCENT_GOLD if is_visited else UIColors.TEXT_PRIMARY)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("campus_player"):
		return
	_player_near = true
	proximity_changed.emit(self, true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("campus_player"):
		return
	_player_near = false
	proximity_changed.emit(self, false)
