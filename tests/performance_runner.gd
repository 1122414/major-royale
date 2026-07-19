extends Node
## 高频战斗界面创建/销毁与刷新压力测试，防止场景切换造成节点和静态内存持续爬升。

const WARMUP_CYCLES := 3
const MEASURED_CYCLES := 20
const UI_REFRESHES_PER_CYCLE := 20
const MAX_NODE_GROWTH := 4
const MAX_ORPHAN_GROWTH := 2
const MAX_MEMORY_GROWTH_BYTES := 12 * 1024 * 1024


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_ai_enabled := Settings.ai_enabled
	Settings.ai_enabled = false
	MetaProgression.save_enabled = false
	MetaProgression.reset_profile()

	for _i in WARMUP_CYCLES:
		await _run_battle_screen_cycle()
	await _settle_frames()

	var baseline_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var baseline_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var baseline_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var started_at := Time.get_ticks_usec()

	for _i in MEASURED_CYCLES:
		await _run_battle_screen_cycle()
	await _settle_frames()

	var elapsed_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
	var node_growth := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - baseline_nodes
	var orphan_growth := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - baseline_orphans
	var memory_growth := int(Performance.get_monitor(Performance.MEMORY_STATIC)) - baseline_memory

	assert(node_growth <= MAX_NODE_GROWTH, "重复战斗场景后节点持续增长: %d" % node_growth)
	assert(orphan_growth <= MAX_ORPHAN_GROWTH, "重复战斗场景后孤儿节点持续增长: %d" % orphan_growth)
	assert(memory_growth <= MAX_MEMORY_GROWTH_BYTES, "重复战斗场景后静态内存增长过高: %.2f MiB" % (float(memory_growth) / 1048576.0))

	print("PERF: %d 次战斗场景循环通过；节点增长 %d，孤儿增长 %d，静态内存增长 %.2f MiB，耗时 %.1f ms" % [
		MEASURED_CYCLES,
		node_growth,
		orphan_growth,
		float(memory_growth) / 1048576.0,
		elapsed_ms,
	])
	Settings.ai_enabled = previous_ai_enabled
	MetaProgression.reset_profile()
	AudioManager.prepare_shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)


func _run_battle_screen_cycle() -> void:
	GameState.start_run("computer")
	GameState.player_stats["current_enemy_id"] = "gpa_anxiety"
	var screen := (load("res://src/ui/screens/battle.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	for _i in UI_REFRESHES_PER_CYCLE:
		screen._request_ui_update()
	await get_tree().process_frame
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _settle_frames() -> void:
	for _i in 4:
		await get_tree().process_frame
