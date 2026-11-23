extends CharacterBody2D
## سكربت البطل الرئيسي - لعبة "حارة البطل"
## - طول ثابت 30 بكسل أثناء الجري (4 إطارات متناسقة بدون تقزّم)
## - انبطاح كامل على الأرض (Prone) لتفادي طلقات الأعداء
## - قفزة مع شقلبة دائرية (Somersault Spin) + قفزة مزدوجة مركبة (Double Jump)
## - 5 أسلحة أصلية بتغيّر بصري واضح + أنيميشن موت واضح مع انفجار واهتزاز

enum WeaponType {
	RIFLE,  # 0: رشاش الحارة السريع
	SPREAD, # 1: سلاح متفرق (3 طلقات)
	HEAVY,  # 2: شعاع ثقيل (ضرر مضاعف)
	WAVE,   # 3: ليزر متموج مزدوج
	FLAME,  # 4: قاذف شرار سريع (5 طلقات)
}

const BULLET_SCENE := preload("res://scenes/player/Bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")

@export_group("Movement")
@export var move_speed: float = 96.0
@export var gravity: float = 540.0
@export var jump_velocity: float = -225.0
@export var double_jump_velocity: float = -205.0
@export var coyote_time: float = 0.09
@export var jump_buffer_time: float = 0.10

@export_group("Combat")
@export var max_hp: int = 5
@export var invincibility_time: float = 1.0

var hp: int = 5
var facing: int = 1
var is_prone: bool = false
var is_dead: bool = false
var aim_direction: Vector2 = Vector2.RIGHT
var current_weapon: WeaponType = WeaponType.RIFLE

var _jumps_left: int = 2
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _fire_timer: float = 0.0
var _invincible_timer: float = 0.0
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _idle_time: float = 0.0
var _recoil_timer: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _drop_through_timer: float = 0.0

var _tex_idle: Texture2D
var _tex_run: Array[Texture2D] = []
var _tex_spin: Texture2D
var _tex_prone: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var stand_shape: CollisionShape2D = $StandCollision
@onready var prone_shape: CollisionShape2D = $CrouchCollision
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var gun_barrel: Line2D = $GunBarrel
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	_build_sprites()
	sprite.texture = _tex_idle
	prone_shape.disabled = true
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	_apply_weapon_visuals()
	GameState.player_hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 140.0 * delta)
		velocity.y = minf(velocity.y + gravity * delta, 340.0)
		move_and_slide()
		return

	if GameState.is_game_over or GameState.is_level_cleared:
		velocity.x = 0.0
		velocity.y += gravity * delta
		move_and_slide()
		return

	_update_timers(delta)
	_handle_input_actions()
	_handle_movement(delta)
	_update_aim_direction()
	_handle_shooting()
	_update_visuals(delta)
	queue_redraw()


func _update_timers(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta
	if _recoil_timer > 0.0:
		_recoil_timer -= delta
	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer -= delta
	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			set_collision_mask_value(6, true)

	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		sprite.visible = int(_invincible_timer * 20.0) % 2 == 0
		if _invincible_timer <= 0.0:
			sprite.visible = true

	if is_on_floor():
		_coyote_timer = coyote_time
		_jumps_left = 2
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)


func _handle_input_actions() -> void:
	if Input.is_action_just_pressed("toggle_autofire"):
		GameState.toggle_auto_fire()
	if Input.is_action_just_pressed("switch_weapon"):
		cycle_weapon()
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func cycle_weapon() -> void:
	set_weapon((int(current_weapon) + 1) % 5)


func set_weapon(weapon_idx: int) -> void:
	current_weapon = clampi(weapon_idx, 0, 4) as WeaponType
	_apply_weapon_visuals()
	_play_sfx("jump")


func get_weapon_name() -> String:
	match current_weapon:
		WeaponType.SPREAD: return "SPREAD"
		WeaponType.HEAVY:  return "HEAVY"
		WeaponType.WAVE:   return "WAVE"
		WeaponType.FLAME:  return "FLAME"
		_:                 return "RIFLE"


func heal(amount: int = 1) -> void:
	if is_dead:
		return
	hp = min(max_hp, hp + amount)
	GameState.player_hp_changed.emit(hp, max_hp)


