extends CharacterBody2D
## سكربت الأعداء - يدعم 5 أنواع مختلفة بتشكيلة متنوعة وذكاء اصطناعي مميز:
## 0) WALKER: دورية مستمرة بين نقطتين/الحواف
## 1) SHOOTER: رصد البطل وإطلاق النار باتجاهه
## 2) JUMPER: قفز دوري نحو البطل مع إطلاق نار
## 3) DRONE: درون طائر يحوم في الجو ويطلق ناراً قطرياً لأسفل
## 4) HEAVY: مدرّع ثقيل (4 HP) يمشي نحو البطل ويطلق رشقة مزدوجة

enum EnemyType {
	WALKER,
	SHOOTER,
	JUMPER,
	DRONE,
	HEAVY,
}

const BULLET_SCENE := preload("res://scenes/player/Bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")

@export var enemy_type: EnemyType = EnemyType.WALKER
@export var max_hp: int = 2
@export var move_speed: float = 42.0
@export var gravity: float = 500.0
@export var patrol_distance: float = 54.0
@export var detect_range: float = 210.0
@export var fire_interval: float = 1.45
@export var jump_velocity: float = -185.0
@export var jump_interval: float = 1.35
@export var bullet_speed: float = 115.0
@export var score_value: int = 100

var hp: int = 2
var facing: int = -1

var _start_pos: Vector2 = Vector2.ZERO
var _hover_time: float = 0.0
var _fire_timer: float = 0.65
var _jump_timer: float = 0.8
var _flash_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var floor_check: RayCast2D = $FloorCheck


func _ready() -> void:
	add_to_group("enemy")
	_start_pos = global_position
	_apply_type_defaults()
	_build_sprite()
	_update_floor_check()


func _apply_type_defaults() -> void:
	match enemy_type:
		EnemyType.WALKER:
			hp = max_hp
			move_speed = 46.0
		EnemyType.SHOOTER:
			hp = max(max_hp, 2)
			move_speed = 0.0
			score_value = 150
		EnemyType.JUMPER:
			hp = max(max_hp, 2)
			move_speed = 55.0
			score_value = 150
		EnemyType.DRONE:
			hp = max(max_hp, 2)
			move_speed = 42.0
			fire_interval = 1.6
			score_value = 200
		EnemyType.HEAVY:
			hp = max(max_hp + 2, 4)
			move_speed = 26.0
			fire_interval = 1.7
			score_value = 250


func _physics_process(delta: float) -> void:
	if GameState.is_game_over or GameState.is_level_cleared:
		velocity = Vector2.ZERO
		return

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			sprite.modulate = Color.WHITE

	var player := _find_player()
	var dist_to_player := INF
	var dir_to_player := Vector2.LEFT
	if player:
		var diff := (player.global_position + Vector2(0, -10)) - (global_position + Vector2(0, -12))
		dist_to_player = diff.length()
		dir_to_player = diff.normalized()

	if enemy_type == EnemyType.DRONE:
		_ai_drone(delta, player, dist_to_player, dir_to_player)
		sprite.flip_h = (facing < 0)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 300.0)

	match enemy_type:
		EnemyType.WALKER:
			_ai_walker()
		EnemyType.SHOOTER:
			_ai_shooter(delta, player, dist_to_player, dir_to_player)
		EnemyType.JUMPER:
			_ai_jumper(delta, player, dist_to_player, dir_to_player)
		EnemyType.HEAVY:
			_ai_heavy(delta, player, dist_to_player, dir_to_player)

	sprite.flip_h = (facing < 0)
	_update_floor_check()
	move_and_slide()


func _ai_walker() -> void:
	velocity.x = facing * move_speed
	var hit_wall := is_on_wall()
	var reached_edge := is_on_floor() and not floor_check.is_colliding()
	var outside_patrol := absf(global_position.x - _start_pos.x) > patrol_distance

	if hit_wall or reached_edge:
		facing = -facing
	elif outside_patrol:
		if global_position.x > _start_pos.x and facing > 0:
			facing = -1
		elif global_position.x < _start_pos.x and facing < 0:
			facing = 1


func _ai_shooter(delta: float, player: Node2D, dist: float, dir_to_player: Vector2) -> void:
	velocity.x = 0.0
	if not player or dist > detect_range:
		return
	facing = 1 if player.global_position.x >= global_position.x else -1
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_shoot_at(dir_to_player)
		_fire_timer = fire_interval


func _ai_jumper(delta: float, player: Node2D, dist: float, dir_to_player: Vector2) -> void:
	_jump_timer -= delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 180.0 * delta)
		if player and dist <= detect_range:
			facing = 1 if player.global_position.x >= global_position.x else -1
		if _jump_timer <= 0.0:
			velocity.y = jump_velocity
			velocity.x = facing * move_speed
			_jump_timer = jump_interval
			_play_sfx("jump")
			if player and dist <= detect_range * 0.9:
				_shoot_at(dir_to_player)
	else:
		if is_on_wall():
			facing = -facing
			velocity.x = facing * move_speed


## سلوك الدرون الطائر (يحوم في الجو ويطلق طلقات قطرية للأسفل)
func _ai_drone(delta: float, player: Node2D, dist: float, dir_to_player: Vector2) -> void:
	_hover_time += delta * 3.0
	velocity.x = facing * move_speed
	velocity.y = sin(_hover_time) * 28.0
	if absf(global_position.x - _start_pos.x) > patrol_distance:
		facing = -1 if global_position.x > _start_pos.x else 1
	if player and dist <= detect_range:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_shoot_at(dir_to_player)
			_fire_timer = fire_interval


