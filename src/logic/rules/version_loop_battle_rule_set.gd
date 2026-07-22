extends "res://src/logic/rules/battle_rule_set.gd"

## 版本回环的第一轮规则：公告影响整场战斗，维护时钟推进世界节奏。

const NOTICE_LIGHTWEIGHT := "lightweight_update"
const NOTICE_NUMERIC := "numeric_inflation"
const NOTICE_FIXED := "known_issue_fix"
const QIXU_ID := "qixu"
const FEILAN_ID := "feilan"
const PITY_KEY := "pity"
const LAST_OUTCOME_KEY := "last_random_outcome"
const FORCED_OUTCOME_KEY := "forced_random_outcome"

var _lightweight_discount_available := true
var _blank_lottery_tube_ready := true
var _feilan_indicator_ready := true
var _feilan_heat_guard := false
var _feilan_heat_guard_used := false
var _feilan_damage_heat := false
var _feilan_damage_heat_used := false
var _feilan_cost_heat := false
var _feilan_hot_discount := false
var _feilan_heat_loss_burst := false
var _feilan_overheat_draw := false
var _feilan_global_hot_list := false
var _feilan_heat_refund := false
var _feilan_heat_refund_used := false
var _feilan_comeback_attacks := 0
var _recent_boss_signatures: Array[String] = []


func get_id() -> String:
	return "version_loop"


func on_battle_started(battle) -> void:
	if _get_notice_id() == NOTICE_FIXED:
		# 抗压会抵消下一次完整负面施加，正好对应“第一个自身负面无效”。
		battle.player.add_status("resistance", 1)
	if battle.player.major_id == QIXU_ID:
		GameState.set_character_run_state_value(PITY_KEY, 0)
		GameState.set_character_run_state_value(LAST_OUTCOME_KEY, "")
		GameState.set_character_run_state_value(FORCED_OUTCOME_KEY, "")
		_blank_lottery_tube_ready = true
	elif battle.player.major_id == FEILAN_ID:
		GameState.set_character_run_state_value("heat", 0)
		GameState.set_character_run_state_value("short_comments_played", 0)
		GameState.set_character_run_state_value("heat_floor", 0)
		_reset_feilan_battle_flags()
	_recent_boss_signatures.clear()


func on_battle_finished(_battle, victory: bool) -> void:
	if not victory:
		return
	if str(_battle.enemy_resource.id) == "vl_probability_calibrator":
		if MetaProgression.discover_character(FEILAN_ID):
			_battle.notify_world_rule_feedback("绯澜档案已发现：下一局可选择舆潮主播")
	var maintenance_clock := GameState.add_world_run_state_int("maintenance_clock", 1)
	if maintenance_clock >= 4:
		GameState.set_world_run_state_value("maintenance_due", true)


func modify_enemy_max_hp(_battle, enemy_resource: Resource, base_max_hp: int) -> int:
	if _get_notice_id() == NOTICE_NUMERIC and str(enemy_resource.enemy_type) == "normal":
		return int(ceil(float(base_max_hp) * 1.2))
	return base_max_hp


func modify_player_draw(_battle, draw_amount: int, has_draw_override: bool) -> int:
	if _get_notice_id() == NOTICE_LIGHTWEIGHT and not has_draw_override:
		return maxi(1, draw_amount - 1)
	return draw_amount


func get_card_cost(_battle, card: Resource, base_cost: int) -> int:
	var result := base_cost
	if _get_notice_id() == NOTICE_LIGHTWEIGHT and _lightweight_discount_available and int(card.cost) == 1:
		result = 0
	if _battle.player.major_id == FEILAN_ID and _feilan_hot_discount and _get_heat() >= 5 and int(card.cost) >= 2:
		result -= 1
	return maxi(0, result)