func _apply_weapon_visuals() -> void:
	match current_weapon:
		WeaponType.RIFLE:
			gun_barrel.width = 2.5
			gun_barrel.default_color = Palette.C_LIGHT_GRAY
			sprite.modulate = Color.WHITE
		WeaponType.SPREAD:
			gun_barrel.width = 4.0
			gun_barrel.default_color = Palette.C_GOLD
			sprite.modulate = Color(1.08, 0.98, 0.88, 1.0)
		WeaponType.HEAVY:
			gun_barrel.width = 3.5
			gun_barrel.default_color = Palette.C_TEAL.lightened(0.35)
			sprite.modulate = Color(0.88, 1.06, 1.12, 1.0)
		WeaponType.WAVE:
			gun_barrel.width = 3.0
			gun_barrel.default_color = Palette.C_CREAM
			sprite.modulate = Color(1.06, 1.06, 0.92, 1.0)
		WeaponType.FLAME:
			gun_barrel.width = 4.5
			gun_barrel.default_color = Palette.C_RED_CORE
			sprite.modulate = Color(1.12, 0.94, 0.90, 1.0)


func _handle_movement(delta: float) -> void:
	var x_input := Input.get_axis("move_left", "move_right")
	var holding_down := Input.is_action_pressed("aim_down")

	if x_input > 0.15:
		facing = 1
	elif x_input < -0.15:
		facing = -1

	# الانبطاح الكامل على الأرض (Prone) لتفادي الرصاص
	var wants_prone := is_on_floor() and holding_down and absf(x_input) < 0.35
	_set_prone(wants_prone)

	velocity.x = 0.0 if is_prone else x_input * move_speed

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 340.0)

	# القفز الأرضي + النزول من المنصات + القفزة المزدوجة في الهواء (Double Jump)
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			if holding_down and is_on_floor() and global_position.y < 156.0:
				set_collision_mask_value(6, false)
				_drop_through_timer = 0.20
				position.y += 2.0
			else:
				velocity.y = jump_velocity
				_jumps_left = 1
				_play_sfx("jump")
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
		elif _jumps_left > 0:
			# قفزة مركبة مزدوجة في الهواء مع شقلبة أسرع!
			velocity.y = double_jump_velocity
			_jumps_left -= 1
			_jump_buffer_timer = 0.0
			_play_sfx("jump")

	# قفزة متغيرة الارتفاع (إفلات الزر مبكراً يعطي قفزة قصيرة متحكم بها)
	if Input.is_action_just_released("jump") and velocity.y < -95.0:
		velocity.y *= 0.55

	move_and_slide()

	if global_position.y > 235.0:
		take_damage(max_hp)


func _set_prone(prone: bool) -> void:
	if is_prone == prone:
		return
	is_prone = prone
	stand_shape.disabled = is_prone
	prone_shape.disabled = not is_prone
	# تصغير منطقة تلقي الضرر لتمر الطلقات المرتفعة فوق البطل أثناء الانبطاح!
	var rect := hurtbox_shape.shape as RectangleShape2D
	if rect:
		if is_prone:
			rect.size = Vector2(18, 7)
			hurtbox_shape.position = Vector2(0, -4)
		else:
			rect.size = Vector2(10, 26)
			hurtbox_shape.position = Vector2(0, -13)


func _update_aim_direction() -> void:
	var x_in := 0
	if Input.is_action_pressed("move_right"):
		x_in += 1
	if Input.is_action_pressed("move_left"):
		x_in -= 1

	var y_in := 0
	if Input.is_action_pressed("aim_up"):
		y_in -= 1
	if Input.is_action_pressed("aim_down"):
		y_in += 1

	if is_prone:
		aim_direction = Vector2(facing, 0)
	elif y_in != 0 and x_in != 0:
		aim_direction = Vector2(x_in, y_in).normalized()
	elif y_in < 0:
		aim_direction = Vector2.UP
	elif y_in > 0 and not is_on_floor():
		aim_direction = Vector2.DOWN
	else:
		aim_direction = Vector2(facing, 0)


func _handle_shooting() -> void:
	var wants_fire := Input.is_action_pressed("fire") or GameState.auto_fire_enabled
	if wants_fire and _fire_timer <= 0.0:
		_fire_weapon()


func _fire_weapon() -> void:
	var origin := _get_muzzle_position()
	_recoil_timer = 0.07
	_muzzle_flash_timer = 0.05

	match current_weapon:
		WeaponType.RIFLE:
			_spawn_bullet(origin, aim_direction, 255.0, 1, 0)
			_fire_timer = 0.14
		WeaponType.SPREAD:
			for deg in [-16.0, 0.0, 16.0]:
				_spawn_bullet(origin, aim_direction.rotated(deg_to_rad(deg)), 230.0, 1, 1)
			_fire_timer = 0.27
		WeaponType.HEAVY:
			_spawn_bullet(origin, aim_direction, 295.0, 2, 2)
			_fire_timer = 0.23
		WeaponType.WAVE:
			_spawn_bullet(origin, aim_direction, 240.0, 1, 3, 1.0)
			_spawn_bullet(origin, aim_direction, 240.0, 1, 3, -1.0)
			_fire_timer = 0.22
		WeaponType.FLAME:
			for deg in [-22.0, -11.0, 0.0, 11.0, 22.0]:
				_spawn_bullet(origin, aim_direction.rotated(deg_to_rad(deg)), 215.0, 1, 4)
			_fire_timer = 0.34

	_play_sfx("shoot")


