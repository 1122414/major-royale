extends Node
## 全局音效 / BGM 管理器。

const BGM_DIR := "res://assets/audio/bgm/"
const SFX_VOICE_COUNT := 4
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
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_voice := 0
var _menu_track_index: int = 0
var _current_bgm_id: String = ""
var _shutdown_requested := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	add_child(sfx_player)
	_sfx_players.append(sfx_player)
	for _voice_index in range(1, SFX_VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_sfx_players.append(voice)
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)
	_generate_placeholders()
	_load_or_generate_bgm()
	_apply_volumes()
	# 启动默认播主页 BGM
	play_bgm_by_id("menu")


func _exit_tree() -> void:
	prepare_shutdown()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_application_quit()


func request_application_quit() -> void:
	if _shutdown_requested:
		return
	_shutdown_requested = true
	prepare_shutdown()
	var timer := get_tree().create_timer(0.2, true)
	timer.timeout.connect(func(): get_tree().quit(), CONNECT_ONE_SHOT)


func stop_all() -> void:
	_current_bgm_id = ""
	for voice in _sfx_players:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null


func prepare_shutdown() -> void:
	stop_all()
	_sfx_placeholders.clear()
	_bgm_streams.clear()


func _apply_volumes() -> void:
	if Settings:
		set_master_volume(Settings.master_volume)
		set_music_volume(Settings.music_volume)
		set_sfx_volume(Settings.sfx_volume)


func _generate_placeholders() -> void:
	# 小体积程序化音效：不同轮廓负责操作、卡牌、答辩窗口与结算反馈。
	_sfx_placeholders["click"] = _generate_soft_tone(220.0, 0.06, 0.12)
	_sfx_placeholders["card_play"] = _generate_arpeggio(PackedFloat32Array([330.0, 440.0]), 0.1, 0.13)
	_sfx_placeholders["attack"] = _generate_soft_noise(0.12, 0.18)
	_sfx_placeholders["shield"] = _generate_arpeggio(PackedFloat32Array([196.0, 246.9]), 0.18, 0.11)
	_sfx_placeholders["heal"] = _generate_arpeggio(PackedFloat32Array([392.0, 523.3]), 0.2, 0.11)
	_sfx_placeholders["perfect"] = _generate_arpeggio(PackedFloat32Array([392.0, 523.3, 659.3]), 0.3, 0.13)
	_sfx_placeholders["dodge"] = _generate_arpeggio(PackedFloat32Array([523.3, 392.0]), 0.14, 0.1)
	_sfx_placeholders["brace"] = _generate_arpeggio(PackedFloat32Array([174.6, 220.0]), 0.2, 0.11)
	_sfx_placeholders["damage"] = _generate_soft_noise(0.16, 0.22)
	_sfx_placeholders["win"] = _generate_arpeggio(PackedFloat32Array([392.0, 523.3, 659.3]), 0.42, 0.14)
	_sfx_placeholders["lose"] = _generate_arpeggio(PackedFloat32Array([196.0, 164.8, 130.8]), 0.45, 0.1)


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


func _generate_arpeggio(frequencies: PackedFloat32Array, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var frame_count := int(sample_rate * duration)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate

	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var note_count := maxi(frequencies.size(), 1)
	var note_duration := duration / float(note_count)
	for i in frame_count:
		var t := float(i) / float(sample_rate)
		var note_index := mini(int(t / note_duration), note_count - 1)
		var note_time := fmod(t, note_duration)
		var frequency := frequencies[note_index] if not frequencies.is_empty() else 220.0
		var note_env := minf(note_time / 0.01, 1.0) * clampf((note_duration - note_time) / maxf(0.025, note_duration * 0.45), 0.0, 1.0)
		var sample := (
			sin(t * frequency * TAU)
			+ sin(t * frequency * 2.0 * TAU) * 0.18
		) * amplitude * note_env
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 314159
	var prev := 0.0
	for i in frame_count:
		var t := float(i) / float(sample_rate)
		var env := 1.0
		var release := duration * 0.5
		if t > duration - release:
			env = maxf(0.0, (duration - t) / release)
		# 简单低通噪声，更闷、不刺耳
		var n := rng.randf_range(-1.0, 1.0)
		prev = prev * 0.85 + n * 0.15
		var sample := prev * amplitude * env
		var s16 := clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s16)
	wav.data = data
	return wav


func _load_or_generate_bgm() -> void:
	var abs_dir := ProjectSettings.globalize_path(BGM_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	for track in BGM_TRACKS:
		var path: String = BGM_DIR + track.file
		var stream: AudioStream = _load_bgm_stream(path)
		if stream == null:
			stream = _generate_default_bgm(track.id)
			_try_save_wav(path, stream)
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if wav.loop_end <= 0 and wav.data.size() > 0:
				wav.loop_begin = 0
				wav.loop_end = int(wav.data.size() / 2)  # 16-bit mono
		_bgm_streams[track.id] = stream


func _load_bgm_stream(res_path: String) -> AudioStream:
	if ResourceLoader.exists(res_path):
		var loaded = load(res_path)
		if loaded is AudioStream:
			return loaded
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		# Godot 4.4：从磁盘直接读 WAV（无需先 import）
		return AudioStreamWAV.load_from_file(abs_path)
	return null


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
		var edge := minf(minf(t, duration - t), 0.4) / 0.4
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
	if stream == null or _sfx_players.is_empty():
		return
	var voice := _sfx_players[_next_sfx_voice % _sfx_players.size()]
	_next_sfx_voice = (_next_sfx_voice + 1) % _sfx_players.size()
	voice.stream = stream
	voice.play()


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
	var volume_db := linear_to_db(clampf(volume, 0.001, 1.0))
	for voice in _sfx_players:
		voice.volume_db = volume_db
