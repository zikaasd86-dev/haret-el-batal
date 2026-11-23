extends Node
## Autoload: GameState
## يدير حالة اللعبة + المحاولات (Lives) + حفظ المرحلة المفتوحة والانتقال بين المراحل بنفس المحاولات والنقاط

const SETTINGS_PATH := "user://settings.cfg"

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
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
var high_score: int = 0
var lives: int = 3
var current_stage: int = 1
var unlocked_stage: int = 1
var saved_weapon: int = 0

var auto_fire_enabled: bool = false
var music_enabled: bool = true
var sfx_enabled: bool = true
var vibration_enabled: bool = true
var is_game_over: bool = false
var is_level_cleared: bool = false


func _ready() -> void:
	load_settings()
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)


## بدء حملة جديدة من المرحلة 1 بـ 3 محاولات
func start_new_campaign() -> void:
	score = 0
	lives = 3
	current_stage = 1
	saved_weapon = 0
	is_game_over = false
	is_level_cleared = false
	score_changed.emit(score)
	lives_changed.emit(lives)
	boss_activated.emit(false)


## بدء مرحلة محددة مع الاحتفاظ بالمحاولات والنقاط والسلاح عند الانتقال للمرحلة التالية
func prepare_stage(stage_num: int) -> void:
	current_stage = stage_num
	is_game_over = false
	is_level_cleared = false
	if lives <= 0:
		lives = 3
	score_changed.emit(score)
	lives_changed.emit(lives)
	boss_activated.emit(false)


func reset_run() -> void:
	prepare_stage(current_stage)


func add_score(amount: int) -> void:
	score += amount
	if score > high_score:
		high_score = score
		save_settings()
	score_changed.emit(score)


func lose_life() -> bool:
	lives = max(0, lives - 1)
	lives_changed.emit(lives)
	return lives > 0


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
	cfg.set_value("progress", "unlocked_stage", unlocked_stage)
	cfg.set_value("progress", "high_score", high_score)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_enabled = bool(cfg.get_value("settings", "music", true))
	sfx_enabled = bool(cfg.get_value("settings", "sfx", true))
	vibration_enabled = bool(cfg.get_value("settings", "vibration", true))
	auto_fire_enabled = bool(cfg.get_value("settings", "auto_fire", false))
	unlocked_stage = int(cfg.get_value("progress", "unlocked_stage", 1))
	high_score = int(cfg.get_value("progress", "high_score", 0))


func trigger_game_over() -> void:
	if is_game_over or is_level_cleared:
		return
	is_game_over = true
	game_over.emit()


func trigger_level_cleared() -> void:
	if is_level_cleared:
		return
	is_level_cleared = true
	if current_stage >= unlocked_stage and current_stage < 2:
		unlocked_stage = current_stage + 1
		save_settings()
	level_cleared.emit()
