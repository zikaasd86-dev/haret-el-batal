extends StaticBody2D
## زعيم نهاية المرحلة — يدعم تصميمين مختلفين بالكامل:
## boss_variant = 1: "زعيم حارة المجانين" (وحش خردة أرضي برأس متحرك ونواة صدر)
## boss_variant = 2: "شبح السطوح" (طائرة/شبح ليلي مجنّح يحلّق في السماء ويناوِر أفقياً ورأسياً!)
## - براميل متفجرة موجهة نحو منطقة البطل + طلقات طويلة المدى تعبر الشاشة بالكامل

const BULLET_SCENE := preload("res://scenes/player/Bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")
const BARREL_SCENE := preload("res://scenes/boss/ExplosiveBarrel.tscn")

@export var boss_name: String = "ZAEEM HARET EL MAGANEEN"
@export var boss_variant: int = 1 # 1 = زعيم المرحلة 1، 2 = زعيم المرحلة 2 الطائر
@export var max_hp: int = 70
@export var activation_distance: float = 340.0
@export var barrel_interval: float = 4.2
@export var score_value: int = 1500

var hp: int = 70
var current_phase: int = 1
var is_active: bool = false
var is_defeated: bool = false

var _base_pos: Vector2 = Vector2.ZERO
var _attack_timer: float = 0.9
var _barrel_timer: float = 2.0 # أول برميل يُقذف بعد ثانيتين فقط لتراه فوراً!
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
	_base_pos = global_position
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

	_anim_time += delta * (2.6 + current_phase * 1.3)

	if boss_variant == 2:
		# زعيم المرحلة 2 (شبح السطوح) يحلّق في الجو ويتحرك يميناً ويساراً وأعلى وأسفل!
		global_position.x = _base_pos.x - 45.0 + sin(_anim_time * 0.55) * 55.0
		global_position.y = _base_pos.y - 26.0 + cos(_anim_time * 0.9) * 20.0
		head_area.position.y = _head_base_y + sin(_anim_time * 1.4) * 5.0
	elif boss_variant == 3:
		# زعيم المرحلة 3 (الغول الحديدي): آلة حرب ومدرعة ميكا عملاقة
		global_position.x = _base_pos.x - 30.0 + sin(_anim_time * 0.42) * 35.0
		head_area.position.y = _head_base_y + sin(_anim_time * 1.6) * 4.0
		if absf(sin(_anim_time * 1.6)) > 0.96 and is_active:
			GameState.request_shake(0.8, 0.04)
	else:
		# زعيم المرحلة 1: رأس الوحش يتحرك صعوداً وهبوطاً
		head_area.position.y = _head_base_y + sin(_anim_time) * 9.0

	var pulse := 1.85 + sin(_anim_time * 1.6) * 0.22
	core_sprite.scale = Vector2(pulse, pulse)

	if _head_flash > 0.0:
		_head_flash -= delta
		if _head_flash <= 0.0:
			head_sprite.modulate = Color.WHITE
	if _core_flash > 0.0:
		_core_flash -= delta
		if _core_flash <= 0.0:
			core_sprite.modulate = Color.WHITE

	# قذف برميل متفجر (أو برميلين في المرحلة 2 و 3) باتجاه منطقة البطل!
	_barrel_timer -= delta
	if _barrel_timer <= 0.0:
		_throw_aimed_barrel(player, 0.0)
		if current_phase >= 2:
			_throw_aimed_barrel(player, randf_range(-55.0, 55.0))
		_barrel_timer = barrel_interval

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_perform_phase_attack(player)


## حساب مسار قوسي دقيق للبرميل المتفجر ليصل فعلياً لمنطقة البطل مهما ابتعد!
func _throw_aimed_barrel(player: Node2D, spread_x: float) -> void:
	var barrel := BARREL_SCENE.instantiate()
	var launch_pos := head_area.global_position + Vector2(-14.0, 0.0)
	var target_x := player.global_position.x + spread_x + randf_range(-30.0, 30.0)
	var dx := clampf(target_x - launch_pos.x, -340.0, -55.0)
	var flight_t := randf_range(0.95, 1.35)
	var vx := dx / flight_t
	var dy := 156.0 - launch_pos.y
	var vy := (dy - 0.5 * 340.0 * flight_t * flight_t) / flight_t
	barrel.setup(launch_pos, Vector2(vx, vy))
	get_tree().current_scene.add_child(barrel)
	_play_sfx("jump")


