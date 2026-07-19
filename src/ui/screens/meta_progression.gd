extends Control
## 局外成长中枢：购买、装配天赋与装备，并提升永久强化。

@onready var back_button: Button = $Header/Margin/Row/BackButton
@onready var gold_label: Label = $Header/Margin/Row/GoldLabel
@onready var status_label: Label = $Header/Margin/Row/TitleColumn/StatusLabel
@onready var talent_list: VBoxContainer = $Content/TalentsPanel/Margin/VBox/TalentScroll/TalentList
@onready var equipment_list: VBoxContainer = $Content/EquipmentPanel/Margin/VBox/EquipmentScroll/EquipmentList
@onready var upgrade_list: VBoxContainer = $Content/UpgradesPanel/Margin/VBox/UpgradeScroll/UpgradeList

var _entry_buttons: Dictionary = {}
var _focus_key := ""
var _built_once := false


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	MetaProgression.profile_changed.connect(_rebuild)
	_rebuild()
	AudioManager.play_bgm_for_phase("menu")


func _rebuild() -> void:
	gold_label.text = "◆ 永久金币\n%d" % MetaProgression.get_gold()
	_entry_buttons.clear()
	_clear_entries(talent_list)
	_clear_entries(equipment_list)
	_clear_entries(upgrade_list)
	_build_talents()
	_build_equipment()
	_build_upgrades()
	if not _built_once:
		_built_once = true
		_focus_key = "talent:%s" % MetaProgression.get_talent_ids()[0]
	call_deferred("_restore_focus")


func _build_talents() -> void:
	var equipped_count := MetaProgression.get_equipped_talent_ids().size()
	for talent_id in MetaProgression.get_talent_ids():
		var info := MetaProgression.get_talent_info(talent_id)
		var unlocked := MetaProgression.is_talent_unlocked(talent_id)
		var equipped := MetaProgression.is_talent_equipped(talent_id)
		var cost := int(info.get("cost", 0))
		var action_text := "购买 %d 金币" % cost
		var disabled := not MetaProgression.can_afford(cost)
		var variation := &""
		if equipped:
			action_text = "已装配 · 点击卸下"
			disabled = false
			variation = &"PrimaryButton"
		elif unlocked:
			action_text = "已解锁 · 点击装配（%d/%d）" % [
				equipped_count,
				MetaProgression.TALENT_SLOT_LIMIT,
			]
			disabled = false
		var text := "%s\n%s" % [str(info.get("name", talent_id)), action_text]
		_add_entry(
			talent_list,
			"talent:%s" % talent_id,
			text,
			str(info.get("desc", "")),
			disabled,
			_on_talent_action.bind(talent_id),
			variation,
		)


func _build_equipment() -> void:
	var current := MetaProgression.get_equipped_equipment()
	for slot_id in MetaProgression.EQUIPMENT_SLOTS:
		var slot_label := Label.new()
		slot_label.text = "— %s槽 —" % str(MetaProgression.EQUIPMENT_SLOTS[slot_id])
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.add_theme_color_override("font_color", UIColors.BORDER_CYAN_BRIGHT)
		equipment_list.add_child(slot_label)
		for equipment_id in MetaProgression.get_equipment_ids():
			var info := MetaProgression.get_equipment_info(equipment_id)
			if str(info.get("slot", "")) != slot_id:
				continue
			var owned := MetaProgression.is_equipment_owned(equipment_id)
			var equipped := str(current.get(slot_id, "")) == equipment_id
			var cost := int(info.get("cost", 0))
			var action_text := "购买 %d 金币" % cost
			var disabled := not MetaProgression.can_afford(cost)
			var variation := &""
			if equipped:
				action_text = "已装配 · 点击卸下"
				disabled = false
				variation = &"PrimaryButton"
			elif owned:
				action_text = "已拥有 · 点击替换"
				disabled = false
			var text := "%s\n%s" % [str(info.get("name", equipment_id)), action_text]
			_add_entry(
				equipment_list,
				"equipment:%s" % equipment_id,
				text,
				str(info.get("desc", "")),
				disabled,
				_on_equipment_action.bind(equipment_id),
				variation,
			)


