extends Control
## 通关 / 败北后的一局总结。

const StatLex := preload("res://src/logic/stat_lexicon.gd")

@onready var title_label: Label = $TitleLabel
@onready var body_label: Label = $Scroll/BodyLabel
@onready var continue_button: Button = $ContinueButton


func _ready() -> void:
	var victory: bool = GameState.player_stats.get("last_battle_victory", false)
	var enemy_id: String = str(GameState.player_stats.get("current_enemy_id", ""))
	var is_clear: bool = victory and enemy_id == "employment_pressure"
	var settlement := MetaProgression.settle_current_run(is_clear)

	if is_clear:
		title_label.text = "通关总结 · 唯一上岸者"
		Achievements.try_after_clear()
		AudioManager.play_bgm_for_phase("victory")
	elif victory:
		title_label.text = "本局总结"
	else:
		title_label.text = "本局回顾"

	body_label.text = _build_summary(is_clear, settlement)
	continue_button.pressed.connect(_on_continue)
	continue_button.grab_focus()


func _build_summary(is_clear: bool, settlement: Dictionary = {}) -> String:
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
		lines.append("你通过了终极答辩。成就已结算，可在主页「成就」查看。")
		if GameState.run_difficulty >= GameState.DIFFICULTY_CATALOG.size() - 1:
			lines.append("最高挑战「唯一席位」已完成。")
		else:
			lines.append("下一阶挑战「%s」现已可选；挑战解锁不提供永久数值加成。" % GameState.get_difficulty_name(
				GameState.run_difficulty + 1
			))
	return "\n".join(lines)


func _format_talents() -> String:
	if GameState.run_meta_talent_ids.is_empty():
		return "永久天赋：无"
	var names: PackedStringArray = []
	for talent_id in GameState.run_meta_talent_ids:
		names.append(str(MetaProgression.get_talent_info(talent_id).get("name", talent_id)))
	return "永久天赋：%s" % "、".join(names)


func _on_continue() -> void:
	AudioManager.play_sfx("click")
	# 仅通关或失败会进入本页；之后回主菜单
	GameState.clear_run_save()
	GameState.change_screen(GameState.Screen.MENU)
