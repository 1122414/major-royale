extends Node
## 奖励选择人工验收入口。


func _ready() -> void:
	GameState.start_run("computer")
	GameState.last_reward_is_elite = true
	GameState.run_progress = 2
	GameState.damage_run(18)
	GameState.add_relic("coffee_thermos")
	var reward = (load("res://src/ui/screens/reward.tscn") as PackedScene).instantiate()
	add_child(reward)
