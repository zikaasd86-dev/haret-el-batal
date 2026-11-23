extends Area2D
## رصاصة عامة تدعم طلقات البطل وطلقات الأعداء/الزعيم
## Shared bullet script for both Player and Enemy/Boss projectiles

@export var speed: float = 240.0
@export var damage: int = 1
@export var lifetime: float = 1.6
@export var is_enemy_bullet: bool = false
@export var weapon_style: int = 0 # 0=رشاش، 1=متفرق، 2=ثقيل

var direction: Vector2 = Vector2.RIGHT
var _timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_configure_collision()
	_configure_visual()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(pos: Vector2, dir: Vector2, enemy_bullet: bool = false, custom_speed: float = -1.0, custom_damage: int = 1, style: int = 0) -> void:
	global_position = pos
	direction = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	is_enemy_bullet = enemy_bullet
	damage = custom_damage
	weapon_style = style
	if custom_speed > 0.0:
		speed = custom_speed


func _configure_collision() -> void:
	if is_enemy_bullet:
		# طبقة 5 (EnemyBullet) تصطدم بطبقة 1 (World) وطبقة 2 (Player)
		collision_layer = 16
		collision_mask = 1 | 2
	else:
		# طبقة 4 (PlayerBullet) تصطدم بطبقة 1 (World) وطبقة 3 (Enemy)
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
		# طلقات متفرقة (Spread)
		sprite.texture = ProceduralArt.create_texture("bullet_spread", PackedStringArray([
			".36.",
			"3ff6",
			"6ff3",
			".63.",
		]))
	elif weapon_style == 2:
		# شعاع ثقيل (Heavy)
		sprite.texture = ProceduralArt.create_texture("bullet_heavy", PackedStringArray([
			".aaaa.",
			"affffa",
			"affffa",
			".aaaa.",
		]))
		rotation = direction.angle()
	else:
		# رشاش افتراضي
		sprite.texture = ProceduralArt.create_texture("bullet_player", PackedStringArray([
			".66.",
			"6ff6",
			"6ff6",
			".66.",
		]))


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		# تجنب إصابة مطلق الرصاصة لنفسه
		var parent := area.get_parent()
		if is_enemy_bullet and parent.is_in_group("player"):
			parent.take_damage(damage)
			queue_free()
		elif (not is_enemy_bullet) and (parent.is_in_group("enemy") or parent.is_in_group("boss")):
			parent.take_damage(damage)
			queue_free()
