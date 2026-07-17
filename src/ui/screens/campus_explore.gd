extends Node2D
## 可移动校园探索竖切：世界移动、五建筑交互、位置恢复与旧路线回退。

@onready var player: CampusPlayer = $World/Player
@onready var hotspots: Node2D = $World/Hotspots
@onready var interaction_prompt: PanelContainer = $HUD/InteractionPrompt
@onready var interaction_label: Label = $HUD/InteractionPrompt/InteractionLabel
@onready var location_label: Label = $HUD/TopHelp/Margin/VBox/LocationLabel
@onready var message_label: Label = $HUD/LocationToast/Margin/MessageLabel
@onready var fallback_button: Button = $HUD/FallbackButton
@onready var settings_button: Button = $HUD/SettingsButton

var _current_hotspot: CampusHotspot = null


func _ready() -> void:
	player.global_position = GameState.campus_player_position
	for node in hotspots.get_children():
		var hotspot := node as CampusHotspot
		if hotspot == null:
			continue
		hotspot.proximity_changed.connect(_on_hotspot_proximity_changed)
		hotspot.activated.connect(_on_hotspot_activated)
		hotspot.set_visited(hotspot.location_id in GameState.campus_visited_locations)
	fallback_button.pressed.connect(_on_fallback_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	interaction_prompt.visible = false
	location_label.text = "异化校园 · %s新生" % _major_name()
	message_label.text = "从校门进入校园。使用 WASD / 方向键移动，靠近建筑后按 E 交互。"
	AudioManager.play_bgm_for_phase("explore")


func _exit_tree() -> void:
	if is_instance_valid(player):
		GameState.campus_player_position = player.global_position


func _major_name() -> String:
	if Config.majors.has(GameState.player_major_id):
		return str(Config.majors[GameState.player_major_id].name)
	return "未定专业"


func _on_hotspot_proximity_changed(_hotspot: CampusHotspot, _is_near: bool) -> void:
	call_deferred("_refresh_nearby_hotspot")


func _refresh_nearby_hotspot() -> void:
	_current_hotspot = null
	var best_distance := INF
	for node in hotspots.get_children():
		var hotspot := node as CampusHotspot
		if hotspot == null or not hotspot.is_player_near():
			continue
		var distance := player.global_position.distance_squared_to(hotspot.global_position)
		if distance < best_distance:
			best_distance = distance
			_current_hotspot = hotspot
	interaction_prompt.visible = _current_hotspot != null
	if _current_hotspot != null:
		interaction_label.text = "E  交互 · %s" % _current_hotspot.display_name


func _on_hotspot_activated(hotspot: CampusHotspot) -> void:
	AudioManager.play_sfx("click")
	if _prepare_hotspot_activation(hotspot):
		player.controls_enabled = false
		GameState.change_screen(GameState.Screen.BATTLE)


func _prepare_hotspot_activation(hotspot: CampusHotspot) -> bool:
	var first_visit := hotspot.location_id not in GameState.campus_visited_locations
	if first_visit:
		GameState.campus_visited_locations.append(hotspot.location_id)
	hotspot.set_visited(true)
	GameState.player_stats["last_campus_hotspot"] = hotspot.location_id
	GameState.campus_player_position = player.global_position
	message_label.text = "%s：%s" % [hotspot.display_name, hotspot.description]

	if hotspot.action_id == "battle":
		if first_visit:
			GameState.run_progress += 1
		GameState.player_stats["current_enemy_id"] = "gpa_anxiety"
		return true
	return false


func _on_fallback_pressed() -> void:
	GameState.campus_player_position = player.global_position
	get_tree().change_scene_to_file("res://src/ui/screens/map_explore.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _current_hotspot == null:
		return
	get_viewport().set_input_as_handled()
	_current_hotspot.activate()