func _perform_phase_attack(player: Node2D) -> void:
	_attack_step += 1
	var target_pos := player.global_position + Vector2(0, -12)

	if boss_variant == 2:
		# أنماط هجوم خاصة بشبح السطوح الطائر
		var origin := head_area.global_position + Vector2(-12, 8)
		var base_dir := (target_pos - origin).normalized()
		match current_phase:
			1:
				for deg in [-14.0, 14.0]:
					_spawn_bullet(origin, base_dir.rotated(deg_to_rad(deg)), 165.0)
				_attack_timer = 1.05
			2:
				for deg in [-24.0, -8.0, 8.0, 24.0]:
					_spawn_bullet(origin, base_dir.rotated(deg_to_rad(deg)), 175.0)
				_attack_timer = 0.92
			3:
				for deg in [-36.0, -18.0, 0.0, 18.0, 36.0]:
					_spawn_bullet(origin, base_dir.rotated(deg_to_rad(deg)), 188.0)
				_attack_timer = 0.78
		return

	if boss_variant == 3:
		# أنماط هجوم زعيم المرحلة 3 (الغول الحديدي - مدافع مزدوجة وهاون جوي)
		var upper_origin := upper_cannon.global_position
		var lower_origin := lower_cannon.global_position
		var head_origin := head_area.global_position + Vector2(-16, 4)
		match current_phase:
			1:
				if _attack_step % 2 == 0:
					var dir := (target_pos - upper_origin).normalized()
					_spawn_bullet(upper_origin, dir, 185.0)
					_spawn_bullet(upper_origin, dir.rotated(deg_to_rad(-12.0)), 180.0)
				else:
					var dir := (target_pos - lower_origin).normalized()
					_spawn_bullet(lower_origin, dir, 185.0)
					_spawn_bullet(lower_origin, dir.rotated(deg_to_rad(12.0)), 180.0)
				_attack_timer = 0.95
			2:
				var dir := (target_pos - head_origin).normalized()
				_spawn_bullet(head_origin, dir, 195.0)
				_spawn_bullet(upper_origin, Vector2(-0.4, -1.0).normalized(), 210.0)
				_spawn_bullet(upper_origin, Vector2(-0.8, -0.9).normalized(), 200.0)
				_attack_timer = 0.82
			3:
				var base_dir := (target_pos - head_origin).normalized()
				for deg in [-28.0, -14.0, 0.0, 14.0, 28.0]:
					_spawn_bullet(head_origin, base_dir.rotated(deg_to_rad(deg)), 205.0)
				_spawn_bullet(lower_origin, (target_pos - lower_origin).normalized(), 215.0)
				_attack_timer = 0.68
		return

	# أنماط هجوم زعيم المرحلة 1 (طلقات طويلة المدى تعبر الشاشة كلها لمنع الاختباء بعيداً!)
	match current_phase:
		1:
			var origin := head_area.global_position + Vector2(-14, 4) if (_attack_step % 2 == 0) else lower_cannon.global_position
			var dir := (target_pos - origin).normalized()
			_spawn_bullet(origin, dir, 160.0)
			_spawn_bullet(origin, dir.rotated(deg_to_rad(10.0)), 155.0)
			_attack_timer = 1.10
		2:
			var origin := head_area.global_position + Vector2(-14, 4)
			var base_dir := (target_pos - origin).normalized()
			for deg in [-18.0, 0.0, 18.0]:
				_spawn_bullet(origin, base_dir.rotated(deg_to_rad(deg)), 172.0)
			_attack_timer = 0.95
		3:
			if _attack_step % 2 == 0:
				var origin := lower_cannon.global_position
				var base_dir := (target_pos - origin).normalized()
				for deg in [-30.0, -15.0, 0.0, 15.0, 30.0]:
					_spawn_bullet(origin, base_dir.rotated(deg_to_rad(deg)), 182.0)
				_attack_timer = 0.85
			else:
				var origin := head_area.global_position + Vector2(-14, 4)
				var dir := (target_pos - origin).normalized()
				_spawn_bullet(origin, dir, 190.0)
				_spawn_bullet(lower_cannon.global_position, dir, 190.0)
				_attack_timer = 0.72


