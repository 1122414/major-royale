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
const ACT_THREE_ENCOUNTERS := [
	"vl_meta_executor",
	"vl_rollback_wreck",
	"vl_test_server_leak",
	"vl_archive_shade",
	"vl_compat_grave",
	"vl_deprecated_echo",
	"vl_version_eater",
	"vl_zero_maintenance",
]
const ACT_TITLES := {
	1: "第一幕：新服预热",
	2: "第二幕：活动高峰",
	3: "第三幕：版本坟场",
}

var _node_list: VBoxContainer
var _status_label: Label
var _notice_label: Label
var _title_label: Label
var _world_event_button: Button
var _event_shade: ColorRect
var _event_panel: PanelContainer
var _event_content: VBoxContainer
var _current_event: EventResource


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
	var path := "res://assets/sprites/bg/version_loop_warmup.png"
	if _get_act_index() == 2:
		path = "res://assets/sprites/bg/version_loop_tide_plaza.png"
	elif _get_act_index() == 3:
		path = "res://assets/sprites/bg/version_loop_graveyard.png"
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
	var event_row := HBoxContainer.new()
	event_row.add_theme_constant_override("separation", 12)
	column.add_child(event_row)
	var event_hint := Label.new()
	event_hint.text = "异闻节点：每幕可解析一次，结算会保留至本局结束。"
	event_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_row.add_child(event_hint)
	_world_event_button = Button.new()
	_world_event_button.custom_minimum_size = Vector2(190, 36)
	_world_event_button.pressed.connect(_open_world_event)
	event_row.add_child(_world_event_button)
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
	_build_world_event_overlay()


func _refresh() -> void:
	var act_index := _get_act_index()
	_title_label.text = "版本回环 · %s" % str(ACT_TITLES.get(act_index, "未加载章节"))
	var notice := _get_notice_info()
	_notice_label.text = "当前公告：%s　收益：%s　代价：%s" % [notice.get("name", "未知公告"), notice.get("benefit", ""), notice.get("drawback", "")]
	var maintenance := int(GameState.get_world_run_state_value("maintenance_clock", 0))
	var tickets := int(GameState.get_world_run_state_value("compensation_tickets", 0))
	var stamina := int(GameState.get_world_run_state_value("activity_stamina", 0))
	var message := str(GameState.player_stats.get("version_loop_maintenance_message", ""))
	var protocol_info := MetaProgression.get_world_ending_info("version_loop")
	var protocol_text := "\n终局协议：%s" % str(protocol_info.get("name", "未写入")) if not protocol_info.is_empty() else ""
	_status_label.text = "维护时钟：%s　补偿券：%d　活动体力：%d%s%s" % [
		"●".repeat(maintenance) + "○".repeat(4 - maintenance), tickets, stamina,
		"\n%s" % message if not message.is_empty() else "", protocol_text
	]
	var event_done := _is_world_event_resolved()
	_world_event_button.text = "本幕异闻已解析 ✓" if event_done else "解析本幕异闻"
	_world_event_button.disabled = event_done
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
		elif act_index == 3:
			GameState.set_world_run_state_value("act_three_complete", true)
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