func _spawn_bullet(origin: Vector2, dir: Vector2, spd: float, dmg: int, style: int, w_sign: float = 1.0) -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(origin, dir, false, spd, dmg, style, w_sign)
	get_tree().current_scene.add_child(bullet)


func _get_barrel_length() -> float:
	match current_weapon:
		WeaponType.SPREAD: return 13.0
		WeaponType.HEAVY:  return 18.0
		WeaponType.FLAME:  return 14.0
		_:                 return 15.0


func _get_muzzle_position() -> Vector2:
	var shoulder := Vector2(facing * 6.0, -5.0) if is_prone else Vector2(0.0, -18.0)
	return global_position + shoulder + aim_direction * _get_barrel_length()


func _update_visuals(delta: float) -> void:
	sprite.flip_h = (facing < 0)
	_idle_time += delta

	var bob_y := 0.0
	if is_prone:
		sprite.texture = _tex_prone
		sprite.position = Vector2(0, -5)
		sprite.rotation = 0.0
	elif not is_on_floor():
		# شقلبة دائرية حقيقية أثناء القفز (Somersault Spin)
		sprite.texture = _tex_spin
		sprite.position = Vector2(0, -14)
		var spin_speed := 18.0 if _jumps_left == 0 else 13.0
		sprite.rotation += facing * spin_speed * delta
	elif absf(velocity.x) > 5.0:
		_anim_timer += delta
		if _anim_timer >= 0.09:
			_anim_timer = 0.0
			_anim_frame = (_anim_frame + 1) % _tex_run.size()
		sprite.texture = _tex_run[_anim_frame]
		bob_y = -1.0 if (_anim_frame % 2 == 1) else 0.0
		sprite.position = Vector2(0, -15.0 + bob_y)
		sprite.rotation = 0.0
	else:
		sprite.texture = _tex_idle
		bob_y = -0.6 if sin(_idle_time * 4.0) > 0.35 else 0.0
		sprite.position = Vector2(0, -15.0 + bob_y)
		sprite.rotation = 0.0

	var recoil := -2.5 if _recoil_timer > 0.0 else 0.0
	var shoulder := Vector2(facing * 6.0, -5.0) if is_prone else Vector2(0.0, -18.0 + bob_y)
	var tip := shoulder + aim_direction * (_get_barrel_length() + recoil)
	gun_barrel.points = PackedVector2Array([shoulder, tip])


func _draw() -> void:
	if _muzzle_flash_timer > 0.0 and not is_dead:
		var shoulder := Vector2(facing * 6.0, -5.0) if is_prone else Vector2(0.0, -18.0)
		var tip := shoulder + aim_direction * (_get_barrel_length() + 1.0)
		var flash_col := Palette.C_TEAL.lightened(0.5) if current_weapon == WeaponType.HEAVY else Palette.C_GOLD
		draw_circle(tip, 3.8, flash_col)
		draw_circle(tip, 1.8, Palette.C_WHITE)


func take_damage(amount: int = 1) -> void:
	if is_dead or _invincible_timer > 0.0 or GameState.is_game_over or GameState.is_level_cleared:
		return
	hp = max(0, hp - amount)
	GameState.player_hp_changed.emit(hp, max_hp)
	GameState.request_shake(3.0, 0.16)
	GameState.vibrate(70)
	_play_sfx("hit")

	if hp <= 0:
		_die()
	else:
		_invincible_timer = invincibility_time
		velocity.y = -110.0


## أنيميشن موت واضح ومؤكد للبطل قبل إظهار شاشة GAME OVER
func _die() -> void:
	is_dead = true
	gun_barrel.visible = false
	sprite.visible = true
	sprite.texture = _tex_prone
	sprite.modulate = Palette.C_RED_CORE
	sprite.rotation = facing * -0.35
	velocity = Vector2(-facing * 75.0, -145.0)

	var exp_fx := EXPLOSION_SCENE.instantiate()
	exp_fx.global_position = global_position + Vector2(0, -14)
	exp_fx.max_radius = 22.0
	exp_fx.particle_count = 14
	get_tree().current_scene.add_child(exp_fx)

	GameState.request_shake(6.0, 0.35)
	GameState.vibrate(220)
	_play_sfx("explode")

	await get_tree().create_timer(0.95).timeout
	if is_instance_valid(self):
		GameState.trigger_game_over()


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("boss"):
		take_damage(1)


