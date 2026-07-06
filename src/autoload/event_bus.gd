extends Node
## 全局事件总线：用于 UI 与逻辑层解耦通信。

signal battle_started(enemy_id: String)
signal battle_ended(victory: bool, rewards: Array)
signal reward_selected(reward_type: String, reward_id: String)
signal event_triggered(event_id: String)
signal map_node_selected(node_id: String)
signal settings_requested()
