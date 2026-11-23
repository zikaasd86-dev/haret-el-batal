extends Node
## Autoload: GameState
## يدير حالة اللعبة العامة + إعدادات الموبايل (الموسيقى، المؤثرات، الفايبريشن، الإطلاق التلقائي)
## مع حفظ تلقائي للإعدادات على الجهاز في user://settings.cfg

const SETTINGS_PATH := "user://settings.cfg"

signal score_changed(new_score: int)
signal player_hp_changed(current_hp: int, max_hp: int)
signal boss_hp_changed(current_hp: int, max_hp: int, phase: int)
signal boss_activated(active: bool)
signal autofire_changed(enabled: bool)
signal music_changed(enabled: bool)
signal sfx_changed(enabled: bool)
signal vibration_changed(enabled: bool)
signal screen_shake_requested(intensity: float, duration: float)
signal game_over()
signal level_cleared()

var score: int = 0
var auto_fire_enabled: bool = false
var music_enabled: bool = true
var sfx_enabled: bool = true
var vibration_enabled: bool = true
var is_game_over: bool = false
var is_level_cleared: bool = false


func _ready() -> void:
	load_settings()


func reset_run() -> void:
	score = 0
	is_game_over = false
	is_level_cleared = false
	score_changed.emit(score)
	boss_activated.emit(false)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func toggle_auto_fire() -> void:
	set_auto_fire(not auto_fire_enabled)


func set_auto_fire(enabled: bool) -> void:
	if auto_fire_enabled != enabled:
		auto_fire_enabled = enabled
		save_settings()
		autofire_changed.emit(auto_fire_enabled)


func toggle_music() -> void:
	music_enabled = not music_enabled
	save_settings()
	music_changed.emit(music_enabled)


func toggle_sfx() -> void:
	sfx_enabled = not sfx_enabled
	save_settings()
	sfx_changed.emit(sfx_enabled)


func toggle_vibration() -> void:
	vibration_enabled = not vibration_enabled
	save_settings()
	vibration_changed.emit(vibration_enabled)
	if vibration_enabled:
		vibrate(35)


## هزة فايبرشن للموبايل (تعمل تلقائياً على Android و iOS)
func vibrate(duration_ms: int = 35) -> void:
	if vibration_enabled:
		Input.vibrate_handheld(duration_ms)


func request_shake(intensity: float = 3.0, duration: float = 0.16) -> void:
	screen_shake_requested.emit(intensity, duration)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "music", music_enabled)
	cfg.set_value("settings", "sfx", sfx_enabled)
	cfg.set_value("settings", "vibration", vibration_enabled)
	cfg.set_value("settings", "auto_fire", auto_fire_enabled)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_enabled = bool(cfg.get_value("settings", "music", true))
	sfx_enabled = bool(cfg.get_value("settings", "sfx", true))
	vibration_enabled = bool(cfg.get_value("settings", "vibration", true))
	auto_fire_enabled = bool(cfg.get_value("settings", "auto_fire", false))


func trigger_game_over() -> void:
	if is_game_over or is_level_cleared:
		return
	is_game_over = true
	game_over.emit()


func trigger_level_cleared() -> void:
	if is_level_cleared:
		return
	is_level_cleared = true
	level_cleared.emit()
