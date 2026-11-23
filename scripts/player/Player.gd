extends CharacterBody2D
## سكربت البطل الرئيسي - لعبة "حارة البطل"
## حركة أركيد حية (4 إطارات جري + تنفس + قفز + ارتداد ووميض إطلاق نار)
## وتبديل أسلحة مع تغير بصري واضح في شكل ولون السلاح والطلقات

enum WeaponType {
	RIFLE,  # رشاش الحارة السريع
	SPREAD, # سلاح متفرق (3 طلقات)
	HEAVY,  # سلاح ثقيل (ضرر مضاعف + شعاع عريض)
}

const BULLET_SCENE := preload("res://scenes/player/Bullet.tscn")

@export_group("Movement")
@export var move_speed: float = 96.0
@export var gravity: float = 540.0
@export var jump_velocity: float = -232.0
@export var coyote_time: float = 0.09
@export var jump_buffer_time: float = 0.10

@export_group("Combat")
@export var max_hp: int = 5
@export var invincibility_time: float = 1.0

var hp: int = 5
var facing: int = 1 # 1 = يمين، -1 = يسار
var is_crouching: bool = false
var aim_direction: Vector2 = Vector2.RIGHT
var current_weapon: WeaponType = WeaponType.RIFLE

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
var _tex_jump: Texture2D
var _tex_crouch: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var stand_shape: CollisionShape2D = $StandCollision
@onready var crouch_shape: CollisionShape2D = $CrouchCollision
@onready var gun_barrel: Line2D = $GunBarrel
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	_build_sprites()
	sprite.texture = _tex_idle
	crouch_shape.disabled = true
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	_apply_weapon_visuals()
	GameState.player_hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
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
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)


func _handle_input_actions() -> void:
	if Input.is_action_just_pressed("toggle_autofire"):
		GameState.toggle_auto_fire()
	if Input.is_action_just_pressed("switch_weapon"):
		cycle_weapon()
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


## تبديل السلاح مع تحديث الشكل البصري للبطل فوراً
func cycle_weapon() -> void:
	set_weapon((int(current_weapon) + 1) % 3)


func set_weapon(weapon_idx: int) -> void:
	current_weapon = clampi(weapon_idx, 0, 2) as WeaponType
	_apply_weapon_visuals()
	_play_sfx("jump")


func heal(amount: int = 1) -> void:
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
			sprite.modulate = Color(1.08, 1.0, 0.9, 1.0)
		WeaponType.HEAVY:
			gun_barrel.width = 3.5
			gun_barrel.default_color = Palette.C_TEAL.lightened(0.35)
			sprite.modulate = Color(0.9, 1.08, 1.1, 1.0)


func _handle_movement(delta: float) -> void:
	var x_input := Input.get_axis("move_left", "move_right")
	var holding_down := Input.is_action_pressed("aim_down")

	if x_input > 0.1:
		facing = 1
	elif x_input < -0.1:
		facing = -1

	var wants_crouch := is_on_floor() and holding_down and absf(x_input) < 0.1
	_set_crouch(wants_crouch)

	velocity.x = 0.0 if is_crouching else x_input * move_speed

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 340.0)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		if holding_down and is_on_floor():
			set_collision_mask_value(6, false)
			_drop_through_timer = 0.18
			position.y += 1.5
		else:
			velocity.y = jump_velocity
			_play_sfx("jump")
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	move_and_slide()

	if global_position.y > 240.0:
		take_damage(max_hp)


func _set_crouch(crouch: bool) -> void:
	if is_crouching == crouch:
		return
	is_crouching = crouch
	stand_shape.disabled = is_crouching
	crouch_shape.disabled = not is_crouching


## حساب اتجاه التصويب في 8 اتجاهات كاملة
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

	if is_crouching:
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
			_spawn_bullet(origin, aim_direction, 250.0, 1, 0)
			_fire_timer = 0.14
		WeaponType.SPREAD:
			for deg in [-15.0, 0.0, 15.0]:
				_spawn_bullet(origin, aim_direction.rotated(deg_to_rad(deg)), 225.0, 1, 1)
			_fire_timer = 0.28
		WeaponType.HEAVY:
			_spawn_bullet(origin, aim_direction, 290.0, 2, 2)
			_fire_timer = 0.24

	_play_sfx("shoot")


func _spawn_bullet(origin: Vector2, dir: Vector2, spd: float, dmg: int, style: int) -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(origin, dir, false, spd, dmg, style)
	get_tree().current_scene.add_child(bullet)


func _get_barrel_length() -> float:
	match current_weapon:
		WeaponType.SPREAD:
			return 13.0
		WeaponType.HEAVY:
			return 18.0
		_:
			return 15.0


func _get_muzzle_position() -> Vector2:
	var shoulder_offset := Vector2(0, -9) if is_crouching else Vector2(0, -18)
	return global_position + shoulder_offset + aim_direction * _get_barrel_length()