func on_card_played(_battle, card: Resource, _shield_before_card: int) -> void:
	if _get_notice_id() == NOTICE_LIGHTWEIGHT and int(card.cost) == 1:
		_lightweight_discount_available = false
	_track_voice_aggregate(_battle, card)
	if _battle.player.major_id != FEILAN_ID:
		return
	match str(card.id):
		"feilan_hot_search": _feilan_heat_guard = true
		"feilan_black_red_is_red": _feilan_damage_heat = true
		"feilan_nine_flavors": _feilan_cost_heat = true
		"feilan_fan_all_in": _feilan_hot_discount = true
		"feilan_flame_marketing": _feilan_heat_loss_burst = true
		"feilan_black_red_positive": _feilan_overheat_draw = true
		"feilan_global_hot_list": _feilan_global_hot_list = true
		"feilan_global_comeback": _feilan_comeback_attacks = 3
		"feilan_fan_eternal": _feilan_heat_refund = true
	if str(card.id) == "feilan_short_comment":
		GameState.add_character_run_state_int("short_comments_played", 1)
	if _feilan_comeback_attacks > 0 and str(card.type) == "attack":
		_feilan_comeback_attacks -= 1


func process_card_effect(battle, card: Resource, effect: Resource, caster, _target) -> bool:
	if caster != battle.player:
		return false
	if caster.major_id == FEILAN_ID:
		return _process_feilan_effect(battle, card, effect, caster)
	if caster.major_id != QIXU_ID:
		return false
	match str(effect.type):
		"random_damage":
			var outcome := _resolve_random_outcome(battle)
			var hit_value := int(effect.params.get("hit_value", effect.value))
			var damage := hit_value if outcome == "hit" else int(effect.value)
			damage += int(GameState.get_effective_stat("学识") / 3)
			damage = battle.modify_card_damage(card, caster, battle.enemy, damage)
			battle.deal_direct_damage_to_enemy(damage)
			return true
		"pity":
			_add_pity(battle, int(effect.value))
			return true
		"force_random":
			GameState.set_character_run_state_value(FORCED_OUTCOME_KEY, str(effect.params.get("outcome", "hit")))
			battle.notify_character_resource_updated()
			battle.notify_world_rule_feedback("概率已校准：下一次随机必定出货")
			return true
		"pity_damage":
			var cost := maxi(0, int(effect.params.get("pity_cost", 0)))
			var current_pity := _get_pity()
			var damage := int(effect.params.get("fallback_value", effect.value))
			if current_pity >= cost:
				GameState.add_character_run_state_int(PITY_KEY, -cost)
				damage = int(effect.params.get("hit_value", effect.value))
			damage += int(GameState.get_effective_stat("学识") / 3)
			damage = battle.modify_card_damage(card, caster, battle.enemy, damage)
			battle.deal_direct_damage_to_enemy(damage)
			battle.notify_character_resource_updated()
			return true
		"pity_shield":
			var required_pity := maxi(0, int(effect.params.get("pity_cost", 0)))
			var shield := int(effect.params.get("fallback_value", effect.value))
			if _get_pity() >= required_pity:
				GameState.add_character_run_state_int(PITY_KEY, -required_pity)
				shield = int(effect.params.get("hit_value", effect.value))
			caster.gain_shield(battle.modify_shield_amount(caster, caster, shield))
			battle.notify_character_resource_updated()
			return true
		"pity_draw":
			if _get_pity() >= int(effect.params.get("threshold", 0)):
				caster.draw_cards(maxi(0, int(effect.value)), battle.MAX_HAND_SIZE)
			return true
		"pity_threshold_set":
			var threshold := int(effect.params.get("threshold", 0))
			if _get_pity() >= threshold:
				GameState.set_character_run_state_value(PITY_KEY, int(effect.params.get("hit_value", 6)))
			else:
				_add_pity(battle, int(effect.value))
			battle.notify_character_resource_updated()
			return true
		"last_outcome_reward":
			if str(GameState.get_character_run_state_value(LAST_OUTCOME_KEY, "")) == "hit":
				battle.energy += int(effect.params.get("hit_energy", 1))
			else:
				_add_pity(battle, int(effect.params.get("miss_pity", effect.value)))
				caster.draw_cards(int(effect.params.get("miss_draw", 0)), battle.MAX_HAND_SIZE)
			return true
	return false


func modify_card_damage(_battle, card: Resource, _caster, _target, amount: int) -> int:
	if _get_notice_id() == NOTICE_NUMERIC and int(card.cost) >= 2:
		amount += 4
	if _battle.player.major_id == FEILAN_ID and _feilan_comeback_attacks > 0 and str(card.type) == "attack":
		amount += 4
	return amount


