extends Node
## 用户设置管理器：保存到 user://settings.cfg，通过 UI 设置图标修改。

const SETTINGS_PATH := "user://settings.cfg"

var ai_enabled: bool = true
var ai_server_url: String = "http://127.0.0.1:8000"
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = false
var action_window_scale: float = 1.0
var reduced_motion: bool = false
var controller_vibration: bool = true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		print("使用默认设置")
		return

	ai_enabled = cfg.get_value("ai", "enabled", ai_enabled)
	ai_server_url = cfg.get_value("ai", "server_url", ai_server_url)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	action_window_scale = float(cfg.get_value("accessibility", "action_window_scale", action_window_scale))
	reduced_motion = bool(cfg.get_value("accessibility", "reduced_motion", reduced_motion))
	controller_vibration = bool(cfg.get_value("accessibility", "controller_vibration", controller_vibration))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ai", "enabled", ai_enabled)
	cfg.set_value("ai", "server_url", ai_server_url)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("accessibility", "action_window_scale", action_window_scale)
	cfg.set_value("accessibility", "reduced_motion", reduced_motion)
	cfg.set_value("accessibility", "controller_vibration", controller_vibration)

	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("无法保存设置文件: %s" % SETTINGS_PATH)
