extends Node
## 全局音效管理器。

@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()

# 占位音效资源（使用 Godot 内置波形生成简单音效）
var _sfx_placeholders: Dictionary = {}


func _ready() -> void:
	add_child(sfx_player)
	add_child(music_player)
	_generate_placeholders()


func _generate_placeholders() -> void:
	_sfx_placeholders["click"] = _generate_beep(440.0, 0.1)
	_sfx_placeholders["card_play"] = _generate_beep(660.0, 0.15)
	_sfx_placeholders["attack"] = _generate_noise(0.2)
	_sfx_placeholders["shield"] = _generate_beep(330.0, 0.3)
	_sfx_placeholders["heal"] = _generate_beep(880.0, 0.3)
	_sfx_placeholders["win"] = _generate_beep(880.0, 0.5)
	_sfx_placeholders["lose"] = _generate_beep(110.0, 0.5)


func _generate_beep(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var frame_count := int(sample_rate * duration)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate

	var data := PackedByteArray()
	data.resize(frame_count)
	for i in frame_count:
		var t := float(i) / float(sample_rate)
		var sample := sin(t * frequency * TAU) * 0.5 + 0.5
		data[i] = int(sample * 255)
	wav.data = data
	return wav


func _generate_noise(duration: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var frame_count := int(sample_rate * duration)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate

	var data := PackedByteArray()
	data.resize(frame_count)
	for i in frame_count:
		data[i] = int(randf() * 255)
	wav.data = data
	return wav


func play_sfx(name: String) -> void:
	var stream = _sfx_placeholders.get(name)
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