func use_active_skill(battle) -> String:
	if battle.player.major_id == QIXU_ID:
		if _get_pity() < 2:
			return ""
		GameState.add_character_run_state_int(PITY_KEY, -2)
		GameState.set_character_run_state_value(FORCED_OUTCOME_KEY, "hit")
		battle.notify_character_resource_updated()
		battle.notify_world_rule_feedback("消耗 2 保底，下一次随机必定出货")
		return "概率校准"
	if battle.player.major_id == FEILAN_ID and _get_heat() >= 5:
		_change_heat(battle, -5)
		_deal_feilan_damage(battle, null, 18)
		battle.notify_world_rule_feedback("引爆话题：消耗 5 热度，造成 18 点伤害")
		return "引爆话题"
	return ""


func _resolve_random_outcome(battle) -> String:
	var forced := str(GameState.get_character_run_state_value(FORCED_OUTCOME_KEY, ""))
	var pity_before := _get_pity()
	var outcome := forced
	if outcome.is_empty():
		outcome = "hit" if pity_before >= 6 or battle.roll_chance(0.5) else "miss"
	GameState.set_character_run_state_value(FORCED_OUTCOME_KEY, "")
	if outcome == "miss":
		_add_pity(battle, 1)
		if _blank_lottery_tube_ready and GameState.has_relic("blank_lottery_tube"):
			_blank_lottery_tube_ready = false
			battle.player.gain_shield(battle.modify_shield_amount(battle.player, battle.player, 4))
			battle.notify_world_rule_feedback("歪了：空白签筒记录失败，获得 1 保底与 4 护盾")
		else:
			battle.notify_world_rule_feedback("歪了：失败记录为保底")
	else:
		if pity_before >= 6:
			GameState.set_character_run_state_value(PITY_KEY, 0)
		battle.notify_world_rule_feedback("出货：概率结算成功")
	GameState.set_character_run_state_value(LAST_OUTCOME_KEY, outcome)
	battle.notify_character_resource_updated()
	return outcome


func _add_pity(battle, amount: int) -> int:
	var pity := GameState.add_character_run_state_int(PITY_KEY, amount)
	battle.notify_character_resource_updated()
	return pity


func _get_pity() -> int:
	return int(GameState.get_character_run_state_value(PITY_KEY, 0))


func _get_notice_id() -> String:
	return str(GameState.get_world_run_state_value("patch_notice_id", NOTICE_LIGHTWEIGHT))


func on_player_turn_started(battle) -> void:
	_lightweight_discount_available = true
	_feilan_heat_guard_used = false
	_feilan_damage_heat_used = false
	_feilan_heat_refund_used = false
	if battle.player.major_id != FEILAN_ID:
		return
	if _feilan_global_hot_list and _get_heat() >= 5:
		battle.player.draw_cards(1, battle.MAX_HAND_SIZE)
		if _get_heat() >= 10:
			battle.energy += 1
	if _feilan_overheat_draw and _get_heat() > 10:
		battle.player.draw_cards(1, battle.MAX_HAND_SIZE)
		battle.player.take_damage(2)
		battle.notify_world_rule_feedback("黑红转正：高热度换来额外抽牌，但失去 2 点生命")


func on_player_turn_ended(battle) -> void:
	if battle.player.major_id == FEILAN_ID and not _feilan_global_hot_list and _get_heat() > _get_heat_floor():
		_change_heat(battle, -1, false)
		battle.notify_world_rule_feedback("热度自然衰减 1 点")
	if str(battle.enemy_resource.id) == "vl_voice_aggregate":
		var type_count := 0
		for card_type in ["attack", "defense", "skill", "control", "heal", "finisher"]:
			if battle.get_turn_card_type_count(card_type) > 0:
				type_count += 1
		if type_count >= 2:
			battle.player.gain_shield(battle.modify_shield_amount(battle.player, battle.player, 5))
			battle.notify_world_rule_feedback("热门话题完成：不同牌型获得 5 护盾")
		else:
			battle.enemy.add_status("charged", 1)
			battle.notify_world_rule_feedback("热门话题未完成：众声聚合体获得声量")


