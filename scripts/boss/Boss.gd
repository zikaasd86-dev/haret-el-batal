extends StaticBody2D
## زعيم نهاية المرحلة — "وحش الخردة ذو الرأس الغريب"
## له نقطتا ضعف (الرأس المتوهج فوق + النواة الحمراء في الصدر تحت)
## يقذف برميلاً متفجراً كل 5 ثوانٍ في اتجاهات عشوائية + 3 مراحل هجوم

const BULLET_SCENE := preload("res://scenes/player/Bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")
const BARREL_SCENE := preload("res://scenes/boss/ExplosiveBarrel.tscn")

@export var boss_name: String = "ZAEEM HARET EL MAGANEEN"
@export var max_hp: int = 110
@export var activation_distance: float = 250.0
@export var barrel_interval: float = 5.0
@export var score_value: int = 1500

var hp: int = 110
var current_phase: int = 1
var is_active: bool = false
var is_defeated: bool = false

var _attack_timer: float = 1.0
var _barrel_timer: float = 3.5
var _attack_step: int = 0
var _head_flash: float = 0.0
var _core_flash: float = 0.0
var _anim_time: float = 0.0
var _head_base_y: float = -88.0

@onready var body_sprite: Sprite2D = $BodySprite
@onready var head_area: Area2D = $HeadArea
@onready var head_sprite: Sprite2D = $HeadArea/HeadSprite
@onready var core_sprite: Sprite2D = $CoreArea/CoreSprite
@onready var upper_cannon: Marker2D = $UpperCannon
@onready var lower_cannon: Marker2D = $LowerCannon


func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	_head_base_y = head_area.position.y
	_build_sprites()


func activate() -> void:
	if is_active or is_defeated:
		return
	is_active = true
	GameState.current_boss_name = boss_name
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

	_anim_time += delta * (2.6 + current_phase * 1.4)
	# حركة رأس الوحش الغريب صعوداً وهبوطاً
	head_area.position.y = _head_base_y + sin(_anim_time) * 8.0
	# نبض النواة الحمراء
	var pulse := 1.85 + sin(_anim_time * 1.6) * 0.2
	core_sprite.scale = Vector2(pulse, pulse)

	if _head_flash > 0.0:
		_head_flash -= delta
		if _head_flash <= 0.0:
			head_sprite.modulate = Color.WHITE
	if _core_flash > 0.0:
		_core_flash -= delta
		if _core_flash <= 0.0:
			core_sprite.modulate = Color.WHITE

	# قذف برميل متفجر في اتجاهات عشوائية كل 5 ثوانٍ
	_barrel_timer -= delta
	if _barrel_timer <= 0.0:
		_throw_random_barrel()
		_barrel_timer = barrel_interval

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_perform_phase_attack(player)


func _throw_random_barrel() -> void:
	var barrel := BARREL_SCENE.instantiate()
	var launch_pos := head_area.global_position + Vector2(-12.0, 2.0)
	var vx := randf_range(-205.0, -70.0)
	var vy := randf_range(-215.0, -145.0)
	barrel.setup(launch_pos, Vector2(vx, vy))
	get_tree().current_scene.add_child(barrel)
	_play_sfx("jump")


func _perform_phase_attack(player: Node2D) -> void:
	_attack_step += 1
	match current_phase:
		1:
			var origin := head_area.global_position + Vector2(-14, 4) if (_attack_step % 2 == 0) else lower_cannon.global_position
			var dir := (player.global_position + Vector2(0, -10) - origin).normalized()
			_spawn_bullet(origin, dir, 118.0)
			_attack_timer = 1.25
		2:
			var origin := head_area.global_position + Vector2(-14, 4)
			var base_dir := (player.global_position + Vector2(0, -10) - origin).normalized()
			for deg in [-18.0, 0.0, 18.0]:
				_spawn_bullet(origin, base_dir.rotated(deg_to_rad(deg)), 130.0)
			_attack_timer = 1.05
		3:
			if _attack_step % 2 == 0:
				var origin := lower_cannon.global_position
				for deg in [-34.0, -17.0, 0.0, 17.0, 34.0]:
					_spawn_bullet(origin, Vector2.LEFT.rotated(deg_to_rad(deg)), 138.0)
				_attack_timer = 0.90
			else:
				var origin := head_area.global_position + Vector2(-14, 4)
				var dir := (player.global_position + Vector2(0, -10) - origin).normalized()
				_spawn_bullet(origin, dir, 150.0)
				_spawn_bullet(lower_cannon.global_position, dir, 150.0)
				_attack_timer = 0.78


