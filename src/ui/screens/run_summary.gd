extends Control
## 通关 / 败北后的一局总结。

const StatLex := preload("res://src/logic/stat_lexicon.gd")

@onready var title_label: Label = $TitleLabel
@onready var body_label: Label = $Scroll/BodyLabel
@onready var continue_button: Button = $ContinueButton


func _ready() -> void:
	var victory: bool = GameState.player_stats.get("last_battle_victory", false)
	var enemy_id: String = str(GameState.player_stats.get("current_enemy_id", ""))
	var is_campus_clear := enemy_id == "employment_pressure" and GameState.current_world_id == "campus"
	var is_version_loop_clear := enemy_id == "vl_zero_maintenance" and GameState.current_world_id == "version_loop"
	var is_clear: bool = victory and (is_campus_clear or is_version_loop_clear)
	var settlement := MetaProgression.settle_current_run(is_clear)
	var world_clearance := MetaProgression.record_world_clear() if is_clear else {}

	if is_clear:
		title_label.text = "通关总结 · %s" % ("唯一上岸者" if is_campus_clear else "版本回环已稳定")
		Achievements.try_after_clear()
		AudioManager.play_bgm_for_phase("victory")
	elif victory:
		title_label.text = "本局总结"
	else:
		title_label.text = "本局回顾"

	body_label.text = _build_summary(is_clear, settlement, world_clearance)
	continue_button.pressed.connect(_on_continue)
	continue_button.grab_focus()


func _build_summary(is_clear: bool, settlement: Dictionary = {}, world_clearance: Dictionary = {}) -> String:
	var major_name := GameState.player_major_id
	if Config.majors.has(major_name):
		major_name = Config.majors[major_name].name

	var lines: PackedStringArray = []
	lines.append("专业：%s　　挑战：%s　　种子：%d" % [
		major_name, GameState.get_difficulty_name(), GameState.run_seed
	])
	lines.append("天数：第%d天　　压力圈：%d" % [GameState.day_count, GameState.run_progress])
	lines.append("生命 %d/%d　　精神 %d/%d" % [GameState.run_hp, GameState.run_max_hp, GameState.run_spirit, GameState.run_max_spirit])
	lines.append("学分 %d　　信用点 %d　　牌库 %d 张" % [GameState.credits, GameState.credit_points, GameState.deck_card_ids.size()])
	if not settlement.is_empty():
		lines.append("本局金币 +%d　　永久余额 %d" % [
			int(settlement.get("earned", 0)),
			int(settlement.get("balance", MetaProgression.get_gold())),
		])
	var RelicCat = preload("res://src/logic/relic.gd")
	lines.append(RelicCat.format_list(GameState.run_relic_ids))
	lines.append(_format_talents())
	lines.append(_format_equipment())
	lines.append("")
	lines.append("—— 战斗数据 ——")
	lines.append("胜利场次：%d　　出牌：%d　　造成伤害：%d" % [
		GameState.run_battles_won, GameState.run_cards_played, GameState.run_damage_dealt
	])
	lines.append("精准反驳：%d　　成功换位：%d" % [
		GameState.run_perfect_rebuttals, GameState.run_successful_dodges
	])
	lines.append("")
	lines.append("—— 击败敌人 ——")
	if GameState.run_enemies_defeated.is_empty():
		lines.append("（尚无击败记录）")
	else:
		for e in GameState.run_enemies_defeated:
			lines.append("· [%s] %s" % [e.get("type", "?"), e.get("name", e.get("id", "?"))])
	lines.append("")
	lines.append("—— 八维属性（含永久加成）——")
	for s in ["学识", "体能", "专注", "表达", "创造", "社交", "抗压", "资源"]:
		lines.append("%s %d　| %s" % [s, GameState.get_effective_stat(s), StatLex.stat_text(s)])
	if is_clear:
		lines.append("")
		if GameState.current_world_id == "version_loop":
			var ending_info := MetaProgression.get_world_ending_info("version_loop")
			lines.append("零号维护已停止。终局协议：%s。" % str(ending_info.get("name", "未选择")))
		else:
			lines.append("你通过了终极答辩。成就已结算，可在主页「成就」查看。")
		lines.append(_format_world_clearance(world_clearance))
		if GameState.run_difficulty >= GameState.DIFFICULTY_CATALOG.size() - 1:
			lines.append("最高挑战「唯一席位」已完成。")
		else:
			lines.append("下一阶挑战「%s」现已可选；挑战解锁不提供永久数值加成。" % GameState.get_difficulty_name(
				GameState.run_difficulty + 1
			))
	return "\n".join(lines)


func _format_world_clearance(world_clearance: Dictionary) -> String:
	if world_clearance.is_empty():
		return "中枢档案同步失败，请在主页查看世界进度。"
	var fragment_name := str(world_clearance.get("fragment_name", ""))
	var unlocked_world_id := str(world_clearance.get("unlocked_world_id", ""))
	if bool(world_clearance.get("new_fragment", false)):
		var text := "获得世界规则碎片：%s。" % fragment_name
		if not unlocked_world_id.is_empty():
			var world_info := MetaProgression.get_world_progress_info(unlocked_world_id)
			text += " 中枢侦测到「%s」入口，正在稳定。" % str(world_info.get("name", unlocked_world_id))
		var new_hidden_character_id := str(world_clearance.get("new_character_id", ""))
		if not new_hidden_character_id.is_empty():
			var character_info := MetaProgression.CHARACTER_PROGRESS_CATALOG.get(new_hidden_character_id, {}) as Dictionary
			text += " 隐藏档案「%s」已解锁。" % str(character_info.get("name", new_hidden_character_id))
		return text
	var new_character_id := str(world_clearance.get("new_character_id", ""))
	if not new_character_id.is_empty():
		var character_info := MetaProgression.CHARACTER_PROGRESS_CATALOG.get(new_character_id, {}) as Dictionary
		return "世界通关档案已同步；隐藏档案「%s」已解锁。" % str(character_info.get("name", new_character_id))
	return "世界通关档案已同步；碎片与入口状态保持不变。"


func _format_talents() -> String:
	if GameState.run_meta_talent_ids.is_empty():
		return "永久天赋：无"
	var names: PackedStringArray = []
	for talent_id in GameState.run_meta_talent_ids:
		names.append(str(MetaProgression.get_talent_info(talent_id).get("name", talent_id)))
	return "永久天赋：%s" % "、".join(names)


func _format_equipment() -> String:
	if GameState.run_meta_equipment.is_empty():
		return "永久装备：无"
	var entries: PackedStringArray = []
	for slot_id in MetaProgression.EQUIPMENT_SLOTS:
		if not GameState.run_meta_equipment.has(slot_id):
			continue
		var equipment_id := str(GameState.run_meta_equipment[slot_id])
		var slot_name := str(MetaProgression.EQUIPMENT_SLOTS[slot_id])
		var equipment_name := str(MetaProgression.get_equipment_info(equipment_id).get("name", equipment_id))
		entries.append("%s·%s" % [slot_name, equipment_name])
	return "永久装备：%s" % "　".join(entries)


func _on_continue() -> void:
	AudioManager.play_sfx("click")
	# 仅通关或失败会进入本页；之后回主菜单
	GameState.clear_run_save()
	GameState.change_screen(GameState.Screen.MENU)