func on_player_damaged(battle) -> void:
	if battle.player.major_id == FEILAN_ID and _feilan_damage_heat and not _feilan_damage_heat_used:
		_feilan_damage_heat_used = true
		_change_heat(battle, 2)
		battle.notify_world_rule_feedback("黑红也是红：受伤转化为 2 热度")


func resolve_world_choice(battle, choice_id: String, context: Dictionary) -> bool:
	if str(context.get("kind", "")) != "short_comment":
		return false
	var value := maxi(0, int(context.get("value", 3)))
	if choice_id == "attack":
		_deal_feilan_damage(battle, null, value)
		battle.notify_world_rule_feedback("短评已发布：造成 %d 点伤害" % value)
		return true
	if choice_id == "shield":
		battle.player.gain_shield(battle.modify_shield_amount(battle.player, battle.player, value))
		battle.notify_world_rule_feedback("短评已护航：获得 %d 点护盾" % value)
		return true
	return false


func _process_feilan_effect(battle, card: Resource, effect: Resource, caster) -> bool:
	match str(effect.type):
		"heat":
			_change_heat(battle, int(effect.value))
			return true
		"random_heat":
			_change_heat(battle, int(effect.params.get("high_value", 3)) if battle.roll_chance(0.5) else int(effect.value))
			return true
		"draw_if_hot":
			if _get_heat() >= 5:
				caster.draw_cards(int(effect.value), battle.MAX_HAND_SIZE)
			return true
		"hot_damage":
			_deal_feilan_damage(battle, card, int(effect.params.get("hot_value", effect.value)) if _get_heat() >= 5 else int(effect.value))
			return true
		"heat_if_previous_attack":
			if battle.get_turn_card_type_count("attack") > 0:
				_change_heat(battle, int(effect.value))
			return true
		"self_damage":
			caster.take_damage(maxi(0, int(effect.value)))
			return true
		"black_red":
			for _i in range(maxi(1, int(effect.params.get("hits", 2)))):
				if _deal_feilan_damage(battle, card, int(effect.value)) > 0:
					_change_heat(battle, 1)
			return true
		"generate_short_comment":
			_generate_short_comments(caster, int(effect.value), battle)
			return true
		"short_comment":
			return battle.request_world_choice({
				"kind": "short_comment",
				"title": "短评 · 选择表达方式",
				"description": "热度会消散，但这一句可以成为攻击或护航。",
				"value": int(effect.value),
				"choices": [
					{"id": "attack", "label": "锐利短评 · 造成 %d 伤害" % int(effect.value)},
					{"id": "shield", "label": "护航短评 · 获得 %d 护盾" % int(effect.value)},
				],
			})
		"enable_heat_guard", "enable_damage_heat", "enable_cost_heat", "enable_hot_discount", "enable_heat_loss_burst", "enable_overheat_draw", "enable_global_hot_list", "enable_comeback", "enable_heat_refund":
			return true
		"spend_heat_heal_draw":
			var spend := mini(_get_heat(), maxi(0, int(effect.params.get("heat_cost", 0))))
			_change_heat(battle, -spend)
			if spend >= int(effect.params.get("heat_cost", 0)):
				caster.heal(maxi(0, int(effect.params.get("heal", 0))))
				caster.draw_cards(maxi(0, int(effect.params.get("draw", 0))), battle.MAX_HAND_SIZE)
			return true
		"low_hp_damage":
			var is_low_hp: bool = caster.hp * 2 < caster.max_hp
			_deal_feilan_damage(battle, card, int(effect.params.get("low_value", effect.value)) if is_low_hp else int(effect.value))
			if is_low_hp:
				_change_heat(battle, int(effect.params.get("heat", 0)))
			return true
		"purge_or_heat_shield":
			var removed := false
			for status_id in caster.statuses.keys():
				if Status.is_debuff(str(status_id)):
					caster.remove_status(str(status_id))
					removed = true
					break
			if removed:
				caster.gain_shield(battle.modify_shield_amount(caster, caster, int(effect.value)))
			else:
				_change_heat(battle, int(effect.params.get("heat", 0)))
			return true
		"spend_heat_damage":
			var spent := mini(_get_heat(), maxi(0, int(effect.params.get("max_heat", _get_heat()))))
			_change_heat(battle, -spent)
			_deal_feilan_damage(battle, card, int(effect.value) + spent * int(effect.params.get("per_heat", 0)))
			return true
		"half_heat_damage":
			var heat_before := _get_heat()
			_deal_feilan_damage(battle, card, int(effect.value) + heat_before * int(effect.params.get("per_heat", 0)))
			_change_heat(battle, -int(ceil(float(heat_before) / 2.0)))
			return true
		"set_heat_floor":
			GameState.set_character_run_state_value("heat_floor", int(effect.params.get("floor", 0)))
			_set_heat(battle, int(effect.params.get("heat", _get_heat())))
			return true
		"set_heat":
			_set_heat(battle, int(effect.value))
			return true
	return false


