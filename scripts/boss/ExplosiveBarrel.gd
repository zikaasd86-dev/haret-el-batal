extends Area2D
## برميل متفجر كبير وواضح يقذفه الزعيم باتجاه منطقة البطل بمسار قوسي عشوائي

const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")

@export var gravity: float = 340.0
@export var blast_radius: float = 32.0

var velocity: Vector2 = Vector2(-140.0, -180.0)
var _exploded: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 16 # EnemyBullet
	collision_mask = 2   # Player
	body_entered.connect(_on_body_entered)
	sprite.scale = Vector2(1.8, 1.8)
	sprite.texture = ProceduralArt.create_texture("explosive_barrel_v2", PackedStringArray([
		"..000000..",
		".066ff660.",
		"0dddddddd0",
		"0de6666ed0",
		"0de6ff6ed0",
		"0dddddddd0",
		"0de6666ed0",
		"0dddddddd0",
		".06666660.",
		"..000000..",
	]))


func setup(origin: Vector2, initial_vel: Vector2) -> void:
	global_position = origin
	velocity = initial_vel


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	velocity.y += gravity * delta
	position += velocity * delta
	sprite.rotation += -7.0 * delta

	if global_position.y >= 156.0:
		_explode()


func _on_body_entered(body: Node2D) -> void:
	if _exploded:
		return
	if body.is_in_group("player"):
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	var exp_fx := EXPLOSION_SCENE.instantiate()
	exp_fx.global_position = global_position
	exp_fx.max_radius = 28.0
	exp_fx.particle_count = 14
	get_tree().current_scene.add_child(exp_fx)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.distance_to(global_position) <= blast_radius:
		if player.has_method("take_damage"):
			player.take_damage(1)

	GameState.request_shake(3.8, 0.20)
	GameState.vibrate(50)
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("explode")

	queue_free()
