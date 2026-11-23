extends StaticBody2D
## زعيم نهاية المرحلة الأولى - "البرج الحديدي للحارة"
## نقطة ضعف واحدة (النواة الحمراء) + 3 مراحل صحة بأنماط هجوم متصاعدة

const BULLET_SCENE := preload("res://scenes/player/Bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")

@export var max_hp: int = 180
@export var activation_distance: float = 240.0
@export var score_value: int = 1500

var hp: int = 180
var current_phase: int = 1
var is_active: bool = false
var is_defeated: bool = false

var _attack_timer: float = 1.0
var _attack_step: int = 0
var _flash_timer: float = 0.0
var _pulse_time: float = 0.0

@onready var body_sprite: Sprite2D = $BodySprite
@onready var core_sprite: Sprite2D = $CoreArea/CoreSprite
@onready var upper_cannon: Marker2D = $UpperCannon
@onready var lower_cannon: Marker2D = $LowerCannon


func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	_build_sprites()


func activate() -> void:
	if is_active or is_defeated:
		return
	is_active = true
	GameState.boss_activated.emit(true)
	GameState.boss_hp_changed.emit(hp, max_hp, current_phase)


func _physics_process(delta: float) -> void:
	if is_defeated or GameState.is_game_over or GameState.is_level_cleared:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	if not is_active:
		if absf(player.global_position.x - global_position.x) <= activation_distance:
			activate()
		return

	# نبض النواة الحمراء (يزداد سرعة في المراحل المتقدمة)
	_pulse_time += delta * (3.0 + current_phase * 2.5)
	var pulse_scale := 2.0 + sin(_pulse_time) * 0.2
	core_sprite.scale = Vector2(pulse_scale, pulse_scale)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			core_sprite.modulate = Color.WHITE

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_perform_phase_attack(player)


func _perform_phase_attack(player: Node2D) -> void:
	_attack_step += 1
	match current_phase:
		1:
			# المرحلة 1: طلقات فردية موجهة بالتناوب من المدفع العلوي والسفلي
			var origin := upper_cannon.global_position if (_attack_step % 2 == 0) else lower_cannon.global_position
			var dir := (player.global_position + Vector2(0, -8) - origin).normalized()
			_spawn_bullet(origin, dir, 125.0)
			_attack_timer = 1.25
		2:
			# المرحلة 2: رشقة ثلاثية متفرقة (3-way spread)
			var origin := upper_cannon.global_position if (_attack_step % 2 == 0) else lower_cannon.global_position
			var base_dir := (player.global_position + Vector2(0, -8) - origin).normalized()
			for angle_deg in [-18.0, 0.0, 18.0]:
				_spawn_bullet(origin, base_dir.rotated(deg_to_rad(angle_deg)), 140.0)
			_attack_timer = 1.0
		3:
			# المرحلة 3: موجة مروحية من 5 طلقات + طلقات سريعة متتابعة
			if _attack_step % 2 == 0:
				var origin := lower_cannon.global_position
				for angle_deg in [-36.0, -18.0, 0.0, 18.0, 36.0]:
					_spawn_bullet(origin, Vector2.LEFT.rotated(deg_to_rad(angle_deg)), 150.0)
				_attack_timer = 0.85
			else:
				var origin := upper_cannon.global_position
				var dir := (player.global_position + Vector2(0, -8) - origin).normalized()
				_spawn_bullet(origin, dir, 165.0)
				_spawn_bullet(lower_cannon.global_position, dir, 165.0)
				_attack_timer = 0.70


func _spawn_bullet(origin: Vector2, dir: Vector2, spd: float) -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(origin, dir, true, spd, 1)
	get_tree().current_scene.add_child(bullet)
	_play_sfx("enemy_shoot")