func _update_visuals(delta: float) -> void:
	sprite.flip_h = (facing < 0)
	_idle_time += delta

	var bob_y := 0.0
	if is_crouching:
		sprite.texture = _tex_crouch
		sprite.position = Vector2(0, -8)
		sprite.rotation = 0.0
	elif not is_on_floor():
		sprite.texture = _tex_jump
		sprite.position = Vector2(0, -15)
		# ميلان خفيف أثناء القفز للأمام لحركة أركيد حية
		sprite.rotation = facing * 0.14 if absf(velocity.x) > 10.0 else 0.0
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
		# حركة تنفس خفيفة أثناء الوقوف
		bob_y = -0.8 if sin(_idle_time * 4.0) > 0.3 else 0.0
		sprite.position = Vector2(0, -15.0 + bob_y)
		sprite.rotation = 0.0

	# رسم ماسورة السلاح مع ارتداد عند الإطلاق
	var recoil := -2.5 if _recoil_timer > 0.0 else 0.0
	var shoulder := Vector2(0, -9) if is_crouching else Vector2(0, -18 + bob_y)
	var tip := shoulder + aim_direction * (_get_barrel_length() + recoil)
	gun_barrel.points = PackedVector2Array([shoulder, tip])


func _draw() -> void:
	if _muzzle_flash_timer > 0.0:
		var shoulder := Vector2(0, -9) if is_crouching else Vector2(0, -18)
		var tip := shoulder + aim_direction * (_get_barrel_length() + 1.0)
		var flash_col := Palette.C_TEAL.lightened(0.5) if current_weapon == WeaponType.HEAVY else Palette.C_GOLD
		draw_circle(tip, 3.5, flash_col)
		draw_circle(tip, 1.8, Palette.C_WHITE)


func take_damage(amount: int = 1) -> void:
	if _invincible_timer > 0.0 or GameState.is_game_over or GameState.is_level_cleared:
		return
	hp = max(0, hp - amount)
	GameState.player_hp_changed.emit(hp, max_hp)
	GameState.vibrate(65)
	_play_sfx("hit")

	if hp <= 0:
		GameState.trigger_game_over()
	else:
		_invincible_timer = invincibility_time
		velocity.y = -110.0


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("boss"):
		take_damage(1)


func _play_sfx(sfx_name: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_name)


## توليد سبرايتات بكسل آرت أصلية للبطل (4 إطارات جري + وقوف + قفز + انحناء)
func _build_sprites() -> void:
	_tex_idle = ProceduralArt.create_texture("player_idle_v2", PackedStringArray([
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

	var run_stride_a := ProceduralArt.create_texture("player_run_a", PackedStringArray([
		".....000000.....",
		"....01111110....",
		"....09999990....",
		"....09909900....",
		".....099990.....",
		"......0990......",
		"...0008888000...",
		"..099087780990..",
		"..099088880990..",
		"...0008778000...",
		"....08888880....",
		"....01166110....",
		"...022222220....",
		"..02220002220...",
		".02220...02220..",
		"02220.....02220.",
		"0220.......0220.",
		"0110.......01110",
		"0110.......00000",
		"0000............",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	]))

	var run_pass := ProceduralArt.create_texture("player_run_pass", PackedStringArray([
		".....000000.....",
		"....01111110....",
		"....09999990....",
		"....09909900....",
		".....099990.....",
		"......0990......",
		"...0008888000...",
		"..099087780990..",
		"..099088880990..",
		"...0008778000...",
		"....08888880....",
		"....01166110....",
		"....02222220....",
		"....02222220....",
		".....022220.....",
		".....022220.....",
		"....02200220....",
		"....02200220....",
		"....01100110....",
		"...0111001110...",
		"...0000000000...",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	]))

	var run_stride_b := ProceduralArt.create_texture("player_run_b", PackedStringArray([
		".....000000.....",
		"....01111110....",
		"....09999990....",
		"....09909900....",
		".....099990.....",
		"......0990......",
		"...0008888000...",
		"..099087780990..",
		"..099088880990..",
		"...0008778000...",
		"....08888880....",
		"....01166110....",
		"....02222220....",
		"...0222002220...",
		"..0220....0220..",
		"..0220....0220..",
		".01110....0110..",
		".00000....0110..",
		"..........0000..",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	]))

	_tex_run = [run_stride_a, run_pass, run_stride_b, run_pass]

	_tex_jump = ProceduralArt.create_texture("player_jump_v2", PackedStringArray([
		".....000000.....",
		"....01111110....",
		"....09999990....",
		"....09909900....",
		".....099990.....",
		"...0008888000...",
		"..099087780990..",
		"..099088880990..",
		"...0008778000...",
		"....01166110....",
		"...0222222220...",
		"..02220..02220..",
		"..0220....0220..",
		"..0110....0110..",
		"..0110....0110..",
		"..0000....0000..",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	]))

	_tex_crouch = ProceduralArt.create_texture("player_crouch_v2", PackedStringArray([
		".........000000.....",
		"........01111110....",
		"........09999990....",
		"........09909900....",
		".........099990.....",
		"....0000088888800...",
		"...022220877880990..",
		"..0222220888880990..",
		".0111122011661000...",
		".01110222222220.....",
		".00000222222220.....",
		"......022200220.....",
		"......011100110.....",
		"......011100110.....",
		"......000000000.....",
		"....................",
	]))
