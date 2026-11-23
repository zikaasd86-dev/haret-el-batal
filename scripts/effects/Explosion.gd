extends Node2D
## تأثير انفجار بكسل آرت أصلي (شرارات مربعة + وميض مركزي)

@export var duration: float = 0.32
@export var max_radius: float = 16.0
@export var particle_count: int = 10

var _elapsed: float = 0.0
var _dirs: Array[Vector2] = []
var _speeds: Array[float] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(particle_count):
		var ang := (TAU / float(particle_count)) * float(i) + rng.randf_range(-0.25, 0.25)
		_dirs.append(Vector2.RIGHT.rotated(ang))
		_speeds.append(rng.randf_range(28.0, 72.0))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	# وميض مركزي سريع في أول الانفجار
	if t < 0.45:
		var r := lerpf(4.0, max_radius * 0.75, t / 0.45)
		draw_circle(Vector2.ZERO, r, Palette.C_GOLD)
		draw_circle(Vector2.ZERO, r * 0.55, Palette.C_WHITE)

	# شرارات بكسل متطايرة بألوان اللوحة الدافئة
	var sz := maxf(1.0, 4.0 * (1.0 - t))
	for i in range(_dirs.size()):
		var pos := _dirs[i] * (_speeds[i] * _elapsed)
		var col := Palette.C_WHITE if t < 0.25 else (Palette.C_GOLD if (i % 2 == 0) else Palette.C_RED_CORE)
		draw_rect(Rect2(pos - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), col)
