extends CharacterBody2D
## سكربت البطل الرئيسي - لعبة "حارة البطل"
## - طول ثابت 30 بكسل أثناء الجري (4 إطارات متناسقة بدون تقزّم)
## - انبطاح كامل على الأرض (Prone) لتفادي طلقات الأعداء
## - قفزة مع شقلبة دائرية (Somersault Spin) + قفزة مزدوجة مركبة (Double Jump)
## - 5 أسلحة أصلية بتغيّر بصري واضح + أنيميشن موت واضح مع انفجار واهتزاز

enum WeaponType {
	RIFLE,   # 0: رشاش الحارة السريع
	SPREAD,  # 1: سلاح متفرق (3 طلقات)
	HEAVY,   # 2: شعاع ثقيل (ضرر مضاعف)
	WAVE,    # 3: ليزر متموج مزدوج
	FLAME,   # 4: قاذف شرار سريع (5 طلقات)
	MISSILE, # 5: قاذف صواريخ متفجرة (المرحلة 3)
	Z_CANNON,# 6: مدفع Z الخارق (هدية نادرة - 5 طلقات ساحقة)
}

const BULLET_SCENE := preload("res://scenes/player/Bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")

@export_group("Movement")
@export var move_speed: float = 76.0
@export var gravity: float = 510.0
@export var jump_velocity: float = -218.0
@export var double_jump_velocity: float = -196.0
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
var inventory: Array[int] = [0]
var current_inv_index: int = 0
var z_ammo: int = 0

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
	if GameState.saved_inventory.is_empty():
		GameState.saved_inventory = [0]
	inventory = GameState.saved_inventory.duplicate()
	current_inv_index = 0
	for i in range(inventory.size()):
		if inventory[i] == GameState.saved_weapon:
			current_inv_index = i
			break
	current_weapon = inventory[current_inv_index] as WeaponType
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


## التبديل بين الأسلحة المحفوظة في الحقيبة (بحد أقصى 3 أسلحة)
func cycle_weapon() -> void:
	if inventory.size() <= 1:
		return
	current_inv_index = (current_inv_index + 1) % inventory.size()
	if z_ammo <= 0:
		current_weapon = inventory[current_inv_index] as WeaponType
		GameState.saved_weapon = int(current_weapon)
		_apply_weapon_visuals()
		_play_sfx("jump")


## إضافة سلاح للحقيبة (بحد أقصى 3 أسلحة) أو تفعيل مدفع Z الخارق بـ 5 طلقات
func add_weapon(weapon_idx: int) -> void:
	if weapon_idx == int(WeaponType.Z_CANNON):
		z_ammo = 5
		current_weapon = WeaponType.Z_CANNON
		_apply_weapon_visuals()
		_play_sfx("jump")
		return

	var w_clamped := clampi(weapon_idx, 0, 5)
	if w_clamped in inventory:
		current_inv_index = inventory.find(w_clamped)
	else:
		if inventory.size() < 3:
			inventory.append(w_clamped)
			current_inv_index = inventory.size() - 1
		else:
			# استبدال السلاح النشط حالياً عند امتلاء الحقيبة بـ 3 أسلحة
			inventory[current_inv_index] = w_clamped

	if z_ammo <= 0:
		current_weapon = inventory[current_inv_index] as WeaponType
		GameState.saved_weapon = int(current_weapon)
		_apply_weapon_visuals()

	GameState.saved_inventory = inventory.duplicate()
	_play_sfx("jump")


func set_weapon(weapon_idx: int) -> void:
	add_weapon(weapon_idx)


func get_weapon_name() -> String:
	if z_ammo > 0:
		return "Z-CANNON: %d" % z_ammo
	var w_name := "RIFLE"
	match current_weapon:
		WeaponType.SPREAD:  w_name = "SPREAD"
		WeaponType.HEAVY:   w_name = "HEAVY"
		WeaponType.WAVE:    w_name = "WAVE"
		WeaponType.FLAME:   w_name = "FLAME"
		WeaponType.MISSILE: w_name = "MISSILE"
		_:                  w_name = "RIFLE"
	return "%s [%d/3]" % [w_name, inventory.size()]


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
		WeaponType.MISSILE:
			gun_barrel.width = 4.8
			gun_barrel.default_color = Palette.C_WOOD.lightened(0.2)
			sprite.modulate = Color(1.15, 1.05, 0.90, 1.0)
		WeaponType.Z_CANNON:
			gun_barrel.width = 6.2
			gun_barrel.default_color = Palette.C_GOLD
			sprite.modulate = Color(1.3, 1.25, 0.8, 1.0)


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
		WeaponType.MISSILE:
			_spawn_bullet(origin, aim_direction, 260.0, 3, 5)
			_fire_timer = 0.28
			GameState.request_shake(2.0, 0.08)
		WeaponType.Z_CANNON:
			_spawn_bullet(origin, aim_direction, 340.0, 8, 6)
			_fire_timer = 0.35
			GameState.request_shake(5.5, 0.22)
			GameState.vibrate(100)
			z_ammo -= 1
			if z_ammo <= 0:
				current_weapon = inventory[current_inv_index] as WeaponType
				_apply_weapon_visuals()

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
		WeaponType.MISSILE:return 16.0
		WeaponType.Z_CANNON:return 21.0
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


