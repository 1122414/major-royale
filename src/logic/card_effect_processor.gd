class_name CardEffectProcessor
extends RefCounted

## 处理单张卡牌的所有效果。使用弱引用避免与 Battle 形成 RefCounted 环。

var _battle_ref: WeakRef


func _init(battle: Battle) -> void:
	_battle_ref = weakref(battle)


func process_card(card: Resource, caster: Character, target: Character) -> void:
	for effect in card.effects:
		_process_effect(effect, caster, target)


func _process_effect(effect: Resource, caster: Character, target: Character) -> void:
	var type: String = effect.type
	var value: int = effect.value
	var effect_target: String = effect.target

	var actual_target := _resolve_target(effect_target, caster, target)

	match type:
		"damage":
			var damage := value
			if caster.has_status("adrenaline"):
				damage += caster.get_status_stacks("adrenaline")
			if caster.is_player:
				damage += int(GameState.get_effective_stat("学识") / 3)
			if actual_target != null and not actual_target.is_player:
				var eid := str(GameState.player_stats.get("current_enemy_id", ""))
				var er = Config.enemies.get(eid)
				if er is EnemyResource and (er as EnemyResource).spirit_weak:
					damage = int(round(float(damage) * 1.3))
			var actual_damage := actual_target.take_damage(damage)
			if caster.is_player:
				GameState.run_damage_dealt += actual_damage
		"shield":
			actual_target.gain_shield(value)
			if caster.is_player and caster.major_id == "finance":
				actual_target.gain_shield(2)
		"heal":
			actual_target.heal(value)
		"spirit_damage":
			actual_target.lose_spirit(value)
		"draw":
			# 抽牌默认作用在施法者；JSON 常省略 target，不能落到敌人上
			if caster.is_player:
				caster.draw_cards(value)
		"energy":
			var battle := _get_battle()
			if caster.is_player and battle != null:
				battle.energy += value
		"status":
			actual_target.add_status(effect.status_id, effect.status_stacks)
		"debuff":
			actual_target.add_status(effect.status_id, effect.status_stacks)
		"buff":
			actual_target.add_status(effect.status_id, effect.status_stacks)
		"purge":
			if actual_target.is_player:
				_remove_negative_status(actual_target, value)
		"reveal_intent":
			var battle := _get_battle()
			if battle != null:
				battle.reveal_intent()
		"conditional_damage":
			var threshold: int = int(_get_effect_param(effect, "threshold", 0))
			var real_value := value
			if actual_target.has_status(effect.status_id) and actual_target.get_status_stacks(effect.status_id) >= threshold:
				real_value = int(_get_effect_param(effect, "real_value", value * 2))
			if caster.is_player:
				real_value += int(GameState.get_effective_stat("学识") / 3)
			var actual_damage := actual_target.take_damage(real_value)
			if caster.is_player:
				GameState.run_damage_dealt += actual_damage
		"damage_per_debuff":
			var debuff_count := _count_debuffs(actual_target)
			var total := debuff_count * value
			var actual_damage := actual_target.take_damage(total)
			if caster.is_player:
				GameState.run_damage_dealt += actual_damage
		"delay":
			var battle := _get_battle()
			if battle != null:
				battle.delay_enemy(value)


func _get_battle() -> Battle:
	return _battle_ref.get_ref() as Battle if _battle_ref != null else null


func _resolve_target(effect_target: String, caster: Character, default_target: Character) -> Character:
	match effect_target:
		"self": return caster
		"enemy": return default_target
		"all_enemies": return default_target
	return default_target


func _get_effect_param(effect: Resource, key: String, default_value: Variant) -> Variant:
	if effect.params.has(key):
		return effect.params[key]
	# 兼容直接写在 effect 上的字段
	if key == "threshold" and effect.has_meta("threshold"):
		return effect.get_meta("threshold")
	if key == "real_value" and effect.has_meta("real_value"):
		return effect.get_meta("real_value")
	return default_value


func _remove_negative_status(character: Character, amount: int) -> void:
	var removed := 0
	for status_id in character.statuses.keys():
		if Status.is_debuff(status_id):
			character.remove_status(status_id)
			removed += 1
			if removed >= amount and amount > 0:
				break


func _count_debuffs(character: Character) -> int:
	var count := 0
	for status_id in character.statuses.keys():
		if Status.is_debuff(status_id):
			count += character.get_status_stacks(status_id)
	return count