func _build_upgrades() -> void:
	for upgrade_id in MetaProgression.get_upgrade_ids():
		var info := MetaProgression.get_upgrade_info(upgrade_id)
		var level := MetaProgression.get_upgrade_level(upgrade_id)
		var max_level := int(info.get("max_level", 0))
		var cost := MetaProgression.get_next_upgrade_cost(upgrade_id)
		var action_text := "已满级" if cost < 0 else "强化需 %d 金币" % cost
		var disabled := cost < 0 or not MetaProgression.can_afford(cost)
		var text := "%s　Lv.%d/%d\n%s" % [
			str(info.get("name", upgrade_id)),
			level,
			max_level,
			action_text,
		]
		_add_entry(
			upgrade_list,
			"upgrade:%s" % upgrade_id,
			text,
			str(info.get("desc", "")),
			disabled,
			_on_upgrade_action.bind(upgrade_id),
			&"PrimaryButton" if level >= max_level else &"",
		)


func _add_entry(
	parent: VBoxContainer,
	key: String,
	text: String,
	tooltip: String,
	disabled: bool,
	action: Callable,
	variation: StringName,
) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = text
	button.tooltip_text = tooltip
	button.disabled = disabled
	if variation != &"":
		button.theme_type_variation = variation
	button.pressed.connect(action)
	parent.add_child(button)
	_entry_buttons[key] = button


func _clear_entries(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_talent_action(talent_id: String) -> void:
	_focus_key = "talent:%s" % talent_id
	var info := MetaProgression.get_talent_info(talent_id)
	var name := str(info.get("name", talent_id))
	if MetaProgression.is_talent_equipped(talent_id):
		MetaProgression.unequip_talent(talent_id)
		_show_status("已卸下天赋「%s」；下局开始生效。" % name)
		return
	if not MetaProgression.is_talent_unlocked(talent_id):
		if not MetaProgression.purchase_talent(talent_id):
			_show_status("金币不足，无法购买「%s」。" % name, true)
			return
		_show_status("永久解锁天赋「%s」。" % name)
	if MetaProgression.equip_talent(talent_id):
		_show_status("已装配天赋「%s」；下局开始生效。" % name)
	else:
		_show_status("天赋槽已满，请先卸下一个天赋。" , true)


func _on_equipment_action(equipment_id: String) -> void:
	_focus_key = "equipment:%s" % equipment_id
	var info := MetaProgression.get_equipment_info(equipment_id)
	var name := str(info.get("name", equipment_id))
	var slot_id := str(info.get("slot", ""))
	if str(MetaProgression.get_equipped_equipment().get(slot_id, "")) == equipment_id:
		MetaProgression.unequip_slot(slot_id)
		_show_status("已卸下装备「%s」；下局开始生效。" % name)
		return
	if not MetaProgression.is_equipment_owned(equipment_id):
		if not MetaProgression.purchase_equipment(equipment_id):
			_show_status("金币不足，无法购买「%s」。" % name, true)
			return
		_show_status("永久获得装备「%s」。" % name)
	if MetaProgression.equip_equipment(equipment_id):
		_show_status("已装配「%s」；同槽旧装备已替换。" % name)


func _on_upgrade_action(upgrade_id: String) -> void:
	_focus_key = "upgrade:%s" % upgrade_id
	var name := str(MetaProgression.get_upgrade_info(upgrade_id).get("name", upgrade_id))
	if MetaProgression.purchase_upgrade(upgrade_id):
		_show_status("「%s」已提升至 Lv.%d；下局开始生效。" % [
			name,
			MetaProgression.get_upgrade_level(upgrade_id),
		])
	else:
		_show_status("金币不足或该强化已满级。", true)


func _show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.add_theme_color_override(
		"font_color",
		UIColors.DANGER_RED if is_error else UIColors.SUCCESS_GREEN,
	)


func _restore_focus() -> void:
	var button = _entry_buttons.get(_focus_key)
	if button is Button and is_instance_valid(button) and not button.disabled:
		button.grab_focus()
		return
	for candidate in _entry_buttons.values():
		if candidate is Button and is_instance_valid(candidate) and not candidate.disabled:
			candidate.grab_focus()
			return
	back_button.grab_focus()


func _on_back() -> void:
	AudioManager.play_sfx("click")
	GameState.change_screen(GameState.Screen.MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
