extends Control
## شاشة البداية وإعدادات الموبايل - "حارة البطل" (Haret El Batal)

@onready var play_btn: Button = $CenterBox/VBox/PlayButton
@onready var music_btn: Button = $CenterBox/VBox/SettingsGrid/MusicButton
@onready var sfx_btn: Button = $CenterBox/VBox/SettingsGrid/SfxButton
@onready var vib_btn: Button = $CenterBox/VBox/SettingsGrid/VibButton
@onready var auto_btn: Button = $CenterBox/VBox/SettingsGrid/AutoButton


func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	music_btn.pressed.connect(_on_music_pressed)
	sfx_btn.pressed.connect(_on_sfx_pressed)
	vib_btn.pressed.connect(_on_vib_pressed)
	auto_btn.pressed.connect(_on_auto_pressed)
	_refresh_buttons()
	queue_redraw()


func _draw() -> void:
	# خلفية غسق الحارة المصرية مع مباني وفوانيس
	draw_rect(Rect2(0, 0, 320, 65), Palette.C_TEAL)
	draw_rect(Rect2(0, 62, 320, 58), Palette.C_SAND.lerp(Palette.C_TEAL, 0.45))
	draw_rect(Rect2(0, 118, 320, 62), Palette.C_DARK_BROWN)

	for i in range(6):
		var bx := 6.0 + i * 54.0
		var bh := 56.0 + float((i * 19) % 34)
		var by := 162.0 - bh
		draw_rect(Rect2(bx, by, 44, bh), Palette.C_BRICK.darkened(0.3) if i % 2 == 0 else Palette.C_SAND.darkened(0.3))
		draw_rect(Rect2(bx + 8, by + 12, 8, 10), Palette.C_GOLD)
		draw_rect(Rect2(bx + 26, by + 12, 8, 10), Palette.C_GOLD if i % 2 == 1 else Palette.C_BLACK)

	draw_rect(Rect2(0, 162, 320, 18), Palette.C_SAND)
	draw_rect(Rect2(0, 162, 320, 2), Palette.C_CREAM)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/Level1.tscn")


func _on_music_pressed() -> void:
	GameState.toggle_music()
	_refresh_buttons()


func _on_sfx_pressed() -> void:
	GameState.toggle_sfx()
	_refresh_buttons()


func _on_vib_pressed() -> void:
	GameState.toggle_vibration()
	_refresh_buttons()


func _on_auto_pressed() -> void:
	GameState.toggle_auto_fire()
	_refresh_buttons()


func _refresh_buttons() -> void:
	music_btn.text = "MUSIC: ON" if GameState.music_enabled else "MUSIC: OFF"
	sfx_btn.text = "SFX: ON" if GameState.sfx_enabled else "SFX: OFF"
	vib_btn.text = "VIBRATE: ON" if GameState.vibration_enabled else "VIBRATE: OFF"
	auto_btn.text = "AUTO-FIRE: ON" if GameState.auto_fire_enabled else "AUTO-FIRE: OFF"