func _spawn_bullet(origin: Vector2, dir: Vector2, spd: float) -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(origin, dir, true, spd, 1)
	get_tree().current_scene.add_child(bullet)
	_play_sfx("enemy_shoot")


## استقبال الضرر في أي من نقطتي الضعف (الرأس أو نواة الصدر)
func take_weakpoint_damage(amount: int = 1, part_id: String = "core") -> void:
	if not is_active or is_defeated:
		return

	hp = max(0, hp - amount)
	if part_id == "head":
		_head_flash = 0.07
		head_sprite.modulate = Color(2.4, 2.4, 2.4, 1.0)
	else:
		_core_flash = 0.07
		core_sprite.modulate = Color(2.4, 2.4, 2.4, 1.0)
	_play_sfx("hit")

	var hp_ratio := float(hp) / float(max_hp)
	var new_phase := 1
	if hp_ratio <= 0.34:
		new_phase = 3
	elif hp_ratio <= 0.67:
		new_phase = 2

	if new_phase != current_phase:
		current_phase = new_phase
		var phase_exp := EXPLOSION_SCENE.instantiate()
		phase_exp.global_position = global_position + Vector2(-14, -46)
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
	for offset in [Vector2(-18, -88), Vector2(-14, -40), Vector2(4, -64)]:
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
	# جسم وحش الخردة الميكانيكي (بدلاً من المبنى)
	body_sprite.texture = ProceduralArt.create_texture("boss_monster_body", PackedStringArray([
		"......000000000000......",
		"....00bbbbbbbbbbbb00....",
		"...0bbccccccccccccbb0...",
		"..0bbc111111111111cbb0..",
		"..0bb13333333333331bb0..",
		".00b133bbbbbbbbbb331b00.",
		"0cc133bb11111111bb331cc0",
		"0bb133bb11111111bb331bb0",
		"0bb133bb11111111bb331bb0",
		"0bb133bb11111111bb331bb0",
		"0bb133bb11111111bb331bb0",
		"0bb133bb11111111bb331bb0",
		".00133bbbbbbbbbbbb33100.",
		"..0b1111111111111111b0..",
		"..0bbbbbbbbbbbbbbbbbb0..",
		".00bb11100000000111bb00.",
		"0bbb1110........0111bbb0",
		"0cc1110..........0111cc0",
		"011110............011110",
		"000000............000000",
	]))

	# الرأس الغريب المتوهج للوحش (نقطة الضعف #1 — عيون حمراء + قرون/هوائيات معدنية + فك)
	head_sprite.texture = ProceduralArt.create_texture("boss_monster_head", PackedStringArray([
		"..060..........060..",
		"..0b0..000000..0b0..",
		"...0000bbbbbb0000...",
		"..0bbbccccccccbbb0..",
		".0bb111111111111bb0.",
		"0bb1deef1111feed1bb0",
		"0bb1efff1111fffe1bb0",
		"0bb1deef1111feed1bb0",
		".0bb111111111111bb0.",
		".0bbbccccccccccbbb0.",
		"..010601060106010...",
		"..011111111111110...",
		"...0000000000000....",
	]))

	# النواة الحمراء النابضة في الصدر (نقطة الضعف #2)
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
