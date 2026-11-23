extends Control
## شاشة البداية وإعدادات الموبايل - "حارة البطل" (Haret El Batal)

@onready var play_btn: Button = $CenterBox/VBox/PlayButton
@onready var music_btn: Button = $CenterBox/VBox/SettingsGrid/MusicButton
@onready var sfx_btn: Button = $CenterBox/VBox/SettingsGrid/SfxButton
@onready var vib_btn: Button = $CenterBox/VBox/SettingsGrid/VibButton
@onready var auto_btn: Button = $CenterBox/VBox/SettingsGrid/AutoButton
@onready var exit_btn: Button = $CenterBox/VBox/ExitButton


func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	music_btn.pressed.connect(_on_music_pressed)
	sfx_btn.pressed.connect(_on_sfx_pressed)
	vib_btn.pressed.connect(_on_vib_pressed)
	auto_btn.pressed.connect(_on_auto_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	_refresh_buttons()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _draw() -> void:
	# خلفية غسق الحارة المصرية تملأ عرض الشاشة بالكامل مهما كانت نسبة الموبايل
	var w := maxf(320.0, size.x)
	var h := maxf(180.0, size.y)
	draw_rect(Rect2(0, 0, w, h * 0.36), Palette.C_TEAL)
	draw_rect(Rect2(0, h * 0.34, w, h * 0.33), Palette.C_SAND.lerp(Palette.C_TEAL, 0.45))
	draw_rect(Rect2(0, h * 0.65, w, h * 0.35), Palette.C_DARK_BROWN)

	var bx := 6.0
	var i := 0
	while bx < w:
		var bh := 105.0 + float((i * 23) % 45)
		var by := h - 18.0 - bh
		draw_rect(Rect2(bx, by, 48, bh), Palette.C_BRICK.darkened(0.32) if i % 2 == 0 else Palette.C_SAND.darkened(0.32))
		draw_rect(Rect2(bx, by, 48, 5), Palette.C_DARK_BROWN)
		var wy := by + 12.0
		while wy < h - 32.0:
			draw_rect(Rect2(bx + 8, wy, 8, 10), Palette.C_GOLD if (int(wy) + i) % 3 != 0 else Palette.C_BLACK)
			draw_rect(Rect2(bx + 28, wy, 8, 10), Palette.C_GOLD if (int(wy) + i) % 2 == 0 else Palette.C_BLACK)
			wy += 22.0
		bx += 56.0
		i += 1

	draw_rect(Rect2(0, h - 18.0, w, 18.0), Palette.C_SAND)
	draw_rect(Rect2(0, h - 18.0, w, 2.0), Palette.C_CREAM)


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