func _reset_feilan_battle_flags() -> void:
	_feilan_indicator_ready = true
	_feilan_heat_guard = false
	_feilan_heat_guard_used = false
	_feilan_damage_heat = false
	_feilan_damage_heat_used = false
	_feilan_cost_heat = false
	_feilan_hot_discount = false
	_feilan_heat_loss_burst = false
	_feilan_overheat_draw = false
	_feilan_global_hot_list = false
	_feilan_heat_refund = false
	_feilan_heat_refund_used = false
	_feilan_comeback_attacks = 0


func _change_heat(battle, amount: int, is_card_loss: bool = true) -> int:
	var before := _get_heat()
	var floor := _get_heat_floor()
	var target := before + amount
	if amount < 0:
		target = maxi(floor, target)
	GameState.set_character_run_state_value("heat", target)
	var after := _get_heat()
	var actual_change := after - before
	if actual_change > 0:
		if _feilan_heat_guard and not _feilan_heat_guard_used:
			_feilan_heat_guard_used = true
			battle.player.gain_shield(battle.modify_shield_amount(battle.player, battle.player, 4))
		if _feilan_indicator_ready and before < 5 and after >= 5 and GameState.has_relic("unextinguished_indicator"):
			_feilan_indicator_ready = false
			battle.player.draw_cards(2, battle.MAX_HAND_SIZE)
			battle.notify_world_rule_feedback("未熄指示灯点亮：首次登上热榜，抽 2 张牌")
	if actual_change < 0 and is_card_loss:
		var spent := -actual_change
		if _feilan_heat_loss_burst:
			_deal_feilan_damage(battle, null, 4)
		if _feilan_heat_refund and not _feilan_heat_refund_used:
			_feilan_heat_refund_used = true
			GameState.add_character_run_state_int("heat", int(ceil(float(spent) / 2.0)))
	battle.notify_character_resource_updated()
	return after


func _set_heat(battle, value: int) -> int:
	return _change_heat(battle, value - _get_heat())


func _get_heat() -> int:
	return int(GameState.get_character_run_state_value("heat", 0))


func _get_heat_floor() -> int:
	return int(GameState.get_character_run_state_value("heat_floor", 0))


func _generate_short_comments(caster, count: int, battle) -> void:
	var comment: Resource = Config.cards.get("feilan_short_comment")
	if comment == null:
		return
	for _i in range(maxi(0, count)):
		if caster.hand.size() >= battle.MAX_HAND_SIZE:
			break
		caster.hand.append(comment)
	battle.notify_character_resource_updated()


func _deal_feilan_damage(battle, card: Resource, amount: int) -> int:
	var damage := maxi(0, amount + int(GameState.get_effective_stat("学识") / 3))
	if card != null:
		damage = battle.modify_card_damage(card, battle.player, battle.enemy, damage)
	return battle.deal_direct_damage_to_enemy(damage)


func _track_voice_aggregate(battle, card: Resource) -> void:
	if str(battle.enemy_resource.id) != "vl_voice_aggregate":
		return
	_recent_boss_signatures.append("%s:%d" % [str(card.type), int(card.cost)])
	if _recent_boss_signatures.size() > 3:
		_recent_boss_signatures.pop_front()
	if _recent_boss_signatures.size() == 3 and _recent_boss_signatures[0] == _recent_boss_signatures[1] and _recent_boss_signatures[1] == _recent_boss_signatures[2]:
		battle.enemy.add_status("charged", 1)
		battle.notify_world_rule_feedback("众声聚合体捕捉到重复话题：获得声量")
