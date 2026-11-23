extends CanvasLayer
## واجهة التحكم اللمسي للموبايل - "حارة البطل"
## أزرار شفافة: D-Pad (يدعم الـ 8 اتجاهات مع السحب) + قفز + إطلاق نار + تبديل السلاح + إطلاق تلقائي

@onready var btn_left: TouchScreenButton = $DPad/BtnLeft
@onready var btn_right: TouchScreenButton = $DPad/BtnRight
@onready var btn_up: TouchScreenButton = $DPad/BtnUp
@onready var btn_down: TouchScreenButton = $DPad/BtnDown

@onready var btn_fire: TouchScreenButton = $Actions/BtnFire
@onready var btn_jump: TouchScreenButton = $Actions/BtnJump
@onready var btn_weapon: TouchScreenButton = $Actions/BtnWeapon
@onready var btn_auto: TouchScreenButton = $Actions/BtnAuto
@onready var lbl_auto: Label = $Actions/BtnAuto/Label


func _ready() -> void:
	_setup_button_textures()
	GameState.autofire_changed.connect(_on_autofire_changed)
	_on_autofire_changed(GameState.auto_fire_enabled)


func _setup_button_textures() -> void:
	var dpad_normal := ProceduralArt.create_rect_texture("touch_dpad_n", 22, 22, Color(0.1, 0.08, 0.06, 0.45), Color(1.0, 0.96, 0.9, 0.5))
	var dpad_press  := ProceduralArt.create_rect_texture("touch_dpad_p", 22, 22, Color(0.95, 0.72, 0.18, 0.65), Color(1.0, 1.0, 1.0, 0.85))

	for b in [btn_left, btn_right, btn_up, btn_down]:
		b.texture_normal = dpad_normal
		b.texture_pressed = dpad_press
		b.passby_press = true # يسمح بتمرير الإصبع بسلاسة للتصويب القطري (8 اتجاهات)

	btn_fire.texture_normal = ProceduralArt.create_rect_texture("touch_fire_n", 28, 28, Color(0.88, 0.19, 0.19, 0.55), Color(1, 0.95, 0.9, 0.65))
	btn_fire.texture_pressed = ProceduralArt.create_rect_texture("touch_fire_p", 28, 28, Color(1.0, 0.35, 0.25, 0.85), Color(1, 1, 1, 0.9))

	btn_jump.texture_normal = ProceduralArt.create_rect_texture("touch_jump_n", 28, 28, Color(0.22, 0.43, 0.29, 0.60), Color(1, 0.95, 0.9, 0.65))
	btn_jump.texture_pressed = ProceduralArt.create_rect_texture("touch_jump_p", 28, 28, Color(0.35, 0.65, 0.45, 0.85), Color(1, 1, 1, 0.9))

	btn_weapon.texture_normal = ProceduralArt.create_rect_texture("touch_wpn_n", 24, 16, Color(0.62, 0.31, 0.20, 0.60), Color(0.96, 0.72, 0.18, 0.8))
	btn_weapon.texture_pressed = ProceduralArt.create_rect_texture("touch_wpn_p", 24, 16, Color(0.96, 0.72, 0.18, 0.85), Color(1, 1, 1, 0.9))

	btn_auto.texture_normal = ProceduralArt.create_rect_texture("touch_auto_n", 28, 14, Color(0.15, 0.12, 0.10, 0.55), Color(0.92, 0.82, 0.60, 0.65))
	btn_auto.texture_pressed = ProceduralArt.create_rect_texture("touch_auto_p", 28, 14, Color(0.96, 0.72, 0.18, 0.80), Color(1, 1, 1, 0.9))


func _on_autofire_changed(enabled: bool) -> void:
	lbl_auto.text = "AUTO✓" if enabled else "AUTO"
	lbl_auto.modulate = Palette.C_GOLD if enabled else Palette.C_WHITE
