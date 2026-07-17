class_name BattleStage
extends Control
## 战斗舞台表现层：角色贴图、站位与攻防动画，不读取或修改战斗数值。

@onready var player_figure: TextureRect = $PlayerFigure
@onready var enemy_figure: TextureRect = $EnemyFigure


func setup_art(player_path: String, enemy_path: String) -> void:
	_set_texture(player_figure, player_path)
	_set_texture(enemy_figure, enemy_path)


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
