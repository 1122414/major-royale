extends Control
## 版本回环地图：每一幕保留独立的线性竖切，避免新内容重置既有局内状态。

const VersionLoopWorldState := preload("res://src/logic/rules/version_loop_world_state.gd")
const ACT_ONE_ENCOUNTERS := [
	"vl_newbie_echo",
	"vl_stamina_leech",
	"vl_signin_beast",
	"vl_resource_sweeper",
	"vl_notice_copy",
	"vl_compat_glitch",
	"vl_pipeline_overload",
	"vl_probability_calibrator",
]
const ACT_TWO_ENCOUNTERS := [
	"vl_outdated_guide",
	"vl_axis_inspector",
	"vl_pathing_failure",
	"vl_rhythm_carrier",
	"vl_rank_aggregate_beast",
	"vl_context_stripper",
	"vl_black_red_symbiote",
	"vl_voice_aggregate",
]
const ACT_TITLES := {
	1: "第一幕：新服预热",
	2: "第二幕：活动高峰",
}

var _node_list: VBoxContainer
var _status_label: Label
var _notice_label: Label
var _title_label: Label


func _ready() -> void:
	_sync_completed_acts()
	_build_background()
	_build_layout()
	if VersionLoopWorldState.is_maintenance_due():
		var reward := VersionLoopWorldState.resolve_forced_maintenance()
		GameState.player_stats["version_loop_maintenance_message"] = "强制维护完成：补偿券 %d，活动体力 %d。" % [
			int(reward.get("compensation_tickets", 0)), int(reward.get("activity_stamina", 0))
		]
	_refresh()
	AudioManager.play_bgm_for_phase("explore")


func _exit_tree() -> void:
	if GameState.current_screen == GameState.Screen.VERSION_LOOP_EXPLORE:
		GameState.save_run_checkpoint(GameState.Screen.VERSION_LOOP_EXPLORE)


func _build_background() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://assets/sprites/bg/version_loop_tide_plaza.png" if _get_act_index() == 2 else "res://assets/sprites/bg/version_loop_warmup.png"
	if ResourceLoader.exists(path):
		background.texture = load(path)
	background.modulate = Color(0.72, 0.78, 0.86, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.04, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_layout() -> void:
	var root := PanelContainer.new()
	root.position = Vector2(48, 34)
	root.size = Vector2(1184, 650)
	add_child(root)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", UIColors.BORDER_CYAN_BRIGHT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)
	var back := Button.new()
	back.text = "返回中枢"
	back.pressed.connect(func(): GameState.change_screen(GameState.Screen.MENU))
	title_row.add_child(back)
	_notice_label = Label.new()
	_notice_label.add_theme_font_size_override("font_size", 16)
	_notice_label.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
	column.add_child(_notice_label)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_status_label)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	column.add_child(split)
	var route_panel := PanelContainer.new()
	route_panel.custom_minimum_size = Vector2(720, 0)
	route_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(route_panel)
	var route_margin := MarginContainer.new()
	route_margin.add_theme_constant_override("margin_left", 16)
	route_margin.add_theme_constant_override("margin_top", 12)
	route_margin.add_theme_constant_override("margin_right", 16)
	route_margin.add_theme_constant_override("margin_bottom", 12)
	route_panel.add_child(route_margin)
	_node_list = VBoxContainer.new()
	_node_list.add_theme_constant_override("separation", 7)
	route_margin.add_child(_node_list)
	var guide_panel := PanelContainer.new()
	guide_panel.custom_minimum_size = Vector2(360, 0)
	split.add_child(guide_panel)
	var guide_margin := MarginContainer.new()
	guide_margin.add_theme_constant_override("margin_left", 16)
	guide_margin.add_theme_constant_override("margin_top", 14)
	guide_margin.add_theme_constant_override("margin_right", 16)
	guide_margin.add_theme_constant_override("margin_bottom", 14)
	guide_panel.add_child(guide_margin)
	var guide := Label.new()
	guide.text = _get_character_guide()
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 16)
	guide_margin.add_child(guide)