## يُستدعى فقط عند إصابة النواة الحمراء (CoreArea)
func take_core_damage(amount: int = 1) -> void:
	if not is_active or is_defeated:
		return

	hp = max(0, hp - amount)
	_flash_timer = 0.07
	core_sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
	_play_sfx("hit")

	# تحديث المرحلة حسب نسبة الصحة المتبقية
	var hp_ratio := float(hp) / float(max_hp)
	var new_phase := 1
	if hp_ratio <= 0.34:
		new_phase = 3
	elif hp_ratio <= 0.67:
		new_phase = 2

	if new_phase != current_phase:
		current_phase = new_phase
		var phase_exp := EXPLOSION_SCENE.instantiate()
		phase_exp.global_position = global_position + Vector2(-14, -36)
		phase_exp.max_radius = 24.0
		get_tree().current_scene.add_child(phase_exp)
		GameState.request_shake(4.5, 0.25)
		GameState.vibrate(80)
		_play_sfx("explode")

	GameState.boss_hp_changed.emit(hp, max_hp, current_phase)

	if hp <= 0:
		_on_defeated()


func _on_defeated() -> void:
	is_defeated = true
	for offset in [Vector2(-14, -36), Vector2(-10, -80), Vector2(4, -55)]:
		var exp_fx := EXPLOSION_SCENE.instantiate()
		exp_fx.global_position = global_position + offset
		exp_fx.max_radius = 28.0
		exp_fx.particle_count = 14
		get_tree().current_scene.add_child(exp_fx)
	GameState.request_shake(6.0, 0.45)
	GameState.vibrate(180)
	GameState.add_score(score_value)
	GameState.boss_activated.emit(false)
	_play_sfx("explode")
	GameState.trigger_level_cleared()
	queue_free()


func _play_sfx(sfx_name: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_name)


func _build_sprites() -> void:
	# هيكل البرج الحديدي للزعيم (24×48 بكسل)
	body_sprite.texture = ProceduralArt.create_texture("boss_body", PackedStringArray([
		"000000000000000000000000",
		"0bbbbbbbbbbbbbbbbbbbbbb0",
		"0bccccccccccccccccccccb0",
		"0b11111111111111111111b0",
		"0b13333333333333333331b0",
		"0000000bcccccccccb1331b0",
		"0bbbbb0bcbbbbbbbcb1331b0",
		"0bccc60bcbbbbbbbcb1331b0",
		"0bbbbb0bcccccccccb1331b0",
		"0000000b111111111b1331b0",
		"0bbbbbbb122222221b1331b0",
		"0bcccccb124444421b1331b0",
		"0bcbbbbbb12222221b1331b0",
		"0bcbbbbbb11111111b1331b0",
		"0bcbbbbbbbbbbbbbbb1331b0",
		"0bcbb0000000000bbb1331b0",
		"0bcbb0111111110bbb1331b0",
		"0bcbb0111111110bbb1331b0",
		"0bcbb0111111110bbb1331b0",
		"0bcbb0111111110bbb1331b0",
		"0bcbb0111111110bbb1331b0",
		"0bcbb0111111110bbb1331b0",
		"0bcbb0000000000bbb1331b0",
		"0bcbbbbbbbbbbbbbbb1331b0",
		"0000000b111111111b1331b0",
		"0bbbbb0b122222221b1331b0",
		"0bccc60b124444421b1331b0",
		"0bbbbb0b122222221b1331b0",
		"0000000b111111111b1331b0",
		"0bccccccccccccccccccccb0",
		"0bbbbbbbbbbbbbbbbbbbbbb0",
		"000000000000000000000000",
	]))

	# النواة الحمراء (نقطة الضعف الوحيدة 10×10 بكسل)
	core_sprite.texture = ProceduralArt.create_texture("boss_core", PackedStringArray([
		"..000000..",
		".0dddddd0.",
		"0ddeeeedd0",
		"0deeffeed0",
		"0deffffed0",
		"0deffffed0",
		"0deeffeed0",
		"0ddeeeedd0",
		".0dddddd0.",
		"..000000..",
	]))
