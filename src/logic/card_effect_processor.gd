class_name CardEffectProcessor
extends RefCounted

## 处理单张卡牌的所有效果。

signal card_drawn(amount: int)
signal energy_gained(amount: int)
signal intent_revealed

var _battle: Battle


func _init(battle: Battle) -> void:
	_battle = battle


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
			actual_target.take_damage(damage)
		"shield":
			actual_target.gain_shield(value)
		"heal":
			actual_target.heal(value)
		"draw":
			if actual_target.is_player:
				actual_target.draw_cards(value)
				card_drawn.emit(value)
		"energy":
			if actual_target.is_player:
				_battle.energy += value
				energy_gained.emit(value)
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
			intent_revealed.emit()
		"conditional_damage":
			var threshold: int = _get_effect_param(effect, "threshold", 0)
			var real_value := value
			if actual_target.has_status(effect.status_id) and actual_target.get_status_stacks(effect.status_id) >= threshold:
				real_value = _get_effect_param(effect, "real_value", value * 2)
			actual_target.take_damage(real_value)
		"damage_per_debuff":
			var debuff_count := _count_debuffs(actual_target)
			actual_target.take_damage(debuff_count * value)
		"delay":
			_battle.delay_enemy(value)


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
