extends CanvasLayer
## واجهة العرض العلوية (HUD) + شريط صحة الزعيم + شاشة الفوز وإعادة المحاولة

@onready var hp_label: Label = $TopBar/HPLabel
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var boss_box: VBoxContainer = $BossBox
@onready var boss_label: Label = $BossBox/BossLabel
@onready var boss_bar: ProgressBar = $BossBox/BossBar
@onready var end_panel: PanelContainer = $EndPanel
@onready var end_title: Label = $EndPanel/VBox/EndTitle
@onready var restart_btn: Button = $EndPanel/VBox/RestartButton


func _ready() -> void:
	boss_box.visible = false
	end_panel.visible = false

	GameState.player_hp_changed.connect(_on_player_hp_changed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.boss_activated.connect(_on_boss_activated)
	GameState.boss_hp_changed.connect(_on_boss_hp_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.level_cleared.connect(_on_level_cleared)
	restart_btn.pressed.connect(_on_restart_pressed)

	_on_score_changed(GameState.score)


func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	var filled := "|".repeat(max(0, current_hp))
	var empty := ".".repeat(max(0, max_hp - current_hp))
	hp_label.text = "HP [%s%s]" % [filled, empty]


func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE %05d" % new_score


func _on_boss_activated(active: bool) -> void:
	boss_box.visible = active


func _on_boss_hp_changed(current_hp: int, max_hp: int, phase: int) -> void:
	boss_bar.max_value = max_hp
	boss_bar.value = current_hp
	boss_label.text = "BOSS - PHASE %d" % phase


func _on_game_over() -> void:
	end_title.text = "GAME OVER"
	end_panel.visible = true


func _on_level_cleared() -> void:
	end_title.text = "STAGE 1 CLEARED!"
	end_panel.visible = true


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
