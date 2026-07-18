extends Node2D
## 可移动校园探索竖切：世界移动、五建筑交互与位置恢复。

const CampusRouteScript := preload("res://src/logic/campus_route.gd")

@onready var player: CampusPlayer = $World/Player
@onready var hotspots: Node2D = $World/Hotspots
@onready var pressure_zone: Polygon2D = $World/PressureZone
@onready var hud: ExploreHUD = $HUD
@onready var player_sprite: Sprite2D = $World/Player/Sprite

var _current_hotspot: CampusHotspot = null
var _current_event: EventResource = null
var _pending_battle_after_event := false
var _pending_run_end_after_event := false
var _pending_hotspot: CampusHotspot = null


func _ready() -> void:
	_apply_player_art()
	player.global_position = GameState.campus_player_position
	for node in hotspots.get_children():
		var hotspot := node as CampusHotspot
		if hotspot == null:
			continue
		hotspot.proximity_changed.connect(_on_hotspot_proximity_changed)
		hotspot.activated.connect(_on_hotspot_activated)
		hotspot.set_visited(hotspot.location_id in GameState.campus_visited_locations)
	hud.settings_requested.connect(_on_settings_pressed)
	hud.event_choice_selected.connect(_on_event_choice_selected)
	hud.event_continue_requested.connect(_on_event_continue_requested)
	hud.set_area("校园正门")
	hud.set_interaction(null)
	hud.show_message("从校门进入校园。使用 WASD / 方向键移动，靠近建筑后按 E 交互。")
	hud.refresh()
	_refresh_pressure_world()
	AudioManager.play_bgm_for_phase("explore")


func _apply_player_art() -> void:
	var paths := {
		"computer": "res://assets/sprites/chars/player_cs.png",
		"law": "res://assets/sprites/chars/player_law.png",
		"medicine": "res://assets/sprites/chars/player_med.png",
		"finance": "res://assets/sprites/chars/player_finance.png",
		"arts": "res://assets/sprites/chars/player_arts.png",
	}
	var path: String = paths.get(GameState.player_major_id, paths.computer)
	if ResourceLoader.exists(path):
		player_sprite.texture = load(path)


func _exit_tree() -> void:
	if is_instance_valid(player):
		GameState.campus_player_position = player.global_position


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
	hud.set_interaction(_current_hotspot)
	hud.set_area(_current_hotspot.display_name if _current_hotspot != null else "异化校园")


func _on_hotspot_activated(hotspot: CampusHotspot) -> void:
	AudioManager.play_sfx("click")
	player.controls_enabled = false
	_pending_hotspot = hotspot
	_pending_run_end_after_event = false
	_pending_battle_after_event = _prepare_hotspot_activation(hotspot)
	_open_hotspot_event(hotspot)


func _prepare_hotspot_activation(hotspot: CampusHotspot) -> bool:
	var first_visit := hotspot.location_id not in GameState.campus_visited_locations
	if first_visit:
		GameState.campus_visited_locations.append(hotspot.location_id)
	hotspot.set_visited(true)
	GameState.player_stats["last_campus_hotspot"] = hotspot.location_id
	GameState.campus_player_position = player.global_position
	hud.show_message("%s：%s" % [hotspot.display_name, hotspot.description])

	var battle_enemy_id := CampusRouteScript.next_enemy_id(hotspot.location_id, GameState.run_enemies_defeated)
	if not battle_enemy_id.is_empty():
		GameState.run_progress += 1
		GameState.player_stats["current_enemy_id"] = battle_enemy_id
		hud.refresh()
		_refresh_pressure_world()
		return true
	hud.show_message("%s：%s" % [hotspot.display_name, _route_status_message(hotspot.location_id)])
	hud.refresh()
	_refresh_pressure_world()
	return false


