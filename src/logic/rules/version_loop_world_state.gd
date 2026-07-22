extends RefCounted

## 版本回环的非战斗世界状态操作。地图、事件和商店共用这一处状态契约。

const WORLD_ID := "version_loop"
const PATCH_NOTICE_KEY := "patch_notice_id"
const MAINTENANCE_CLOCK_KEY := "maintenance_clock"
const MAINTENANCE_DUE_KEY := "maintenance_due"
const COMPENSATION_TICKETS_KEY := "compensation_tickets"
const ACTIVITY_STAMINA_KEY := "activity_stamina"


static func select_patch_notice(notice_id: String) -> bool:
	if GameState.current_world_id != WORLD_ID:
		return false
	return GameState.set_world_run_state_value(PATCH_NOTICE_KEY, notice_id)


static func is_maintenance_due() -> bool:
	return GameState.current_world_id == WORLD_ID and bool(GameState.get_world_run_state_value(MAINTENANCE_DUE_KEY, false))


static func resolve_forced_maintenance() -> Dictionary:
	if not is_maintenance_due():
		return {}
	GameState.set_world_run_state_value(MAINTENANCE_CLOCK_KEY, 0)
	GameState.set_world_run_state_value(MAINTENANCE_DUE_KEY, false)
	var tickets := GameState.add_world_run_state_int(COMPENSATION_TICKETS_KEY, 1)
	var stamina := GameState.add_world_run_state_int(ACTIVITY_STAMINA_KEY, 1)
	return {
		"compensation_tickets": tickets,
		"activity_stamina": stamina,
	}


static func spend_compensation_ticket() -> bool:
	if GameState.current_world_id != WORLD_ID:
		return false
	var tickets := int(GameState.get_world_run_state_value(COMPENSATION_TICKETS_KEY, 0))
	if tickets <= 0:
		return false
	GameState.add_world_run_state_int(COMPENSATION_TICKETS_KEY, -1)
	return true
