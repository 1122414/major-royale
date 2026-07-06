extends Node
## 全局音效管理器：占位实现，阶段 9 完善。

@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	add_child(sfx_player)
	add_child(music_player)


func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()


func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()


func set_master_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume))