func _route_status_message(location_id: String) -> String:
	if location_id == "sports" and CampusRouteScript.is_finale_ready(GameState.run_enemies_defeated):
		return "终局已经完成，本区暂无新的挑战。"
	var remaining := CampusRouteScript.remaining_enemy_ids(GameState.run_enemies_defeated)
	if remaining.is_empty():
		return "所有区域挑战均已完成。"
	var progress := CampusRouteScript.location_progress(location_id, GameState.run_enemies_defeated)
	if bool(progress.get("completed", false)):
		return "本区挑战已清空，终局前还需完成其他区域。"
	return _hotspot_description_fallback(location_id)


func _hotspot_description_fallback(location_id: String) -> String:
	return "继续探索，准备下一场校园遭遇。" if location_id != "sports" else "先完成各区域挑战，再返回操场参加终极答辩。"


func _open_hotspot_event(hotspot: CampusHotspot) -> void:
	var area_map := {
		"teaching": "classroom",
		"library": "library",
		"dorm": "dorm",
		"cafeteria": "cafeteria",
		"sports": "playground",
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hotspot.location_id) + GameState.run_events_resolved * 31 + GameState.day_count * 101
	_current_event = EventHandler.pick_random_event(str(area_map.get(hotspot.location_id, "")), rng)
	if _current_event == null:
		if _pending_battle_after_event:
			GameState.change_screen(GameState.Screen.BATTLE)
		else:
			player.controls_enabled = true
		return
	hud.show_event(hotspot.display_name, _current_event)


func _on_event_choice_selected(choice_index: int) -> void:
	if _current_event == null:
		return
	AudioManager.play_sfx("click")
	var handler := EventHandler.new(GameState.player_stats)
	var result := handler.apply_event(_current_event, choice_index)
	GameState.run_events_resolved += 1
	GameState.day_count = maxi(GameState.day_count, 1 + int(GameState.run_events_resolved / 3))
	var continue_label := "进入战斗 ▶" if _pending_battle_after_event else "返回校园"
	if GameState.run_hp <= 0:
		_pending_run_end_after_event = true
		_pending_battle_after_event = false
		GameState.player_stats["last_battle_victory"] = false
		GameState.player_stats["last_enemy_was_ai"] = false
		result += "\n\n体力已经耗尽，本次校园生存结束。"
		continue_label = "查看本局总结"
	if not _pending_run_end_after_event and _pending_hotspot != null and _pending_hotspot.location_id == "sports" and not _pending_battle_after_event:
		var remaining := CampusRouteScript.remaining_enemy_ids(GameState.run_enemies_defeated)
		if not remaining.is_empty():
			result += "\n\n终局尚未开启：还需击败 %d 名校园竞争者。" % remaining.size()
	hud.show_event_result(result, continue_label)
	hud.refresh()
	_refresh_pressure_world()


func _on_event_continue_requested() -> void:
	hud.close_event()
	_current_event = null
	_pending_hotspot = null
	if _pending_run_end_after_event:
		_pending_run_end_after_event = false
		GameState.change_screen(GameState.Screen.RUN_SUMMARY)
		return
	if _pending_battle_after_event:
		_pending_battle_after_event = false
		GameState.change_screen(GameState.Screen.BATTLE)
		return
	player.controls_enabled = true


func _refresh_pressure_world() -> void:
	if GameState.run_progress <= 0:
		pressure_zone.polygon = PackedVector2Array()
		return
	var danger_width := clampf(80.0 + float(GameState.run_progress) * 52.0, 80.0, 560.0)
	var left := 1280.0 - danger_width
	pressure_zone.polygon = PackedVector2Array([
		Vector2(left, 0),
		Vector2(1280, 0),
		Vector2(1280, 720),
		Vector2(left + 110.0, 720),
	])
	pressure_zone.color = Color(UIColors.DANGER_RED, clampf(0.1 + float(GameState.run_progress) * 0.018, 0.1, 0.34))


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.SETTINGS)


func _unhandled_input(event: InputEvent) -> void:
	if not player.controls_enabled or not event.is_action_pressed("interact") or _current_hotspot == null:
		return
	get_viewport().set_input_as_handled()
	_current_hotspot.activate()