## سلوك المدرّع الثقيل (يتقدم بثبات ويطلق رشقة مزدوجة)
func _ai_heavy(delta: float, player: Node2D, dist: float, dir_to_player: Vector2) -> void:
	if player and dist <= detect_range:
		facing = 1 if player.global_position.x >= global_position.x else -1
		velocity.x = facing * move_speed if dist > 55.0 else 0.0
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_shoot_at(dir_to_player.rotated(deg_to_rad(-8.0)))
			_shoot_at(dir_to_player.rotated(deg_to_rad(8.0)))
			_fire_timer = fire_interval
	else:
		_ai_walker()


func _shoot_at(dir: Vector2) -> void:
	var bullet := BULLET_SCENE.instantiate()
	var muzzle := global_position + Vector2(facing * 10.0, -16.0)
	bullet.setup(muzzle, dir, true, bullet_speed, 1, 0, 1.0, 2.8)
	get_tree().current_scene.add_child(bullet)
	_play_sfx("enemy_shoot")


func take_damage(amount: int = 1) -> void:
	hp -= amount
	_flash_timer = 0.08
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	_play_sfx("hit")

	if hp <= 0:
		var exp_fx := EXPLOSION_SCENE.instantiate()
		exp_fx.global_position = global_position + Vector2(0, -12)
		get_tree().current_scene.add_child(exp_fx)
		GameState.request_shake(2.2, 0.12)
		GameState.vibrate(25)
		GameState.add_score(score_value)
		_play_sfx("explode")
		queue_free()


func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _update_floor_check() -> void:
	floor_check.position = Vector2(facing * 8.0, -1.0)


func _play_sfx(sfx_name: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_name)


func _build_sprite() -> void:
	match enemy_type:
		EnemyType.WALKER:
			sprite.texture = ProceduralArt.create_texture("enemy_walker_lg", PackedStringArray([
				"....0000000.....",
				"...0ddddddd0....",
				"...0d11111d0....",
				"...099999990....",
				"...090999090....",
				"....0999990.....",
				".....09990......",
				"..000ddddd000...",
				".0990d111d0990..",
				".0990ddddd0990..",
				".0990d111d0990..",
				"..000ddddd000...",
				"...011111110....",
				"...011000110....",
				"...011000110....",
				"...0110.0110....",
				"...0110.0110....",
				"...0110.0110....",
				"..00110.01100...",
				"..00000.00000...",
			]))
			sprite.scale = Vector2(1.25, 1.3)
		EnemyType.SHOOTER:
			sprite.texture = ProceduralArt.create_texture("enemy_shooter_lg", PackedStringArray([
				"....0000000.....",
				"...0bbbbbbb0....",
				"..0bbcccccbb0...",
				"..0bbeeeeebb0...",
				"...0bbbbbbb0....",
				".....0bbb0......",
				"..000ddddd000...",
				".0bb0dc1cd0bbb0.",
				".0bb0ddddd0bbb0.",
				".0bb0dc1cd0000..",
				"..000ddddd00....",
				"...0bbbbbbb0....",
				"...0bb000bb0....",
				"...0bb000bb0....",
				"...0bb0.0bb0....",
				"...0bb0.0bb0....",
				"...0110.0110....",
				"..01110.01110...",
				"..00000.00000...",
				"................",
			]))
			sprite.scale = Vector2(1.25, 1.3)
		EnemyType.JUMPER:
			sprite.texture = ProceduralArt.create_texture("enemy_jumper_lg", PackedStringArray([
				".....000000.....",
				"....06666660....",
				"...0333333330...",
				"...033e33e330...",
				"...0333333330...",
				"....03333330....",
				"..000366663000..",
				".03303333330330.",
				".03303666630330.",
				"..000333333000..",
				"...0111111110...",
				"...0660000660...",
				"..0660....0660..",
				"..0330....0330..",
				"..0330....0330..",
				".01110....01110.",
				".01110....01110.",
				".00000....00000.",
				"................",
				"................",
			]))
			sprite.scale = Vector2(1.25, 1.3)
		EnemyType.DRONE:
			sprite.texture = ProceduralArt.create_texture("enemy_drone_lg", PackedStringArray([
				"00000......00000",
				"..0cc000000cc0..",
				"...0bbbbbbbb0...",
				"..0bbccccccbb0..",
				".0bb11deed11bb0.",
				".0bb1deffed1bb0.",
				".0bb11deed11bb0.",
				"..0bbbbbbbbbb0..",
				"...0006666000...",
				".....0e00e0.....",
				"......0000......",
			]))
			sprite.scale = Vector2(1.4, 1.4)
		EnemyType.HEAVY:
			sprite.texture = ProceduralArt.create_texture("enemy_heavy_lg", PackedStringArray([
				"...0000000000...",
				"..0bbbbbbbbbb0..",
				"..0bccccccccb0..",
				"..0b1ee11ee1b0..",
				"..0bbbbbbbbbb0..",
				".00dddddddddd00.",
				"0bb0d666666d0bb0",
				"0bb0dddddddd0bb0",
				"0bb0d666666d0bb0",
				"0bb0dddddddd0bb0",
				".00bbbbbbbbbb00.",
				"..0bbb0000bbb0..",
				"..0bbb0..0bbb0..",
				"..0bbb0..0bbb0..",
				".011110..011110.",
				".000000..000000.",
			]))
			sprite.scale = Vector2(1.5, 1.65)
