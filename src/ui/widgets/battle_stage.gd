class_name BattleStage
extends Control
## 战斗舞台表现层：角色贴图、站位与攻防动画，不读取或修改战斗数值。

@onready var player_figure: TextureRect = $PlayerFigure
@onready var enemy_figure: TextureRect = $EnemyFigure
@onready var ai_pressure_zone: Polygon2D = $AIPressureZone
@onready var ai_pressure_core: Polygon2D = $AIPressureCore
@onready var lane_zones: Array[ColorRect] = [$LaneZones/Left, $LaneZones/Center, $LaneZones/Right]

var _pressure_tween: Tween
var _lane_tween: Tween
var _player_base_position := Vector2.ZERO


func _ready() -> void:
	_player_base_position = player_figure.position
	_start_idle(player_figure, -0.012)
	_start_idle(enemy_figure, 0.012)


func setup_art(player_path: String, enemy_path: String) -> void:
	_set_texture(player_figure, player_path)
	_set_texture(enemy_figure, enemy_path)


func set_ai_mode(enabled: bool) -> void:
	ai_pressure_zone.visible = enabled
	ai_pressure_core.visible = enabled
	if _pressure_tween and _pressure_tween.is_valid():
		_pressure_tween.kill()
	if not enabled:
		return
	ai_pressure_zone.scale = Vector2.ONE
	ai_pressure_core.scale = Vector2.ONE
	_pressure_tween = create_tween().set_loops()
	_pressure_tween.set_parallel(true)
	_pressure_tween.tween_property(ai_pressure_zone, "scale", Vector2(1.08, 1.18), 0.9).set_trans(Tween.TRANS_SINE)
	_pressure_tween.tween_property(ai_pressure_zone, "modulate:a", 0.45, 0.9)
	_pressure_tween.chain().set_parallel(true)
	_pressure_tween.tween_property(ai_pressure_zone, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	_pressure_tween.tween_property(ai_pressure_zone, "modulate:a", 1.0, 0.9)


func show_defense_lanes(danger_lane: int, player_lane: int) -> void:
	$LaneZones.visible = true
	for i in lane_zones.size():
		var zone := lane_zones[i]
		if i == danger_lane and i == player_lane:
			zone.color = Color(1.0, 0.45, 0.12, 0.62)
		elif i == danger_lane:
			zone.color = Color(0.92, 0.12, 0.15, 0.48)
		elif i == player_lane:
			zone.color = Color(0.0, 0.82, 0.88, 0.52)
		else:
			zone.color = Color(0.02, 0.15, 0.18, 0.34)
	_move_player_to_lane(player_lane)


func hide_defense_lanes(outcome: String = "") -> void:
	$LaneZones.visible = false
	if _lane_tween and _lane_tween.is_valid():
		_lane_tween.kill()
	_lane_tween = create_tween()
	_lane_tween.tween_property(player_figure, "position", _player_base_position, 0.12).set_trans(Tween.TRANS_SINE)
	if outcome == "perfect":
		pulse_figure(false, Color(1.35, 1.18, 0.5))
	elif outcome == "dodge":
		pulse_figure(false, Color(0.55, 1.25, 1.35))


func _move_player_to_lane(player_lane: int) -> void:
	if _lane_tween and _lane_tween.is_valid():
		_lane_tween.kill()
	var target := _player_base_position + Vector2(float(clampi(player_lane, 0, 2) - 1) * 72.0, 0)
	_lane_tween = create_tween()
	_lane_tween.tween_property(player_figure, "position", target, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_texture(target: TextureRect, path: String) -> void:
	if not ResourceLoader.exists(path):
		target.texture = null
		return
	target.texture = load(path)


func play_attack(from_player: bool) -> void:
	var attacker: Control = player_figure if from_player else enemy_figure
	var defender: Control = enemy_figure if from_player else player_figure
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	attacker.pivot_offset = attacker.size * 0.5
	defender.pivot_offset = defender.size * 0.5
	var base := attacker.position
	var defender_base := defender.position
	var direction := (defender.position - attacker.position).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector2.RIGHT if from_player else Vector2.LEFT

	var attack_tween := create_tween()
	attack_tween.tween_property(attacker, "position", base + direction * 54.0, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	attack_tween.tween_property(attacker, "scale", Vector2(1.08, 0.92), 0.05)
	attack_tween.tween_callback(_spawn_slash.bind(attacker, defender, from_player))
	attack_tween.tween_property(attacker, "scale", Vector2.ONE, 0.08)
	attack_tween.tween_property(attacker, "position", base, 0.14).set_trans(Tween.TRANS_SINE)

	var hit_tween := create_tween()
	hit_tween.tween_property(defender, "modulate", Color(1.5, 0.45, 0.45), 0.05)
	hit_tween.tween_property(defender, "position", defender_base + Vector2(10 if from_player else -10, -4), 0.05)
	hit_tween.tween_property(defender, "position", defender_base + Vector2(-6 if from_player else 6, 2), 0.05)
	hit_tween.tween_property(defender, "position", defender_base, 0.08)
	hit_tween.tween_property(defender, "modulate", Color.WHITE, 0.12)


func show_feedback(text: String, on_enemy: bool, color: Color) -> void:
	var target: Control = enemy_figure if on_enemy else player_figure
	if not is_instance_valid(target):
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	add_child(label)
	label.global_position = target.global_position + Vector2(target.size.x * 0.35, 42)
	var end_position := label.position + Vector2(0, -46)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", end_position, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.45)
	tween.chain().tween_callback(label.queue_free)


func pulse_figure(on_enemy: bool, color: Color) -> void:
	var target: Control = enemy_figure if on_enemy else player_figure
	if not is_instance_valid(target):
		return
	var tween := create_tween()
	tween.tween_property(target, "modulate", color, 0.07)
	tween.tween_property(target, "modulate", Color.WHITE, 0.2)


func play_outcome(player_won: bool) -> void:
	var winner: Control = player_figure if player_won else enemy_figure
	var loser: Control = enemy_figure if player_won else player_figure
	var tween := create_tween().set_parallel(true)
	tween.tween_property(winner, "scale", Vector2(1.1, 1.1), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(winner, "modulate", Color(1.25, 1.2, 0.72), 0.38)
	tween.tween_property(loser, "position:y", loser.position.y + 24.0, 0.38).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(loser, "modulate", Color(0.35, 0.35, 0.42, 0.25), 0.38)
	await tween.finished


func _start_idle(target: Control, angle: float) -> void:
	target.pivot_offset = target.size * 0.5
	var tween := create_tween().set_loops()
	tween.tween_property(target, "rotation", angle, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "rotation", -angle, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _spawn_slash(attacker: Control, defender: Control, from_player: bool) -> void:
	var slash := ColorRect.new()
	slash.color = Color(1.0, 0.92, 0.55, 0.9) if from_player else Color(1.0, 0.4, 0.4, 0.9)
	slash.size = Vector2(68, 9)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.z_index = 20
	add_child(slash)
	slash.global_position = (attacker.global_position + defender.global_position) * 0.5 + Vector2(54, 88)
	slash.rotation = 0.6 if from_player else -0.6
	var tween := create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.18)
	tween.tween_callback(slash.queue_free)
