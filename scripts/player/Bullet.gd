extends Area2D
## رصاصة عامة تدعم طلقات الأعداء و6 أسلحة أصلية للبطل + مدفع Z الخارق
## Styles: 0=Rifle, 1=Spread, 2=Heavy, 3=Wave, 4=Flame, 5=Missile, 6=Z-Beam

const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")

@export var speed: float = 240.0
@export var damage: int = 1
@export var lifetime: float = 1.6
@export var is_enemy_bullet: bool = false
@export var weapon_style: int = 0

var direction: Vector2 = Vector2.RIGHT
var wave_sign: float = 1.0
var _timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_configure_collision()
	_configure_visual()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(pos: Vector2, dir: Vector2, enemy_bullet: bool = false, custom_speed: float = -1.0, custom_damage: int = 1, style: int = 0, w_sign: float = 1.0, custom_lifetime: float = -1.0) -> void:
	global_position = pos
	direction = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	is_enemy_bullet = enemy_bullet
	damage = custom_damage
	weapon_style = style
	wave_sign = w_sign
	if custom_speed > 0.0:
		speed = custom_speed
	if custom_lifetime > 0.0:
		lifetime = custom_lifetime


func _configure_collision() -> void:
	if is_enemy_bullet:
		collision_layer = 16
		collision_mask = 1 | 2
	else:
		collision_layer = 8
		collision_mask = 1 | 4


func _configure_visual() -> void:
	if is_enemy_bullet:
		sprite.texture = ProceduralArt.create_texture("bullet_enemy", PackedStringArray([
			".de.",
			"defd",
			"dfed",
			".ed.",
		]))
	elif weapon_style == 1:
		sprite.texture = ProceduralArt.create_texture("bullet_spread", PackedStringArray([
			".36.",
			"3ff6",
			"6ff3",
			".63.",
		]))
	elif weapon_style == 2:
		sprite.texture = ProceduralArt.create_texture("bullet_heavy", PackedStringArray([
			".aaaa.",
			"affffa",
			"affffa",
			".aaaa.",
		]))
		rotation = direction.angle()
	elif weapon_style == 3:
		# شعاع متموج (Wave)
		sprite.texture = ProceduralArt.create_texture("bullet_wave", PackedStringArray([
			".6f6.",
			"6fff6",
			".6f6.",
		]))
	elif weapon_style == 4:
		# شرار ناري (Flame Burst)
		sprite.texture = ProceduralArt.create_texture("bullet_flame", PackedStringArray([
			".e6e.",
			"e6f6e",
			"6fff6",
			".e6e.",
		]))
	elif weapon_style == 5:
		# صاروخ متفجر (Missile)
		sprite.texture = ProceduralArt.create_texture("bullet_missile", PackedStringArray([
			"..000000..",
			".0dbbbbfe0.",
			"0deffffffe0",
			".0dbbbbfe0.",
			"..000000..",
		]))
		rotation = direction.angle()
	elif weapon_style == 6:
		# شعاع طاقة خارق لمدفع Z
		sprite.texture = ProceduralArt.create_texture("bullet_z_beam", PackedStringArray([
			"...00000000...",
			"..06ffffff60..",
			".06ffffffff60.",
			"066ffffffff660",
			"066ffffffff660",
			".06ffffffff60.",
			"..06ffffff60..",
			"...00000000...",
		]))
		rotation = direction.angle()
		scale = Vector2(1.8, 1.6)
	else:
		sprite.texture = ProceduralArt.create_texture("bullet_player", PackedStringArray([
			".66.",
			"6ff6",
			"6ff6",
			".66.",
		]))


func _physics_process(delta: float) -> void:
	_timer += delta
	var move_vec := direction * speed * delta
	if (not is_enemy_bullet) and weapon_style == 3:
		# حركة موجية (Sine Wave) متعامدة على اتجاه الطلقة
		var perp := Vector2(-direction.y, direction.x)
		move_vec += perp * cos(_timer * 26.0) * 110.0 * wave_sign * delta
	position += move_vec
	if _timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	if not is_enemy_bullet and weapon_style == 6 and body.is_in_group("enemy"):
		var exp_fx := EXPLOSION_SCENE.instantiate()
		exp_fx.global_position = global_position
		get_tree().current_scene.add_child(exp_fx)
		return
	if not is_enemy_bullet and (weapon_style == 5 or weapon_style == 6):
		var exp_fx := EXPLOSION_SCENE.instantiate()
		exp_fx.global_position = global_position
		get_tree().current_scene.add_child(exp_fx)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		if not is_enemy_bullet and (weapon_style == 5 or weapon_style == 6):
			var exp_fx := EXPLOSION_SCENE.instantiate()
			exp_fx.global_position = global_position
			get_tree().current_scene.add_child(exp_fx)
		if not is_enemy_bullet and weapon_style == 6:
			return
		queue_free()
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		var parent := area.get_parent()
		if is_enemy_bullet and parent.is_in_group("player"):
			parent.take_damage(damage)
			queue_free()
		elif (not is_enemy_bullet) and (parent.is_in_group("enemy") or parent.is_in_group("boss")):
			parent.take_damage(damage)
			if weapon_style == 5 or weapon_style == 6:
				var exp_fx := EXPLOSION_SCENE.instantiate()
				exp_fx.global_position = global_position
				get_tree().current_scene.add_child(exp_fx)
			if weapon_style == 6:
				return
			queue_free()