func _spawn_bullet(origin: Vector2, dir: Vector2, spd: float) -> void:
	var bullet := BULLET_SCENE.instantiate()
	# مدة بقاء 3.8 ثانية لتعبر الرصاصة عرض الشاشة بالكامل حتى أقصى اليسار
	bullet.setup(origin, dir, true, spd, 1, 0, 1.0, 3.8)
	get_tree().current_scene.add_child(bullet)
	_play_sfx("enemy_shoot")


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
	if boss_variant == 2:
		# زعيم المرحلة 2: "شبح السطوح" — طائرة/بومة ميكانيكية ليلية مجنّحة مختلفة تماماً!
		body_sprite.texture = ProceduralArt.create_texture("boss_phantom_body", PackedStringArray([
			"000..................000",
			"0aa0................0aa0",
			"0aaa00....0000....00aaa0",
			"0aacaa0000aaaa0000aacaa0",
			".0aacaaaaaccccaaaaacaa0.",
			"..0aa11aaaaaaaaaa11aa0..",
			"...0a166aaaaaaaa661a0...",
			"....0aa1111111111aa0....",
			"....0aa1dddddddd1aa0....",
			".....0a1dddddddd1a0.....",
			"......0a11111111a0......",
			".......0aaaaaaaa0.......",
			"......06600..00660......",
			".....0e60......06e0.....",
			".....000........000.....",
		]))
		head_sprite.texture = ProceduralArt.create_texture("boss_phantom_head", PackedStringArray([
			"060..............060",
			"0aa0....0000....0aa0",
			".0aa0000aaaa0000aa0.",
			"..0aaaaccccccaaaa0..",
			".0aa111111111111aa0.",
			"0aa16fff1111fff61aa0",
			"0aa1feef1111feef1aa0",
			".0aa111111111111aa0.",
			"..0aaaa166661aaaa0..",
			"...00000000000000...",
		]))
	elif boss_variant == 3:
		# زعيم المرحلة 3: "الغول الحديدي" (آلة حرب صناعية مصفحة مع خطوط تحذير صفراء وعوادم)
		body_sprite.texture = ProceduralArt.create_texture("boss_mech_body", PackedStringArray([
			"......000000000000......",
			"...000aaaaaaaaaaaa000...",
			"..0aabbbbbbbbbbbbaab0..",
			".0abbccccccccccccbba0..",
			".0ab06060606060600ba0..",
			".0ab60606060606060ba0..",
			"0ab0aaaaaaaaaaaa0ba00..",
			"0abbbbbbbbbbbbbbbbbb0..",
			"0ac1111111111111111ca0.",
			"0ab1dddddddddddddd1ba0.",
			"0ab1deeeeeeeeeeeed1ba0.",
			"0ab1dddddddddddddd1ba0.",
			"0ac1111111111111111ca0.",
			"0abbbbbbbbbbbbbbbbbb0..",
			".00bb000000000000bb00..",
			"..0bb0..........0bb0...",
			".0bbb0..........0bbb0..",
			"0ccccc0........0ccccc0.",
			"0000000........0000000.",
		]))
		head_sprite.texture = ProceduralArt.create_texture("boss_mech_head", PackedStringArray([
			"000000................",
			"0bbcc000000000000000..",
			"0bccccaaaaaaaaaaaaab0.",
			"0bbcc01111111111111ab0",
			"0000001feeeeffeeee1ab0",
			".....01feeeeffeeee1ab0",
			"0000001111111111111ab0",
			"0bbcc0aaaaaaaaaaaaab0.",
			"0bcccc00000000000000..",
			"000000................",
		]))
		core_sprite.texture = ProceduralArt.create_texture("boss_core_mech", PackedStringArray([
			"..000000..",
			".0aaaaaa0.",
			"0aa6666aa0",
			"0a6ffff6a0",
			"0a6ffff6a0",
			"0a6ffff6a0",
			"0aa6666aa0",
			".0aaaaaa0.",
			"..000000..",
		]))
	else:
		# زعيم المرحلة 1: وحش الخردة الميكانيكي الأرضي
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