func _refresh() -> void:
	var act_index := _get_act_index()
	_title_label.text = "版本回环 · %s" % str(ACT_TITLES.get(act_index, "未加载章节"))
	var notice := _get_notice_info()
	_notice_label.text = "当前公告：%s　收益：%s　代价：%s" % [notice.get("name", "未知公告"), notice.get("benefit", ""), notice.get("drawback", "")]
	var maintenance := int(GameState.get_world_run_state_value("maintenance_clock", 0))
	var tickets := int(GameState.get_world_run_state_value("compensation_tickets", 0))
	var stamina := int(GameState.get_world_run_state_value("activity_stamina", 0))
	var message := str(GameState.player_stats.get("version_loop_maintenance_message", ""))
	_status_label.text = "维护时钟：%s　补偿券：%d　活动体力：%d%s" % [
		"●".repeat(maintenance) + "○".repeat(4 - maintenance), tickets, stamina,
		"\n%s" % message if not message.is_empty() else ""
	]
	for child in _node_list.get_children():
		child.queue_free()
	var next_id := _next_encounter_id()
	if next_id.is_empty():
		var complete := Label.new()
		complete.text = "%s已完成。当前构筑、维护时钟与角色资源会保留到下一幕。" % str(ACT_TITLES.get(act_index, "本幕"))
		complete.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		complete.add_theme_font_size_override("font_size", 18)
		complete.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
		_node_list.add_child(complete)
		if act_index == 1:
			GameState.set_world_run_state_value("act_one_complete", true)
		elif act_index == 2:
			GameState.set_world_run_state_value("act_two_complete", true)
		return
	for encounter_id in _get_current_encounters():
		_node_list.add_child(_make_encounter_button(encounter_id, encounter_id == next_id))


func _make_encounter_button(encounter_id: String, is_next: bool) -> Button:
	var enemy: EnemyResource = Config.enemies.get(encounter_id)
	var defeated := _is_defeated(encounter_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 43)
	button.disabled = not is_next
	var kind := "Boss" if enemy.enemy_type == "boss" else ("精英" if enemy.enemy_type == "elite" else "遭遇")
	button.text = "%s  %s  ·  %s" % ["✓" if defeated else ("▶" if is_next else "○"), kind, enemy.name]
	button.tooltip_text = "%s\n%s" % [enemy.specialty, enemy.weakness]
	if is_next:
		button.add_theme_color_override("font_color", UIColors.ACCENT_GOLD)
		button.pressed.connect(_start_encounter.bind(encounter_id))
	elif defeated:
		button.add_theme_color_override("font_color", UIColors.SUCCESS_GREEN)
	return button


func _start_encounter(encounter_id: String) -> void:
	AudioManager.play_sfx("click")
	GameState.player_stats.erase("version_loop_maintenance_message")
	GameState.player_stats["current_enemy_id"] = encounter_id
	GameState.change_screen(GameState.Screen.BATTLE)


func _next_encounter_id() -> String:
	for encounter_id in _get_current_encounters():
		if not _is_defeated(encounter_id):
			return encounter_id
	return ""


func _is_defeated(encounter_id: String) -> bool:
	for defeated in GameState.run_enemies_defeated:
		if str(defeated.get("id", "")) == encounter_id:
			return true
	return false


func _get_notice_info() -> Dictionary:
	var world: Resource = Config.get_world("version_loop")
	var notice_id := str(GameState.get_world_run_state_value("patch_notice_id", ""))
	for notice in world.get_rule_catalog_entries("patch_notices"):
		if str(notice.get("id", "")) == notice_id:
			return notice
	return {}


func _get_current_encounters() -> Array:
	return ACT_TWO_ENCOUNTERS if _get_act_index() == 2 else ACT_ONE_ENCOUNTERS


func _get_act_index() -> int:
	return clampi(int(GameState.get_world_run_state_value("act_index", 1)), 1, 2)


func _sync_completed_acts() -> void:
	if _is_defeated("vl_probability_calibrator"):
		GameState.set_world_run_state_value("act_one_complete", true)
		if _get_act_index() == 1:
			GameState.set_world_run_state_value("act_index", 2)
	if _is_defeated("vl_voice_aggregate"):
		GameState.set_world_run_state_value("act_two_complete", true)


func _get_character_guide() -> String:
	if GameState.player_character_id == "feilan":
		return "绯澜 · 舆潮主播\n\n核心资源：热度 0—10；达到 5 进入热榜。\n热度会在回合结束时衰减，可用短评在攻击与护航之间选择。\n\n主动：引爆话题\n消耗 5 热度，造成 18 点伤害。\n\n世界规则\n每次胜利推进 1 格维护时钟。满 4 格触发强制维护，获得补偿券与活动体力。"
	return "祈序 · 概率校准师\n\n核心资源：保底 0—6\n歪结果会积累保底；达到 6 后，下一次随机必定出货并清零。\n\n主动：概率校准\n消耗 2 保底，锁定下一次出货。\n\n世界规则\n每次胜利推进 1 格维护时钟。满 4 格触发强制维护，获得补偿券与活动体力。"
