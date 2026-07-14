extends Node
## 全局音效 / BGM 管理器。

const BGM_DIR := "res://assets/audio/bgm/"
## 五轨默认 BGM（可替换同名文件）：menu / explore / battle / boss / victory
const BGM_TRACKS := [
	{"id": "menu", "name": "主页轻律", "file": "01_menu.wav", "phase": "menu"},
	{"id": "explore", "name": "探索漫步", "file": "02_explore.wav", "phase": "explore"},
	{"id": "battle", "name": "战斗脉冲", "file": "03_battle.wav", "phase": "battle"},
	{"id": "boss", "name": "Boss压迫", "file": "04_boss.wav", "phase": "boss"},
	{"id": "victory", "name": "胜利余韵", "file": "05_victory.wav", "phase": "victory"},
]

@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()

var _sfx_placeholders: Dictionary = {}
var _bgm_streams: Dictionary = {}  # id -> AudioStream
var _menu_track_index: int = 0
var _current_bgm_id: String = ""


func _ready() -> void:
	add_child(sfx_player)
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)
	_generate_placeholders()
	_load_or_generate_bgm()
	_apply_volumes()
	# 启动默认播主页 BGM
	play_bgm_by_id("menu")


func _apply_volumes() -> void:
	if Settings:
		set_master_volume(Settings.master_volume)
		set_music_volume(Settings.music_volume)
		set_sfx_volume(Settings.sfx_volume)


func _generate_placeholders() -> void:
	# 柔和短音：低音量 + 包络淡入淡出，避免刺耳「滴」声
	_sfx_placeholders["click"] = _generate_soft_tone(220.0, 0.06, 0.12)
	_sfx_placeholders["card_play"] = _generate_soft_tone(330.0, 0.08, 0.14)
	_sfx_placeholders["attack"] = _generate_soft_noise(0.12, 0.18)
	_sfx_placeholders["shield"] = _generate_soft_tone(196.0, 0.18, 0.12)
	_sfx_placeholders["heal"] = _generate_soft_tone(392.0, 0.2, 0.12)
	_sfx_placeholders["win"] = _generate_soft_tone(523.0, 0.35, 0.14)
	_sfx_placeholders["lose"] = _generate_soft_tone(130.0, 0.4, 0.1)


func _generate_soft_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var frame_count := int(sample_rate * duration)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate

	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for i in frame_count:
		var t := float(i) / float(sample_rate)
		var env := 1.0
		var attack := 0.015
		var release := duration * 0.45
		if t < attack:
			env = t / attack
		elif t > duration - release:
			env = maxf(0.0, (duration - t) / release)
		var sample := sin(t * frequency * TAU) * amplitude * env
		var s16 := clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s16)
	wav.data = data
	return wav


func _generate_soft_noise(duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var frame_count := int(sample_rate * duration)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate

	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var prev := 0.0
	for i in frame_count:
		var t := float(i) / float(sample_rate)
		var env := 1.0
		var release := duration * 0.5
		if t > duration - release:
			env = maxf(0.0, (duration - t) / release)
		# 简单低通噪声，更闷、不刺耳
		var n := (randf() * 2.0 - 1.0)
		prev = prev * 0.85 + n * 0.15
		var sample := prev * amplitude * env
		var s16 := clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s16)
	wav.data = data
	return wav


func _load_or_generate_bgm() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio/bgm")
	# 运行时用用户可替换的 res 路径；若无文件则生成默认循环并尝试落盘到项目目录
	for track in BGM_TRACKS:
		var path: String = BGM_DIR + track.file
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = load(path)
		if stream == null:
			stream = _generate_default_bgm(track.id)
			_try_save_wav(path, stream)
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_bgm_streams[track.id] = stream


func _generate_default_bgm(track_id: String) -> AudioStreamWAV:
	## 五轨默认氛围：不同根音/节奏的柔和双音 pad，可被同名 wav 覆盖。
	var roots := {
		"menu": [196.0, 246.9],
		"explore": [174.6, 220.0],
		"battle": [110.0, 146.8],
		"boss": [82.4, 123.5],
		"victory": [261.6, 329.6],
	}
	var tempos := {
		"menu": 0.4,
		"explore": 0.55,
		"battle": 1.1,
		"boss": 0.85,
		"victory": 0.5,
	}
	var pair: Array = roots.get(track_id, [196.0, 246.9])
	var pulse: float = tempos.get(track_id, 0.5)
	var sample_rate := 22050
	var duration := 8.0
	var frame_count := int(sample_rate * duration)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frame_count

	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var f1: float = pair[0]
	var f2: float = pair[1]
	for i in frame_count:
		var t := float(i) / float(sample_rate)
		var beat := 0.55 + 0.45 * absf(sin(t * pulse * TAU * 0.5))
		var sample := (
			sin(t * f1 * TAU) * 0.11
			+ sin(t * f2 * TAU) * 0.08
			+ sin(t * (f1 * 0.5) * TAU) * 0.05
		) * beat
		# 首尾淡入淡出便于循环
		var edge := minf(t, duration - t, 0.4) / 0.4
		sample *= clampf(edge, 0.0, 1.0)
		var s16 := clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s16)
	wav.data = data
	return wav


func _try_save_wav(res_path: String, stream: AudioStream) -> void:
	if not (stream is AudioStreamWAV):
		return
	var abs_path := ProjectSettings.globalize_path(res_path)
	var dir_path := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var err := (stream as AudioStreamWAV).save_to_wav(abs_path)
	if err != OK:
		push_warning("无法写出默认 BGM: %s (%s)" % [abs_path, error_string(err)])


func play_sfx(sfx_name: String) -> void:
	var stream = _sfx_placeholders.get(sfx_name)
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()


func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()


func play_bgm_by_id(track_id: String, force: bool = false) -> void:
	if not force and _current_bgm_id == track_id and music_player.playing:
		return
	var stream: AudioStream = _bgm_streams.get(track_id)
	if stream == null:
		return
	_current_bgm_id = track_id
	music_player.stream = stream
	music_player.play()


func play_bgm_for_phase(phase: String) -> void:
	for track in BGM_TRACKS:
		if track.phase == phase:
			play_bgm_by_id(track.id)
			return


func cycle_menu_bgm() -> String:
	_menu_track_index = (_menu_track_index + 1) % BGM_TRACKS.size()
	var track: Dictionary = BGM_TRACKS[_menu_track_index]
	play_bgm_by_id(track.id, true)
	return str(track.name)


func get_current_bgm_name() -> String:
	for track in BGM_TRACKS:
		if track.id == _current_bgm_id:
			return str(track.name)
	return "无"


func get_menu_track_index() -> int:
	return _menu_track_index


func _on_music_finished() -> void:
	# 循环兜底（部分格式未设 loop 时）
	if music_player.stream != null:
		music_player.play()


func set_master_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(clampf(volume, 0.001, 1.0)))


func set_music_volume(volume: float) -> void:
	music_player.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))


func set_sfx_volume(volume: float) -> void:
	sfx_player.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