func _build_world_event_overlay() -> void:
	_event_shade = ColorRect.new()
	_event_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_event_shade.color = Color(0.0, 0.02, 0.05, 0.82)
	_event_shade.visible = false
	_event_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_event_shade)
	_event_panel = PanelContainer.new()
	_event_panel.position = Vector2(330, 150)
	_event_panel.size = Vector2(620, 420)
	_event_shade.add_child(_event_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	_event_panel.add_child(margin)
	_event_content = VBoxContainer.new()
	_event_content.add_theme_constant_override("separation", 14)
	margin.add_child(_event_content)


func _open_world_event() -> void:
	if _is_world_event_resolved():
		return
	AudioManager.play_sfx("click")
	var rng := GameState.make_run_rng(
		"version_loop_event:%d" % _get_act_index(),
		GameState.run_events_resolved + _get_act_index() * 100
	)
	_current_event = EventHandler.pick_random_event("version_loop", rng)
	if _current_event == null:
		GameState.player_stats["version_loop_event_message"] = "本幕没有可解析的异闻。"
		_refresh()
		return
	_event_shade.visible = true
	_clear_event_content()
	_add_event_label("版本异闻 · %s" % _current_event.name, 26, UIColors.BORDER_CYAN_BRIGHT)
	_add_event_label(_current_event.description, 17, Color.WHITE, true)
	if _current_event.choices.is_empty():
		_add_event_choice("确认解析", -1, true)
	else:
		for choice_index in _current_event.choices.size():
			_add_event_choice(str(_current_event.choices[choice_index].get("text", "选择")), choice_index, choice_index == 0)


func _resolve_world_event(choice_index: int) -> void:
	if _current_event == null:
		return
	AudioManager.play_sfx("click")
	var handler := EventHandler.new(GameState.player_stats)
	var result := handler.apply_event(_current_event, choice_index)
	GameState.add_event_flag(_world_event_flag_id())
	GameState.run_events_resolved += 1
	GameState.player_stats["version_loop_event_message"] = "%s：%s" % [_current_event.name, result]
	_clear_event_content()
	_add_event_label("异闻结算", 26, UIColors.ACCENT_GOLD)
	_add_event_label(result, 17, Color.WHITE, true)
	var continue_button := Button.new()
	continue_button.text = "返回版本路线"
	continue_button.custom_minimum_size = Vector2(0, 48)
	continue_button.pressed.connect(_close_world_event)
	_event_content.add_child(continue_button)
	continue_button.grab_focus()
	if GameState.run_hp <= 0 or GameState.run_spirit <= 0:
		GameState.player_stats["last_battle_victory"] = false
		GameState.player_stats["last_enemy_was_ai"] = false
		continue_button.text = "查看本局总结"
		continue_button.pressed.disconnect(_close_world_event)
		continue_button.pressed.connect(func(): GameState.change_screen(GameState.Screen.RUN_SUMMARY))
		return
	GameState.save_run_checkpoint(GameState.Screen.VERSION_LOOP_EXPLORE)


func _close_world_event() -> void:
	_current_event = null
	_event_shade.visible = false
	_clear_event_content()
	_refresh()


func _add_event_label(text: String, font_size: int, color: Color, wrap: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	_event_content.add_child(label)


func _add_event_choice(text: String, choice_index: int, focus: bool) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 54)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(_resolve_world_event.bind(choice_index))
	_event_content.add_child(button)
	if focus:
		button.grab_focus()


func _clear_event_content() -> void:
	for child in _event_content.get_children():
		_event_content.remove_child(child)
		child.queue_free()


func _world_event_flag_id() -> String:
	return "version_loop_event_act_%d" % _get_act_index()


func _is_world_event_resolved() -> bool:
	return GameState.has_event_flag(_world_event_flag_id())


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
	match _get_act_index():
		2: return ACT_TWO_ENCOUNTERS
		3: return ACT_THREE_ENCOUNTERS
	return ACT_ONE_ENCOUNTERS


func _get_act_index() -> int:
	return clampi(int(GameState.get_world_run_state_value("act_index", 1)), 1, 3)


func _sync_completed_acts() -> void:
	if _is_defeated("vl_probability_calibrator"):
		GameState.set_world_run_state_value("act_one_complete", true)
		if _get_act_index() == 1:
			GameState.set_world_run_state_value("act_index", 2)
	if _is_defeated("vl_voice_aggregate"):
		GameState.set_world_run_state_value("act_two_complete", true)
		if _get_act_index() == 2:
			GameState.set_world_run_state_value("act_index", 3)
	if _is_defeated("vl_zero_maintenance"):
		GameState.set_world_run_state_value("act_three_complete", true)


func _get_character_guide() -> String:
	if GameState.player_character_id == "feilan":
		return "绯澜 · 舆潮主播\n\n核心资源：热度 0—10；达到 5 进入热榜。\n热度会在回合结束时衰减，可用短评在攻击与护航之间选择。\n\n主动：引爆话题\n消耗 5 热度，造成 18 点伤害。\n\n世界规则\n每次胜利推进 1 格维护时钟。满 4 格触发强制维护，获得补偿券与活动体力。"
	if GameState.player_character_id == "xunji":
		return "循迹 · 流程代行员\n\n核心资源：唯一脚本槽与最近三张牌序。\n录制可复演的直接效果；复演不会复制抽牌、能量、生成或再次复演。\n\n主动：执行脚本\n脚本槽不为空时，以 60% 强度复演。\n\n世界规则\n每次胜利推进 1 格维护时钟。满 4 格触发强制维护，获得补偿券与活动体力。"
	if GameState.player_character_id == "mimo":
		return "弥默 · 模因回收员\n\n核心资源：模因片与当前标签。\n回收牌会积累模因片；攻击、防御、流程标签可被拼接为不同效果。\n\n主动：协议拼接\n消耗 3 枚模因片，按标签执行转译。\n\n世界规则\n三名标准角色各通关一次后解锁；终局协议会永久写入中枢。"
	return "祈序 · 概率校准师\n\n核心资源：保底 0—6\n歪结果会积累保底；达到 6 后，下一次随机必定出货并清零。\n\n主动：概率校准\n消耗 2 保底，锁定下一次出货。\n\n世界规则\n每次胜利推进 1 格维护时钟。满 4 格触发强制维护，获得补偿券与活动体力。"
