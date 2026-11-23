extends CanvasLayer
## واجهة العرض العلوية (HUD) + وميض الضرر الأحمر + قائمة الإيقاف المؤقت والإعدادات والخروج

@onready var hp_label: Label = $TopBar/HPLabel
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var wpn_label: Label = $TopBar/WeaponLabel
@onready var pause_btn: Button = $TopBar/PauseButton
@onready var boss_box: VBoxContainer = $BossBox
@onready var boss_label: Label = $BossBox/BossLabel
@onready var boss_bar: ProgressBar = $BossBox/BossBar
@onready var damage_flash: ColorRect = $DamageFlash

@onready var pause_panel: PanelContainer = $PausePanel
@onready var resume_btn: Button = $PausePanel/VBox/ResumeButton
@onready var auto_btn: Button = $PausePanel/VBox/AutoButton
@onready var music_btn: Button = $PausePanel/VBox/MusicButton
@onready var menu_btn: Button = $PausePanel/VBox/MenuButton
@onready var exit_btn: Button = $PausePanel/VBox/ExitButton

@onready var end_panel: PanelContainer = $EndPanel
@onready var end_title: Label = $EndPanel/VBox/EndTitle
@onready var restart_btn: Button = $EndPanel/VBox/RestartButton
@onready var end_menu_btn: Button = $EndPanel/VBox/MenuButton
@onready var end_exit_btn: Button = $EndPanel/VBox/ExitButton

var _last_hp: int = 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	boss_box.visible = false
	end_panel.visible = false
	pause_panel.visible = false
	damage_flash.color.a = 0.0

	GameState.player_hp_changed.connect(_on_player_hp_changed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.boss_activated.connect(_on_boss_activated)
	GameState.boss_hp_changed.connect(_on_boss_hp_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.level_cleared.connect(_on_level_cleared)

	pause_btn.pressed.connect(_toggle_pause)
	resume_btn.pressed.connect(_toggle_pause)
	auto_btn.pressed.connect(_on_toggle_auto)
	music_btn.pressed.connect(_on_toggle_music)
	menu_btn.pressed.connect(_go_main_menu)
	exit_btn.pressed.connect(_quit_game)

	restart_btn.pressed.connect(_on_restart_pressed)
	end_menu_btn.pressed.connect(_go_main_menu)
	end_exit_btn.pressed.connect(_quit_game)

	_on_score_changed(GameState.score)
	_refresh_pause_buttons()


func _process(_delta: float) -> void:
	if damage_flash.color.a > 0.0:
		damage_flash.color.a = maxf(0.0, damage_flash.color.a - _delta * 2.2)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_weapon_name"):
		wpn_label.text = "[%s]" % player.get_weapon_name()


func _notification(what: int) -> void:
	# دعم زر الرجوع في أندرويد لفتح قائمة الإيقاف/الخروج
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not end_panel.visible:
			_toggle_pause()


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused
	_refresh_pause_buttons()


func _refresh_pause_buttons() -> void:
	auto_btn.text = "AUTO-FIRE: ON" if GameState.auto_fire_enabled else "AUTO-FIRE: OFF"
	music_btn.text = "MUSIC: ON" if GameState.music_enabled else "MUSIC: OFF"


func _on_toggle_auto() -> void:
	GameState.toggle_auto_fire()
	_refresh_pause_buttons()


func _on_toggle_music() -> void:
	GameState.toggle_music()
	_refresh_pause_buttons()


func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	if current_hp < _last_hp:
		damage_flash.color.a = 0.45
	_last_hp = current_hp
	var filled := "♥".repeat(max(0, current_hp))
	var empty := "♡".repeat(max(0, max_hp - current_hp))
	hp_label.text = "%s%s" % [filled, empty]


func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE %05d" % new_score


func _on_boss_activated(active: bool) -> void:
	boss_box.visible = active


func _on_boss_hp_changed(current_hp: int, max_hp: int, phase: int) -> void:
	boss_bar.max_value = max_hp
	boss_bar.value = current_hp
	boss_label.text = "BOSS - PHASE %d" % phase


func _on_game_over() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	end_title.text = "YOU DIED — GAME OVER"
	end_panel.visible = true


func _on_level_cleared() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	end_title.text = "STAGE 1 CLEARED!"
	end_panel.visible = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _quit_game() -> void:
	get_tree().quit()