func _play_sfx(sfx_name: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_name)


## سبرايتات بطول ثابت 30 بكسل (القدم دائماً في الصف السفلي حتى لا يتقزّم البطل أثناء الجري!)
func _build_sprites() -> void:
	_tex_idle = ProceduralArt.create_texture("player_idle_v3", PackedStringArray([
		".....000000.....",
		"....01111110....",
		"....01111110....",
		"....09999990....",
		"....09909900....",
		"....09999990....",
		".....099990.....",
		"......0990......",
		"...0008888000...",
		"..099087780990..",
		"..099088880990..",
		"..099087780990..",
		"..099088880990..",
		"...0008778000...",
		"....08888880....",
		"....01166110....",
		"....02222220....",
		"....02200220....",
		"....02200220....",
		"....02200220....",
		"....02200220....",
		"....02200220....",
		"....02200220....",
		"....02200220....",
		"....02200220....",
		"...0111001110...",
		"...0111001110...",
		"...0111001110...",
		"...0000000000...",
		"................",
	]))

	var run_a := ProceduralArt.create_texture("player_run_a_v3", PackedStringArray([
		".....000000.....",
		"....01111110....",
		"....01111110....",
		"....09999990....",
		"....09909900....",
		"....09999990....",
		".....099990.....",
		"......0990......",
		"...0008888000...",
		"..099087780990..",
		"..099088880990..",
		"..099087780990..",
		"...0008888000...",
		"....08888880....",
		"....01166110....",
		"....02222220....",
		"...0222002220...",
		"..02220..02220..",
		"..0220....0220..",
		".02220....02220.",
		".0220......0220.",
		".0220......0220.",
		"0220........0220",
		"0220........0220",
		"0110........0110",
		"01110......01110",
		"01110......01110",
		"00000......00000",
		"................",
		"................",
	]))

	var run_mid := ProceduralArt.create_texture("player_run_mid_v3", PackedStringArray([
		".....000000.....",
		"....01111110....",
		"....01111110....",
		"....09999990....",
		"....09909900....",
		"....09999990....",
		".....099990.....",
		"......0990......",
		"...0008888000...",
		"..099087780990..",
		"..099088880990..",
		"..099087780990..",
		"...0008888000...",
		"....08888880....",
		"....01166110....",
		"....02222220....",
		"....02222220....",
		".....022220.....",
		".....022220.....",
		"....02222220....",
		"....02200220....",
		"....02200220....",
		"....02200220....",
		"....02200220....",
		"....01100110....",
		"...0111001110...",
		"...0111001110...",
		"...0000000000...",
		"................",
		"................",
	]))

	var run_b := ProceduralArt.create_texture("player_run_b_v3", PackedStringArray([
		".....000000.....",
		"....01111110....",
		"....01111110....",
		"....09999990....",
		"....09909900....",
		"....09999990....",
		".....099990.....",
		"......0990......",
		"...0008888000...",
		"..099087780990..",
		"..099088880990..",
		"..099087780990..",
		"...0008888000...",
		"....08888880....",
		"....01166110....",
		"....02222220....",
		"...0222002220...",
		"...0220..0220...",
		"..0220....0220..",
		"..0220....0220..",
		"..0220....0220..",
		"..0220....0220..",
		".0220......0220.",
		".0110......0110.",
		".01110....01110.",
		".01110....01110.",
		".00000....00000.",
		"................",
		"................",
		"................",
	]))

	_tex_run = [run_a, run_mid, run_b, run_mid]

	# وضعية الشقلبة الدائرية في الهواء (16×16 متكورة تدور حول مركزها)
	_tex_spin = ProceduralArt.create_texture("player_spin_v3", PackedStringArray([
		"....00000000....",
		"..001111111100..",
		".01199999988810.",
		".01990998877880.",
		"0119999888888220",
		"0188888877822220",
		"0887788116622220",
		"0888881166222110",
		"0222222222221110",
		"0222222222111100",
		".0222222111100..",
		".011111111000...",
		"..001111100.....",
		"....00000.......",
		"................",
		"................",
	]))

	# وضعية الانبطاح الكامل على الأرض (Prone 28×10 بكسل لتفادي الرصاص)
	_tex_prone = ProceduralArt.create_texture("player_prone_v3", PackedStringArray([
		"..................000000....",
		".................01111110...",
		".................09999990...",
		"....000000000000009909900...",
		"..00111222222888880999900...",
		".0111122222228778888099900..",
		"01111222222116688888809990..",
		"00000222222116687788800000..",
		".....0000000000000000.......",
		"............................",
	]))
