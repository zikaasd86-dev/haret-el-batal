extends Control
## شاشة البداية والتحميل (Splash & Loading Screen) - لعبة "حارة البطل"
## تعرض شعار اللعبة مع شريط تحميل متحرك لمدة ~2.2 ثانية ثم تنتقل بسلاسة للقائمة الرئيسية

@export var splash_duration: float = 2.2

var _elapsed: float = 0.0
var _transitioned: bool = false

@onready var logo_tex: TextureRect = $CenterBox/VBox/Logo
@onready var title_lbl: Label = $CenterBox/VBox/Title
@onready var progress_bar: ProgressBar = $CenterBox/VBox/LoadingBar
@onready var status_lbl: Label = $CenterBox/VBox/StatusLabel


func _ready() -> void:
	logo_tex.texture = load("res://assets/icons/icon.png")
	UITheme.style_progress_bar(progress_bar, Palette.C_GOLD)
	progress_bar.value = 0.0
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	queue_redraw()


func _process(delta: float) -> void:
	if _transitioned:
		return

	_elapsed += delta
	var pct := clampf(_elapsed / splash_duration, 0.0, 1.0)
	progress_bar.value = pct * 100.0

	if pct < 0.35:
		status_lbl.text = "LOADING ALLEY..."
	elif pct < 0.75:
		status_lbl.text = "PREPARING WEAPONS..."
	else:
		status_lbl.text = "READY!"

	if _elapsed >= splash_duration:
		_go_to_menu()


func _input(event: InputEvent) -> void:
	# السماح بتخطي الشاشة بلمسة بعد ثانية واحدة
	if _elapsed > 0.9 and not _transitioned:
		if event is InputEventScreenTouch and event.pressed:
			_go_to_menu()
		elif event is InputEventMouseButton and event.pressed:
			_go_to_menu()


func _go_to_menu() -> void:
	if _transitioned:
		return
	_transitioned = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)


func _draw() -> void:
	var w := maxf(320.0, size.x)
	var h := maxf(180.0, size.y)
	# خلفية دافئة بألوان لوحة "حارة البطل"
	draw_rect(Rect2(0, 0, w, h), Palette.C_BLACK)
	draw_rect(Rect2(0, h - 22.0, w, 22.0), Palette.C_DARK_BROWN)
	draw_rect(Rect2(0, h - 22.0, w, 2.0), Palette.C_GOLD)