## أنيميشن موت واضح ومؤكد للبطل: إذا تبقّت محاولات (Lives) يعود للعب، وإلا تظهر GAME OVER
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

	var has_more_lives := GameState.lose_life()
	await get_tree().create_timer(0.95).timeout
	if not is_instance_valid(self):
		return

	if has_more_lives:
		# عودة البطل بمحاولة جديدة في مكان آمن مع فترة حماية
		is_dead = false
		hp = max_hp
		GameState.player_hp_changed.emit(hp, max_hp)
		gun_barrel.visible = true
		sprite.rotation = 0.0
		_apply_weapon_visuals()
		if global_position.y > 170.0:
			global_position = Vector2(maxf(40.0, global_position.x - 48.0), 120.0)
		velocity = Vector2.ZERO
		_invincible_timer = 2.0
	else:
		GameState.trigger_game_over()


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("boss"):
		take_damage(1)


func _play_sfx(sfx_name: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_name)


## سبرايتات 16-bit محسّنة للبطل (18×32 بكسل — شعر مظلل، وجه معبّر، وشاح ذهبي طائر، سترة خضراء وحزام وأحذية)
func _build_sprites() -> void:
	_tex_idle = ProceduralArt.create_texture("player_idle_v4", PackedStringArray([
		"......000000......",
		".....01122110.....",
		"....0121111110....",
		"....0119999910....",
		"....0999099090....",
		"....0999999990....",
		".....09995990.....",
		"....006666600.....",
		"..006608888000....",
		".06609987788990...",
		"..0009988888990...",
		"....09987788990...",
		"....00088668000...",
		".....008888800....",
		".....011666110....",
		".....022444220....",
		".....022202220....",
		".....022202220....",
		".....0220.0220....",
		".....0220.0220....",
		".....0220.0220....",
		".....0220.0220....",
		".....0220.0220....",
		".....0220.0220....",
		"....01110.01110...",
		"....01120.01120...",
		"....01110.01110...",
		"....01110.01110...",
		"....00000.00000...",
		"..................",
	]))

	var run_a := ProceduralArt.create_texture("player_run_a_v4", PackedStringArray([
		"......000000......",
		".....01122110.....",
		"....0121111110....",
		"....0119999910....",
		"....0999099090....",
		"....0999999990....",
		".....09995990.....",
		".000006666600.....",
		"06666008888000....",
		".00009987788990...",
		"....09988888990...",
		"....00087788000...",
		".....008866800....",
		".....011666110....",
		".....022444220....",
		"....02220002220...",
		"...02220...02220..",
		"..02220.....02220.",
		"..0220.......0220.",
		".02220.......02220",
		".0220.........0220",
		".0220.........0220",
		"0220..........0220",
		"0110..........0110",
		"01120........01120",
		"01110........01110",
		"01110........01110",
		"00000........00000",
		"..................",
		"..................",
	]))

	var run_mid := ProceduralArt.create_texture("player_run_mid_v4", PackedStringArray([
		"......000000......",
		".....01122110.....",
		"....0121111110....",
		"....0119999910....",
		"....0999099090....",
		"....0999999990....",
		".....09995990.....",
		"..00006666600.....",
		".0666008888000....",
		"..0009987788990...",
		"....09988888990...",
		"....00087788000...",
		".....008866800....",
		".....011666110....",
		".....022444220....",
		".....022222220....",
		"......0222220.....",
		"......0222220.....",
		".....022202220....",
		".....0220.0220....",
		".....0220.0220....",
		".....0220.0220....",
		".....0220.0220....",
		".....0110.0110....",
		"....01120.01120...",
		"....01110.01110...",
		"....01110.01110...",
		"....00000.00000...",
		"..................",
		"..................",
	]))

	var run_b := ProceduralArt.create_texture("player_run_b_v4", PackedStringArray([
		"......000000......",
		".....01122110.....",
		"....0121111110....",
		"....0119999910....",
		"....0999099090....",
		"....0999999990....",
		".....09995990.....",
		"0000006666600.....",
		"06666608888000....",
		".00009987788990...",
		"....09988888990...",
		"....00087788000...",
		".....008866800....",
		".....011666110....",
		".....022444220....",
		"....02220002220...",
		"....0220...0220...",
		"...0220.....0220..",
		"...0220.....0220..",
		"..0220.......0220.",
		"..0220.......0220.",
		"..0220.......0220.",
		".0220.........0220",
		".0110.........0110",
		".01120.......01120",
		".01110.......01110",
		".01110.......01110",
		".00000.......00000",
		"..................",
		"..................",
	]))

	_tex_run = [run_a, run_mid, run_b, run_mid]

	# شقلبة دائرية مع أثر الوشاح الذهبي
	_tex_spin = ProceduralArt.create_texture("player_spin_v4", PackedStringArray([
		"....00000000....",
		"..001122111100..",
		".01199996688810.",
		".01990966877880.",
		"0119996688888220",
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

	# وضعية الانبطاح الكامل مع الوشاح الذهبي
	_tex_prone = ProceduralArt.create_texture("player_prone_v4", PackedStringArray([
		"..................000000....",
		".................01122110...",
		".................09999990...",
		"....000000000000009909900...",
		"..00111222222886660999900...",
		".0111122222228776688099900..",
		"01111222222116688888809990..",
		"00000222222116687788800000..",
		".....0000000000000000.......",
		"............................",
	]))
